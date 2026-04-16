import Foundation
import Combine

struct HermesProviderDescriptor: Identifiable, Equatable {
    let id: String
    let displayName: String
    let apiKeyEnvVars: [String]
    let baseURLEnvVar: String?

    var primaryAPIKeyEnvVar: String? {
        apiKeyEnvVars.first
    }

    var apiKeyStorageDescription: String {
        if let envVar = primaryAPIKeyEnvVar {
            return ".env → \(envVar)"
        }
        return "Managed outside .env via auth/login"
    }

    var baseURLStorageDescription: String {
        if id == "custom" {
            return "config.yaml → model.base_url"
        }
        if let envVar = baseURLEnvVar {
            return ".env → \(envVar)"
        }
        return "config.yaml → model.base_url"
    }

    static let knownProviders: [HermesProviderDescriptor] = [
        .init(id: "custom", displayName: "Custom / OpenAI-compatible", apiKeyEnvVars: ["OPENAI_API_KEY"], baseURLEnvVar: nil),
        .init(id: "openrouter", displayName: "OpenRouter", apiKeyEnvVars: ["OPENROUTER_API_KEY"], baseURLEnvVar: "OPENROUTER_BASE_URL"),
        .init(id: "anthropic", displayName: "Anthropic", apiKeyEnvVars: ["ANTHROPIC_API_KEY", "ANTHROPIC_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"], baseURLEnvVar: nil),
        .init(id: "gemini", displayName: "Google AI Studio", apiKeyEnvVars: ["GOOGLE_API_KEY", "GEMINI_API_KEY"], baseURLEnvVar: "GEMINI_BASE_URL"),
        .init(id: "zai", displayName: "Z.AI / GLM", apiKeyEnvVars: ["GLM_API_KEY", "ZAI_API_KEY", "Z_AI_API_KEY"], baseURLEnvVar: "GLM_BASE_URL"),
        .init(id: "kimi-coding", displayName: "Kimi / Moonshot", apiKeyEnvVars: ["KIMI_API_KEY"], baseURLEnvVar: "KIMI_BASE_URL"),
        .init(id: "minimax", displayName: "MiniMax", apiKeyEnvVars: ["MINIMAX_API_KEY"], baseURLEnvVar: "MINIMAX_BASE_URL"),
        .init(id: "minimax-cn", displayName: "MiniMax (China)", apiKeyEnvVars: ["MINIMAX_CN_API_KEY"], baseURLEnvVar: "MINIMAX_CN_BASE_URL"),
        .init(id: "alibaba", displayName: "Alibaba / DashScope", apiKeyEnvVars: ["DASHSCOPE_API_KEY"], baseURLEnvVar: "DASHSCOPE_BASE_URL"),
        .init(id: "xai", displayName: "xAI", apiKeyEnvVars: ["XAI_API_KEY"], baseURLEnvVar: "XAI_BASE_URL"),
        .init(id: "ai-gateway", displayName: "AI Gateway", apiKeyEnvVars: ["AI_GATEWAY_API_KEY"], baseURLEnvVar: "AI_GATEWAY_BASE_URL"),
        .init(id: "opencode-zen", displayName: "OpenCode Zen", apiKeyEnvVars: ["OPENCODE_ZEN_API_KEY"], baseURLEnvVar: "OPENCODE_ZEN_BASE_URL"),
        .init(id: "opencode-go", displayName: "OpenCode Go", apiKeyEnvVars: ["OPENCODE_GO_API_KEY"], baseURLEnvVar: "OPENCODE_GO_BASE_URL"),
        .init(id: "kilocode", displayName: "Kilo Code", apiKeyEnvVars: ["KILOCODE_API_KEY"], baseURLEnvVar: "KILOCODE_BASE_URL"),
        .init(id: "huggingface", displayName: "Hugging Face", apiKeyEnvVars: ["HF_TOKEN"], baseURLEnvVar: "HF_BASE_URL"),
        .init(id: "xiaomi", displayName: "Xiaomi MiMo", apiKeyEnvVars: ["XIAOMI_API_KEY"], baseURLEnvVar: "XIAOMI_BASE_URL"),
        .init(id: "nous", displayName: "Nous Portal", apiKeyEnvVars: [], baseURLEnvVar: nil),
        .init(id: "openai-codex", displayName: "OpenAI Codex", apiKeyEnvVars: [], baseURLEnvVar: nil),
        .init(id: "qwen-oauth", displayName: "Qwen OAuth", apiKeyEnvVars: [], baseURLEnvVar: nil),
        .init(id: "copilot", displayName: "GitHub Copilot", apiKeyEnvVars: ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"], baseURLEnvVar: nil),
        .init(id: "copilot-acp", displayName: "GitHub Copilot ACP", apiKeyEnvVars: [], baseURLEnvVar: "COPILOT_ACP_BASE_URL"),
    ]

    private static let aliases: [String: String] = [
        "openai": "custom",
        "openai-compatible": "custom",
        "openai compatible": "custom",
        "openai_compatible": "custom",
        "google": "gemini",
        "google-ai-studio": "gemini",
        "google ai studio": "gemini",
        "glm": "zai",
        "z.ai": "zai",
        "moonshot": "kimi-coding",
        "kimi": "kimi-coding",
        "dashscope": "alibaba",
        "minimax_china": "minimax-cn",
        "minimax-china": "minimax-cn"
    ]

    static func resolve(_ providerID: String) -> HermesProviderDescriptor? {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canonical = aliases[normalized] ?? normalized
        return knownProviders.first { $0.id == canonical }
    }

    static func suggestedCanonicalID(for providerID: String) -> String? {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aliases[normalized]
    }
}

struct HermesProfileDraft: Equatable {
    var provider: String
    var modelName: String
    var baseURL: String
    var apiKey: String
    var terminalCwd: String
    var messagingCwd: String

    static let empty = HermesProfileDraft(
        provider: "",
        modelName: "",
        baseURL: "",
        apiKey: "",
        terminalCwd: "",
        messagingCwd: ""
    )

    var normalized: HermesProfileDraft {
        HermesProfileDraft(
            provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalCwd: terminalCwd.trimmingCharacters(in: .whitespacesAndNewlines),
            messagingCwd: messagingCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct HermesProfileSnapshot: Equatable {
    let configURL: URL
    let envURL: URL
    let draft: HermesProfileDraft
    let providerDescriptor: HermesProviderDescriptor?
    let routing: HermesRoutingSummary
    let notes: [String]

    static func empty(settings: AppSettings) -> HermesProfileSnapshot {
        let paths = HermesPaths(settings: settings)
        return HermesProfileSnapshot(
            configURL: paths.hermesHome.appending(path: "config.yaml"),
            envURL: paths.hermesHome.appending(path: ".env"),
            draft: .empty,
            providerDescriptor: nil,
            routing: .empty,
            notes: []
        )
    }

    var workspaceURL: URL? {
        let path = !draft.terminalCwd.isEmpty ? draft.terminalCwd : draft.messagingCwd
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

struct HermesRoutingSummary: Equatable {
    struct AuxiliaryRoute: Equatable, Identifiable {
        let id: String
        let task: String
        let provider: String
    }

    let auxiliaryRoutes: [AuxiliaryRoute]
    let smartRoutingEnabled: Bool
    let smartRoutingTargetProvider: String
    let smartRoutingTargetModel: String
    let smartRoutingMaxSimpleChars: Int
    let smartRoutingMaxSimpleWords: Int

    static let empty = HermesRoutingSummary(
        auxiliaryRoutes: [],
        smartRoutingEnabled: false,
        smartRoutingTargetProvider: "",
        smartRoutingTargetModel: "",
        smartRoutingMaxSimpleChars: 160,
        smartRoutingMaxSimpleWords: 28
    )
}

@MainActor
final class HermesProfileStore: ObservableObject {
    @Published private(set) var snapshot: HermesProfileSnapshot
    @Published private(set) var isSaving: Bool = false
    @Published var lastSaveMessage: String?

    private let settingsStore: SettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.snapshot = HermesProfileSnapshot.empty(settings: settingsStore.settings)
        load()

        settingsStore.$settings
            .sink { [weak self] settings in
                self?.lastSaveMessage = nil
                self?.snapshot = Self.loadSnapshot(settings: settings)
            }
            .store(in: &cancellables)
    }

    func load() {
        snapshot = Self.loadSnapshot(settings: settingsStore.settings)
    }

    func save(_ draft: HermesProfileDraft) {
        guard !isSaving else { return }

        let normalized = draft.normalized
        let provider = normalized.provider.lowercased()
        let descriptor = HermesProviderDescriptor.resolve(provider)
        guard provider == "custom" || descriptor != nil else {
            lastSaveMessage = "Provider \(normalized.provider) 还没有在 menubar 里做真实映射，先直接用 Hermes CLI 改。"
            return
        }

        isSaving = true
        lastSaveMessage = nil
        let settings = settingsStore.settings

        Task {
            defer { Task { @MainActor in self.isSaving = false } }
            do {
                try await Self.apply(settings: settings, draft: normalized, descriptor: descriptor)
                await MainActor.run {
                    self.snapshot = Self.loadSnapshot(settings: settings)
                    self.lastSaveMessage = "已写入 Hermes profile。若改了 .env 中的密钥或 base URL，重启 gateway 后再看效果。"
                }
            } catch {
                await MainActor.run {
                    self.lastSaveMessage = "保存失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func activate(provider: SavedProviderConnection, model: SavedModelEntry) {
        let draft = HermesProfileDraft(
            provider: provider.providerID,
            modelName: model.modelName,
            baseURL: provider.baseURL,
            apiKey: provider.apiKey,
            terminalCwd: snapshot.draft.terminalCwd,
            messagingCwd: snapshot.draft.messagingCwd
        )
        save(draft)
    }

    func saveAuxiliaryProviders(_ providersByTask: [String: String]) {
        guard !isSaving else { return }

        isSaving = true
        lastSaveMessage = nil
        let settings = settingsStore.settings

        Task {
            defer { Task { @MainActor in self.isSaving = false } }
            do {
                for (task, provider) in providersByTask.sorted(by: { $0.key < $1.key }) {
                    let normalizedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = normalizedProvider.isEmpty ? "main" : normalizedProvider
                    let result = try await CommandRunner.runHermes(settings, ["config", "set", "auxiliary.\(task).provider", value])
                    guard result.status == 0 else {
                        let message = result.combinedOutput.isEmpty ? "Command failed: auxiliary.\(task).provider" : result.combinedOutput
                        throw NSError(domain: "HermesProfileStore", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: message])
                    }
                }
                await MainActor.run {
                    self.snapshot = Self.loadSnapshot(settings: settings)
                    self.lastSaveMessage = "已写入 auxiliary provider 路由。"
                }
            } catch {
                await MainActor.run {
                    self.lastSaveMessage = "保存 auxiliary 路由失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func saveSmartRouting(enabled: Bool, provider: String, model: String, maxSimpleChars: Int, maxSimpleWords: Int) {
        guard !isSaving else { return }

        isSaving = true
        lastSaveMessage = nil
        let settings = settingsStore.settings

        let commands: [[String]] = [
            ["config", "set", "smart_model_routing.enabled", enabled ? "true" : "false"],
            ["config", "set", "smart_model_routing.cheap_model.provider", provider.trimmingCharacters(in: .whitespacesAndNewlines)],
            ["config", "set", "smart_model_routing.cheap_model.model", model.trimmingCharacters(in: .whitespacesAndNewlines)],
            ["config", "set", "smart_model_routing.max_simple_chars", "\(max(1, maxSimpleChars))"],
            ["config", "set", "smart_model_routing.max_simple_words", "\(max(1, maxSimpleWords))"],
        ]

        Task {
            defer { Task { @MainActor in self.isSaving = false } }
            do {
                for args in commands {
                    let result = try await CommandRunner.runHermes(settings, args)
                    guard result.status == 0 else {
                        let message = result.combinedOutput.isEmpty ? "Command failed: \(args.joined(separator: " "))" : result.combinedOutput
                        throw NSError(domain: "HermesProfileStore", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: message])
                    }
                }
                await MainActor.run {
                    self.snapshot = Self.loadSnapshot(settings: settings)
                    self.lastSaveMessage = "已写入 smart model routing。"
                }
            } catch {
                await MainActor.run {
                    self.lastSaveMessage = "保存 smart model routing 失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func openConfigFile() {
        Task { _ = try? await CommandRunner.openPath(snapshot.configURL) }
    }

    func openEnvFile() {
        Task { _ = try? await CommandRunner.openPath(snapshot.envURL) }
    }

    private static func loadSnapshot(settings: AppSettings) -> HermesProfileSnapshot {
        let paths = HermesPaths(settings: settings)
        let configURL = paths.hermesHome.appending(path: "config.yaml")
        let envURL = paths.hermesHome.appending(path: ".env")

        let configValues = parseConfigValues(from: configURL)
        let envValues = parseEnvValues(from: envURL)

        let provider = configValues["model.provider"] ?? ""
        let descriptor = HermesProviderDescriptor.resolve(provider)
        let modelName = configValues["model.default"] ?? configValues["model.name"] ?? ""
        let modelBaseURL = configValues["model.base_url"] ?? ""
        let legacyOpenAIBaseURL = envValues["OPENAI_BASE_URL"] ?? ""

        let effectiveBaseURL: String
        if provider == "custom" {
            effectiveBaseURL = !modelBaseURL.isEmpty ? modelBaseURL : legacyOpenAIBaseURL
        } else if let envVar = descriptor?.baseURLEnvVar, let value = envValues[envVar], !value.isEmpty {
            effectiveBaseURL = value
        } else {
            effectiveBaseURL = modelBaseURL
        }

        let effectiveAPIKey = descriptor?.apiKeyEnvVars
            .compactMap { envValues[$0] }
            .first(where: { !$0.isEmpty }) ?? ""

        let auxiliaryTasks = ["vision", "web_extract", "approval", "session_search", "skills_hub", "mcp", "flush_memories"]
        let auxiliaryRoutes = auxiliaryTasks.map { task in
            HermesRoutingSummary.AuxiliaryRoute(
                id: task,
                task: task,
                provider: configValues["auxiliary.\(task).provider"] ?? "main"
            )
        }
        let smartRoutingEnabled = parseBoolean(configValues["smart_model_routing.enabled"])
        let smartRoutingTargetProvider = configValues["smart_model_routing.cheap_model.provider"] ?? ""
        let smartRoutingTargetModel = configValues["smart_model_routing.cheap_model.model"] ?? ""
        let smartRoutingMaxSimpleChars = parseInteger(configValues["smart_model_routing.max_simple_chars"]) ?? 160
        let smartRoutingMaxSimpleWords = parseInteger(configValues["smart_model_routing.max_simple_words"]) ?? 28

        var notes: [String] = []
        if provider == "custom", modelBaseURL.isEmpty, !legacyOpenAIBaseURL.isEmpty {
            notes.append("检测到旧的 OPENAI_BASE_URL。保存时会迁移到 config.yaml 的 model.base_url。")
        }
        if !provider.isEmpty, provider != "custom", descriptor == nil {
            notes.append("当前 provider 没有在 menubar 里做映射，面板只能展示，不能安全保存。")
        }

        return HermesProfileSnapshot(
            configURL: configURL,
            envURL: envURL,
            draft: HermesProfileDraft(
                provider: provider,
                modelName: modelName,
                baseURL: effectiveBaseURL,
                apiKey: effectiveAPIKey,
                terminalCwd: configValues["terminal.cwd"] ?? "",
                messagingCwd: envValues["MESSAGING_CWD"] ?? ""
            ),
            providerDescriptor: descriptor,
            routing: HermesRoutingSummary(
                auxiliaryRoutes: auxiliaryRoutes,
                smartRoutingEnabled: smartRoutingEnabled,
                smartRoutingTargetProvider: smartRoutingTargetProvider,
                smartRoutingTargetModel: smartRoutingTargetModel,
                smartRoutingMaxSimpleChars: smartRoutingMaxSimpleChars,
                smartRoutingMaxSimpleWords: smartRoutingMaxSimpleWords
            ),
            notes: notes
        )
    }

    private static func apply(settings: AppSettings, draft: HermesProfileDraft, descriptor: HermesProviderDescriptor?) async throws {
        var commands: [[String]] = [
            ["config", "set", "model.provider", draft.provider],
            ["config", "set", "model.default", draft.modelName],
            ["config", "set", "terminal.cwd", draft.terminalCwd],
            ["config", "set", "MESSAGING_CWD", draft.messagingCwd],
        ]

        let provider = draft.provider.lowercased()

        if provider == "custom" {
            commands.append(["config", "set", "model.base_url", draft.baseURL])
            commands.append(["config", "set", "OPENAI_API_KEY", draft.apiKey])
            commands.append(["config", "set", "OPENAI_BASE_URL", ""])
        } else if let descriptor {
            if let apiKeyEnvVar = descriptor.primaryAPIKeyEnvVar {
                commands.append(["config", "set", apiKeyEnvVar, draft.apiKey])
            }

            if let baseURLEnvVar = descriptor.baseURLEnvVar {
                commands.append(["config", "set", baseURLEnvVar, draft.baseURL])
                commands.append(["config", "set", "model.base_url", ""])
            } else {
                commands.append(["config", "set", "model.base_url", draft.baseURL])
            }

            commands.append(["config", "set", "OPENAI_BASE_URL", ""])
        }

        for args in commands {
            let result = try await CommandRunner.runHermes(settings, args)
            guard result.status == 0 else {
                let message = result.combinedOutput.isEmpty ? "Command failed: \(args.joined(separator: " "))" : result.combinedOutput
                throw NSError(domain: "HermesProfileStore", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
    }

    private static func parseConfigValues(from url: URL) -> [String: String] {
        guard let content = readText(at: url) else { return [:] }

        var values: [String: String] = [:]
        var sections: [(indent: Int, key: String)] = []

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let indent = line.prefix { $0 == " " }.count
            guard let colon = trimmed.firstIndex(of: ":") else { continue }

            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let valueStart = trimmed.index(after: colon)
            let rawValue = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)

            while let last = sections.last, indent <= last.indent {
                sections.removeLast()
            }

            if rawValue.isEmpty {
                sections.append((indent, key))
                continue
            }

            let path = (sections.map(\.key) + [key]).joined(separator: ".")
            values[path] = cleanValue(rawValue)
        }

        return values
    }

    private static func parseEnvValues(from url: URL) -> [String: String] {
        guard let content = readText(at: url) else { return [:] }

        var values: [String: String] = [:]
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = parts.first else { continue }
            let value = parts.count > 1 ? String(parts[1]) : ""
            values[String(key)] = cleanValue(value)
        }
        return values
    }

    private static func readText(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return try? String(contentsOf: url, encoding: .isoLatin1)
    }

    private static func cleanValue(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func parseBoolean(_ raw: String?) -> Bool {
        guard let raw else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private static func parseInteger(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
