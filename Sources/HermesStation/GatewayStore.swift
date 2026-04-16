import Foundation
import AppKit
import Combine

@MainActor
final class GatewayStore: ObservableObject {
    @Published private(set) var snapshot: GatewaySnapshot = .empty
    @Published var isBusy: Bool = false

    let settingsStore: SettingsStore
    let profileStore: HermesProfileStore

    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(settingsStore: SettingsStore, profileStore: HermesProfileStore) {
        self.settingsStore = settingsStore
        self.profileStore = profileStore
        refresh()
        configureTimer()
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.configureTimer()
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        let previousOutput = snapshot.lastCommandOutput
        let settings = settingsStore.settings

        refreshTask?.cancel()
        refreshTask = Task(priority: .utility) { [weak self] in
            let snapshot = await Self.makeSnapshot(settings: settings, previousOutput: previousOutput)
            guard !Task.isCancelled else { return }
            self?.snapshot = snapshot
        }
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

    func openWorkspace() {
        let workspaceURL = profileStore.snapshot.workspaceURL ?? paths.workspaceRoot
        Task { _ = try? await CommandRunner.openPath(workspaceURL) }
    }

    func openHermesHome() {
        Task { _ = try? await CommandRunner.openPath(paths.hermesHome) }
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

    nonisolated private static func makeSnapshot(settings: AppSettings, previousOutput: String?) async -> GatewaySnapshot {
        let paths = HermesPaths(settings: settings)
        let plistExists = FileManager.default.fileExists(atPath: paths.launchAgentPlist.path)
        let launchctlLoaded = await readLaunchdLoaded(label: paths.launchAgentLabel)
        let runtime = readRuntimeStatus(at: paths.gatewayState)
        let agentSessions = SQLiteSessionStore.loadAgents(from: paths.stateDB, paths: paths)
        let usage = SQLiteSessionStore.loadUsage(from: paths.stateDB)
        let sessions = SessionSummary(
            totalCount: agentSessions.totalCount,
            recent: agentSessions.rows.prefix(5).map {
                SessionRow(id: $0.id, title: $0.title, updatedAt: $0.startedAtText, transcriptURL: $0.transcriptURL)
            }
        )

        let serviceStatus: ServiceStatus
        if launchctlLoaded && runtime != nil {
            let states = runtime?.platforms.values.compactMap { $0.state } ?? []
            if states.contains(where: { $0 != "connected" }) {
                serviceStatus = .degraded
            } else {
                serviceStatus = .running
            }
        } else if plistExists {
            serviceStatus = .stopped
        } else {
            serviceStatus = .unknown
        }

        return GatewaySnapshot(
            serviceInstalled: plistExists,
            serviceLoaded: launchctlLoaded,
            serviceStatus: serviceStatus,
            runtime: runtime,
            sessions: sessions,
            agentSessions: agentSessions,
            usage: usage,
            lastCommandOutput: previousOutput
        )
    }

    nonisolated private static func readRuntimeStatus(at url: URL) -> RuntimeStatus? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RuntimeStatus.self, from: data)
    }

    nonisolated private static func readLaunchdLoaded(label: String) async -> Bool {
        if let result = try? await CommandRunner.runLaunchctl(["list", label]) {
            return result.status == 0
        }
        return false
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
