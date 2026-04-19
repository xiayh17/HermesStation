import Foundation

struct HermesContentPackSnapshot: Hashable {
    let steps: [HermesResearchPackStep]
    let optionalUpgrades: [HermesResearchPackStep]
    let generatedAt: Date

    var safeActionSteps: [HermesResearchPackStep] {
        steps.filter { $0.canRunIndividually }
    }

    var canApplySafeChanges: Bool {
        !safeActionSteps.isEmpty
    }
}

enum HermesContentPackPlanner {
    private static let requiredToolsets = ["image_gen", "tts", "vision", "skills", "browser"]
    private static let requiredSkills = [
        "xitter",
        "popular-web-designs",
        "ideation",
        "architecture-diagram"
    ]

    static func load(
        settings: AppSettings,
        skillEntries: [SkillCatalogEntry],
        doctorReport: HermesDoctorReport?
    ) async -> HermesContentPackSnapshot {
        let paths = HermesPaths(settings: settings)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let toolStates = await loadToolStates(settings: settings)

        let disabledToolsets = requiredToolsets.filter { toolStates[$0] != true }
        let toolsetStep = HermesResearchPackStep(
            id: "content-toolsets",
            title: "Content toolsets",
            detail: disabledToolsets.isEmpty
                ? "Creative output toolsets are already enabled: \(requiredToolsets.joined(separator: ", "))."
                : "Enable missing content toolsets: \(disabledToolsets.joined(separator: ", ")).",
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
                return "Enable built-in content skills: \(missingSkillActions.joined(separator: ", "))."
            }
            if !unavailableSkills.isEmpty {
                return "All detected content skills are enabled, but HermesStation could not find: \(unavailableSkills.joined(separator: ", "))."
            }
            return "Built-in content skills are already enabled."
        }()

        let skillState: HermesResearchPackStepState = {
            if !missingSkillActions.isEmpty { return .actionNeeded }
            if !unavailableSkills.isEmpty { return .warning }
            return .ready
        }()

        let skillStep = HermesResearchPackStep(
            id: "content-skills",
            title: "Content skills",
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
            id: "content-doctor",
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
        if !hasImageProviderKey(envValues: envValues) {
            optionalUpgrades.append(
                HermesResearchPackStep(
                    id: "content-image-provider",
                    title: "Image provider",
                    detail: "Add `FAL_KEY`, `OPENAI_API_KEY`, or another image-capable provider key to `.env` so Content Pack can generate visual assets.",
                    state: .externalUpgrade,
                    isSafeAction: false,
                    commandPreview: [],
                    commands: []
                )
            )
        }
        if !hasAudioProviderKey(envValues: envValues) {
            optionalUpgrades.append(
                HermesResearchPackStep(
                    id: "content-audio-provider",
                    title: "Audio provider",
                    detail: "Add an audio-capable key such as `ELEVENLABS_API_KEY` if you want higher-quality speech output than the default TTS path.",
                    state: .externalUpgrade,
                    isSafeAction: false,
                    commandPreview: [],
                    commands: []
                )
            )
        }

        return HermesContentPackSnapshot(
            steps: [toolsetStep, skillStep, doctorStep],
            optionalUpgrades: optionalUpgrades,
            generatedAt: Date()
        )
    }

    static func applySafeChanges(
        settings: AppSettings,
        snapshot: HermesContentPackSnapshot
    ) async throws -> [HermesPackStepReceipt] {
        var receipts: [HermesPackStepReceipt] = []
        for step in snapshot.steps where step.canRunIndividually {
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

    private static func hasImageProviderKey(envValues: [String: String]) -> Bool {
        ["FAL_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"].contains { key in
            !(envValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        }
    }

    private static func hasAudioProviderKey(envValues: [String: String]) -> Bool {
        ["ELEVENLABS_API_KEY", "OPENAI_API_KEY"].contains { key in
            !(envValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        }
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
            return "Run `doctor --fix` once so HermesStation has a trust baseline after Content Pack setup."
        }
        switch report.status {
        case .clean:
            return "Doctor is already clean for this profile."
        case .fixed:
            return "Doctor already repaired this profile recently."
        case .needsAttention:
            return "Doctor still reports issues that should be reconciled after Content Pack setup."
        case .failed:
            return "Doctor failed on the last run and should be rerun."
        case .unknown:
            return "Doctor output was inconclusive; rerun after applying pack changes."
        }
    }
}
