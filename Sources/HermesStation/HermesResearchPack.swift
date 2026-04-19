import Foundation

enum HermesPackKind: String, Identifiable {
    case research
    case content

    var id: String { rawValue }

    var title: String {
        switch self {
        case .research: return "Research Pack"
        case .content: return "Content Pack"
        }
    }
}

enum HermesResearchPackStepState: String {
    case ready
    case actionNeeded
    case externalUpgrade
    case warning

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .actionNeeded: return "Apply"
        case .externalUpgrade: return "Optional"
        case .warning: return "Check"
        }
    }
}

struct HermesPackCommand: Hashable {
    let args: [String]
    let preview: String
    let successSummary: String
}

enum HermesPackStepReceiptStatus: String {
    case success
    case failure
}

struct HermesPackStepReceipt: Identifiable, Hashable {
    let id: String
    let stepID: String
    let status: HermesPackStepReceiptStatus
    let summary: String
    let output: String
    let ranAt: Date
}

struct HermesResearchPackStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let state: HermesResearchPackStepState
    let isSafeAction: Bool
    let commandPreview: [String]
    let commands: [HermesPackCommand]

    var canRunIndividually: Bool {
        isSafeAction && state == .actionNeeded && !commands.isEmpty
    }
}

struct HermesResearchPackSnapshot: Hashable {
    let desiredSearchBackend: String
    let steps: [HermesResearchPackStep]
    let optionalUpgrades: [HermesResearchPackStep]
    let generatedAt: Date

    var safeActionSteps: [HermesResearchPackStep] {
        steps.filter { $0.isSafeAction && $0.state == .actionNeeded }
    }

    var canApplySafeChanges: Bool {
        !safeActionSteps.isEmpty
    }
}

enum HermesResearchPackPlanner {
    private static let requiredToolsets = ["web", "browser", "skills", "memory", "session_search"]
    private static let requiredSkills = [
        "arxiv",
        "llm-wiki",
        "blogwatcher",
        "research-paper-writing",
        "ocr-and-documents",
        "nano-pdf"
    ]

    static func load(
        settings: AppSettings,
        skillEntries: [SkillCatalogEntry],
        doctorReport: HermesDoctorReport?
    ) async -> HermesResearchPackSnapshot {
        let paths = HermesPaths(settings: settings)
        let configValues = HermesProfileStore.parseConfigValues(from: paths.configURL)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let toolStates = await loadToolStates(settings: settings)

        let desiredSearchBackend = hasTavilyKey(envValues: envValues) ? "tavily" : "duckduckgo"
        let currentSearchBackend = configValues["web.backend"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let searchStep = HermesResearchPackStep(
            id: "search-backend",
            title: "Search backend",
            detail: currentSearchBackend == desiredSearchBackend
                ? "Using \(desiredSearchBackend) for web search."
                : "Switch web search backend from \(currentSearchBackend.isEmpty ? "unset" : currentSearchBackend) to \(desiredSearchBackend).",
            state: currentSearchBackend == desiredSearchBackend ? .ready : .actionNeeded,
            isSafeAction: currentSearchBackend != desiredSearchBackend,
            commandPreview: currentSearchBackend == desiredSearchBackend ? [] : ["hermes config set web.backend \(desiredSearchBackend)"],
            commands: currentSearchBackend == desiredSearchBackend ? [] : [
                HermesPackCommand(
                    args: ["config", "set", "web.backend", desiredSearchBackend],
                    preview: "hermes config set web.backend \(desiredSearchBackend)",
                    successSummary: "Set web.backend to \(desiredSearchBackend)."
                )
            ]
        )

        let disabledToolsets = requiredToolsets.filter { toolStates[$0] != true }
        let toolsetStep = HermesResearchPackStep(
            id: "toolsets",
            title: "Research toolsets",
            detail: disabledToolsets.isEmpty
                ? "Required CLI toolsets are already enabled: \(requiredToolsets.joined(separator: ", "))."
                : "Enable missing CLI toolsets: \(disabledToolsets.joined(separator: ", ")).",
            state: disabledToolsets.isEmpty ? .ready : .actionNeeded,
            isSafeAction: !disabledToolsets.isEmpty,
            commandPreview: disabledToolsets.map { "hermes tools enable --platform cli \($0)" },
            commands: disabledToolsets.map { tool in
                HermesPackCommand(
                    args: ["tools", "enable", "--platform", "cli", tool],
                    preview: "hermes tools enable --platform cli \(tool)",
                    successSummary: "Enabled CLI toolset \(tool)."
                )
            }
        )

        let installedSkillMap = Dictionary(uniqueKeysWithValues: skillEntries.map { ($0.identifier, $0) })
        let missingSkillActions = requiredSkills.compactMap { skillID -> String? in
            guard let skill = installedSkillMap[skillID], !skill.isEnabled else { return nil }
            return skillID
        }
        let unavailableSkills = requiredSkills.filter { installedSkillMap[$0] == nil }

        let skillDetail: String = {
            if !missingSkillActions.isEmpty {
                return "Enable built-in research skills: \(missingSkillActions.joined(separator: ", "))."
            }
            if !unavailableSkills.isEmpty {
                return "All detected research skills are enabled, but HermesStation could not find: \(unavailableSkills.joined(separator: ", "))."
            }
            return "Built-in research and document skills are already enabled."
        }()

        let skillState: HermesResearchPackStepState = {
            if !missingSkillActions.isEmpty { return .actionNeeded }
            if !unavailableSkills.isEmpty { return .warning }
            return .ready
        }()

        let skillStep = HermesResearchPackStep(
            id: "skills",
            title: "Research skills",
            detail: skillDetail,
            state: skillState,
            isSafeAction: !missingSkillActions.isEmpty,
            commandPreview: missingSkillActions.map { "hermes skills enable \($0)" },
            commands: missingSkillActions.map { skill in
                HermesPackCommand(
                    args: ["skills", "enable", skill],
                    preview: "hermes skills enable \(skill)",
                    successSummary: "Enabled skill \(skill)."
                )
            }
        )

        let doctorStep = HermesResearchPackStep(
            id: "doctor",
            title: "Doctor baseline",
            detail: doctorDetail(for: doctorReport),
            state: doctorState(for: doctorReport),
            isSafeAction: doctorNeedsAttention(doctorReport),
            commandPreview: doctorNeedsAttention(doctorReport) ? ["hermes doctor --fix"] : [],
            commands: doctorNeedsAttention(doctorReport) ? [
                HermesPackCommand(
                    args: ["doctor", "--fix"],
                    preview: "hermes doctor --fix",
                    successSummary: "Doctor --fix completed."
                )
            ] : []
        )

        var optionalUpgrades: [HermesResearchPackStep] = []
        if !hasTavilyKey(envValues: envValues) {
            optionalUpgrades.append(
                HermesResearchPackStep(
                    id: "tavily-key",
                    title: "Tavily upgrade",
                    detail: "Add `TAVILY_API_KEY` to `.env` to upgrade Research Pack from DuckDuckGo fallback to cited Tavily search.",
                    state: .externalUpgrade,
                    isSafeAction: false,
                    commandPreview: [],
                    commands: []
                )
            )
        }

        return HermesResearchPackSnapshot(
            desiredSearchBackend: desiredSearchBackend,
            steps: [searchStep, toolsetStep, skillStep, doctorStep],
            optionalUpgrades: optionalUpgrades,
            generatedAt: Date()
        )
    }

    static func applySafeChanges(
        settings: AppSettings,
        snapshot: HermesResearchPackSnapshot
    ) async throws -> [HermesPackStepReceipt] {
        var receipts: [HermesPackStepReceipt] = []

        for step in snapshot.steps where step.isSafeAction && step.state == .actionNeeded {
            receipts.append(try await HermesPackExecutor.apply(step: step, settings: settings))
        }

        return receipts
    }

    private static func loadToolStates(settings: AppSettings) async -> [String: Bool] {
        do {
            let result = try await CommandRunner.runHermes(settings, ["tools", "list", "--platform", "cli"])
            guard result.status == 0 else { return [:] }
            return parseToolStates(result.combinedOutput)
        } catch {
            return [:]
        }
    }

    private static func parseToolStates(_ output: String) -> [String: Bool] {
        var states: [String: Bool] = [:]

        for rawLine in output.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("✓ enabled") || line.contains("✓ enabled") {
                let pieces = line.split(whereSeparator: \.isWhitespace)
                if pieces.count >= 3 {
                    states[String(pieces[2])] = true
                }
            } else if line.hasPrefix("✗ disabled") || line.contains("✗ disabled") {
                let pieces = line.split(whereSeparator: \.isWhitespace)
                if pieces.count >= 3 {
                    states[String(pieces[2])] = false
                }
            }
        }

        return states
    }

    private static func hasTavilyKey(envValues: [String: String]) -> Bool {
        let key = envValues["TAVILY_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !key.isEmpty
    }

    private static func doctorNeedsAttention(_ report: HermesDoctorReport?) -> Bool {
        guard let report else { return true }
        switch report.status {
        case .clean, .fixed:
            return false
        case .needsAttention, .failed, .unknown:
            return true
        }
    }

    private static func doctorState(for report: HermesDoctorReport?) -> HermesResearchPackStepState {
        guard let report else { return .actionNeeded }
        switch report.status {
        case .clean, .fixed:
            return .ready
        case .needsAttention, .failed:
            return .actionNeeded
        case .unknown:
            return .warning
        }
    }

    private static func doctorDetail(for report: HermesDoctorReport?) -> String {
        guard let report else {
            return "Run `doctor --fix` once so HermesStation has a trust baseline after pack setup."
        }
        switch report.status {
        case .clean:
            return "Doctor is already clean for this profile."
        case .fixed:
            return "Doctor already repaired this profile recently."
        case .needsAttention:
            return "Doctor still reports issues that should be reconciled after Research Pack setup."
        case .failed:
            return "Doctor failed on the last run and should be rerun."
        case .unknown:
            return "Doctor output was inconclusive; rerun after applying pack changes."
        }
    }

    private static func researchPackError(_ step: String, _ output: String) -> NSError {
        NSError(
            domain: "HermesResearchPack",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "\(step) failed."
                    : output
            ]
        )
    }
}

enum HermesPackExecutor {
    static func apply(step: HermesResearchPackStep, settings: AppSettings) async throws -> HermesPackStepReceipt {
        guard step.canRunIndividually else {
            throw NSError(
                domain: "HermesPackExecutor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(step.title) has no safe executable action."]
            )
        }

        var collectedOutput: [String] = []

        for command in step.commands {
            let result = try await CommandRunner.runHermes(settings, command.args)
            guard result.status == 0 else {
                throw NSError(
                    domain: "HermesPackExecutor",
                    code: Int(result.status),
                    userInfo: [NSLocalizedDescriptionKey: result.combinedOutput.isEmpty ? "\(step.title) failed." : result.combinedOutput]
                )
            }
            collectedOutput.append(result.combinedOutput.isEmpty ? command.successSummary : result.combinedOutput)
        }

        let output = collectedOutput.joined(separator: "\n\n")
        return HermesPackStepReceipt(
            id: "\(step.id)-\(UUID().uuidString)",
            stepID: step.id,
            status: .success,
            summary: output.isEmpty ? "\(step.title) completed." : output.components(separatedBy: "\n").first ?? "\(step.title) completed.",
            output: output,
            ranAt: Date()
        )
    }
}
