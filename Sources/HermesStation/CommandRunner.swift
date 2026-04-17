import Foundation

struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        let joined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        return joined.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class PipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var outData = Data()
    private var errData = Data()

    func appendStdout(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        outData.append(data)
        lock.unlock()
    }

    func appendStderr(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        errData.append(data)
        lock.unlock()
    }

    func snapshot() -> (String, String) {
        lock.lock()
        defer { lock.unlock() }
        return (
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
}

enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err

            // Drain pipes concurrently while the process runs so large outputs don't
            // fill the pipe buffer (~64 KB) and deadlock the child. `readDataToEndOfFile`
            // inside `terminationHandler` is unsafe for commands like `ps -ax` whose
            // output can easily exceed the buffer.
            let buffer = PipeBuffer()
            out.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    buffer.appendStdout(chunk)
                }
            }
            err.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    buffer.appendStderr(chunk)
                }
            }

            process.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                // Drain anything left buffered after EOF.
                buffer.appendStdout(out.fileHandleForReading.readDataToEndOfFile())
                buffer.appendStderr(err.fileHandleForReading.readDataToEndOfFile())
                let (stdout, stderr) = buffer.snapshot()
                continuation.resume(returning: CommandResult(status: proc.terminationStatus, stdout: stdout, stderr: stderr))
            }

            do {
                try process.run()
            } catch {
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    static func runGateway(_ settings: AppSettings, _ args: [String]) async throws -> CommandResult {
        let command = HermesPaths(settings: settings).gatewayCommand(args)
        guard let executable = command.first else {
            throw NSError(domain: "HermesStation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing gateway executable"])
        }
        return try await run(executable, Array(command.dropFirst()))
    }

    static func runHermes(_ settings: AppSettings, _ args: [String]) async throws -> CommandResult {
        let command = HermesPaths(settings: settings).hermesCommand(args)
        guard let executable = command.first else {
            throw NSError(domain: "HermesStation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Hermes executable"])
        }
        return try await run(executable, Array(command.dropFirst()))
    }

    static func runLaunchctl(_ args: [String]) async throws -> CommandResult {
        try await run("/bin/launchctl", args)
    }

    static func openLocation(_ location: String) async throws -> CommandResult {
        try await run("/usr/bin/open", [location])
    }

    static func openPath(_ url: URL) async throws -> CommandResult {
        try await openLocation(url.path)
    }
}
