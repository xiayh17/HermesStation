import Foundation
import AppKit
import Combine

@MainActor
final class GatewayStore: ObservableObject {
    @Published private(set) var snapshot: GatewaySnapshot = .empty
    @Published var isBusy: Bool = false
    @Published var updater: HermesUpdater

    let settingsStore: SettingsStore
    let profileStore: HermesProfileStore

    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    nonisolated(unsafe) private static var lastAutoRestartDate: Date?

    init(settingsStore: SettingsStore, profileStore: HermesProfileStore) {
        self.settingsStore = settingsStore
        self.profileStore = profileStore
        self.updater = HermesUpdater(settings: settingsStore.settings)
        bindUpdater()
        refresh()
        configureTimer()
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.updater = HermesUpdater(settings: settingsStore.settings)
                self?.bindUpdater()
                self?.configureTimer()
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func bindUpdater() {
        updater.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        let previousOutput = snapshot.lastCommandOutput
        let previousDoctorReport = snapshot.doctorReport
        let settings = settingsStore.settings

        refreshTask?.cancel()
        refreshTask = Task(priority: .utility) { [weak self] in
            let snapshot = await Self.makeSnapshot(
                settings: settings,
                previousOutput: previousOutput,
                previousDoctorReport: previousDoctorReport
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.snapshot = snapshot
                self?.performAutoRestartIfNeeded()
            }
        }
    }

    private func performAutoRestartIfNeeded() {
        guard snapshot.runtimeIsStale,
              settingsStore.settings.autoRestartOnStaleRuntime else { return }
        let minInterval: TimeInterval = 60
        if let last = Self.lastAutoRestartDate, Date().timeIntervalSince(last) < minInterval {
            return
        }
        Self.lastAutoRestartDate = Date()
        snapshot.lastCommandOutput = "Runtime stale detected. Auto-restarting gateway..."
        restartService()
    }

    func installService() {
        performGatewayAction(["install"])
    }

    func installOrRepairService() {
        performGatewayAction(["install"])
    }

    func startService() {
        performGatewayAction(["start"])
    }

    func stopService() {
        performGatewayAction(["stop"])
    }

    func restartService() {
        performGatewayAction(["restart"])
    }

    func runDoctorFix() {
        guard !isBusy else { return }
        isBusy = true
        let settings = settingsStore.settings
        Task {
            defer {
                Task { @MainActor in self.isBusy = false }
            }
            do {
                let result = try await CommandRunner.runHermes(settings, ["doctor", "--fix"])
                let report = HermesDoctorReport.parse(
                    output: result.combinedOutput,
                    exitStatus: result.status,
                    profileName: settings.profileName
                )
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput
                    self.snapshot.doctorReport = report
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = error.localizedDescription
                    self.snapshot.doctorReport = HermesDoctorReport.parse(
                        output: error.localizedDescription,
                        exitStatus: 1,
                        profileName: self.settingsStore.settings.profileName
                    )
                    self.refresh()
                }
            }
        }
    }

    func useCurrentHermesProfile() {
        performHermesAction(["profile", "use", settingsStore.settings.profileName])
    }

    func installPythonPackage(packageName: String, label: String, restartGatewayAfterInstall: Bool) {
        guard !isBusy else { return }
        isBusy = true
        let settings = settingsStore.settings
        Task {
            do {
                let paths = HermesPaths(settings: settings)
                guard FileManager.default.isExecutableFile(atPath: paths.pythonExecutable.path) else {
                    throw NSError(
                        domain: "HermesStation",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Hermes Python executable not found at \(paths.pythonExecutable.path)"]
                    )
                }

                let result = try await CommandRunner.run(paths.pythonExecutable.path, ["-m", "pip", "install", packageName])
                await MainActor.run {
                    self.isBusy = false
                    if result.status == 0 {
                        let detail = result.combinedOutput.isEmpty ? "" : "\n\(result.combinedOutput)"
                        self.snapshot.lastCommandOutput = "Installed \(label).\(detail)"
                        self.refresh()
                        if restartGatewayAfterInstall {
                            self.restartService()
                        }
                    } else {
                        self.snapshot.lastCommandOutput = "Failed to install \(label): \(result.combinedOutput)"
                        self.refresh()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.snapshot.lastCommandOutput = "Failed to install \(label): \(error.localizedDescription)"
                    self.refresh()
                }
            }
        }
    }

    func openLogs() {
        Task { _ = try? await CommandRunner.openPath(paths.logsDir) }
    }

    func openTranscript(for session: SessionRow) {
        Task {
            guard FileManager.default.fileExists(atPath: session.transcriptURL.path) else {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Transcript not found for session \(session.id)"
                }
                return
            }
            _ = try? await CommandRunner.openPath(session.transcriptURL)
        }
    }

    func openTranscript(for session: AgentSessionRow) {
        let row = SessionRow(id: session.id, title: session.title, updatedAt: session.startedAtText, transcriptURL: session.transcriptURL)
        openTranscript(for: row)
    }

    func openLogExcerpt(for session: SessionRow) {
        Task {
            do {
                let fileURL = try createLogExcerpt(for: session.id)
                _ = try await CommandRunner.openPath(fileURL)
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Failed to prepare logs for \(session.id): \(error.localizedDescription)"
                }
            }
        }
    }

    func openLogExcerpt(for session: AgentSessionRow) {
        let row = SessionRow(id: session.id, title: session.title, updatedAt: session.startedAtText, transcriptURL: session.transcriptURL)
        openLogExcerpt(for: row)
    }

    func renameAgentSession(id: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            snapshot.lastCommandOutput = "Title cannot be empty."
            return
        }
        performHermesAction(["sessions", "rename", id, trimmed])
    }

    func deleteAgentSession(id: String) {
        performHermesAction(["sessions", "delete", "--yes", id])
    }

    func exportAgentSession(id: String) {
        Task {
            do {
                let exportDir = paths.hermesHome.appending(path: "exports", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
                let out = exportDir.appending(path: "session-\(id).jsonl")
                let result = try await CommandRunner.runHermes(settingsStore.settings, ["sessions", "export", "--session-id", id, out.path])
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput.isEmpty ? "Exported \(id) to \(out.path)" : result.combinedOutput
                }
                _ = try? await CommandRunner.openPath(out)
                await MainActor.run {
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = error.localizedDescription
                }
            }
        }
    }

    func openGatewayLog() {
        Task { _ = try? await CommandRunner.openPath(paths.logsDir.appending(path: "gateway.log")) }
    }

    func openGatewayErrorLog() {
        Task { _ = try? await CommandRunner.openPath(paths.logsDir.appending(path: "gateway.error.log")) }
    }

    func openAuthStore() {
        Task { _ = try? await CommandRunner.openPath(paths.authStore) }
    }

    func openLatestRequestDump() {
        guard let url = paths.latestRequestDumpURL() else {
            snapshot.lastCommandOutput = "No request_dump JSON found in \(paths.sessionsDir.path)"
            return
        }
        Task { _ = try? await CommandRunner.openPath(url) }
    }

    func syncCredentialPoolBaseURL(
        providerID: String,
        desiredBaseURL: String,
        apiKey: String,
        restartAfter: Bool = false
    ) {
        let trimmedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedBaseURL = desiredBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProviderID.isEmpty, !trimmedBaseURL.isEmpty else {
            snapshot.lastCommandOutput = "Missing provider or target base URL for auth pool sync."
            return
        }

        do {
            var root: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: paths.authStore.path),
               let data = try? Data(contentsOf: paths.authStore),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                root = json
            }

            var credentialPool = root["credential_pool"] as? [String: Any] ?? [:]
            var entries = credentialPool[trimmedProviderID] as? [[String: Any]] ?? []
            let descriptor = HermesProviderDescriptor.resolve(trimmedProviderID)
            let envVarCandidates = Set(descriptor?.apiKeyEnvVars ?? [])
            let sourceCandidates = Set(envVarCandidates.map { "env:\($0)" })

            var updated = false
            var matchedEntry = false

            for index in entries.indices {
                let source = (entries[index]["source"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let label = (entries[index]["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let shouldUpdate = sourceCandidates.contains(source) || envVarCandidates.contains(label)
                guard shouldUpdate else { continue }
                matchedEntry = true

                let currentBaseURL = (entries[index]["base_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if currentBaseURL != trimmedBaseURL {
                    entries[index]["base_url"] = trimmedBaseURL
                    updated = true
                }
                if let primaryEnvVar = descriptor?.primaryAPIKeyEnvVar {
                    if label.isEmpty {
                        entries[index]["label"] = primaryEnvVar
                        updated = true
                    }
                    if source.isEmpty {
                        entries[index]["source"] = "env:\(primaryEnvVar)"
                        updated = true
                    }
                }
                if !trimmedAPIKey.isEmpty && (entries[index]["access_token"] as? String ?? "").isEmpty {
                    entries[index]["access_token"] = trimmedAPIKey
                    updated = true
                }
            }

            if !matchedEntry, let primaryEnvVar = descriptor?.primaryAPIKeyEnvVar, !trimmedAPIKey.isEmpty {
                let nextPriority = entries.compactMap { $0["priority"] as? Int }.max().map { $0 + 1 } ?? 0
                entries.append([
                    "id": String(UUID().uuidString.prefix(6)).lowercased(),
                    "label": primaryEnvVar,
                    "auth_type": "api_key",
                    "priority": nextPriority,
                    "source": "env:\(primaryEnvVar)",
                    "access_token": trimmedAPIKey,
                    "base_url": trimmedBaseURL,
                    "request_count": 0,
                ])
                updated = true
            }

            if !updated {
                snapshot.lastCommandOutput = "Auth pool already matches \(trimmedBaseURL)."
                if restartAfter {
                    restartService()
                }
                refresh()
                return
            }

            credentialPool[trimmedProviderID] = entries
            root["version"] = root["version"] ?? 1
            root["credential_pool"] = credentialPool
            root["updated_at"] = ISO8601DateFormatter().string(from: Date())

            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: paths.authStore, options: .atomic)
            snapshot.lastCommandOutput = "Synced auth.json credential_pool[\(trimmedProviderID)] -> \(trimmedBaseURL)."
            refresh()
            if restartAfter {
                restartService()
            }
        } catch {
            snapshot.lastCommandOutput = "Failed to sync auth.json: \(error.localizedDescription)"
        }
    }

    func openWorkspace() {
        let workspaceURL = profileStore.snapshot.workspaceURL ?? paths.workspaceRoot
        Task { _ = try? await CommandRunner.openPath(workspaceURL) }
    }

    func openHermesHome() {
        Task { _ = try? await CommandRunner.openPath(paths.hermesHome) }
    }

    func openHermesRoot() {
        Task { _ = try? await CommandRunner.openPath(paths.hermesRoot) }
    }

    func openLatestReleasePage() {
        guard let url = snapshot.releaseInfo?.releaseURL else {
            snapshot.lastCommandOutput = "No release URL available."
            return
        }
        Task { _ = try? await CommandRunner.openPath(url) }
    }

    func runHermesUpdate() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer {
                Task { @MainActor in self.isBusy = false }
            }
            do {
                let result = try await CommandRunner.runHermes(settingsStore.settings, ["update"])
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput.isEmpty ? "Hermes update completed." : result.combinedOutput
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Update failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func applyPreparedUpdate() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer {
                Task { @MainActor in self.isBusy = false }
            }
            let error = await updater.applyUpdate()
            await MainActor.run {
                if let error {
                    self.snapshot.lastCommandOutput = error
                } else {
                    self.snapshot.lastCommandOutput = "Update applied and gateway restarted."
                }
                self.refresh()
            }
        }
    }

    func killGateway(pid: Int) {
        guard pid > 0 else { return }
        Task {
            do {
                let result = try await CommandRunner.run("/bin/kill", ["-9", "\(pid)"])
                await MainActor.run {
                    if result.status == 0 {
                        self.snapshot.lastCommandOutput = "Killed gateway PID \(pid)."
                    } else {
                        self.snapshot.lastCommandOutput = "Failed to kill PID \(pid): \(result.combinedOutput)"
                    }
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Failed to kill PID \(pid): \(error.localizedDescription)"
                    self.refresh()
                }
            }
        }
    }

    func promoteToAuthoritative(pid: Int) {
        guard pid > 0 else { return }
        let url = paths.gatewayPID
        do {
            var json: [String: Any] = ["pid": pid, "kind": "hermes-gateway"]
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = existing
                json["pid"] = pid
            }
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            snapshot.lastCommandOutput = "Promoted PID \(pid) to authoritative gateway."
            refresh()
        } catch {
            snapshot.lastCommandOutput = "Failed to promote PID \(pid): \(error.localizedDescription)"
        }
    }

    func killDuplicateGateways() {
        let processes = snapshot.gatewayProcesses
        guard processes.count > 1 else { return }
        let keptPID = snapshot.authoritativeGatewayPID
        let targets = processes.filter { $0.id != keptPID }.map(\.id)
        guard !targets.isEmpty else { return }

        Task {
            var killed: [Int] = []
            var failed: [Int] = []
            for pid in targets {
                do {
                    let result = try await CommandRunner.run("/bin/kill", ["-9", "\(pid)"])
                    if result.status == 0 {
                        killed.append(pid)
                    } else {
                        failed.append(pid)
                    }
                } catch {
                    failed.append(pid)
                }
            }
            await MainActor.run {
                var parts: [String] = []
                if !killed.isEmpty {
                    parts.append("Killed rogue gateway PIDs: \(killed.map(String.init).joined(separator: ", "))")
                }
                if !failed.isEmpty {
                    parts.append("Failed to kill PIDs: \(failed.map(String.init).joined(separator: ", "))")
                }
                self.snapshot.lastCommandOutput = parts.joined(separator: "\n")
                self.refresh()
            }
        }
    }

    func submitPendingAction(type: String, sessionKey: String) {
        let action: [String: Any] = [
            "type": type,
            "session_key": sessionKey,
        ]
        let url = paths.gatewayActions
        do {
            var existing: [String: Any] = ["actions": []]
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existing = json
            }
            var actions = existing["actions"] as? [[String: Any]] ?? []
            actions.append(action)
            existing["actions"] = actions
            let data = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted])
            try data.write(to: url, options: .atomic)
            snapshot.lastCommandOutput = "Submitted \(type) for \(sessionKey). Gateway will process it within ~30s."
        } catch {
            snapshot.lastCommandOutput = "Failed to submit action: \(error.localizedDescription)"
        }
    }

    private func performGatewayAction(_ args: [String]) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer {
                Task { @MainActor in self.isBusy = false }
            }
            do {
                let result = try await CommandRunner.runGateway(settingsStore.settings, args)
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = error.localizedDescription
                    self.refresh()
                }
            }
        }
    }

    private func performHermesAction(_ args: [String]) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer {
                Task { @MainActor in self.isBusy = false }
            }
            do {
                let result = try await CommandRunner.runHermes(settingsStore.settings, args)
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = error.localizedDescription
                    self.refresh()
                }
            }
        }
    }

    nonisolated private static func makeSnapshot(
        settings: AppSettings,
        previousOutput: String?,
        previousDoctorReport: HermesDoctorReport?
    ) async -> GatewaySnapshot {
        let paths = HermesPaths(settings: settings)
        let plistExists = FileManager.default.fileExists(atPath: paths.launchAgentPlist.path)
        let launchctlLoaded = await readLaunchdLoaded(label: paths.launchAgentLabel)
        let launchdPID = await readLaunchdPID(label: paths.launchAgentLabel)
        let runtime = readRuntimeStatus(at: paths.gatewayState)
        let pidFilePID = readGatewayPID(at: paths.gatewayPID)
        let gatewayProcesses = await readGatewayProcesses(settings: settings, launchdPID: launchdPID)
        let endpointTransparency = loadEndpointTransparency(paths: paths)
        let agentSessions = SQLiteSessionStore.loadAgents(from: paths.stateDB, paths: paths)
        let sessionBindings = SessionBindingStore.load(from: paths.sessionBindingsURL)
        let recentAgentActivityCount = computeRecentAgentActivityCount(
            sessions: agentSessions.rows,
            bindings: sessionBindings
        )
        let usage = SQLiteSessionStore.loadUsage(from: paths.stateDB)
        let sessions = SessionSummary(
            totalCount: agentSessions.totalCount,
            recent: agentSessions.rows.prefix(5).map {
                SessionRow(id: $0.id, title: $0.title, updatedAt: $0.startedAtText, transcriptURL: $0.transcriptURL)
            }
        )

        let duplicateGatewayPIDs = gatewayProcesses.map(\.id)
        let authoritativeGatewayPID = resolveAuthoritativeGatewayPID(
            launchdPID: launchdPID,
            liveGatewayPIDs: duplicateGatewayPIDs,
            pidFilePID: pidFilePID
        )
        let runtimeStaleReason = computeRuntimeStaleReason(
            runtime: runtime,
            authoritativeGatewayPID: authoritativeGatewayPID
        )
        let runtimeIsStale = runtimeStaleReason != nil

        let enrichedProcesses = gatewayProcesses.map {
            GatewayProcessInfo(
                id: $0.id,
                command: $0.command,
                startTime: $0.startTime,
                isLaunchdManaged: $0.isLaunchdManaged,
                isAuthoritative: $0.id == authoritativeGatewayPID
            )
        }

        let serviceStatus: ServiceStatus
        if enrichedProcesses.count > 1 {
            serviceStatus = .degraded
        } else if authoritativeGatewayPID != nil {
            let states = (runtimeIsStale ? nil : runtime)?.platforms.values.compactMap { $0.state } ?? []
            if states.contains(where: { $0 != "connected" }) {
                serviceStatus = .degraded
            } else {
                serviceStatus = .running
            }
        } else if launchctlLoaded {
            serviceStatus = .degraded
        } else if plistExists {
            serviceStatus = .stopped
        } else {
            serviceStatus = .unknown
        }

        if settings.autoCleanupDuplicateGateways,
           enrichedProcesses.count > 1,
           let keptPID = authoritativeGatewayPID {
            let targets = enrichedProcesses.filter { $0.id != keptPID }.map(\.id)
            for pid in targets {
                _ = try? await CommandRunner.run("/bin/kill", ["-9", "\(pid)"])
            }
        }

        let releaseInfo = await loadReleaseInfo(settings: settings)
        let aliases = loadAliasScripts(settings: settings)
        let profileAlignment = loadProfileAlignment(settings: settings, paths: paths)
        let doctorReport = previousDoctorReport?.profileName == settings.profileName ? previousDoctorReport : nil

        return GatewaySnapshot(
            serviceInstalled: plistExists,
            serviceLoaded: launchctlLoaded,
            serviceStatus: serviceStatus,
            runtime: runtime,
            authoritativeGatewayPID: authoritativeGatewayPID,
            pidFilePID: pidFilePID,
            runtimeIsStale: runtimeIsStale,
            runtimeStaleReason: runtimeStaleReason,
            duplicateGatewayPIDs: enrichedProcesses.map(\.id),
            gatewayProcesses: enrichedProcesses,
            endpointTransparency: endpointTransparency,
            releaseInfo: releaseInfo,
            aliases: aliases,
            profileAlignment: profileAlignment,
            doctorReport: doctorReport,
            sessions: sessions,
            agentSessions: agentSessions,
            sessionBindings: sessionBindings,
            recentAgentActivityCount: recentAgentActivityCount,
            usage: usage,
            lastCommandOutput: previousOutput
        )
    }

    nonisolated private static func loadProfileAlignment(settings: AppSettings, paths: HermesPaths) -> HermesProfileAlignment {
        let stickyURL = paths.hermesRoot.appending(path: "active_profile")
        let stickyProfile = (try? String(contentsOf: stickyURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return HermesProfileAlignment(
            expectedProfile: settings.profileName,
            stickyProfile: stickyProfile,
            hermesRootPath: paths.hermesRoot.path,
            profileHomePath: paths.hermesHome.path
        )
    }

    nonisolated private static func loadReleaseInfo(settings: AppSettings) async -> HermesReleaseInfo {
        let current = await readInstalledHermesVersion(settings: settings)
        let (release, error) = await fetchLatestHermesRelease()
        let global = await resolveGlobalHermes(settings: settings)

        if let release = release {
            let currentTag = extractTag(from: current)
            let latestTag = release.tagName
            let isUpdate: Bool = {
                guard let ct = currentTag else { return false }
                return ct != latestTag
            }()
            return HermesReleaseInfo(
                currentVersion: current,
                currentTag: currentTag,
                latestVersion: release.name ?? release.tagName,
                latestTag: latestTag,
                releaseURL: release.htmlUrl.flatMap { URL(string: $0) },
                publishedAt: release.publishedAt,
                body: release.body,
                isUpdateAvailable: isUpdate,
                globalHermesPath: global.path,
                globalHermesTarget: global.target,
                globalHermesVersion: global.version,
                isGlobalHermesMatching: global.isMatching,
                fetchError: nil
            )
        } else {
            return HermesReleaseInfo(
                currentVersion: current,
                currentTag: extractTag(from: current),
                latestVersion: nil,
                latestTag: nil,
                releaseURL: nil,
                publishedAt: nil,
                body: nil,
                isUpdateAvailable: false,
                globalHermesPath: global.path,
                globalHermesTarget: global.target,
                globalHermesVersion: global.version,
                isGlobalHermesMatching: global.isMatching,
                fetchError: error
            )
        }
    }

    nonisolated private static func resolveGlobalHermes(settings: AppSettings) async -> (path: String?, target: String?, version: String?, isMatching: Bool) {
        let paths = HermesPaths(settings: settings)
        let expected = paths.launcher.path
        let legacyExpected = paths.projectRoot.appending(path: "hermes-agent/venv/bin/hermes").path
        let whichResult = try? await CommandRunner.run("/usr/bin/which", ["hermes"])
        guard whichResult?.status == 0 else {
            return (nil, nil, nil, false)
        }
        let path = whichResult!.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let readlinkResult = try? await CommandRunner.run("/usr/bin/readlink", [path])
        let target = readlinkResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? path
        let versionResult = try? await CommandRunner.run(path, ["--version"])
        let version = versionResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMatching = target == expected || path == expected
        if !isMatching, target == legacyExpected || path == legacyExpected {
            return (path, target, version, false)
        }
        return (path, target, version, isMatching)
    }

    nonisolated private static func loadAliasScripts(settings: AppSettings) -> [HermesAliasScript] {
        let wrapperDir = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: wrapperDir.path) else {
            return []
        }
        let profilePattern = "-p \(settings.profileName)"
        let launcherPattern = settings.launcherPath
        return entries.compactMap { name in
            let filePath = wrapperDir.appending(path: name).path
            guard FileManager.default.isExecutableFile(atPath: filePath),
                  let data = FileManager.default.contents(atPath: filePath),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            let refersToProfile = text.contains(profilePattern) || text.contains(launcherPattern)
            guard refersToProfile else { return nil }
            let standard = "#!/bin/sh\nexec hermes -p \(settings.profileName) \"$@\"\n"
            return HermesAliasScript(
                id: name,
                name: name,
                path: filePath,
                content: text,
                isStandard: text.trimmingCharacters(in: .whitespacesAndNewlines) == standard.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        .sorted { $0.name < $1.name }
    }

    func createAlias(name: String) {
        guard !name.isEmpty else {
            snapshot.lastCommandOutput = "Alias name cannot be empty."
            return
        }
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { Task { @MainActor in self.isBusy = false } }
            let args: [String] = ["profile", "alias", settingsStore.settings.profileName, "--name", name]
            do {
                let result = try await CommandRunner.runHermes(settingsStore.settings, args)
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput.isEmpty ? "Created alias '\(name)'." : result.combinedOutput
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Failed to create alias: \(error.localizedDescription)"
                }
            }
        }
    }

    func removeAlias(name: String) {
        guard !name.isEmpty else { return }
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { Task { @MainActor in self.isBusy = false } }
            let args: [String] = ["profile", "alias", settingsStore.settings.profileName, "--remove", "--name", name]
            do {
                let result = try await CommandRunner.runHermes(settingsStore.settings, args)
                await MainActor.run {
                    self.snapshot.lastCommandOutput = result.combinedOutput.isEmpty ? "Removed alias '\(name)'." : result.combinedOutput
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.snapshot.lastCommandOutput = "Failed to remove alias: \(error.localizedDescription)"
                }
            }
        }
    }

    nonisolated private static func readInstalledHermesVersion(settings: AppSettings) async -> String? {
        guard let result = try? await CommandRunner.runHermes(settings, ["--version"]), result.status == 0 else {
            return nil
        }
        let firstLine = result.stdout.split(separator: "\n").first.map(String.init) ?? result.stdout
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func fetchLatestHermesRelease() async -> (release: GitHubRelease?, error: String?) {
        let url = URL(string: "https://api.github.com/repos/NousResearch/hermes-agent/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("HermesStation/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Invalid response from GitHub")
            }
            guard http.statusCode == 200 else {
                return (nil, "GitHub HTTP \(http.statusCode)")
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            return (release, nil)
        } catch let decodingError as DecodingError {
            return (nil, "Decode error: \(decodingError.localizedDescription)")
        } catch {
            return (nil, "Network error: \(error.localizedDescription)")
        }
    }

    nonisolated private static func extractTag(from versionLine: String?) -> String? {
        guard let line = versionLine else { return nil }
        // Match patterns like v2026.4.16 or v0.10.0 from strings like:
        // "Hermes Agent v0.9.0 (2026.4.13)" or "v2026.4.16"
        let pattern = #"v\d+(\.\d+)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        if let range = Range(match.range, in: line) {
            return String(line[range])
        }
        return nil
    }

    nonisolated private static func loadEndpointTransparency(paths: HermesPaths) -> EndpointTransparencySnapshot? {
        let configValues = HermesProfileStore.parseConfigValues(from: paths.configURL)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let provider = configValues["model.provider"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = configValues["model.default"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? configValues["model.name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        guard !provider.isEmpty || !model.isEmpty else { return nil }

        let descriptor = HermesProviderDescriptor.resolve(provider)
        let configBaseURL = normalizedOptionalURL(configValues["model.base_url"])
        let envBaseURLKey = descriptor?.baseURLEnvVar
        let envBaseURL = normalizedOptionalURL(envBaseURLKey.flatMap { envValues[$0] })
        let credentialPoolEntries = loadCredentialPoolEntries(from: paths.authStore, provider: provider)
        let latestRequestDump = loadLatestRequestDump(from: paths.latestRequestDumpURL())
        let isThirdPartyAnthropicRoute = isThirdPartyAnthropicRoute(provider: provider, configBaseURL: configBaseURL)

        let canonical = canonicalSourceURL(
            latestRequestBaseURL: latestRequestDump?.requestBaseURL,
            credentialPoolEntries: credentialPoolEntries,
            envBaseURL: envBaseURL,
            configBaseURL: configBaseURL,
            isThirdPartyAnthropicRoute: isThirdPartyAnthropicRoute
        )

        let sourceRows: [EndpointSourceSnapshot] = [
            EndpointSourceSnapshot(
                label: "config.yaml → model.base_url",
                value: configBaseURL,
                detail: configBaseURL == nil ? "empty" : nil,
                isMismatch: isMismatch(value: configBaseURL, canonical: canonical)
            ),
            EndpointSourceSnapshot(
                label: envBaseURLKey.map { ".env → \($0)" } ?? ".env → provider base URL",
                value: envBaseURL,
                detail: envBaseURL == nil ? "unset" : nil,
                isMismatch: isMismatch(value: envBaseURL, canonical: canonical)
            ),
            EndpointSourceSnapshot(
                label: "auth.json → credential_pool",
                value: normalizedOptionalURL(credentialPoolEntries.first?.baseURL),
                detail: isThirdPartyAnthropicRoute
                    ? "\(credentialPoolEntries.first?.label ?? "no entry") • official Anthropic default, informational only"
                    : credentialPoolEntries.first.map { "\($0.label) • \($0.source ?? "unknown")" } ?? "no entry",
                isMismatch: isThirdPartyAnthropicRoute ? false : isMismatch(value: credentialPoolEntries.first?.baseURL, canonical: canonical)
            ),
            EndpointSourceSnapshot(
                label: "latest request dump",
                value: latestRequestDump?.requestURL,
                detail: latestRequestDump.map {
                    let base = [$0.reason, $0.errorType].compactMap { $0 }.joined(separator: " • ")
                    if isThirdPartyAnthropicRoute,
                       let requestBaseURL = $0.requestBaseURL,
                       let configBaseURL,
                       areEquivalentKimiCodingRoutes(requestBaseURL, configBaseURL) {
                        return "\(base) • previous Kimi route variant"
                    }
                    return base
                },
                isMismatch: isMismatch(value: latestRequestDump?.requestBaseURL, canonical: canonical)
            ),
        ]

        return EndpointTransparencySnapshot(
            provider: provider,
            model: model,
            configBaseURL: configBaseURL,
            envBaseURLKey: envBaseURLKey,
            envBaseURL: envBaseURL,
            credentialPoolEntries: credentialPoolEntries,
            latestRequestDump: latestRequestDump,
            sourceRows: sourceRows,
            isThirdPartyAnthropicRoute: isThirdPartyAnthropicRoute
        )
    }

    nonisolated private static func loadCredentialPoolEntries(from url: URL, provider: String) -> [CredentialPoolEntrySnapshot] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pool = json["credential_pool"] as? [String: Any] else {
            return []
        }

        let providerKey = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let entries = pool[providerKey] as? [[String: Any]] else { return [] }

        return entries.compactMap { entry in
            let id = (entry["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (entry["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let resolvedID = id, let resolvedLabel = label else { return nil }
            return CredentialPoolEntrySnapshot(
                id: resolvedID,
                label: resolvedLabel,
                source: entry["source"] as? String,
                baseURL: normalizedOptionalURL(entry["base_url"] as? String),
                requestCount: entry["request_count"] as? Int
            )
        }
        .sorted { lhs, rhs in
            let lhsCount = lhs.requestCount ?? .max
            let rhsCount = rhs.requestCount ?? .max
            if lhsCount == rhsCount {
                return lhs.label < rhs.label
            }
            return lhsCount < rhsCount
        }
    }

    nonisolated private static func loadLatestRequestDump(from url: URL?) -> LatestRequestDumpSnapshot? {
        guard let url,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let request = json["request"] as? [String: Any]
        let body = request?["body"] as? [String: Any]
        let response = json["response"] as? [String: Any]
        let error = response?["error"] as? [String: Any]

        return LatestRequestDumpSnapshot(
            fileURL: url,
            timestamp: json["timestamp"] as? String,
            reason: json["reason"] as? String,
            method: request?["method"] as? String,
            requestURL: normalizedOptionalURL(request?["url"] as? String),
            requestBaseURL: normalizedRequestBaseURL(request?["url"] as? String),
            model: body?["model"] as? String,
            errorType: error?["type"] as? String,
            errorMessage: error?["message"] as? String
        )
    }

    nonisolated private static func canonicalSourceURL(
        latestRequestBaseURL: String?,
        credentialPoolEntries: [CredentialPoolEntrySnapshot],
        envBaseURL: String?,
        configBaseURL: String?,
        isThirdPartyAnthropicRoute: Bool
    ) -> String? {
        if isThirdPartyAnthropicRoute, let configBaseURL {
            return configBaseURL
        }
        if let latestRequestBaseURL {
            return latestRequestBaseURL
        }
        if let poolURL = credentialPoolEntries.first?.baseURL {
            return poolURL
        }
        if let envBaseURL {
            return envBaseURL
        }
        return configBaseURL
    }

    nonisolated private static func normalizedOptionalURL(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func normalizedRequestBaseURL(_ value: String?) -> String? {
        guard var normalized = normalizedOptionalURL(value) else { return nil }
        let knownSuffixes = [
            "/chat/completions",
            "/responses",
            "/v1/messages",
            "/messages",
            "/models",
        ]
        for suffix in knownSuffixes where normalized.hasSuffix(suffix) {
            normalized.removeLast(suffix.count)
            return normalizedOptionalURL(normalized)
        }
        return normalized
    }

    nonisolated private static func isMismatch(value: String?, canonical: String?) -> Bool {
        guard let canonical else { return false }
        guard let normalized = normalizedOptionalURL(value) else { return false }
        if areEquivalentKimiCodingRoutes(normalized, canonical) {
            return false
        }
        return normalized != canonical
    }

    nonisolated private static func isThirdPartyAnthropicRoute(provider: String, configBaseURL: String?) -> Bool {
        let normalizedProvider = HermesProviderDescriptor.resolve(provider)?.id
            ?? provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedProvider == "anthropic", let configBaseURL else { return false }
        return !configBaseURL.lowercased().contains("api.anthropic.com")
    }

    nonisolated private static func areEquivalentKimiCodingRoutes(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = normalizedOptionalURL(lhs)?.lowercased()
        let normalizedRHS = normalizedOptionalURL(rhs)?.lowercased()
        let equivalents = Set([
            "https://api.kimi.com/coding",
            "https://api.kimi.com/coding/v1"
        ])
        guard let normalizedLHS, let normalizedRHS else { return false }
        return equivalents.contains(normalizedLHS) && equivalents.contains(normalizedRHS)
    }

    nonisolated private static func readRuntimeStatus(at url: URL) -> RuntimeStatus? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RuntimeStatus.self, from: data)
    }

    nonisolated private static func readGatewayPID(at url: URL) -> Int? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pid = json["pid"] as? Int else {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }
        return pid
    }

    nonisolated private static func readLaunchdLoaded(label: String) async -> Bool {
        if let result = try? await CommandRunner.runLaunchctl(["list", label]) {
            return result.status == 0
        }
        return false
    }

    nonisolated private static func readLaunchdPID(label: String) async -> Int? {
        guard let result = try? await CommandRunner.runLaunchctl(["print", "gui/501/\(label)"]), result.status == 0 else {
            return nil
        }

        for rawLine in result.combinedOutput.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("pid = ") else { continue }
            return Int(line.replacingOccurrences(of: "pid = ", with: ""))
        }
        return nil
    }

    nonisolated private static func readGatewayProcesses(settings: AppSettings, launchdPID: Int?) async -> [GatewayProcessInfo] {
        let profileID = settings.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileID.isEmpty else { return [] }
        guard let result = try? await CommandRunner.run("/bin/ps", ["-ax", "-o", "pid=,etimes=,command="]), result.status == 0 else {
            return []
        }

        return result.stdout
            .split(separator: "\n")
            .compactMap { rawLine -> GatewayProcessInfo? in
                let line = String(rawLine)
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let parts = trimmed.split(maxSplits: 2, whereSeparator: \.isWhitespace)
                guard parts.count >= 2 else { return nil }
                guard let pid = Int(parts[0]) else { return nil }
                let etimesStr = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                let command = parts.count > 2 ? String(parts[2]) : ""
                let launchdPattern = "hermes_cli.main --profile \(profileID) gateway run"
                let manualPattern = "bin/hermes -p \(profileID) gateway run"
                guard command.contains(launchdPattern) || command.contains(manualPattern) else { return nil }
                // Exclude rg/grep/zsh shells that happen to contain the pattern in their own arguments
                guard !command.hasPrefix("rg "), !command.hasPrefix("grep "), !command.hasPrefix("/bin/zsh -c ") else { return nil }
                let startTime: Date? = {
                    guard let elapsed = Double(etimesStr), elapsed >= 0 else { return nil }
                    return Date().addingTimeInterval(-elapsed)
                }()
                return GatewayProcessInfo(
                    id: pid,
                    command: command,
                    startTime: startTime,
                    isLaunchdManaged: pid == launchdPID,
                    isAuthoritative: false // resolved later in makeSnapshot
                )
            }
            .sorted { $0.id < $1.id }
    }

    nonisolated private static func resolveAuthoritativeGatewayPID(
        launchdPID: Int?,
        liveGatewayPIDs: [Int],
        pidFilePID: Int?
    ) -> Int? {
        if let launchdPID, liveGatewayPIDs.contains(launchdPID) {
            return launchdPID
        }
        if let pidFilePID, liveGatewayPIDs.contains(pidFilePID) {
            return pidFilePID
        }
        if let launchdPID {
            return launchdPID
        }
        if let pidFilePID {
            return pidFilePID
        }
        if liveGatewayPIDs.count == 1 {
            return liveGatewayPIDs.first
        }
        return nil
    }

    nonisolated private static func computeRuntimeStaleReason(
        runtime: RuntimeStatus?,
        authoritativeGatewayPID: Int?
    ) -> String? {
        guard let runtime else { return authoritativeGatewayPID == nil ? nil : "gateway_state.json missing" }
        guard let authoritativeGatewayPID else { return nil }
        if runtime.pid != authoritativeGatewayPID {
            let runtimePID = runtime.pid.map(String.init) ?? "nil"
            return "gateway_state.json pid=\(runtimePID), live pid=\(authoritativeGatewayPID)"
        }
        if runtime.gatewayState?.lowercased() != "running" {
            return "gateway_state.json says \(runtime.gatewayState ?? "unknown") while process is alive"
        }
        return nil
    }

    nonisolated private static func computeRecentAgentActivityCount(
        sessions: [AgentSessionRow],
        bindings: [SessionBindingEntry]
    ) -> Int {
        let threshold: TimeInterval = 180
        let now = Date()
        let bindingsBySessionID = Dictionary(uniqueKeysWithValues: bindings.map { ($0.sessionID, $0) })

        return sessions.reduce(into: 0) { count, session in
            guard session.isActive else { return }

            let transcriptMTime = (try? session.transcriptURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            let bindingUpdatedAt = bindingsBySessionID[session.id]?.updatedAtDate
            let startedAt = Date(timeIntervalSince1970: session.startedAt)
            let latestActivity = [transcriptMTime, bindingUpdatedAt, startedAt].compactMap { $0 }.max() ?? startedAt

            if now.timeIntervalSince(latestActivity) <= threshold {
                count += 1
            }
        }
    }

    private func createLogExcerpt(for sessionID: String) throws -> URL {
        let fm = FileManager.default
        let excerptDir = paths.hermesHome.appending(path: "excerpts", directoryHint: .isDirectory)
        try fm.createDirectory(at: excerptDir, withIntermediateDirectories: true)

        let logFiles = [
            paths.logsDir.appending(path: "gateway.log"),
            paths.logsDir.appending(path: "agent.log"),
            paths.logsDir.appending(path: "errors.log"),
            paths.logsDir.appending(path: "gateway.error.log"),
        ]

        var chunks: [String] = []
        for file in logFiles where fm.fileExists(atPath: file.path) {
            let content = try String(contentsOf: file, encoding: .utf8)
            let matches = content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.localizedCaseInsensitiveContains(sessionID) }
                .map(String.init)
            if !matches.isEmpty {
                chunks.append("# \(file.lastPathComponent)\n" + matches.joined(separator: "\n"))
            }
        }

        if chunks.isEmpty {
            chunks.append("No matching log lines found for session \(sessionID).")
        }

        let out = excerptDir.appending(path: "session-\(sessionID)-logs.md")
        try chunks.joined(separator: "\n\n").write(to: out, atomically: true, encoding: .utf8)
        return out
    }

    private var paths: HermesPaths {
        HermesPaths(settings: settingsStore.settings)
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settingsStore.settings.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}
