import Foundation

struct HermesPaths {
    let settings: AppSettings

    var projectRoot: URL {
        URL(fileURLWithPath: settings.projectRootPath, isDirectory: true)
    }

    var workspaceRoot: URL {
        URL(fileURLWithPath: settings.workspaceRootPath, isDirectory: true)
    }

    var hermesHome: URL {
        projectRoot.appending(path: ".hermes-home/profiles/\(settings.profileName)", directoryHint: .isDirectory)
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

    var sessionsDir: URL {
        hermesHome.appending(path: "sessions", directoryHint: .isDirectory)
    }

    var logsDir: URL {
        hermesHome.appending(path: "logs", directoryHint: .isDirectory)
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
}
