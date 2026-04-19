import Foundation

struct HermesPaths {
    let settings: AppSettings

    var projectRoot: URL {
        URL(fileURLWithPath: settings.projectRootPath, isDirectory: true)
    }

    var workspaceRoot: URL {
        URL(fileURLWithPath: settings.workspaceRootPath, isDirectory: true)
    }

    var hermesRoot: URL {
        projectRoot.appending(path: ".hermes-home", directoryHint: .isDirectory)
    }

    var hermesHome: URL {
        hermesRoot.appending(path: "profiles/\(settings.profileName)", directoryHint: .isDirectory)
    }

    var configURL: URL {
        hermesHome.appending(path: "config.yaml")
    }

    var envURL: URL {
        hermesHome.appending(path: ".env")
    }

    var soulURL: URL {
        hermesHome.appending(path: "SOUL.md")
    }

    var launcher: URL {
        URL(fileURLWithPath: settings.launcherPath)
    }

    var pythonExecutable: URL {
        launcher.deletingLastPathComponent().appending(path: "python")
    }

    var gatewayState: URL {
        hermesHome.appending(path: "gateway_state.json")
    }

    var gatewayActions: URL {
        hermesHome.appending(path: "gateway_actions.json")
    }

    var gatewayPID: URL {
        hermesHome.appending(path: "gateway.pid")
    }

    var stateDB: URL {
        hermesHome.appending(path: "state.db")
    }

    var authStore: URL {
        hermesHome.appending(path: "auth.json")
    }

    var sessionsDir: URL {
        hermesHome.appending(path: "sessions", directoryHint: .isDirectory)
    }

    var sessionModelOverridesURL: URL {
        sessionsDir.appending(path: "session_model_overrides.json")
    }

    var sessionBindingsURL: URL {
        sessionsDir.appending(path: "sessions.json")
    }

    var logsDir: URL {
        hermesHome.appending(path: "logs", directoryHint: .isDirectory)
    }

    var cronDir: URL {
        hermesHome.appending(path: "cron", directoryHint: .isDirectory)
    }

    var cronJobsURL: URL {
        cronDir.appending(path: "jobs.json")
    }

    var cronOutputDir: URL {
        cronDir.appending(path: "output", directoryHint: .isDirectory)
    }

    func cronOutputDir(for jobID: String) -> URL {
        cronOutputDir.appending(path: jobID, directoryHint: .isDirectory)
    }

    var launchAgentLabel: String {
        "ai.hermes.gateway-\(settings.profileName)"
    }

    var launchAgentPlist: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    func gatewayCommand(_ args: [String]) -> [String] {
        [launcher.path, "-p", settings.profileName, "gateway"] + args
    }

    func hermesCommand(_ args: [String]) -> [String] {
        [launcher.path, "-p", settings.profileName] + args
    }

    func transcriptURL(for sessionID: String) -> URL {
        sessionsDir.appending(path: "session_\(sessionID).json")
    }

    func latestRequestDumpURL() -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents
            .filter { $0.lastPathComponent.hasPrefix("request_dump_") && $0.pathExtension == "json" }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .first
    }
}
