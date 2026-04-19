import Foundation

enum HermesCapabilityDomain: String, CaseIterable, Identifiable {
    case identity
    case memory
    case perception
    case expression
    case automation
    case observability

    var id: String { rawValue }

    var title: String {
        switch self {
        case .identity: return "Identity"
        case .memory: return "Memory"
        case .perception: return "Perception"
        case .expression: return "Expression"
        case .automation: return "Automation"
        case .observability: return "Observability"
        }
    }

    var subtitle: String {
        switch self {
        case .identity: return "Who this Hermes instance is supposed to be"
        case .memory: return "What it can remember across sessions"
        case .perception: return "How it gathers and normalizes outside context"
        case .expression: return "How it responds across text, image, and audio"
        case .automation: return "How much work it can do without babysitting"
        case .observability: return "How trustworthy and inspectable the system is"
        }
    }

    var icon: String {
        switch self {
        case .identity: return "person.crop.circle.badge.checkmark"
        case .memory: return "brain.head.profile"
        case .perception: return "eye.circle"
        case .expression: return "sparkles.rectangle.stack"
        case .automation: return "clock.arrow.2.circlepath"
        case .observability: return "waveform.path.ecg.rectangle"
        }
    }
}

enum HermesCapabilityReadiness: String, Codable {
    case ready
    case partial
    case blocked
    case unverified
    case degraded

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .partial: return "Partial"
        case .blocked: return "Blocked"
        case .unverified: return "Unverified"
        case .degraded: return "Degraded"
        }
    }

    var rank: Int {
        switch self {
        case .ready: return 0
        case .partial: return 1
        case .unverified: return 2
        case .degraded: return 3
        case .blocked: return 4
        }
    }
}

enum HermesCapabilityDependencyState: String {
    case ok
    case info
    case warning
    case blocked

    var label: String {
        switch self {
        case .ok: return "OK"
        case .info: return "Info"
        case .warning: return "Check"
        case .blocked: return "Blocked"
        }
    }
}

struct HermesCapabilityDependency: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let state: HermesCapabilityDependencyState
}

struct HermesCapabilityCard: Identifiable, Hashable {
    let id: String
    let domain: HermesCapabilityDomain
    let readiness: HermesCapabilityReadiness
    let summary: String
    let providerLine: String?
    let evidenceLine: String?
    let dependencies: [HermesCapabilityDependency]
}

extension HermesCapabilityCard {
    var okDependencyCount: Int {
        dependencies.filter { $0.state == .ok }.count
    }

    var warningDependencyCount: Int {
        dependencies.filter { $0.state == .warning || $0.state == .blocked }.count
    }

    var progressLabel: String {
        "\(okDependencyCount)/\(dependencies.count) checks healthy"
    }
}

struct HermesCapabilityRecommendation: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let reason: String
    let targetDomains: [HermesCapabilityDomain]
    let actionTitle: String
    let priority: Int
}

enum HermesCapabilityEvaluator {
    static func evaluate(
        settings: AppSettings,
        gatewaySnapshot: GatewaySnapshot,
        profileSnapshot: HermesProfileSnapshot,
        platformInstances: [PlatformInstance],
        memoryEntries: [MemoryCatalogEntry],
        skillEntries: [SkillCatalogEntry]
    ) -> [HermesCapabilityCard] {
        let paths = HermesPaths(settings: settings)
        let configValues = HermesProfileStore.parseConfigValues(from: paths.configURL)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let cronStatus = loadCronStatus(from: paths.cronJobsURL)

        return [
            evaluateIdentity(
                gatewaySnapshot: gatewaySnapshot,
                profileSnapshot: profileSnapshot,
                configValues: configValues
            ),
            evaluateMemory(
                profileSnapshot: profileSnapshot,
                configValues: configValues,
                envValues: envValues,
                memoryEntries: memoryEntries
            ),
            evaluatePerception(
                gatewaySnapshot: gatewaySnapshot,
                configValues: configValues,
                envValues: envValues,
                platformInstances: platformInstances,
                skillEntries: skillEntries
            ),
            evaluateExpression(
                settings: settings,
                profileSnapshot: profileSnapshot,
                configValues: configValues,
                envValues: envValues,
                skillEntries: skillEntries
            ),
            evaluateAutomation(
                gatewaySnapshot: gatewaySnapshot,
                platformInstances: platformInstances,
                cronStatus: cronStatus
            ),
            evaluateObservability(
                gatewaySnapshot: gatewaySnapshot
            )
        ]
    }

    private static func evaluateIdentity(
        gatewaySnapshot: GatewaySnapshot,
        profileSnapshot: HermesProfileSnapshot,
        configValues: [String: String]
    ) -> HermesCapabilityCard {
        let soulExists = FileManager.default.fileExists(atPath: profileSnapshot.soulURL.path)
        let providerConfigured = !profileSnapshot.draft.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let modelConfigured = !profileSnapshot.draft.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let workspaceBound = profileSnapshot.workspaceURL != nil
        let routingConfigured = !configValues["smart_model_routing.cheap_model.provider", default: ""].isEmpty
            || profileSnapshot.routing.auxiliaryRoutes.contains { $0.provider != "main" && !$0.provider.isEmpty }
        let profileAligned = gatewaySnapshot.profileAlignment?.isAligned ?? true

        let dependencies = [
            HermesCapabilityDependency(
                id: "identity-soul",
                title: "SOUL.md",
                detail: soulExists ? "Persona file present" : "Missing profile persona file",
                state: soulExists ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "identity-provider",
                title: "Provider",
                detail: providerConfigured ? profileSnapshot.draft.provider : "No active provider configured",
                state: providerConfigured ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "identity-model",
                title: "Default model",
                detail: modelConfigured ? profileSnapshot.draft.modelName : "No default model configured",
                state: modelConfigured ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "identity-workspace",
                title: "Workspace",
                detail: workspaceBound ? (profileSnapshot.workspaceURL?.path ?? "") : "No terminal or messaging cwd bound",
                state: workspaceBound ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "identity-routing",
                title: "Routing intent",
                detail: routingConfigured ? "Auxiliary or smart routing configured" : "Main-model-only routing",
                state: routingConfigured ? .info : .warning
            ),
            HermesCapabilityDependency(
                id: "identity-profile-alignment",
                title: "CLI alignment",
                detail: profileAligned ? "Hermes CLI sticky profile matches current instance" : "CLI sticky profile does not match current HermesStation instance",
                state: profileAligned ? .ok : .warning
            )
        ]

        let readiness: HermesCapabilityReadiness
        if !providerConfigured || !modelConfigured {
            readiness = .blocked
        } else if !profileAligned {
            readiness = .degraded
        } else if !soulExists || !workspaceBound {
            readiness = .partial
        } else {
            readiness = .ready
        }

        let providerLabel = [
            profileSnapshot.providerDescriptor?.displayName ?? profileSnapshot.draft.provider,
            profileSnapshot.draft.modelName
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " · ")

        let summary: String
        switch readiness {
        case .ready:
            summary = "This Hermes instance has a persona file, active model identity, and workspace context."
        case .partial:
            summary = "Core identity exists, but the persona or working context is still thin."
        case .blocked:
            summary = "Hermes still lacks an active provider or default model, so higher-level abilities cannot stabilize."
        case .degraded:
            summary = "Identity is configured, but the CLI sticky profile is misaligned with the instance HermesStation is managing."
        case .unverified:
            summary = "Identity configuration exists, but HermesStation cannot yet trust it."
        }

        let evidenceLine = routingConfigured ? "Auxiliary routing is already being used to shape side-task behavior." : nil

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.identity.rawValue,
            domain: .identity,
            readiness: readiness,
            summary: summary,
            providerLine: providerLabel.isEmpty ? nil : providerLabel,
            evidenceLine: evidenceLine,
            dependencies: dependencies
        )
    }

    private static func evaluateMemory(
        profileSnapshot: HermesProfileSnapshot,
        configValues: [String: String],
        envValues: [String: String],
        memoryEntries: [MemoryCatalogEntry]
    ) -> HermesCapabilityCard {
        let externalMemoryConfigured = hasMemoryBackend(configValues: configValues, envValues: envValues)
        let latestMemoryDate = memoryEntries.compactMap(\.modifiedAt).max()
        let flushRoute = profileSnapshot.routing.auxiliaryRoutes.first { $0.task == "flush_memories" }?.provider ?? "main"

        let dependencies = [
            HermesCapabilityDependency(
                id: "memory-local",
                title: "Local memory",
                detail: memoryEntries.isEmpty ? "No memory entries indexed yet" : "\(memoryEntries.count) memory entries indexed",
                state: memoryEntries.isEmpty ? .warning : .ok
            ),
            HermesCapabilityDependency(
                id: "memory-external",
                title: "External backend",
                detail: externalMemoryConfigured ? "Detected external memory backend wiring" : "Only local MEMORY.md-style persistence detected",
                state: externalMemoryConfigured ? .ok : .info
            ),
            HermesCapabilityDependency(
                id: "memory-flush-route",
                title: "Flush route",
                detail: flushRoute == "main" ? "Flush memories still follows main provider" : "Flush memories routed via \(flushRoute)",
                state: flushRoute == "main" ? .info : .ok
            )
        ]

        let readiness: HermesCapabilityReadiness
        if memoryEntries.isEmpty && !externalMemoryConfigured {
            readiness = .unverified
        } else if memoryEntries.isEmpty || !externalMemoryConfigured {
            readiness = .partial
        } else {
            readiness = .ready
        }

        let summary: String
        switch readiness {
        case .ready:
            summary = "Hermes has both local memory artifacts and an external memory backend signal."
        case .partial:
            summary = "Memory is present, but it is still biased toward either local notes or backend wiring instead of both."
        case .blocked:
            summary = "Memory is not usable yet."
        case .unverified:
            summary = "HermesStation cannot yet prove this profile has durable memory beyond the default local surface."
        case .degraded:
            summary = "Memory exists, but recent runtime behavior suggests it is unreliable."
        }

        let evidenceLine: String?
        if let latestMemoryDate {
            evidenceLine = "Latest memory artifact updated \(relativeDateString(for: latestMemoryDate))."
        } else {
            evidenceLine = nil
        }

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.memory.rawValue,
            domain: .memory,
            readiness: readiness,
            summary: summary,
            providerLine: externalMemoryConfigured ? "External backend detected" : "Local memory only",
            evidenceLine: evidenceLine,
            dependencies: dependencies
        )
    }

    private static func evaluatePerception(
        gatewaySnapshot: GatewaySnapshot,
        configValues: [String: String],
        envValues: [String: String],
        platformInstances: [PlatformInstance],
        skillEntries: [SkillCatalogEntry]
    ) -> HermesCapabilityCard {
        let searchBackend = firstNonEmpty([
            configValues["web.backend"],
            configValues["search.backend"]
        ])
        let fetchSignals = countMatchingSkills(
            skillEntries,
            patterns: ["jina", "crawl4ai", "scrapling", "reader", "web", "browser"]
        )
        let documentSignals = countMatchingSkills(
            skillEntries,
            patterns: ["marker", "pandoc", "document", "pdf", "markitdown"]
        )
        let browserSignals = countMatchingSkills(
            skillEntries,
            patterns: ["browser use", "browser-use", "browser", "camofox", "playwright", "agent-browser"]
        )
        let ingressCount = platformInstances.filter(\.isEnabled).count

        let searchConfigured = !(searchBackend?.isEmpty ?? true)
        let fetchConfigured = fetchSignals > 0 || envValues.keys.contains(where: { $0.localizedCaseInsensitiveContains("JINA") })
        let documentConfigured = documentSignals > 0
        let browserConfigured = browserSignals > 0

        let achievedCount = [searchConfigured, fetchConfigured, documentConfigured, browserConfigured, ingressCount > 0].filter { $0 }.count

        let dependencies = [
            HermesCapabilityDependency(
                id: "perception-search",
                title: "Search backend",
                detail: searchConfigured ? (searchBackend ?? "") : "No search backend configured",
                state: searchConfigured ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "perception-fetch",
                title: "Content fetch",
                detail: fetchConfigured ? "Fetch-oriented skills detected" : "No clean single-page or crawl signal detected",
                state: fetchConfigured ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "perception-docs",
                title: "Document conversion",
                detail: documentConfigured ? "Document or PDF tooling signal detected" : "No document conversion tooling detected",
                state: documentConfigured ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "perception-browser",
                title: "Browser automation",
                detail: browserConfigured ? "Browser automation skill signal detected" : "No browser automation signal detected",
                state: browserConfigured ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "perception-platforms",
                title: "Ingress surfaces",
                detail: ingressCount > 0 ? "\(ingressCount) enabled message surfaces configured" : "No enabled ingress surfaces configured",
                state: ingressCount > 0 ? .ok : .info
            )
        ]

        let readiness: HermesCapabilityReadiness
        if gatewaySnapshot.runtimeIsStale && ingressCount > 0 {
            readiness = .degraded
        } else if !searchConfigured && ingressCount == 0 && !fetchConfigured {
            readiness = .blocked
        } else if achievedCount >= 4 {
            readiness = .ready
        } else {
            readiness = .partial
        }

        let summary: String
        switch readiness {
        case .ready:
            summary = "This Hermes profile can search, ingest, and normalize outside information through multiple perception paths."
        case .partial:
            summary = "Perception is coming together, but one or more of search, browser, fetch, or docs still need setup."
        case .blocked:
            summary = "Hermes has no reliable research-grade input path yet."
        case .degraded:
            summary = "Perception configuration exists, but stale runtime state makes live ingress hard to trust."
        case .unverified:
            summary = "Perception signals exist, but HermesStation cannot yet verify them."
        }

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.perception.rawValue,
            domain: .perception,
            readiness: readiness,
            summary: summary,
            providerLine: searchConfigured ? "Search via \(searchBackend ?? "configured backend")" : nil,
            evidenceLine: ingressCount > 0 ? "\(ingressCount) enabled messaging surfaces act as live ingress." : nil,
            dependencies: dependencies
        )
    }

    private static func evaluateExpression(
        settings: AppSettings,
        profileSnapshot: HermesProfileSnapshot,
        configValues: [String: String],
        envValues: [String: String],
        skillEntries: [SkillCatalogEntry]
    ) -> HermesCapabilityCard {
        let textConfigured = !profileSnapshot.draft.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profileSnapshot.draft.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let imageConfigured = hasAnyKey(in: envValues, matchingAny: ["FAL_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"])
            || countMatchingSkills(skillEntries, patterns: ["image", "flux", "fal", "dall-e", "black forest"]) > 0
            || settings.modelProviders.contains { provider in
                provider.models.contains { $0.isEnabled && $0.capabilities.contains(.image) }
            }
        let audioConfigured = hasAnyKey(in: envValues, matchingAny: ["ELEVENLABS_API_KEY", "WHISPER_API_KEY"])
            || countMatchingSkills(skillEntries, patterns: ["whisper", "audio", "speech", "tts", "voice"]) > 0
            || settings.modelProviders.contains { provider in
                provider.models.contains { $0.isEnabled && ($0.capabilities.contains(.audio) || $0.capabilities.contains(.vision)) }
            }
        let visionRouting = configValues["auxiliary.vision.provider"] ?? "main"

        let dependencies = [
            HermesCapabilityDependency(
                id: "expression-text",
                title: "Primary text model",
                detail: textConfigured ? "\(profileSnapshot.draft.provider) · \(profileSnapshot.draft.modelName)" : "No active primary model configured",
                state: textConfigured ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "expression-image",
                title: "Image generation",
                detail: imageConfigured ? "Image-capable provider or skill detected" : "No image generation signal detected",
                state: imageConfigured ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "expression-audio",
                title: "Audio I/O",
                detail: audioConfigured ? "Audio or speech capability signal detected" : "No speech-to-text or TTS signal detected",
                state: audioConfigured ? .ok : .warning
            ),
            HermesCapabilityDependency(
                id: "expression-vision-route",
                title: "Vision routing",
                detail: visionRouting == "main" ? "Vision still follows the main provider" : "Vision routed via \(visionRouting)",
                state: visionRouting == "main" ? .info : .ok
            )
        ]

        let readiness: HermesCapabilityReadiness
        if !textConfigured {
            readiness = .blocked
        } else if imageConfigured && audioConfigured {
            readiness = .ready
        } else {
            readiness = .partial
        }

        let summary: String
        switch readiness {
        case .ready:
            summary = "Hermes can already answer in text and shows signals for both image and audio expression."
        case .partial:
            summary = "Text generation is ready, but multimodal expression is still asymmetric."
        case .blocked:
            summary = "Hermes does not yet have a stable primary model, so expression cannot anchor."
        case .degraded:
            summary = "Expression exists, but it is not trustworthy right now."
        case .unverified:
            summary = "Expression signals are present, but HermesStation cannot yet verify them."
        }

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.expression.rawValue,
            domain: .expression,
            readiness: readiness,
            summary: summary,
            providerLine: textConfigured ? "\(profileSnapshot.providerDescriptor?.displayName ?? profileSnapshot.draft.provider) · \(profileSnapshot.draft.modelName)" : nil,
            evidenceLine: imageConfigured || audioConfigured ? "Multimodal signals are being inferred from installed providers, env vars, and skills." : nil,
            dependencies: dependencies
        )
    }

    private static func evaluateAutomation(
        gatewaySnapshot: GatewaySnapshot,
        platformInstances: [PlatformInstance],
        cronStatus: HermesCronStatus
    ) -> HermesCapabilityCard {
        let enabledPlatforms = platformInstances.filter(\.isEnabled)
        let liveBindings = gatewaySnapshot.boundSessionCount

        let dependencies = [
            HermesCapabilityDependency(
                id: "automation-cron",
                title: "Cron jobs",
                detail: cronStatus.totalCount == 0 ? "No cron jobs defined" : "\(cronStatus.enabledCount)/\(cronStatus.totalCount) jobs enabled",
                state: cronStatus.enabledCount > 0 ? .ok : (cronStatus.totalCount > 0 ? .warning : .blocked)
            ),
            HermesCapabilityDependency(
                id: "automation-platforms",
                title: "Platform triggers",
                detail: enabledPlatforms.isEmpty ? "No enabled message surfaces" : "\(enabledPlatforms.count) enabled message surfaces",
                state: enabledPlatforms.isEmpty ? .warning : .ok
            ),
            HermesCapabilityDependency(
                id: "automation-bindings",
                title: "Live bindings",
                detail: liveBindings > 0 ? "\(liveBindings) bound sessions available for follow-up work" : "No stored bindings yet",
                state: liveBindings > 0 ? .ok : .info
            )
        ]

        let readiness: HermesCapabilityReadiness
        if cronStatus.totalCount == 0 && enabledPlatforms.isEmpty {
            readiness = .blocked
        } else if cronStatus.enabledCount > 0 && !enabledPlatforms.isEmpty {
            readiness = .ready
        } else {
            readiness = .partial
        }

        let summary: String
        switch readiness {
        case .ready:
            summary = "Hermes has both scheduled work and live ingress surfaces for durable automation."
        case .partial:
            summary = "Automation has one half of the loop, but still needs either schedules or live triggers to mature."
        case .blocked:
            summary = "No durable automation surface is configured yet."
        case .degraded:
            summary = "Automation is configured, but recent runtime issues make it unreliable."
        case .unverified:
            summary = "Automation signals exist, but HermesStation cannot yet verify them."
        }

        let evidenceLine: String?
        if cronStatus.latestRunAtDescription != nil {
            evidenceLine = cronStatus.latestRunAtDescription
        } else {
            evidenceLine = nil
        }

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.automation.rawValue,
            domain: .automation,
            readiness: readiness,
            summary: summary,
            providerLine: cronStatus.totalCount > 0 ? "\(cronStatus.enabledCount) active jobs in cron/jobs.json" : nil,
            evidenceLine: evidenceLine,
            dependencies: dependencies
        )
    }

    private static func evaluateObservability(
        gatewaySnapshot: GatewaySnapshot
    ) -> HermesCapabilityCard {
        let runtimeTrusted = !gatewaySnapshot.runtimeIsStale && gatewaySnapshot.runtime != nil
        let doctorStatus = gatewaySnapshot.doctorReport?.status ?? .unknown
        let hasUsage = gatewaySnapshot.usage.last7Days.sessionCount > 0 || gatewaySnapshot.usage.allTime.totalTokens > 0
        let updateAvailable = gatewaySnapshot.releaseInfo?.isUpdateAvailable ?? false

        let dependencies = [
            HermesCapabilityDependency(
                id: "observability-runtime",
                title: "Runtime truth",
                detail: runtimeTrusted ? "Runtime file is trusted" : (gatewaySnapshot.runtimeIsStale ? "Runtime file is stale" : "No runtime file loaded"),
                state: runtimeTrusted ? .ok : .blocked
            ),
            HermesCapabilityDependency(
                id: "observability-doctor",
                title: "Doctor",
                detail: doctorLabel(for: gatewaySnapshot.doctorReport),
                state: doctorState(for: doctorStatus)
            ),
            HermesCapabilityDependency(
                id: "observability-usage",
                title: "Usage signal",
                detail: hasUsage ? "Usage history is available" : "No meaningful usage history yet",
                state: hasUsage ? .ok : .info
            ),
            HermesCapabilityDependency(
                id: "observability-release",
                title: "Version posture",
                detail: updateAvailable ? "A newer Hermes release is available" : "Installed version matches latest known release",
                state: updateAvailable ? .warning : .ok
            )
        ]

        let readiness: HermesCapabilityReadiness
        if gatewaySnapshot.hasDuplicateGatewayProcesses || gatewaySnapshot.runtimeIsStale || doctorStatus == .failed || doctorStatus == .needsAttention {
            readiness = .degraded
        } else if gatewaySnapshot.doctorReport == nil {
            readiness = .unverified
        } else if runtimeTrusted {
            readiness = .ready
        } else {
            readiness = .partial
        }

        let summary: String
        switch readiness {
        case .ready:
            summary = "HermesStation has a trustworthy runtime view, a doctor baseline, and usage telemetry."
        case .partial:
            summary = "Observability is mostly present, but one or more trust signals are still thin."
        case .blocked:
            summary = "Observability is not usable yet."
        case .unverified:
            summary = "The system is running, but HermesStation does not yet have a doctor-backed trust baseline."
        case .degraded:
            summary = "Runtime drift, duplicate processes, or doctor failures are reducing trust in the live system."
        }

        let evidenceLine: String?
        if let report = gatewaySnapshot.doctorReport {
            evidenceLine = "Latest doctor run: \(relativeDateString(for: report.ranAt))."
        } else {
            evidenceLine = nil
        }

        return HermesCapabilityCard(
            id: HermesCapabilityDomain.observability.rawValue,
            domain: .observability,
            readiness: readiness,
            summary: summary,
            providerLine: hasUsage ? "\(gatewaySnapshot.usage.last7Days.sessionCount) sessions in the last 7 days" : nil,
            evidenceLine: evidenceLine,
            dependencies: dependencies
        )
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    static func recommendations(
        from cards: [HermesCapabilityCard],
        platformInstances: [PlatformInstance]
    ) -> [HermesCapabilityRecommendation] {
        var recommendations: [HermesCapabilityRecommendation] = []

        let byDomain = Dictionary(uniqueKeysWithValues: cards.map { ($0.domain, $0) })
        let identity = byDomain[.identity]
        let memory = byDomain[.memory]
        let perception = byDomain[.perception]
        let expression = byDomain[.expression]
        let automation = byDomain[.automation]
        let observability = byDomain[.observability]

        if let identity, identity.readiness == .blocked || identity.readiness == .partial {
            recommendations.append(
                HermesCapabilityRecommendation(
                    id: "baseline",
                    title: "Baseline Pack",
                    summary: "先把 persona、主模型和 workspace 绑稳，后面的研究、内容和自动化能力才不会漂。",
                    reason: "Identity 现在是 \(identity.readiness.label)，这是所有能力域的前置条件。",
                    targetDomains: [.identity, .observability],
                    actionTitle: identity.readiness == .blocked ? "Open Models" : "Open General",
                    priority: 100
                )
            )
        }

        if let perception, let memory,
           perception.readiness != .ready || memory.readiness != .ready {
            recommendations.append(
                HermesCapabilityRecommendation(
                    id: "research",
                    title: "Research Pack",
                    summary: "把搜索、网页抓取、文档转换和记忆补齐，Hermes 才真正像一个研究型代理。",
                    reason: "Perception 是 \(perception.readiness.label)，Memory 是 \(memory.readiness.label)。",
                    targetDomains: [.perception, .memory],
                    actionTitle: "Open Research Pack",
                    priority: 90
                )
            )
        }

        if let expression, expression.readiness != .ready {
            recommendations.append(
                HermesCapabilityRecommendation(
                    id: "content",
                    title: "Content Pack",
                    summary: "把图片、语音和主写作模型串起来，让 Hermes 从能答复升级成能产出。",
                    reason: "Expression 现在是 \(expression.readiness.label)，多模态输出还不对称。",
                    targetDomains: [.expression, .identity],
                    actionTitle: "Open Content Pack",
                    priority: 80
                )
            )
        }

        if let automation, automation.readiness != .ready {
            let hasEnabledPlatforms = platformInstances.contains(where: \.isEnabled)
            recommendations.append(
                HermesCapabilityRecommendation(
                    id: "automation",
                    title: "Automation Pack",
                    summary: "把 cron 和消息入口连成闭环，让 Hermes 从手动助手变成持续运行的代理。",
                    reason: hasEnabledPlatforms
                        ? "Automation 现在是 \(automation.readiness.label)，cron 或 follow-up 还没成形。"
                        : "Automation 现在是 \(automation.readiness.label)，而且还缺少稳定的消息触发面。",
                    targetDomains: [.automation, .perception],
                    actionTitle: automation.readiness == .blocked ? "Open Platforms" : "Open Cron",
                    priority: 70
                )
            )
        }

        if let observability, observability.readiness == .degraded || observability.readiness == .unverified {
            recommendations.append(
                HermesCapabilityRecommendation(
                    id: "trust",
                    title: "Trust Pack",
                    summary: "先把 doctor、runtime truth 和 usage 信号打通，不然其它能力域再强也不稳。",
                    reason: "Observability 现在是 \(observability.readiness.label)。",
                    targetDomains: [.observability],
                    actionTitle: "Doctor --fix",
                    priority: observability.readiness == .degraded ? 95 : 60
                )
            )
        }

        return recommendations
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.title < rhs.title
            }
            .prefix(3)
            .map { $0 }
    }

    private static func hasMemoryBackend(configValues: [String: String], envValues: [String: String]) -> Bool {
        let allPairs = configValues.map { ($0.key, $0.value) } + envValues.map { ($0.key, $0.value) }
        return allPairs.contains { key, value in
            let keyLower = key.lowercased()
            let valueLower = value.lowercased()
            if keyLower.contains("hindsight") || valueLower.contains("hindsight") {
                return true
            }
            if keyLower.contains("memory_backend") || keyLower.contains("memory.provider") {
                return true
            }
            if keyLower.contains("mem0") || valueLower.contains("mem0") {
                return true
            }
            return false
        }
    }

    private static func countMatchingSkills(_ skillEntries: [SkillCatalogEntry], patterns: [String]) -> Int {
        skillEntries.filter { skill in
            let haystack = [
                skill.identifier,
                skill.name,
                skill.description,
                skill.relativePath,
                skill.body
            ]
            .joined(separator: "\n")
            .lowercased()
            return patterns.contains { haystack.contains($0.lowercased()) }
        }.count
    }

    private static func hasAnyKey(in envValues: [String: String], matchingAny keys: [String]) -> Bool {
        keys.contains { key in
            let value = envValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !value.isEmpty
        }
    }

    private static func doctorLabel(for report: HermesDoctorReport?) -> String {
        guard let report else { return "Doctor has not been run from HermesStation yet" }
        switch report.status {
        case .clean:
            return "Doctor checks are clean"
        case .fixed:
            return "Doctor fixed \(report.fixedCount) issues"
        case .needsAttention:
            return "Doctor still reports \(max(report.issueCount, 1)) issues"
        case .failed:
            return "Doctor failed during the last run"
        case .unknown:
            return "Doctor output did not contain enough signal"
        }
    }

    private static func doctorState(for status: HermesDoctorReportStatus) -> HermesCapabilityDependencyState {
        switch status {
        case .clean, .fixed:
            return .ok
        case .unknown:
            return .info
        case .needsAttention:
            return .warning
        case .failed:
            return .blocked
        }
    }

    private static func relativeDateString(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private struct HermesCronStatus {
        let totalCount: Int
        let enabledCount: Int
        let latestRunAtDescription: String?
    }

    private struct HermesCronJobDocument: Decodable {
        let jobs: [HermesCronJob]
    }

    private struct HermesCronJob: Decodable {
        let enabled: Bool?
        let lastRunAt: String?

        enum CodingKeys: String, CodingKey {
            case enabled
            case lastRunAt = "last_run_at"
        }
    }

    private static func loadCronStatus(from url: URL) -> HermesCronStatus {
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(HermesCronJobDocument.self, from: data) else {
            return HermesCronStatus(totalCount: 0, enabledCount: 0, latestRunAtDescription: nil)
        }

        let enabledCount = document.jobs.filter { $0.enabled ?? true }.count
        let latestDate = document.jobs
            .compactMap { parseISODate($0.lastRunAt) }
            .max()

        let latestRunAtDescription = latestDate.map { "Latest cron execution \(relativeDateString(for: $0))." }

        return HermesCronStatus(
            totalCount: document.jobs.count,
            enabledCount: enabledCount,
            latestRunAtDescription: latestRunAtDescription
        )
    }

    private static func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let formatters: [ISO8601DateFormatter] = {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return [fractional, plain]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
