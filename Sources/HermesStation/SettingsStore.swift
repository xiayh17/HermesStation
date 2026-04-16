import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var profiles: [AppSettings]
    @Published private(set) var activeProfileID: UUID

    private let fileManager = FileManager.default
    private let settingsURL: URL

    init() {
        let appSupport = fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/HermesStation", directoryHint: .isDirectory)
        settingsURL = appSupport.appending(path: "settings.json")

        let stored = Self.loadStoreFile(from: settingsURL)
            ?? Self.migrateFromLegacyDirectory(using: fileManager)
            ?? .default
        let resolved = Self.normalize(stored)
        profiles = resolved.profiles
        activeProfileID = resolved.activeProfileID
        settings = Self.resolveActiveSettings(from: resolved)
        persist(resolved)
    }

    func update(_ settings: AppSettings) {
        var stored = currentStoreFile
        guard let index = stored.profiles.firstIndex(where: { $0.id == settings.id }) else { return }
        stored.profiles[index] = settings
        applyAndPersist(stored)
    }

    func activateProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        var stored = currentStoreFile
        stored.activeProfileID = id
        applyAndPersist(stored)
    }

    func createProfile() {
        let base = settings
        var stored = currentStoreFile
        let copyCount = stored.profiles.filter { $0.displayName.hasPrefix(base.displayName) }.count
        let newProfile = AppSettings(
            id: UUID(),
            displayName: copyCount == 0 ? "\(base.displayName) Copy" : "\(base.displayName) Copy \(copyCount + 1)",
            profileName: "",
            projectRootPath: base.projectRootPath,
            workspaceRootPath: base.workspaceRootPath,
            launcherPath: base.launcherPath,
            refreshIntervalSeconds: base.refreshIntervalSeconds,
            modelProviders: base.modelProviders
        )
        stored.profiles.append(newProfile)
        stored.activeProfileID = newProfile.id
        applyAndPersist(stored)
    }

    func duplicateActiveProfile() {
        let base = settings
        var stored = currentStoreFile
        let copyCount = stored.profiles.filter { $0.displayName.hasPrefix(base.displayName) }.count
        let duplicate = AppSettings(
            id: UUID(),
            displayName: copyCount == 0 ? "\(base.displayName) Copy" : "\(base.displayName) Copy \(copyCount + 1)",
            profileName: base.profileName,
            projectRootPath: base.projectRootPath,
            workspaceRootPath: base.workspaceRootPath,
            launcherPath: base.launcherPath,
            refreshIntervalSeconds: base.refreshIntervalSeconds,
            modelProviders: base.modelProviders
        )
        stored.profiles.append(duplicate)
        stored.activeProfileID = duplicate.id
        applyAndPersist(stored)
    }

    func deleteActiveProfile() {
        guard profiles.count > 1 else { return }
        var stored = currentStoreFile
        stored.profiles.removeAll { $0.id == activeProfileID }
        stored.activeProfileID = stored.profiles.first?.id ?? AppSettings.default.id
        applyAndPersist(stored)
    }

    func reset() {
        let current = settings
        let reset = AppSettings(
            id: current.id,
            displayName: current.displayName,
            profileName: current.profileName,
            projectRootPath: AppSettings.default.projectRootPath,
            workspaceRootPath: AppSettings.default.workspaceRootPath,
            launcherPath: AppSettings.default.launcherPath,
            refreshIntervalSeconds: AppSettings.default.refreshIntervalSeconds,
            modelProviders: current.modelProviders
        )
        update(reset)
    }

    func openSettingsFile() {
        let url = settingsURL
        Task { _ = try? await CommandRunner.openPath(url) }
    }

    private var currentStoreFile: AppSettingsStoreFile {
        AppSettingsStoreFile(activeProfileID: activeProfileID, profiles: profiles)
    }

    private func applyAndPersist(_ stored: AppSettingsStoreFile) {
        let normalized = Self.normalize(stored)
        profiles = normalized.profiles
        activeProfileID = normalized.activeProfileID
        settings = Self.resolveActiveSettings(from: normalized)
        persist(normalized)
    }

    private func persist(_ stored: AppSettingsStoreFile) {
        do {
            try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(stored)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            NSLog("Failed to persist settings: %@", error.localizedDescription)
        }
    }

    private static func loadStoreFile(from url: URL) -> AppSettingsStoreFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        if let decoded = try? JSONDecoder().decode(AppSettingsStoreFile.self, from: data) {
            return decoded
        }

        if let legacy = try? JSONDecoder().decode(LegacyAppSettings.self, from: data) {
            let migrated = legacy.toAppSettings()
            return AppSettingsStoreFile(activeProfileID: migrated.id, profiles: [migrated])
        }

        return nil
    }

    private static func migrateFromLegacyDirectory(using fileManager: FileManager) -> AppSettingsStoreFile? {
        let legacyURL = fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/HermesStationMenuBar/settings.json")
        guard let store = loadStoreFile(from: legacyURL) else { return nil }
        return store
    }

    private static func normalize(_ stored: AppSettingsStoreFile) -> AppSettingsStoreFile {
        var normalizedProfiles = stored.profiles.map { profile in
            var copy = profile
            copy.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.displayName.isEmpty {
                copy.displayName = profile.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if copy.displayName.isEmpty {
                copy.displayName = "Profile"
            }
            copy.profileName = profile.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.projectRootPath = profile.projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.workspaceRootPath = profile.workspaceRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.launcherPath = profile.launcherPath.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.refreshIntervalSeconds = max(2, min(30, profile.refreshIntervalSeconds))
            copy.modelProviders = profile.modelProviders.map { provider in
                var normalizedProvider = provider
                normalizedProvider.displayName = provider.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if normalizedProvider.displayName.isEmpty {
                    normalizedProvider.displayName = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if normalizedProvider.displayName.isEmpty {
                    normalizedProvider.displayName = "Provider"
                }
                normalizedProvider.providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
                normalizedProvider.baseURL = SavedProviderConnection.normalizedBaseURL(
                    providerID: normalizedProvider.providerID,
                    baseURL: provider.baseURL
                )
                normalizedProvider.apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                normalizedProvider.models = provider.models.map { model in
                    var normalizedModel = model
                    normalizedModel.displayName = model.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    normalizedModel.modelName = model.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalizedModel.displayName.isEmpty {
                        normalizedModel.displayName = normalizedModel.modelName.isEmpty ? "Model" : normalizedModel.modelName
                    }
                    if normalizedModel.capabilities.isEmpty {
                        normalizedModel.capabilities = [.chat]
                    }
                    return normalizedModel
                }
                if normalizedProvider.models.isEmpty {
                    normalizedProvider.models = [SavedModelEntry.blank()]
                }
                return normalizedProvider
            }
            return copy
        }

        if normalizedProfiles.isEmpty {
            normalizedProfiles = [.default]
        }

        let activeID = normalizedProfiles.contains(where: { $0.id == stored.activeProfileID })
            ? stored.activeProfileID
            : normalizedProfiles[0].id

        return AppSettingsStoreFile(activeProfileID: activeID, profiles: normalizedProfiles)
    }

    private static func resolveActiveSettings(from stored: AppSettingsStoreFile) -> AppSettings {
        stored.profiles.first(where: { $0.id == stored.activeProfileID }) ?? stored.profiles[0]
    }
}

private struct LegacyAppSettings: Codable {
    var profileName: String
    var projectRootPath: String
    var workspaceRootPath: String
    var launcherPath: String
    var refreshIntervalSeconds: Double
    var model: LegacyModelSettings?

    struct LegacyModelSettings: Codable {
        var provider: String?
        var modelName: String?
        var baseURL: String?
        var apiKey: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case modelName
            case baseURL
            case apiKey
        }
    }

    func toAppSettings() -> AppSettings {
        let migratedProviders: [SavedProviderConnection]
        if let model, let modelName = model.modelName, !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let providerID = Self.migrateProviderID(model.provider ?? "")
            migratedProviders = [
                SavedProviderConnection(
                    id: UUID(),
                    displayName: model.provider?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? model.provider!.trimmingCharacters(in: .whitespacesAndNewlines) : providerID,
                    providerID: providerID,
                    baseURL: model.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    apiKey: model.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    isEnabled: true,
                    models: [
                        SavedModelEntry(
                            id: UUID(),
                            displayName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                            isEnabled: true,
                            capabilities: [.chat]
                        )
                    ]
                )
            ]
        } else {
            migratedProviders = []
        }

        return AppSettings(
            id: UUID(),
            displayName: profileName,
            profileName: profileName,
            projectRootPath: projectRootPath,
            workspaceRootPath: workspaceRootPath,
            launcherPath: launcherPath,
            refreshIntervalSeconds: refreshIntervalSeconds,
            modelProviders: migratedProviders
        )
    }

    private static func migrateProviderID(_ provider: String) -> String {
        let normalized = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return "custom"
        }
        if normalized.contains("openai compatible") || normalized == "openai-compatible" {
            return "custom"
        }
        return normalized.replacingOccurrences(of: " ", with: "-")
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
