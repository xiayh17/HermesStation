import Foundation

enum HermesUpdateState: Equatable {
    case idle
    case preparing(tag: String, message: String)
    case ready(tag: String, stagingPath: String)
    case applying(tag: String, message: String)
    case completed(tag: String)
    case failed(String)
}

@MainActor
final class HermesUpdater: ObservableObject {
    @Published private(set) var state: HermesUpdateState = .idle

    private let settings: AppSettings
    private let projectRoot: URL
    private var activeTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        self.projectRoot = URL(fileURLWithPath: settings.projectRootPath, isDirectory: true)
    }

    func prepareUpdate(to tag: String) {
        guard !isBusy else { return }
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.state = .preparing(tag: tag, message: "Cloning \(tag)...") }

            let staging = self.stagingDir(for: tag)
            let fm = FileManager.default
            if fm.fileExists(atPath: staging.path) {
                _ = try? fm.removeItem(at: staging)
            }

            // 1. Clone
            let cloneResult = await Self.runShell(
                cd: projectRoot.path,
                "git clone --depth 1 --branch \(tag) https://github.com/NousResearch/hermes-agent.git \(staging.lastPathComponent)"
            )
            guard !Task.isCancelled else { return }
            guard cloneResult.status == 0 else {
                await MainActor.run { self.state = .failed("Clone failed: \(cloneResult.combinedOutput)") }
                return
            }

            await MainActor.run { self.state = .preparing(tag: tag, message: "Creating venv...") }

            // 2. Create venv using the same Python that runs the current live hermes-agent
            let venvPath = staging.appending(path: "venv")
            let python = self.resolvePythonPath()
            let venvResult: CommandResult
            do { venvResult = try await CommandRunner.run(python, ["-m", "venv", venvPath.path]) } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.state = .failed("venv creation failed: \(error.localizedDescription)") }
                return
            }
            guard !Task.isCancelled else { return }
            guard venvResult.status == 0 else {
                await MainActor.run { self.state = .failed("venv creation failed: \(venvResult.combinedOutput)") }
                return
            }

            await MainActor.run { self.state = .preparing(tag: tag, message: "Upgrading pip...") }

            // 3. Upgrade pip first (system python often ships an old pip that cannot do editable installs for pyproject.toml packages)
            let pip = venvPath.appending(path: "bin/pip").path
            let upgradeResult: CommandResult
            do { upgradeResult = try await CommandRunner.run(pip, ["install", "--upgrade", "pip"]) } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.state = .failed("pip upgrade failed: \(error.localizedDescription)") }
                return
            }
            guard !Task.isCancelled else { return }
            guard upgradeResult.status == 0 else {
                await MainActor.run { self.state = .failed("pip upgrade failed: \(upgradeResult.combinedOutput)") }
                return
            }

            await MainActor.run { self.state = .preparing(tag: tag, message: "Installing dependencies...") }

            // 4. Install
            let installResult: CommandResult
            do { installResult = try await CommandRunner.run(pip, ["install", "-e", staging.path]) } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.state = .failed("pip install failed: \(error.localizedDescription)") }
                return
            }
            guard !Task.isCancelled else { return }
            guard installResult.status == 0 else {
                await MainActor.run { self.state = .failed("pip install failed: \(installResult.combinedOutput)") }
                return
            }

            await MainActor.run { self.state = .preparing(tag: tag, message: "Verifying...") }

            // 4. Verify
            let hermesBin = venvPath.appending(path: "bin/hermes").path
            let verifyResult: CommandResult
            do { verifyResult = try await CommandRunner.run(hermesBin, ["--version"]) } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.state = .failed("Verification failed: \(error.localizedDescription)") }
                return
            }
            guard !Task.isCancelled else { return }
            guard verifyResult.status == 0, verifyResult.stdout.contains(tag) else {
                await MainActor.run {
                    self.state = .failed("Verification failed: \(verifyResult.combinedOutput)")
                }
                return
            }

            await MainActor.run {
                self.state = .ready(tag: tag, stagingPath: staging.path)
            }
        }
    }

    func applyUpdate() async -> String? {
        guard case .ready(let tag, let stagingPath) = state else { return "No prepared update to apply." }
        state = .applying(tag: tag, message: "Stopping gateway...")

        let fm = FileManager.default
        let current = projectRoot.appending(path: "hermes-agent")
        let backup = projectRoot.appending(path: "hermes-agent-backup-\(Self.timestamp())")
        let staging = URL(fileURLWithPath: stagingPath)

        // 1. Stop service via launcher script (same as GatewayStore.stopService)
        let stopResult = await runLauncher(args: ["stop"])
        if stopResult.status != 0 {
            state = .failed("Stop failed: \(stopResult.combinedOutput)")
            return state.errorMessage
        }

        state = .applying(tag: tag, message: "Swapping directories...")

        // 2. Atomic-ish swap
        do {
            try fm.moveItem(at: current, to: backup)
            try fm.moveItem(at: staging, to: current)

            // 2a. Rewrite any absolute staging paths left inside the venv
            // (shebangs, editable-install metadata, activate scripts, pyvenv.cfg, etc.)
            let venvDir = current.appending(path: "venv")
            if let enumerator = fm.enumerator(at: venvDir, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                    guard resourceValues?.isSymbolicLink != true,
                          resourceValues?.isDirectory != true else { continue }
                    guard let data = fm.contents(atPath: fileURL.path),
                          var text = String(data: data, encoding: .utf8),
                          text.contains(staging.path) else { continue }
                    text = text.replacingOccurrences(of: staging.path, with: current.path)
                    try? Data(text.utf8).write(to: fileURL, options: .atomic)
                }
            }
        } catch {
            // Attempt rollback if current is missing
            if !fm.fileExists(atPath: current.path), fm.fileExists(atPath: backup.path) {
                try? fm.moveItem(at: backup, to: current)
            }
            state = .failed("Swap failed: \(error.localizedDescription)")
            return state.errorMessage
        }

        state = .applying(tag: tag, message: "Starting gateway...")

        // 3. Start service
        let startResult = await runLauncher(args: ["start"])
        if startResult.status != 0 {
            state = .failed("Start failed: \(startResult.combinedOutput). Old version kept at \(backup.lastPathComponent)")
            return state.errorMessage
        }

        state = .completed(tag: tag)
        return nil
    }

    func discardPreparedUpdate() {
        activeTask?.cancel()
        if case .ready(_, let path) = state {
            _ = try? FileManager.default.removeItem(atPath: path)
        }
        state = .idle
    }

    func reset() {
        activeTask?.cancel()
        state = .idle
    }

    var isBusy: Bool {
        switch state {
        case .idle, .ready, .completed, .failed: return false
        case .preparing, .applying: return true
        }
    }

    private func stagingDir(for tag: String) -> URL {
        projectRoot.appending(path: "hermes-agent-staging-\(tag)")
    }

    private func resolvePythonPath() -> String {
        let liveVenvPython = projectRoot.appending(path: "hermes-agent/venv/bin/python3").path
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: liveVenvPython) {
            return liveVenvPython
        }
        return "/usr/bin/python3"
    }

    private func runLauncher(args: [String]) async -> CommandResult {
        let command = HermesPaths(settings: settings).gatewayCommand(args)
        guard let executable = command.first else {
            return CommandResult(status: 1, stdout: "", stderr: "Missing launcher executable")
        }
        return (try? await CommandRunner.run(executable, Array(command.dropFirst()))) ?? CommandResult(status: 1, stdout: "", stderr: "Command failed")
    }

    nonisolated private static func runShell(cd: String, _ script: String) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", "cd \(cd) && \(script)"]

            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err

            process.terminationHandler = { proc in
                let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(status: proc.terminationStatus, stdout: stdout, stderr: stderr))
            }

            try? process.run()
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

extension HermesUpdateState {
    var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}
