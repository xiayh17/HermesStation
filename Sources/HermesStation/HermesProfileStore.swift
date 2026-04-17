import Foundation
import Combine

enum ProviderAuthType: Equatable {
    case apiKey
    case oauth
    case mixed
}

struct HermesProviderDescriptor: Identifiable, Equatable {
    let id: String
    let displayName: String
    let apiKeyEnvVars: [String]
    let baseURLEnvVar: String?
    let authType: ProviderAuthType

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
        .init(id: "custom", displayName: "Custom / OpenAI-compatible", apiKeyEnvVars: ["OPENAI_API_KEY"], baseURLEnvVar: nil, authType: .apiKey),
        .init(id: "openrouter", displayName: "OpenRouter", apiKeyEnvVars: ["OPENROUTER_API_KEY"], baseURLEnvVar: "OPENROUTER_BASE_URL", authType: .apiKey),
        .init(id: "anthropic", displayName: "Anthropic", apiKeyEnvVars: ["ANTHROPIC_API_KEY", "ANTHROPIC_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"], baseURLEnvVar: nil, authType: .apiKey),
        .init(id: "gemini", displayName: "Google AI Studio", apiKeyEnvVars: ["GOOGLE_API_KEY", "GEMINI_API_KEY"], baseURLEnvVar: "GEMINI_BASE_URL", authType: .apiKey),
        .init(id: "zai", displayName: "Z.AI / GLM", apiKeyEnvVars: ["GLM_API_KEY", "ZAI_API_KEY", "Z_AI_API_KEY"], baseURLEnvVar: "GLM_BASE_URL", authType: .apiKey),
        .init(id: "kimi-coding", displayName: "Kimi / Moonshot", apiKeyEnvVars: ["KIMI_API_KEY"], baseURLEnvVar: "KIMI_BASE_URL", authType: .apiKey),
        .init(id: "minimax", displayName: "MiniMax", apiKeyEnvVars: ["MINIMAX_API_KEY"], baseURLEnvVar: "MINIMAX_BASE_URL", authType: .apiKey),
        .init(id: "minimax-cn", displayName: "MiniMax (China)", apiKeyEnvVars: ["MINIMAX_CN_API_KEY"], baseURLEnvVar: "MINIMAX_CN_BASE_URL", authType: .apiKey),
        .init(id: "alibaba", displayName: "Alibaba / DashScope", apiKeyEnvVars: ["DASHSCOPE_API_KEY"], baseURLEnvVar: "DASHSCOPE_BASE_URL", authType: .apiKey),
        .init(id: "xai", displayName: "xAI", apiKeyEnvVars: ["XAI_API_KEY"], baseURLEnvVar: "XAI_BASE_URL", authType: .apiKey),
        .init(id: "ai-gateway", displayName: "AI Gateway", apiKeyEnvVars: ["AI_GATEWAY_API_KEY"], baseURLEnvVar: "AI_GATEWAY_BASE_URL", authType: .apiKey),
        .init(id: "opencode-zen", displayName: "OpenCode Zen", apiKeyEnvVars: ["OPENCODE_ZEN_API_KEY"], baseURLEnvVar: "OPENCODE_ZEN_BASE_URL", authType: .apiKey),
        .init(id: "opencode-go", displayName: "OpenCode Go", apiKeyEnvVars: ["OPENCODE_GO_API_KEY"], baseURLEnvVar: "OPENCODE_GO_BASE_URL", authType: .apiKey),
        .init(id: "kilocode", displayName: "Kilo Code", apiKeyEnvVars: ["KILOCODE_API_KEY"], baseURLEnvVar: "KILOCODE_BASE_URL", authType: .apiKey),
        .init(id: "huggingface", displayName: "Hugging Face", apiKeyEnvVars: ["HF_TOKEN"], baseURLEnvVar: "HF_BASE_URL", authType: .apiKey),
        .init(id: "xiaomi", displayName: "Xiaomi MiMo", apiKeyEnvVars: ["XIAOMI_API_KEY"], baseURLEnvVar: "XIAOMI_BASE_URL", authType: .apiKey),
        .init(id: "nous", displayName: "Nous Portal", apiKeyEnvVars: [], baseURLEnvVar: nil, authType: .oauth),
        .init(id: "openai-codex", displayName: "OpenAI Codex", apiKeyEnvVars: [], baseURLEnvVar: nil, authType: .oauth),
        .init(id: "qwen-oauth", displayName: "Qwen OAuth", apiKeyEnvVars: [], baseURLEnvVar: nil, authType: .oauth),
        .init(id: "copilot", displayName: "GitHub Copilot", apiKeyEnvVars: ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"], baseURLEnvVar: nil, authType: .mixed),
        .init(id: "copilot-acp", displayName: "GitHub Copilot ACP", apiKeyEnvVars: [], baseURLEnvVar: "COPILOT_ACP_BASE_URL", authType: .apiKey),
        .init(id: "arcee", displayName: "Arcee AI", apiKeyEnvVars: ["ARCEEAI_API_KEY"], baseURLEnvVar: "ARCEEAI_BASE_URL", authType: .apiKey),
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
            baseURL: SavedProviderConnection.normalizedBaseURL(
                providerID: provider,
                baseURL: baseURL
            ),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            terminalCwd: terminalCwd.trimmingCharacters(in: .whitespacesAndNewlines),
            messagingCwd: messagingCwd.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct HermesProfileSnapshot: Equatable {
    let configURL: URL
    let envURL: URL
    let soulURL: URL
    let draft: HermesProfileDraft
    let providerDescriptor: HermesProviderDescriptor?
    let routing: HermesRoutingSummary
    let notes: [String]

    static func empty(settings: AppSettings) -> HermesProfileSnapshot {
        let paths = HermesPaths(settings: settings)
        return HermesProfileSnapshot(
            configURL: paths.hermesHome.appending(path: "config.yaml"),
            envURL: paths.hermesHome.appending(path: ".env"),
            soulURL: paths.hermesHome.appending(path: "SOUL.md"),
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
            lastSaveMessage = "Provider \(normalized.provider) 还没有在 HermesStation 里做真实映射，先直接用 Hermes CLI 改。"
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

    func openSoulFile() {
        Task { _ = try? await CommandRunner.openPath(snapshot.soulURL) }
    }

    // MARK: - Model Health

    enum ModelHealthStatus: Equatable {
        case unknown
        case checking
        case healthy
        case unhealthy(String, Int?)
        case authError
        case noModel

        var isHealthy: Bool {
            if case .healthy = self { return true }
            return false
        }

        var displayText: String {
            switch self {
            case .unknown: return "未检查"
            case .checking: return "检查中..."
            case .healthy: return "可用"
            case .unhealthy(let reason, _): return "不可用: \(reason)"
            case .authError: return "认证失败"
            case .noModel: return "未配置模型"
            }
        }
    }

    struct ModelHealthResult: Equatable {
        let provider: String
        let model: String
        let status: ModelHealthStatus
    }

    nonisolated func checkModelHealth(provider: String, baseURL: String, apiKey: String, model: String) async -> ModelHealthStatus {
        guard !model.isEmpty else { return .noModel }
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return .unhealthy("缺少 base URL 或 API Key", nil) }

        guard let url = Self.healthEndpointURL(provider: provider, baseURL: baseURL, path: "chat/completions") else {
            return .unhealthy("无效的 base URL", nil)
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return .unhealthy("请求构造失败", nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (header, value) in Self.providerSpecificHeaders(provider: provider, baseURL: baseURL) {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpBody = body
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unhealthy("无效响应", nil)
            }

            let bodyString = String(data: data, encoding: .utf8) ?? ""

            switch httpResponse.statusCode {
            case 200...299:
                return .healthy
            case 401, 403:
                return .authError
            case 404:
                if bodyString.contains("resource_not_found_error") || bodyString.contains("model") && bodyString.contains("not found") {
                    return .unhealthy("模型不存在 (404)", 404)
                }
                return .unhealthy("接口不存在 (404)", 404)
            case 400:
                if bodyString.contains("context") || bodyString.contains("too long") || bodyString.contains("length") || bodyString.contains("tokens") {
                    return .healthy
                }
                if bodyString.contains("model") && (bodyString.contains("not exist") || bodyString.contains("not supported") || bodyString.contains("invalid")) {
                    return .unhealthy("模型不存在 (400)", 400)
                }
                return .unhealthy("请求错误 (400)", 400)
            case 429:
                return .healthy
            case 500...599:
                return .unhealthy("服务端错误 (\(httpResponse.statusCode))", httpResponse.statusCode)
            default:
                return .unhealthy("HTTP \(httpResponse.statusCode)", httpResponse.statusCode)
            }
        } catch URLError.timedOut {
            return .unhealthy("请求超时", nil)
        } catch {
            return .unhealthy(error.localizedDescription, nil)
        }
    }

    nonisolated func fetchAvailableModels(provider: String, baseURL: String, apiKey: String) async -> [String] {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return [] }
        guard let url = Self.healthEndpointURL(provider: provider, baseURL: baseURL, path: "models") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (header, value) in Self.providerSpecificHeaders(provider: provider, baseURL: baseURL) {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelList = json["data"] as? [[String: Any]] else {
                return []
            }
            return modelList.compactMap { $0["id"] as? String }
        } catch {
            return []
        }
    }

    func fallbackModel(for providerID: String) -> String? {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canonical = HermesProviderDescriptor.resolve(normalized)?.id ?? normalized
        switch canonical {
        case "kimi-coding", "kimi", "moonshot":
            return "kimi-for-coding"
        case "openrouter":
            return "openai/gpt-4o"
        case "anthropic":
            return "claude-sonnet-4-20250514"
        case "gemini", "google-ai-studio":
            return "gemini-2.0-flash"
        case "minimax", "minimax-cn":
            return "minimax-text-01"
        case "alibaba", "dashscope":
            return "qwen-max"
        case "xai":
            return "grok-3"
        case "zai", "glm":
            return "glm-4-plus"
        case "custom":
            return "gpt-4o"
        default:
            return "gpt-4o"
        }
    }

    func autoFixModel(provider: String, model: String) async -> (success: Bool, message: String, newDraft: HermesProfileDraft?) {
        let draft = snapshot.draft
        let fixedBaseURL = draft.baseURL
        let fixedAPIKey = draft.apiKey

        let available = await fetchAvailableModels(provider: provider, baseURL: fixedBaseURL, apiKey: fixedAPIKey)
        let replacement: String
        if let firstAvailable = available.first {
            if available.contains(model) {
                return (false, "模型 \(model) 在 /v1/models 列表中存在，可能只是临时不可用。请手动检查。", nil)
            }
            replacement = firstAvailable
        } else if let fallback = fallbackModel(for: provider) {
            replacement = fallback
        } else {
            return (false, "无法获取可用模型列表，也没有内置 fallback。", nil)
        }

        let newDraft = HermesProfileDraft(
            provider: provider,
            modelName: replacement,
            baseURL: draft.baseURL,
            apiKey: draft.apiKey,
            terminalCwd: draft.terminalCwd,
            messagingCwd: draft.messagingCwd
        )

        let descriptor = HermesProviderDescriptor.resolve(provider)
        do {
            try await Self.apply(settings: settingsStore.settings, draft: newDraft, descriptor: descriptor)
            await MainActor.run {
                self.snapshot = Self.loadSnapshot(settings: settingsStore.settings)
                self.lastSaveMessage = "已将失效模型 \(model) 修复为 \(replacement)。重启 gateway 后生效。"
            }
            return (true, "已将失效模型 \(model) 修复为 \(replacement)。", newDraft)
        } catch {
            return (false, "修复失败: \(error.localizedDescription)", nil)
        }
    }

    private static func loadSnapshot(settings: AppSettings) -> HermesProfileSnapshot {
        let paths = HermesPaths(settings: settings)
        let configURL = paths.configURL
        let envURL = paths.envURL
        let soulURL = paths.soulURL

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
        } else if let envVar = descriptor?.baseURLEnvVar {
            let configuredBaseURL = envValues[envVar] ?? configValues[envVar] ?? ""
            if !configuredBaseURL.isEmpty {
                effectiveBaseURL = SavedProviderConnection.normalizedBaseURL(
                    providerID: provider,
                    baseURL: configuredBaseURL
                )
            } else {
                effectiveBaseURL = modelBaseURL
            }
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
            notes.append("当前 provider 没有在 HermesStation 里做映射，面板只能展示，不能安全保存。")
        }

        return HermesProfileSnapshot(
            configURL: configURL,
            envURL: envURL,
            soulURL: soulURL,
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

    private nonisolated static func healthEndpointURL(provider: String, baseURL: String, path: String) -> URL? {
        let normalizedBaseURL = SavedProviderConnection.normalizedBaseURL(providerID: provider, baseURL: baseURL)
        guard !normalizedBaseURL.isEmpty else { return nil }

        let prefix: String
        if normalizedBaseURL.lowercased().hasSuffix("/v1") {
            prefix = normalizedBaseURL
        } else {
            prefix = "\(normalizedBaseURL)/v1"
        }

        return URL(string: "\(prefix)/\(path)")
    }

    private nonisolated static func providerSpecificHeaders(provider: String, baseURL: String) -> [String: String] {
        let normalizedBaseURL = SavedProviderConnection.normalizedBaseURL(providerID: provider, baseURL: baseURL).lowercased()
        if normalizedBaseURL.contains("api.kimi.com") {
            return ["User-Agent": "KimiCLI/1.30.0"]
        }
        return [:]
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

    nonisolated static func parseConfigValues(from url: URL) -> [String: String] {
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

    nonisolated static func parseEnvValues(from url: URL) -> [String: String] {
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

    nonisolated private static func readText(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return try? String(contentsOf: url, encoding: .isoLatin1)
    }

    nonisolated private static func cleanValue(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    nonisolated private static func parseBoolean(_ raw: String?) -> Bool {
        guard let raw else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    nonisolated private static func parseInteger(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
