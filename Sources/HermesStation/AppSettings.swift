import Foundation

enum ModelCapability: String, Codable, CaseIterable, Identifiable {
    case chat
    case coding
    case reasoning
    case tools
    case vision
    case web
    case image
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .coding: return "Coding"
        case .reasoning: return "Reasoning"
        case .tools: return "Tools"
        case .vision: return "Vision"
        case .web: return "Web"
        case .image: return "Image"
        case .audio: return "Audio"
        }
    }
}

struct SavedModelEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var modelName: String
    var isEnabled: Bool
    var capabilities: [ModelCapability]

    static func blank(name: String = "New Model") -> SavedModelEntry {
        SavedModelEntry(
            id: UUID(),
            displayName: name,
            modelName: "",
            isEnabled: true,
            capabilities: [.chat]
        )
    }
}

struct SavedProviderConnection: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var providerID: String
    var baseURL: String
    var apiKey: String
    var isEnabled: Bool
    var models: [SavedModelEntry]

    static func blank(name: String = "New Provider") -> SavedProviderConnection {
        SavedProviderConnection(
            id: UUID(),
            displayName: name,
            providerID: "",
            baseURL: "",
            apiKey: "",
            isEnabled: true,
            models: [SavedModelEntry.blank()]
        )
    }
}

struct AppSettings: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var profileName: String
    var projectRootPath: String
    var workspaceRootPath: String
    var launcherPath: String
    var refreshIntervalSeconds: Double
    var modelProviders: [SavedProviderConnection]

    init(
        id: UUID,
        displayName: String,
        profileName: String,
        projectRootPath: String,
        workspaceRootPath: String,
        launcherPath: String,
        refreshIntervalSeconds: Double,
        modelProviders: [SavedProviderConnection] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.profileName = profileName
        self.projectRootPath = projectRootPath
        self.workspaceRootPath = workspaceRootPath
        self.launcherPath = launcherPath
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.modelProviders = modelProviders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName) ?? ""
        projectRootPath = try container.decodeIfPresent(String.self, forKey: .projectRootPath) ?? ""
        workspaceRootPath = try container.decodeIfPresent(String.self, forKey: .workspaceRootPath) ?? ""
        launcherPath = try container.decodeIfPresent(String.self, forKey: .launcherPath) ?? ""
        refreshIntervalSeconds = try container.decodeIfPresent(Double.self, forKey: .refreshIntervalSeconds) ?? 5
        modelProviders = try container.decodeIfPresent([SavedProviderConnection].self, forKey: .modelProviders) ?? []
    }

    static let `default` = AppSettings(
        id: UUID(),
        displayName: "yong",
        profileName: "yong",
        projectRootPath: "/Users/xiayh/Projects/install_hermers",
        workspaceRootPath: "/Users/xiayh/Documents/hermers_workspace",
        launcherPath: "/Users/xiayh/Projects/install_hermers/run-hermes-local.sh",
        refreshIntervalSeconds: 5,
        modelProviders: []
    )

    static func blank(name: String = "New Profile") -> AppSettings {
        AppSettings(
            id: UUID(),
            displayName: name,
            profileName: "",
            projectRootPath: "",
            workspaceRootPath: "",
            launcherPath: "",
            refreshIntervalSeconds: 5,
            modelProviders: []
        )
    }
}

struct AppSettingsStoreFile: Codable, Equatable {
    var activeProfileID: UUID
    var profiles: [AppSettings]

    static let `default` = AppSettingsStoreFile(
        activeProfileID: AppSettings.default.id,
        profiles: [.default]
    )
}
