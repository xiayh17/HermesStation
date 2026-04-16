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

            process.terminationHandler = { proc in
                let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(status: proc.terminationStatus, stdout: stdout, stderr: stderr))
            }

            do {
                try process.run()
            } catch {
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

    static func openPath(_ url: URL) async throws -> CommandResult {
        try await run("/usr/bin/open", [url.path])
    }
}
