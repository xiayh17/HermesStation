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

    private static let kimiCodingBaseURL = "https://api.kimi.com/coding/v1"
    private static let kimiCodingAnthropicBaseURL = "https://api.kimi.com/coding"

    static func normalizedBaseURL(providerID: String, baseURL: String) -> String {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else { return "" }

        let normalizedProviderID = HermesProviderDescriptor.resolve(providerID)?.id
            ?? providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let strippedBaseURL: String
        if trimmedBaseURL.hasSuffix("/") {
            strippedBaseURL = String(trimmedBaseURL.dropLast())
        } else {
            strippedBaseURL = trimmedBaseURL
        }

        if normalizedProviderID == "kimi-coding",
           strippedBaseURL.caseInsensitiveCompare("https://api.kimi.com/coding") == .orderedSame {
            return kimiCodingBaseURL
        }

        if normalizedProviderID == "anthropic",
           strippedBaseURL.caseInsensitiveCompare("https://api.kimi.com/coding/v1") == .orderedSame {
            return kimiCodingAnthropicBaseURL
        }

        return strippedBaseURL
    }

    static func hasKimiCodingV1Issue(providerID: String, baseURL: String) -> Bool {
        let normalizedProviderID = HermesProviderDescriptor.resolve(providerID)?.id
            ?? providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedProviderID == "kimi-coding" else { return false }

        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else { return false }

        let strippedBaseURL: String
        if trimmedBaseURL.hasSuffix("/") {
            strippedBaseURL = String(trimmedBaseURL.dropLast())
        } else {
            strippedBaseURL = trimmedBaseURL
        }

        return strippedBaseURL.caseInsensitiveCompare("https://api.kimi.com/coding") == .orderedSame
    }

    static func isKimiCodingPlanAnthropicRoute(providerID: String, baseURL: String) -> Bool {
        let normalizedProviderID = HermesProviderDescriptor.resolve(providerID)?.id
            ?? providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedProviderID == "anthropic" else { return false }

        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else { return false }

        let strippedBaseURL: String
        if trimmedBaseURL.hasSuffix("/") {
            strippedBaseURL = String(trimmedBaseURL.dropLast())
        } else {
            strippedBaseURL = trimmedBaseURL
        }

        return strippedBaseURL.caseInsensitiveCompare(kimiCodingAnthropicBaseURL) == .orderedSame
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
    var autoCleanupDuplicateGateways: Bool
    var autoRestartOnStaleRuntime: Bool
    var modelProviders: [SavedProviderConnection]

    init(
        id: UUID,
        displayName: String,
        profileName: String,
        projectRootPath: String,
        workspaceRootPath: String,
        launcherPath: String,
        refreshIntervalSeconds: Double,
        autoCleanupDuplicateGateways: Bool = true,
        autoRestartOnStaleRuntime: Bool = true,
        modelProviders: [SavedProviderConnection] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.profileName = profileName
        self.projectRootPath = projectRootPath
        self.workspaceRootPath = workspaceRootPath
        self.launcherPath = launcherPath
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.autoCleanupDuplicateGateways = autoCleanupDuplicateGateways
        self.autoRestartOnStaleRuntime = autoRestartOnStaleRuntime
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
        autoCleanupDuplicateGateways = try container.decodeIfPresent(Bool.self, forKey: .autoCleanupDuplicateGateways) ?? true
        autoRestartOnStaleRuntime = try container.decodeIfPresent(Bool.self, forKey: .autoRestartOnStaleRuntime) ?? true
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
        autoCleanupDuplicateGateways: true,
        autoRestartOnStaleRuntime: true,
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
            autoCleanupDuplicateGateways: true,
            autoRestartOnStaleRuntime: true,
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
