import SwiftUI
import Charts

private enum SettingsTab: Hashable, CaseIterable {
    case station
    case general
    case model
    case sessions
    case memory
    case skills
    case tools
    case cronjobs
    case usage
    case platforms
    case environment
}

enum AgentPanelFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .running: return "Running"
        case .completed: return "Completed"
        }
    }
}

private enum SkillPanelFilter: String, CaseIterable, Identifiable {
    case all
    case enabled
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        }
    }
}

private struct AuxiliaryProviderOption: Identifiable, Hashable {
    let id: String
    let label: String
}

private struct ProviderPresetOption: Identifiable, Hashable {
    let id: String
    let label: String
}

private enum ValidationSeverity {
    case error
    case warning

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        }
    }

    var symbol: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

private struct ValidationIssue: Identifiable {
    let id = UUID()
    let severity: ValidationSeverity
    let message: String
}

private enum UsageWindow: String, CaseIterable, Identifiable {
    case last24Hours
    case last7Days
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours: return "24h"
        case .last7Days: return "7d"
        case .allTime: return "All"
        }
    }
}

private enum UsageChartMetric: String, CaseIterable, Identifiable {
    case sessions
    case tokens
    case cost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions: return "Sessions"
        case .tokens: return "Tokens"
        case .cost: return "Cost"
        }
    }
}

private enum AddAPIWizardPage: Int, CaseIterable {
    case connection
    case models

    var title: String {
        switch self {
        case .connection: return "API Connection"
        case .models: return "Models"
        }
    }
}

private enum ModelSidebarDestination: Hashable {
    case current
    case routing
    case health
    case provider(UUID)
}

private struct ModelHealthProbeTarget {
    let provider: String
    let model: String
    let baseURL: String
    let apiKey: String
}

private let kimiCodingPlanDocsURL = "https://www.kimi.com/code/docs/more/third-party-agents.html"

private enum PlatformDependencyStatus {
    case ok
    case info
    case warning
    case blocker

    var label: String {
        switch self {
        case .ok: return "OK"
        case .info: return "Info"
        case .warning: return "Check"
        case .blocker: return "Blocked"
        }
    }

    var color: Color {
        switch self {
        case .ok: return .green
        case .info: return .blue
        case .warning: return .orange
        case .blocker: return .red
        }
    }

    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocker: return "xmark.octagon.fill"
        }
    }
}

private enum PlatformDependencyAction {
    case installLarkOAPI
    case restartGateway
    case openGatewayLog
    case openEnvFile
}

private struct PlatformDependencyCheck: Identifiable {
    let id: String
    let status: PlatformDependencyStatus
    let title: String
    let detail: String
    let action: PlatformDependencyAction?
}

private struct HermesProfileOverview: Identifiable {
    let id: UUID
    let settings: AppSettings
    let paths: HermesPaths
    let configuredPlatforms: [PlatformInstance]
    let enabledPlatformCount: Int
    let totalModelCount: Int
    let configExists: Bool
    let envExists: Bool
    let soulExists: Bool
    let runtimeExists: Bool
}

private struct SettingsTabPage: Identifiable {
    let id: SettingsTab
    let title: String
    let systemImage: String
    let view: AnyView
}

private struct SettingsTabHost: View {
    @Binding var selectedTab: SettingsTab
    let pages: [SettingsTabPage]

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(pages) { page in
                page.view
                    .tabItem { Label(page.title, systemImage: page.systemImage) }
                    .tag(page.id)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var profileStore: HermesProfileStore
    @EnvironmentObject private var gatewayStore: GatewayStore

    @State private var appDraft: AppSettings = .default
    @State private var hermesDraft: HermesProfileDraft = .empty
    @State private var hasLoadedDraft = false
    @State private var selectedTab: SettingsTab = .general
    @State private var selectedModelProviderID: UUID?
    @State private var selectedSavedModelID: UUID?
    @State private var selectedModelSidebarDestination: ModelSidebarDestination = .current
    @State private var auxiliaryProviderDrafts: [String: String] = [:]
    @State private var smartRoutingEnabledDraft = false
    @State private var smartRoutingProviderDraft = ""
    @State private var smartRoutingModelDraft = ""
    @State private var smartRoutingMaxSimpleCharsDraft = "160"
    @State private var smartRoutingMaxSimpleWordsDraft = "28"
    @State private var showAddAPIWizard = false
    @State private var addAPIWizardPage: AddAPIWizardPage = .connection
    @State private var newProviderDraft = SavedProviderConnection.blank()
    @State private var newProviderSelectedModelID: UUID?
    @State private var newProviderPresetID = "custom"
    @State private var selectedUsageWindow: UsageWindow = .last7Days
    @State private var selectedUsageMetric: UsageChartMetric = .tokens
    @State private var selectedAgentID: String?
    @State private var agentSearchText: String = ""
    @State private var agentFilter: AgentPanelFilter = .all
    @State private var agentTranscriptSearchTextByID: [String: String] = [:]
    @State private var isLoadingAgentSearchIndex = false
    @State private var agentRenameDraft: String = ""
    @State private var memoryEntries: [MemoryCatalogEntry] = []
    @State private var selectedMemoryEntryID: String?
    @State private var memorySearchText: String = ""
    @State private var memorySourceFilter: String = "All"
    @State private var isLoadingMemoryEntries = false
    @State private var skillEntries: [SkillCatalogEntry] = []
    @State private var selectedSkillEntryID: String?
    @State private var skillSearchText: String = ""
    @State private var skillFilter: SkillPanelFilter = .all
    @State private var isLoadingSkillEntries = false
    @State private var isPerformingSkillAction = false
    @State private var skillActionMessage: String?
    @State private var showDeleteAgentAlert = false
    @State private var showDeleteProviderAlert = false
    @State private var selectedAgentTranscript: SessionTranscript? = nil
    @State private var isLoadingTranscript = false
    @State private var selectedPlatformInstanceID: String?
    @State private var platformInstancesCache: [PlatformInstance] = []
    @State private var platformConfigDrafts: [String: String] = [:]
    @State private var showAddPlatformWizard = false
    @State private var newPlatformPresetID = ""
    @State private var newPlatformConfigDrafts: [String: String] = [:]
    @State private var isSavingPlatforms = false
    @State private var platformStatusMessage: String?
    @State private var platformDraftOverrides: [String: [String: String]] = [:]
    @State private var platformDiagnosticSummary: String?
    @State private var platformDiagnosticLines: [String] = []
    @State private var platformDependencyChecks: [PlatformDependencyCheck] = []
    @State private var isCheckingPlatformDependencies = false
    @State private var modelHealthResults: [HermesProfileStore.ModelHealthResult] = []
    @State private var isCheckingModelHealth = false
    @State private var modelHealthFixMessage: String?
    @State private var newAliasName: String = ""
    @State private var researchPackSnapshot: HermesResearchPackSnapshot?
    @State private var contentPackSnapshot: HermesContentPackSnapshot?
    @State private var isLoadingPacks = false
    @State private var applyingPackKinds: Set<HermesPackKind> = []
    @State private var inFlightPackStepIDs: Set<String> = []
    @State private var packMessages: [HermesPackKind: String] = [:]
    @State private var packReceipts: [String: HermesPackStepReceipt] = [:]
    @State private var activePackSheet: HermesPackKind?

    var body: some View {
        settingsContent
    }

    private var settingsContent: some View {
        let pages = makeSettingsTabPages()
        let host = SettingsTabHost(selectedTab: $selectedTab, pages: pages)
        let base = AnyView(
            host
                .frame(minWidth: 980, idealWidth: 1080, minHeight: 620, idealHeight: 720)
                .sheet(item: $activePackSheet) { pack in
                    packSheet(for: pack)
                }
        )

        return base
            .onAppear {
                guard !hasLoadedDraft else { return }
                syncDrafts()
                refreshPlatformInstances()
                reloadKnowledgeCatalogs()
                reloadAgentSearchIndex()
                loadCapabilityPacks()
                hasLoadedDraft = true
            }
            .onChange(of: settingsStore.settings) { _, newValue in
                appDraft = newValue
                platformDraftOverrides = [:]
                platformStatusMessage = nil
                selectedPlatformInstanceID = nil
                refreshPlatformInstances()
                syncModelSelection()
                reloadKnowledgeCatalogs()
                reloadAgentSearchIndex()
                loadCapabilityPacks()
            }
            .onChange(of: profileStore.snapshot) { _, newValue in
                hermesDraft = newValue.draft
                auxiliaryProviderDrafts = Dictionary(uniqueKeysWithValues: newValue.routing.auxiliaryRoutes.map { ($0.task, $0.provider) })
                syncSmartRoutingDrafts(from: newValue.routing)
                refreshPlatformInstances()
                refreshPlatformDiagnostics()
                loadCapabilityPacks()
            }
            .onChange(of: stationDiagnosticsTrigger) { _, _ in
                refreshPlatformDiagnostics()
                loadCapabilityPacks()
            }
            .onChange(of: selectedModelProviderID) { _, _ in
                syncSelectedSavedModel()
            }
            .onChange(of: selectedModelSidebarDestination) { _, newValue in
                if case let .provider(id) = newValue {
                    selectedModelProviderID = id
                    syncSelectedSavedModel()
                }
            }
            .onChange(of: selectedAgentID) { _, newValue in
                guard let newValue, let agent = gatewayStore.snapshot.agentSessions.rows.first(where: { $0.id == newValue }) else {
                    agentRenameDraft = ""
                    selectedAgentTranscript = nil
                    return
                }
                agentRenameDraft = agent.title
                loadTranscript(for: agent)
            }
            .onChange(of: agentSelectionTrigger) { _, _ in
                syncAgentSelection()
                reloadAgentSearchIndex()
            }
            .onChange(of: memoryFilterTrigger) { _, _ in
                syncMemorySelection()
            }
            .onChange(of: skillFilterTrigger) { _, _ in
                syncSkillSelection()
                loadCapabilityPacks()
            }
    }

    private func makeSettingsTabPages() -> [SettingsTabPage] {
        [
            SettingsTabPage(id: .station, title: "Hermes", systemImage: "square.grid.2x2", view: AnyView(stationTab)),
            SettingsTabPage(id: .general, title: "通用", systemImage: "gearshape", view: AnyView(generalTab)),
            SettingsTabPage(id: .model, title: "模型", systemImage: "cpu", view: AnyView(modelTab)),
            SettingsTabPage(id: .sessions, title: "Sessions", systemImage: "person.2", view: AnyView(agentTab)),
            SettingsTabPage(id: .memory, title: "Memory", systemImage: "brain.head.profile", view: AnyView(memoryTab)),
            SettingsTabPage(id: .skills, title: "Skills", systemImage: "wand.and.stars", view: AnyView(skillsTab)),
            SettingsTabPage(id: .tools, title: "Tools", systemImage: "wrench.and.screwdriver", view: AnyView(HermesToolsSettingsView(settings: settingsStore.settings))),
            SettingsTabPage(id: .cronjobs, title: "Cron", systemImage: "clock.badge", view: AnyView(HermesCronJobsSettingsView(settings: settingsStore.settings))),
            SettingsTabPage(id: .usage, title: "Usage", systemImage: "chart.bar", view: AnyView(usageTab)),
            SettingsTabPage(id: .platforms, title: "Platforms", systemImage: "network", view: AnyView(platformsTab)),
            SettingsTabPage(id: .environment, title: "环境", systemImage: "folder", view: AnyView(environmentTab)),
        ]
    }

    // MARK: - Station

    private var stationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stationCommandCenterSection
                stationCapabilitiesSection
                stationRuntimeHealthSection
                stationMessagingSection
                stationFleetSection
                stationFilesSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var stationCommandCenterSection: some View {
        GroupBox("Hermes Control Center") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: gatewayStore.snapshot.menuBarSymbol)
                        .font(.system(size: 28))
                        .foregroundStyle(stationIconColor)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileSwitcherLabel(for: settingsStore.settings))
                            .font(.system(size: 18, weight: .semibold))
                        Text("把当前 profile 当成一个独立 Hermes 实例来管理：模型、消息平台、gateway、日志、doctor、升级都从这里汇总。")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if gatewayStore.snapshot.releaseInfo?.isUpdateAvailable == true {
                        statusBadge("有新版本", color: .green)
                    }
                }

                HStack(spacing: 8) {
                    summaryPill(title: "Gateway", value: gatewayRuntimeHeadline)
                    summaryPill(title: "Provider", value: activeProviderTitle)
                    summaryPill(title: "Platforms", value: "\(connectedPlatformCount)/\(configuredPlatformCount) connected")
                    summaryPill(title: "Active", value: gatewayStore.snapshot.liveAgentCountDisplay)
                    summaryPill(title: "Bindings", value: "\(gatewayStore.snapshot.boundSessionCount)")
                    summaryPill(title: "Sessions", value: "\(gatewayStore.snapshot.agentSessions.totalCount)")
                }

                HStack {
                    Button("Restart Gateway") {
                        gatewayStore.restartService()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(gatewayStore.isBusy)

                    Button("Doctor --fix") {
                        gatewayStore.runDoctorFix()
                    }
                    .disabled(gatewayStore.isBusy)

                    Button("平台管理") {
                        selectedTab = .platforms
                    }

                    Button("模型管理") {
                        selectedTab = .model
                    }

                    Button("环境与版本") {
                        selectedTab = .environment
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var stationCapabilitiesSection: some View {
        GroupBox("Capability Home") {
            VStack(alignment: .leading, spacing: 12) {
                Text("先回答“这台 Hermes 现在能做什么”。这一层把运行态、配置、记忆、skills、cron 和平台状态压成 6 个能力域，帮助我们先看 readiness，再决定去哪个高级面板。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    summaryPill(title: "Ready", value: "\(stationCapabilityCards.filter { $0.readiness == .ready }.count)")
                    summaryPill(title: "Partial", value: "\(stationCapabilityCards.filter { $0.readiness == .partial }.count)")
                    summaryPill(title: "Watch", value: "\(stationCapabilityCards.filter { $0.readiness == .degraded || $0.readiness == .blocked }.count)")
                    Spacer()
                    Button("Research Pack") {
                        activePackSheet = .research
                    }
                    .disabled(isLoadingPacks)
                    Button("Content Pack") {
                        activePackSheet = .content
                    }
                    .disabled(isLoadingPacks)
                }

                if let topGap = stationTopGapCard {
                    stationInfoBanner(
                        title: "Top Gap: \(topGap.domain.title)",
                        message: topGap.summary,
                        color: stationCapabilityReadinessColor(topGap.readiness)
                    )
                }

                if !stationCapabilityRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recommended Next Moves")
                            .font(.system(size: 12, weight: .semibold))
                        LazyVGrid(columns: stationGridColumns, alignment: .leading, spacing: 12) {
                            ForEach(stationCapabilityRecommendations) { recommendation in
                                stationCapabilityRecommendationCard(recommendation)
                            }
                        }
                    }
                }

                LazyVGrid(columns: stationGridColumns, alignment: .leading, spacing: 12) {
                    ForEach(stationCapabilityCards) { card in
                        stationCapabilityCard(card)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var stationRuntimeHealthSection: some View {
        GroupBox("Runtime Health") {
            VStack(alignment: .leading, spacing: 12) {
                if let alignment = gatewayStore.snapshot.profileAlignment, !alignment.isAligned {
                    stationInfoBanner(
                        title: "CLI profile 与当前实例不一致",
                        message: "Hermes CLI 默认指向 \(alignment.stickyDisplayName)，但 HermesStation 正在管理 \(alignment.expectedProfile)。先执行 Use This Profile，再继续改 gateway 或平台配置。",
                        color: .orange
                    )
                }

                if let transparency = gatewayStore.snapshot.endpointTransparency, transparency.hasMismatch {
                    stationInfoBanner(
                        title: "当前请求来源有分叉",
                        message: "激活模型的 base URL / auth pool / 最近请求来源不一致。先去模型页确认，再决定是否同步 credential pool。",
                        color: .orange
                    )
                }

                if let report = gatewayStore.snapshot.doctorReport {
                    doctorReportView(report)
                } else {
                    stationInfoBanner(
                        title: "还没有 doctor 结果",
                        message: "升级 Hermes 或消息平台掉线后，先跑一次 Doctor --fix，能更快把 profile 对齐到新版本预期。",
                        color: .blue
                    )
                }

                if let latestDump = gatewayStore.snapshot.endpointTransparency?.latestRequestDump,
                   let errorMessage = latestDump.errorMessage,
                   !errorMessage.isEmpty {
                    stationLatestRequestDumpCard(latestDump)
                }

                if let feishuSession = gatewayStore.snapshot.trustedRuntime?.activeSessions?["feishu"]?.first,
                   gatewayStore.snapshot.trustedRuntime?.modelOverrides?["feishu"]?.isEmpty != false {
                    stationInfoBanner(
                        title: "Feishu 当前跟随主模型",
                        message: "当前 Feishu 会话 \(feishuSession.sessionKey ?? "unknown") 没有单独的会话级模型绑定，所以会直接使用主模型。这不是故障；只有你在聊天里显式切过 `/model`，才会出现单独 override。",
                        color: .blue
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private var stationMessagingSection: some View {
        GroupBox("Messaging Surfaces") {
            VStack(alignment: .leading, spacing: 12) {
                if platformInstancesCache.isEmpty {
                    stationInfoBanner(
                        title: "当前实例还没有接入消息平台",
                        message: "把 Email、Feishu、Weixin 这些入口接进来之后，HermesStation 才能真正成为一站式控制台。",
                        color: .blue
                    )

                    HStack {
                        Button("Add Platform") {
                            selectedTab = .platforms
                            openAddPlatformWizard()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("打开平台页") {
                            selectedTab = .platforms
                        }
                    }
                } else {
                    LazyVGrid(columns: stationGridColumns, alignment: .leading, spacing: 12) {
                        ForEach(platformInstancesCache) { instance in
                            stationPlatformCard(instance)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var stationFleetSection: some View {
        GroupBox("Hermes Fleet") {
            VStack(alignment: .leading, spacing: 12) {
                Text("一个 profile 就是一台独立 Hermes。这里按实例列出模型规模、平台配置和关键文件完整度。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ForEach(profileOverviews) { overview in
                    stationProfileRow(overview)
                }
            }
            .padding(.top, 4)
        }
    }

    private var stationFilesSection: some View {
        GroupBox("Current Instance Files") {
            VStack(alignment: .leading, spacing: 10) {
                pathRow("config.yaml", path: profileStore.snapshot.configURL.path, action: profileStore.openConfigFile)
                pathRow(".env", path: profileStore.snapshot.envURL.path, action: profileStore.openEnvFile)
                pathRow("SOUL.md", path: profileStore.snapshot.soulURL.path, action: profileStore.openSoulFile)
                pathRow("logs", path: HermesPaths(settings: settingsStore.settings).logsDir.path, action: gatewayStore.openLogs)

                HStack {
                    Button("Open Workspace") { gatewayStore.openWorkspace() }
                    Button("Open Hermes Home") { gatewayStore.openHermesHome() }
                    Button("Open Hermes Root") { gatewayStore.openHermesRoot() }
                    Button("Open settings.json") { settingsStore.openSettingsFile() }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Profiles") {
                Picker("Current Profile", selection: activeSettingsProfileID) {
                    ForEach(settingsStore.profiles) { profile in
                        Text(profileSwitcherLabel(for: profile)).tag(profile.id)
                    }
                }

                activeProfileScopeBanner

                HStack {
                    Button("New") {
                        settingsStore.createProfile()
                    }
                    Button("Duplicate") {
                        settingsStore.duplicateActiveProfile()
                    }
                    Button("Delete") {
                        settingsStore.deleteActiveProfile()
                    }
                    .disabled(settingsStore.profiles.count <= 1)
                }

                mappingHint("切换 profile，等价于把 menubar 和 Hermes 切到另一套隔离环境，而不只是换一个显示名。")

                profileMeaningOverview
            }

            Section("Menubar 应用") {
                labeledField("Display Name", text: $appDraft.displayName)
                labeledField("Hermes Profile ID", text: $appDraft.profileName)
                mappingHint("这个 ID 会进入 `.hermes-home/profiles/<id>`、Hermes 的 `-p <id>` 参数，以及 `ai.hermes.gateway-<id>` 服务标签。")
                labeledField("Project Root", text: $appDraft.projectRootPath)
                labeledField("Workspace Root", text: $appDraft.workspaceRootPath)
                labeledField("Launcher", text: $appDraft.launcherPath)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Refresh Interval")
                        .font(.system(size: 12, weight: .medium))
                    HStack {
                        Slider(value: $appDraft.refreshIntervalSeconds, in: 2...30, step: 1)
                        Text("\(Int(appDraft.refreshIntervalSeconds))s")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 36)
                    }
                }

                Toggle("Auto-cleanup duplicate gateways", isOn: $appDraft.autoCleanupDuplicateGateways)
                    .font(.system(size: 12))

                Toggle("Auto-restart when runtime file is stale", isOn: $appDraft.autoRestartOnStaleRuntime)
                    .font(.system(size: 12))
            }

            Section("派生路径") {
                profileScopePreview
            }

            Section {
                HStack {
                    Button("Open settings.json") { settingsStore.openSettingsFile() }
                    Spacer()
                    Button("Revert") { appDraft = settingsStore.settings }
                    Button("Restore Defaults") {
                        appDraft = AppSettings(
                            id: appDraft.id,
                            displayName: appDraft.displayName,
                            profileName: appDraft.profileName,
                            projectRootPath: AppSettings.default.projectRootPath,
                            workspaceRootPath: AppSettings.default.workspaceRootPath,
                            launcherPath: AppSettings.default.launcherPath,
                            refreshIntervalSeconds: AppSettings.default.refreshIntervalSeconds,
                            autoCleanupDuplicateGateways: AppSettings.default.autoCleanupDuplicateGateways,
                            autoRestartOnStaleRuntime: AppSettings.default.autoRestartOnStaleRuntime,
                            modelProviders: appDraft.modelProviders
                        )
                        settingsStore.reset()
                    }
                    Button("Save") {
                        settingsStore.update(appDraft.normalized)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Model

    private var modelTab: some View {
        HStack(spacing: 0) {
            modelProviderSidebar
            Divider()
            modelProviderDetails
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showAddAPIWizard) {
            addAPIWizardSheet
        }
        .alert("删除 Provider?", isPresented: $showDeleteProviderAlert) {
            Button("删除", role: .destructive) {
                removeSelectedModelProvider()
            }
            Button("取消", role: .cancel) {}
        } message: {
            let provider = selectedModelProvider
            if !provider.displayName.isEmpty && provider.displayName != "Provider" {
                Text("这会从本地目录移除 \(provider.displayName) 及其下的所有模型配置。")
            } else {
                Text("这会从本地目录移除该 Provider 及其下的所有模型配置。")
            }
        }
    }

    private var modelProviderSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: selectedModelSidebarBinding) {
                Section("Hermes") {
                    providerSidebarRow(
                        title: "Current Hermes Active",
                        subtitle: activeProviderSubtitle,
                        systemImage: "checkmark.circle.fill"
                    )
                    .tag(ModelSidebarDestination.current)

                    providerSidebarRow(
                        title: "Hermes Routing Reality",
                        subtitle: routingSidebarSubtitle,
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .tag(ModelSidebarDestination.routing)

                    providerSidebarRow(
                        title: "Model Health",
                        subtitle: modelHealthSidebarSubtitle,
                        systemImage: modelHealthIconName
                    )
                    .tag(ModelSidebarDestination.health)
                }

                Section("Provider APIs") {
                    ForEach(appDraft.modelProviders) { provider in
                        providerSidebarRow(
                            title: provider.displayName,
                            subtitle: modelProviderSidebarSubtitle(provider),
                            systemImage: isProviderActive(provider) ? "checkmark.circle.fill" : "network"
                        )
                        .tag(ModelSidebarDestination.provider(provider.id))
                        .contextMenu {
                            Button {
                                selectedModelProviderID = provider.id
                                showDeleteProviderAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack {
                Button("Add API") {
                    openAddAPIWizard()
                }
                Button("Import Current") {
                    importCurrentHermesModel()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("每个 Provider/API 连接下面可以配置多个模型。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("激活某个模型后，才会把该 Provider + Model 写回 Hermes。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var modelProviderDetails: some View {
        switch selectedModelSidebarDestination {
        case .current:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    currentHermesActiveSection
                    endpointTransparencySection
                    hermesNotesSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))

        case .routing:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    routingRealitySection
                    hermesNotesSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))

        case .health:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modelHealthSection
                    endpointTransparencySection
                    hermesNotesSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))

        case .provider:
            if let providerIndex = selectedModelProviderIndex {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        providerConnectionSection(providerIndex: providerIndex)
                        modelsOnAPISection(providerIndex: providerIndex)
                        if let modelIndex = selectedSavedModelIndex {
                            selectedModelSection(providerIndex: providerIndex, modelIndex: modelIndex)
                        }
                        hermesNotesSection
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No saved API config")
                        .font(.system(size: 18, weight: .semibold))
                    Text("先添加一个 Provider/API 连接，或者把当前 Hermes 生效配置导入成本地目录。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Add API") {
                            openAddAPIWizard()
                        }
                        Button("Import Current Hermes") {
                            importCurrentHermesModel()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var currentHermesActiveSection: some View {
        GroupBox("Current Hermes Active") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: currentHermesProviderDescriptor == nil ? "questionmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(currentHermesProviderDescriptor == nil ? .orange : .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeProviderTitle)
                            .font(.system(size: 15, weight: .semibold))
                        Text(activeProviderSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusBadge("激活中", color: .green)
                }
                Text("当前 Hermes 同时只会有一个生效 provider/model。本地目录里的其它条目会显示为未激活。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: hermesDraft.provider, baseURL: hermesDraft.baseURL) {
                    stationInfoBanner(
                        title: "Coding Plan 已按官方兼容方式接入",
                        message: "当前实例使用 `provider=anthropic` + `https://api.kimi.com/coding/` 连接 Kimi Coding Plan。这个经验已经沉淀到 HermesStation 的验证和导入逻辑里，后续遇到 `/coding/v1` 的兼容问题时会直接提示切换。",
                        color: .green
                    )
                } else if canAdoptOfficialKimiCodingPlanRoute {
                    stationInfoBanner(
                        title: "检测到 Kimi Coding Plan 可切换到官方兼容路由",
                        message: "当前配置仍然可能走 `kimi-coding` 的 OpenAI-compatible 路由。HermesStation 现在支持一键切到 `anthropic + https://api.kimi.com/coding/`，并自动重启 gateway。",
                        color: .orange
                    )
                }

                HStack {
                    if canAdoptOfficialKimiCodingPlanRoute {
                        Button("Adopt Official Kimi Route") {
                            profileStore.adoptKimiCodingPlanOfficialRoute(restartGateway: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profileStore.isSaving)
                    }

                    Button("Kimi Coding Docs") {
                        openKimiCodingPlanDocs()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var routingRealitySection: some View {
        GroupBox("Hermes Routing Reality") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hermes 目前不是“多主模型同时在线”。主对话始终只会使用一个激活中的 provider/model。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Auxiliary Tasks")
                        .font(.system(size: 12, weight: .medium))
                    ForEach(profileStore.snapshot.routing.auxiliaryRoutes) { route in
                        HStack {
                            Text(route.task)
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 110, alignment: .leading)
                            Picker("", selection: auxiliaryProviderBinding(for: route.task)) {
                                ForEach(auxiliaryProviderOptions) { option in
                                    Text(option.label).tag(option.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 220, alignment: .leading)
                            Spacer()
                        }
                    }
                    HStack {
                        Button("Save Auxiliary Routing") {
                            profileStore.saveAuxiliaryProviders(auxiliaryProviderDrafts)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profileStore.isSaving)

                        Button("Reset From Hermes") {
                            auxiliaryProviderDrafts = Dictionary(uniqueKeysWithValues: profileStore.snapshot.routing.auxiliaryRoutes.map { ($0.task, $0.provider) })
                        }
                    }
                    Text("可编辑的是 `auxiliary.*.provider`。它控制 vision / web_extract / approval 等侧任务走 `main`、`auto`，还是指定 provider。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Model Routing")
                        .font(.system(size: 12, weight: .medium))
                    Toggle("Enabled", isOn: $smartRoutingEnabledDraft)
                    Picker("Cheap Provider", selection: $smartRoutingProviderDraft) {
                        ForEach(auxiliaryProviderOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)

                    labeledField("Cheap Model", text: $smartRoutingModelDraft)
                    HStack {
                        labeledField("Max Simple Chars", text: $smartRoutingMaxSimpleCharsDraft)
                        labeledField("Max Simple Words", text: $smartRoutingMaxSimpleWordsDraft)
                    }

                    HStack {
                        Button("Save Smart Routing") {
                            profileStore.saveSmartRouting(
                                enabled: smartRoutingEnabledDraft,
                                provider: smartRoutingProviderDraft,
                                model: smartRoutingModelDraft,
                                maxSimpleChars: Int(smartRoutingMaxSimpleCharsDraft) ?? 160,
                                maxSimpleWords: Int(smartRoutingMaxSimpleWordsDraft) ?? 28
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profileStore.isSaving || !canSaveSmartRouting)

                        Button("Reset From Hermes") {
                            syncSmartRoutingDrafts(from: profileStore.snapshot.routing)
                        }
                    }

                    Text("只针对“简单消息”把单次请求路由到便宜模型，不会改变主模型的长期激活状态。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var endpointTransparencySection: some View {
        if let transparency = gatewayStore.snapshot.endpointTransparency {
            GroupBox("Endpoint Transparency") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: transparency.hasMismatch ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(transparency.hasMismatch ? .orange : .green)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(transparency.provider) • \(transparency.model)")
                                .font(.system(size: 13, weight: .semibold))
                            Text("这里不再猜“运行时大概会怎么解析”，而是直接把 `config.yaml`、`.env`、`auth.json credential_pool` 和最新 `request_dump` 的 endpoint 并排展示出来。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        statusBadge(transparency.hasMismatch ? "来源不一致" : "来源一致", color: transparency.hasMismatch ? .orange : .green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(transparency.sourceRows.enumerated()), id: \.offset) { _, row in
                            endpointSourceRow(row)
                        }
                    }

                    if !transparency.credentialPoolEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Credential Pool Entries")
                                .font(.system(size: 12, weight: .medium))
                            ForEach(transparency.credentialPoolEntries) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.label) • \(entry.source ?? "unknown")")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(entry.baseURL ?? "no base_url")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    if let requestCount = entry.requestCount {
                                        Text("request_count: \(requestCount)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    if let latestDump = transparency.latestRequestDump {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest Request Dump")
                                .font(.system(size: 12, weight: .medium))
                            if let timestamp = latestDump.timestamp {
                                Text("timestamp: \(timestamp)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            if let reason = latestDump.reason, !reason.isEmpty {
                                Text("reason: \(reason)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            if let errorMessage = latestDump.errorMessage, !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack {
                        Button("Open auth.json") {
                            gatewayStore.openAuthStore()
                        }
                        Button("Open latest request dump") {
                            gatewayStore.openLatestRequestDump()
                        }
                        .disabled(transparency.latestRequestDump == nil)
                        Spacer()
                        Button("Sync auth pool -> Hermes") {
                            syncEndpointTransparency(restartAfter: false)
                        }
                        .disabled(endpointSyncTargetBaseURL == nil)
                        Button("Sync + Restart Gateway") {
                            syncEndpointTransparency(restartAfter: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(endpointSyncTargetBaseURL == nil)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var modelHealthSection: some View {
        GroupBox("Model Health") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("直接探测当前 Hermes 配置中的模型是否真正可用（不依赖 gateway）。")
                        Text("会检查当前主模型；如果配置了 smart routing，也会按对应 provider/model 的保存连接信息一起检查。")
                    }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(isCheckingModelHealth ? "检查中..." : "检查可用性") {
                        runModelHealthChecks()
                    }
                    .disabled(isCheckingModelHealth)
                }

                if let message = modelHealthFixMessage {
                    HStack(spacing: 6) {
                        Image(systemName: message.contains("失败") ? "xmark.octagon.fill" : "checkmark.circle.fill")
                            .foregroundStyle(message.contains("失败") ? .red : .green)
                        Text(message)
                            .font(.system(size: 12))
                    }
                    .padding(.vertical, 4)
                }

                ForEach(Array(modelHealthResults.enumerated()), id: \.offset) { _, result in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: healthIcon(for: result.status))
                            .foregroundStyle(healthColor(for: result.status))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.model)
                                .font(.system(size: 13, weight: .medium))
                            Text("\(result.provider) • \(result.status.displayText)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if case .unhealthy = result.status, !isCheckingModelHealth, canAutoFixModelHealth(result) {
                            Button("修复") {
                                fixModelHealth(result: result)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if modelHealthResults.isEmpty, !isCheckingModelHealth {
                    Text("点击“检查可用性”开始测试模型连接。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private func providerConnectionSection(providerIndex: Int) -> some View {
        GroupBox("Provider / API Connection") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusBadge(isProviderActive(selectedModelProvider) ? "激活" : "未激活", color: isProviderActive(selectedModelProvider) ? .green : .secondary)
                    statusBadge(isProviderAvailable(selectedModelProvider) ? "可用" : "不可用", color: isProviderAvailable(selectedModelProvider) ? .blue : .orange)
                    if let descriptor = selectedModelProviderDescriptor {
                        statusBadge(descriptor.displayName, color: .accentColor)
                    } else {
                        statusBadge("未映射", color: .orange)
                    }
                }

                Toggle("Enabled", isOn: providerEnabledBinding)
                labeledField("Connection Name", text: providerDisplayNameBinding)
                labeledField("Provider ID", text: providerIDBinding)

                if selectedModelProviderDescriptor?.authType != .oauth {
                    labeledField("Base URL", text: providerBaseURLBinding)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.system(size: 12, weight: .medium))
                        SecureField("API key", text: providerAPIKeyBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if let authType = selectedModelProviderDescriptor?.authType, authType != .apiKey {
                    oauthInfoBanner(authType: authType, forExistingProvider: true)
                }

                HStack {
                    Button("Save Catalog") {
                        settingsStore.update(appDraft.normalized)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Add Model") {
                        addModelToSelectedProvider()
                    }

                    Button("Delete API") {
                        showDeleteProviderAlert = true
                    }
                    .foregroundStyle(.red)
                }

                Text(providerAvailabilityMessage(selectedModelProvider))
                    .font(.system(size: 11))
                    .foregroundStyle(isProviderAvailable(selectedModelProvider) ? Color.secondary : Color.orange)
                validationIssueList(selectedProviderValidationIssues)
            }
            .padding(.top, 4)
        }
    }

    private var addAPIWizardSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add API")
                        .font(.system(size: 18, weight: .semibold))
                    Text("分页配置新的 Provider/API，避免直接插进当前列表底部。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Step \(addAPIWizardPage.rawValue + 1) / \(AddAPIWizardPage.allCases.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(AddAPIWizardPage.allCases, id: \.rawValue) { page in
                    RoundedRectangle(cornerRadius: 999)
                        .fill(page.rawValue <= addAPIWizardPage.rawValue ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(height: 6)
                }
            }

            GroupBox(addAPIWizardPage.title) {
                VStack(alignment: .leading, spacing: 12) {
                    if addAPIWizardPage == .connection {
                        addAPIConnectionPage
                    } else {
                        addAPIModelsPage
                    }
                }
                .padding(.top, 4)
            }

            HStack {
                Button("Cancel") {
                    showAddAPIWizard = false
                }
                Spacer()
                if addAPIWizardPage == .models {
                    Button("Back") {
                        addAPIWizardPage = .connection
                    }
                }
                if addAPIWizardPage == .connection {
                    Button("Next") {
                        addAPIWizardPage = .models
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvanceAddAPIWizard)
                } else {
                    Button("Create API") {
                        commitNewProviderDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateNewProvider)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, idealWidth: 820, minHeight: 540, idealHeight: 620)
    }

    private var addAPIConnectionPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Provider Preset", selection: $newProviderPresetID) {
                ForEach(providerPresetOptions) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: newProviderPresetID) { _, newValue in
                applyProviderPreset(newValue)
            }

            labeledField("Connection Name", text: newProviderDisplayNameBinding)
            labeledField("Provider ID", text: newProviderIDBinding)

            if newProviderDescriptor?.authType != .oauth {
                labeledField("Base URL", text: newProviderBaseURLBinding)

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium))
                    SecureField("API key", text: newProviderAPIKeyBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let authType = newProviderDescriptor?.authType, authType != .apiKey {
                oauthInfoBanner(authType: authType, forExistingProvider: false)
            }

            Toggle("Enabled", isOn: newProviderEnabledBinding)

            Text(newProviderAvailabilityMessage)
                .font(.system(size: 11))
                .foregroundStyle(canAdvanceAddAPIWizard ? Color.secondary : Color.orange)
            validationIssueList(newProviderValidationIssues)
        }
    }

    private var addAPIModelsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Models")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("Add Model") {
                    addModelToNewProviderDraft()
                }
                Button("Delete Model") {
                    removeSelectedDraftModel()
                }
                .foregroundStyle(.red)
                .disabled(newProviderSelectedModelIndex == nil)
            }

            HStack(spacing: 12) {
                List(selection: newProviderSelectedModelBinding) {
                    ForEach(newProviderDraft.models) { model in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.displayName)
                                .font(.system(size: 12, weight: .medium))
                            Text(model.modelName.isEmpty ? "No model ID yet" : model.modelName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                        .tag(model.id)
                    }
                }
                .frame(width: 220)

                if let modelIndex = newProviderSelectedModelIndex {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enabled", isOn: newProviderModelEnabledBinding(modelIndex: modelIndex))
                        labeledField("Display Name", text: newProviderModelDisplayNameBinding(modelIndex: modelIndex))
                        labeledField("Model ID", text: newProviderModelNameBinding(modelIndex: modelIndex))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capabilities")
                                .font(.system(size: 12, weight: .medium))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(ModelCapability.allCases) { capability in
                                    capabilityToggle(
                                        capability,
                                        selected: newProviderDraft.models[modelIndex].capabilities.contains(capability)
                                    ) {
                                        toggleDraftModelCapability(capability, modelIndex: modelIndex)
                                    }
                                }
                            }
                        }

                        Text(newProviderModelMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(canCreateNewProvider ? Color.secondary : Color.orange)
                        validationIssueList(newProviderModelValidationIssues)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private func modelsOnAPISection(providerIndex: Int) -> some View {
        GroupBox("Models On This API") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(appDraft.modelProviders[providerIndex].models) { model in
                    modelSummaryRow(model)
                }

                HStack {
                    Button("Add Model") {
                        addModelToSelectedProvider()
                    }
                    Button("Delete Model") {
                        removeSelectedSavedModel()
                    }
                    .foregroundStyle(.red)
                    .disabled(selectedSavedModelIndex == nil)
                }
            }
            .padding(.top, 4)
        }
    }

    private func modelSummaryRow(_ model: SavedModelEntry) -> some View {
        Button {
            selectedSavedModelID = model.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(.system(size: 13, weight: .medium))
                        statusBadge(isModelActive(selectedModelProvider, model) ? "激活" : "未激活", color: isModelActive(selectedModelProvider, model) ? .green : .secondary)
                        statusBadge(isModelAvailable(selectedModelProvider, model) ? "可用" : "不可用", color: isModelAvailable(selectedModelProvider, model) ? .blue : .orange)
                    }
                    Text(model.modelName.isEmpty ? "No model ID yet" : model.modelName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    capabilityTagWrap(model.capabilities)
                }
                Spacer()
                Image(systemName: selectedSavedModelID == model.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedSavedModelID == model.id ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedSavedModelID == model.id ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .hoverPlate(cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }

    private func selectedModelSection(providerIndex: Int, modelIndex: Int) -> some View {
        GroupBox("Selected Model") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusBadge(isModelActive(selectedModelProvider, selectedSavedModel) ? "激活中" : "待激活", color: isModelActive(selectedModelProvider, selectedSavedModel) ? .green : .secondary)
                    statusBadge(isModelAvailable(selectedModelProvider, selectedSavedModel) ? "可用" : "不可用", color: isModelAvailable(selectedModelProvider, selectedSavedModel) ? .blue : .orange)
                }

                Toggle("Enabled", isOn: modelEnabledBinding(providerIndex: providerIndex, modelIndex: modelIndex))
                labeledField("Display Name", text: modelDisplayNameBinding(providerIndex: providerIndex, modelIndex: modelIndex))
                labeledField("Model ID", text: modelNameBinding(providerIndex: providerIndex, modelIndex: modelIndex))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capabilities")
                        .font(.system(size: 12, weight: .medium))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(ModelCapability.allCases) { capability in
                            capabilityToggle(
                                capability,
                                selected: appDraft.modelProviders[providerIndex].models[modelIndex].capabilities.contains(capability)
                            ) {
                                toggleCapability(capability, providerIndex: providerIndex, modelIndex: modelIndex)
                            }
                        }
                    }
                }

                HStack {
                    Button("Save Catalog") {
                        settingsStore.update(appDraft.normalized)
                    }
                    Button("Activate Model In Hermes") {
                        activateSelectedSavedModel()
                    }
                    .disabled(!canActivateSelectedSavedModel)
                    .buttonStyle(.borderedProminent)
                }

                Text(modelAvailabilityMessage(selectedModelProvider, selectedSavedModel))
                    .font(.system(size: 11))
                    .foregroundStyle(isModelAvailable(selectedModelProvider, selectedSavedModel) ? Color.secondary : Color.orange)
                validationIssueList(selectedModelValidationIssues)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Agents

    private var agentTab: some View {
        SettingsAgentSessionsPane(
            activeCount: gatewayStore.snapshot.agentSessions.activeCount,
            trackedCount: gatewayStore.snapshot.agentSessions.totalCount,
            boundCount: gatewayStore.snapshot.boundSessionCount,
            liveCountText: gatewayStore.snapshot.liveAgentCountDisplay,
            filter: $agentFilter,
            searchText: $agentSearchText,
            isLoadingSearchIndex: isLoadingAgentSearchIndex,
            filteredBoundAgents: filteredBoundAgents,
            filteredUnboundAgents: filteredUnboundAgents,
            selectedAgentID: $selectedAgentID,
            selectedAgent: selectedAgent,
            bindingForAgentID: { sessionID in
                gatewayStore.snapshot.bindingEntry(for: sessionID)
            },
            selectedBindingEntry: selectedAgentBindingEntry,
            selectedTranscript: selectedAgentTranscript,
            isLoadingTranscript: isLoadingTranscript,
            agentRenameDraft: $agentRenameDraft,
            isBusy: gatewayStore.isBusy,
            formatBindingTimestamp: formatBindingTimestamp,
            onRename: { agent, title in
                gatewayStore.renameAgentSession(id: agent.id, title: title)
            },
            onOpenTranscript: { agent in
                gatewayStore.openTranscript(for: agent)
            },
            onOpenLogExcerpt: { agent in
                gatewayStore.openLogExcerpt(for: agent)
            },
            onExport: { agent in
                gatewayStore.exportAgentSession(id: agent.id)
            },
            onDelete: {
                showDeleteAgentAlert = true
            },
            onFocusPlatform: focusPlatform,
            onSubmitPendingAction: { type, sessionKey in
                gatewayStore.submitPendingAction(type: type, sessionKey: sessionKey)
            }
        )
        .alert("Delete Agent Session?", isPresented: $showDeleteAgentAlert) {
            Button("Delete", role: .destructive) {
                if let selectedAgent {
                    gatewayStore.deleteAgentSession(id: selectedAgent.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let selectedAgent {
                Text("This will remove session \(selectedAgent.id) from Hermes history.")
            } else {
                Text("This will remove the selected session from Hermes history.")
            }
        }
    }

    private var memoryTab: some View {
        SettingsMemoryPane(
            entries: memoryEntries,
            sourceOptions: memorySourceOptions,
            sourceFilter: $memorySourceFilter,
            searchText: $memorySearchText,
            filteredEntries: filteredMemoryEntries,
            selectedEntryID: $selectedMemoryEntryID,
            selectedEntry: selectedMemoryEntry,
            isLoading: isLoadingMemoryEntries,
            onReload: reloadMemoryEntries,
            onOpenPath: openPath,
            formatTimestamp: formatMemoryTimestamp
        )
    }

    private var skillsTab: some View {
        HStack(spacing: 0) {
            skillsSidebar
            Divider()
            skillsDetailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Usage

    private var usageTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Window", selection: $selectedUsageWindow) {
                            ForEach(UsageWindow.allCases) { window in
                                Text(window.title).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            summaryPill(title: "Sessions", value: "\(selectedUsageTotals.sessionCount)")
                            summaryPill(title: "Tokens", value: compactCount(selectedUsageTotals.totalTokens))
                            summaryPill(title: "Tool Calls", value: "\(selectedUsageTotals.toolCallCount)")
                            summaryPill(title: "Cost", value: compactCurrency(selectedUsageTotals.totalCostUSD))
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox("Usage Over Time") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Metric", selection: $selectedUsageMetric) {
                            ForEach(UsageChartMetric.allCases) { metric in
                                Text(metric.title).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedUsageBuckets.isEmpty {
                            Text("No usage found for this time window.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(selectedUsageBuckets) { bucket in
                                BarMark(
                                    x: .value("Time", Date(timeIntervalSince1970: bucket.bucketStart)),
                                    y: .value(selectedUsageMetric.title, usageMetricValue(bucket))
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: selectedUsageWindow == .last24Hours ? 6 : 7)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: usageAxisFormat)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 220)
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox("By Model / Provider") {
                    VStack(alignment: .leading, spacing: 10) {
                        if selectedUsageRows.isEmpty {
                            Text("No usage found for this time window.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedUsageRows) { row in
                                usageRow(row)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var skillsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryPill(title: "Enabled", value: "\(enabledSkillCount)")
                summaryPill(title: "Total", value: "\(skillEntries.count)")
                summaryPill(title: "Categories", value: "\(skillCategoryCount)")
                Spacer()
                Button {
                    reloadSkillEntries()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .hoverPlate(cornerRadius: 6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Picker("Status", selection: $skillFilter) {
                ForEach(SkillPanelFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            TextField("Search skill / description / tag", text: $skillSearchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            if isLoadingSkillEntries {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 12)
            }

            List(selection: selectedSkillEntryBinding) {
                ForEach(filteredSkillEntries) { skill in
                    skillRow(skill)
                        .tag(skill.id)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 340, idealWidth: 380, maxWidth: 440, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var skillsDetailPanel: some View {
        if let skill = selectedSkillEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.name)
                                .font(.system(size: 18, weight: .semibold))
                            Text(skill.relativePath)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        skillStatusBadge(skill.isEnabled)
                    }

                    if let skillActionMessage, !skillActionMessage.isEmpty {
                        Text(skillActionMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    GroupBox("Actions") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button(skill.isEnabled ? "Disable" : "Enable") {
                                    toggleSkill(skill)
                                }
                                .disabled(isPerformingSkillAction)

                                Button("Open Skill File") {
                                    openPath(skill.fileURL)
                                }

                                Button("Open Folder") {
                                    openPath(skill.folderURL)
                                }

                                Button("Refresh") {
                                    reloadSkillEntries()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow("Identifier", skill.identifier)
                            detailRow("Category", skill.categoryPath)
                            detailRow("Path", skill.folderURL.path)
                            detailRow("Version", skill.version ?? "n/a")
                            detailRow("Author", skill.author ?? "n/a")
                            detailRow("License", skill.license ?? "n/a")
                            if let homepage = skill.homepage, !homepage.isEmpty {
                                detailRow("Homepage", homepage)
                            }
                            if !skill.platforms.isEmpty {
                                detailRow("Platforms", skill.platforms.joined(separator: ", "))
                            }
                            detailRow("Manifest", skill.hash ?? "disabled")
                        }
                        .padding(.top, 4)
                    }

                    if !skill.tags.isEmpty {
                        GroupBox("Tags") {
                            tokenWrap(skill.tags)
                                .padding(.top, 4)
                        }
                    }

                    if !skill.prerequisites.isEmpty {
                        GroupBox("Prerequisites") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(skill.prerequisites, id: \.self) { command in
                                    Text(command)
                                        .font(.system(size: 12, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    GroupBox("Summary") {
                        Text(skill.description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }

                    if !skill.body.isEmpty {
                        GroupBox("Content") {
                            Text(skill.body)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No skill selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Pick a skill from the left to inspect metadata and manage enable or disable state in the active profile.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func loadTranscript(for agent: AgentSessionRow) {
        isLoadingTranscript = true
        selectedAgentTranscript = nil
        Task(priority: .userInitiated) {
            let transcript = SessionTranscriptLoader.load(from: agent.transcriptURL)
            await MainActor.run {
                self.selectedAgentTranscript = transcript
                self.isLoadingTranscript = false
            }
        }
    }

    // MARK: - Platforms

    private var platformsTab: some View {
        HStack(spacing: 0) {
            platformSidebar
            Divider()
            platformDetailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showAddPlatformWizard) {
            addPlatformWizardSheet
        }
    }

    private var platformSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedPlatformInstanceID) {
                Section("Platforms") {
                    ForEach(platformInstancesCache) { instance in
                        platformSidebarRow(instance)
                            .tag(instance.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack {
                Button("Add Platform") {
                    openAddPlatformWizard()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("Add a messaging platform and configure its required tokens/keys.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Changes are written via `hermes config set` into the current profile's Hermes config files.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func platformSidebarRow(_ instance: PlatformInstance) -> some View {
        let descriptor = PlatformDescriptorRegistry.descriptor(for: instance.platformID)
        let runtimeState = gatewayStore.snapshot.runtime?.platforms[instance.platformID]
        let isStale = gatewayStore.snapshot.runtimeIsStale
        return Button {
            selectedPlatformInstanceID = instance.id
            loadPlatformConfigDraft(for: instance)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: descriptor?.icon ?? "network")
                    .font(.system(size: 16))
                    .foregroundStyle(isStale ? Color.secondary : platformColor(runtimeState?.state))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(platformConnectionLabel(for: instance, runtimeState: runtimeState))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                } else {
                    Circle()
                        .fill(platformColor(runtimeState?.state))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var platformDetailPanel: some View {
        if let instance = selectedPlatformInstance {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: PlatformDescriptorRegistry.descriptor(for: instance.platformID)?.icon ?? "network")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instance.displayName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(instance.platformID)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                    }

                    if gatewayStore.snapshot.runtimeIsStale {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("gateway_state.json is stale; showing cached platform states.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    GroupBox("Configuration") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let descriptor = PlatformDescriptorRegistry.descriptor(for: instance.platformID) {
                                ForEach(descriptor.fields) { field in
                                    platformConfigFieldRow(field)
                                }
                            }

                            HStack {
                                Button("Save Config") {
                                    savePlatformConfig()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isSavingPlatforms)

                                if canApplyNeteaseEmailPreset {
                                    Button("Apply 163/188 Preset") {
                                        applyNeteaseEmailPreset()
                                    }
                                    .disabled(isSavingPlatforms)
                                }

                                Button("Delete Platform") {
                                    deletePlatformConfig()
                                }
                                .foregroundStyle(.red)
                            }

                            if isSavingPlatforms {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let platformStatusMessage {
                                platformStatusBanner(platformStatusMessage)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let runtime = gatewayStore.snapshot.runtime?.platforms[instance.platformID] {
                        GroupBox("Runtime Status") {
                            platformRuntimeRow(key: instance.platformID, state: runtime)
                                .padding(.top, 4)
                        }
                    }

                    GroupBox("Diagnostics") {
                        platformDiagnosticsSection(for: instance)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No platform selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Pick a platform from the left to edit its settings, or add a new one.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func platformConfigFieldRow(_ field: PlatformConfigField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.system(size: 12, weight: .medium))
            if field.isSecret {
                SecureField(field.label, text: platformConfigBinding(for: field.key))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(field.label, text: platformConfigBinding(for: field.key))
                    .textFieldStyle(.roundedBorder)
            }
            if !field.helpText.isEmpty {
                Text(field.helpText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addPlatformWizardSheet: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Add Platform")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                    }

                    Picker("Platform", selection: $newPlatformPresetID) {
                        Text("Select a platform...").tag("")
                        ForEach(PlatformDescriptorRegistry.allPlatforms) { platform in
                            Text(platform.displayName).tag(platform.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: newPlatformPresetID) { _, newValue in
                        applyPlatformPreset(newValue)
                    }

                    if let descriptor = PlatformDescriptorRegistry.descriptor(for: newPlatformPresetID) {
                        GroupBox("Setup Instructions") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(descriptor.setupInstructions, id: \.self) { line in
                                    Text(line)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }

                        GroupBox("Configuration") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(descriptor.fields) { field in
                                    platformWizardFieldRow(field)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("Cancel") {
                        showAddPlatformWizard = false
                        platformStatusMessage = nil
                    }
                    Spacer()
                    Button("Add") {
                        commitNewPlatform()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPlatformPresetID.isEmpty || isSavingPlatforms)
                }

                if let platformStatusMessage {
                    platformStatusBanner(platformStatusMessage)
                }
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 600)
    }

    private func platformStatusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.hasPrefix("Failed") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(message.hasPrefix("Failed") ? Color.red : Color.accentColor)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background((message.hasPrefix("Failed") ? Color.red : Color.accentColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func platformDiagnosticsSection(for instance: PlatformInstance) -> some View {
        let runtimeState = gatewayStore.snapshot.runtime?.platforms[instance.platformID]
        let hints = platformDiagnosticHints(for: instance, runtimeState: runtimeState, logLines: platformDiagnosticLines)
        let boundSessions = gatewayStore.snapshot.bindingEntries(for: instance.platformID)
        let modelOverrides = gatewayStore.snapshot.trustedRuntime?.modelOverrides?[instance.platformID] ?? []

        VStack(alignment: .leading, spacing: 12) {
            if let platformDiagnosticSummary {
                platformDiagnosticBanner(platformDiagnosticSummary, isWarning: !instance.isEnabled || runtimeState == nil || runtimeState?.state != "connected")
            }

            HStack {
                Button("Restart Gateway") {
                    gatewayStore.restartService()
                }
                .buttonStyle(.bordered)

                Button("Open gateway.log") {
                    gatewayStore.openGatewayLog()
                }

                Button("Open error.log") {
                    gatewayStore.openGatewayErrorLog()
                }

                Button(isCheckingPlatformDependencies ? "Checking Dependencies..." : "Check Dependencies") {
                    refreshPlatformDiagnostics()
                }
                .disabled(isCheckingPlatformDependencies)
            }

            platformDependencySection

            if !boundSessions.isEmpty || !modelOverrides.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bound Sessions")
                        .font(.system(size: 12, weight: .medium))

                    ForEach(boundSessions) { binding in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(binding.sessionID)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    statusBadge(gatewayStore.snapshot.isBindingLive(binding) ? "live" : "stored", color: gatewayStore.snapshot.isBindingLive(binding) ? .green : .secondary)
                                }
                                Text(binding.sessionKey)
                                    .font(.system(size: 10, design: .monospaced))
                                Text(binding.displayLabel)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                if !binding.displaySubtitle.isEmpty {
                                    Text(binding.displaySubtitle)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                if let override = modelOverrides.first(where: { $0.sessionKey == binding.sessionKey })?.overrideModel,
                                   !override.isEmpty {
                                    Text("override: \(override)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Menu {
                                Button("Show Session") {
                                    focusAgentSession(binding.sessionID)
                                }
                                Button("Open Transcript") {
                                    openTranscript(for: binding)
                                }
                                Button("Reset Session") {
                                    gatewayStore.submitPendingAction(type: "reset_session", sessionKey: binding.sessionKey)
                                }
                                Button("Clear Model Binding") {
                                    gatewayStore.submitPendingAction(type: "clear_model_override", sessionKey: binding.sessionKey)
                                }
                                Button("Evict Cached Agent") {
                                    gatewayStore.submitPendingAction(type: "evict_agent", sessionKey: binding.sessionKey)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 12))
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    ForEach(modelOverrides, id: \.sessionKey) { override in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(override.sessionKey ?? "unknown")
                                    .font(.system(size: 10, design: .monospaced))
                                if let model = override.overrideModel, !model.isEmpty {
                                    Text("override: \(model)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Button {
                                if let sk = override.sessionKey {
                                    gatewayStore.submitPendingAction(type: "clear_model_override", sessionKey: sk)
                                }
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if !hints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested next steps")
                        .font(.system(size: 12, weight: .medium))

                    ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(hint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Recent matching log lines")
                    .font(.system(size: 12, weight: .medium))

                if platformDiagnosticLines.isEmpty {
                    Text("No recent matching log lines found for this platform.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(platformDiagnosticLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var platformDependencySection: some View {
        if isCheckingPlatformDependencies {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Checking platform dependencies...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else if !platformDependencyChecks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dependency Checks")
                    .font(.system(size: 12, weight: .medium))

                ForEach(platformDependencyChecks) { check in
                    platformDependencyRow(check)
                }
            }
        }
    }

    private func platformDependencyRow(_ check: PlatformDependencyCheck) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.status.symbol)
                .foregroundStyle(check.status.color)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(check.title)
                        .font(.system(size: 12, weight: .semibold))
                    statusBadge(check.status.label, color: check.status.color)
                }
                Text(check.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let action = check.action {
                Button(platformDependencyActionTitle(action)) {
                    performPlatformDependencyAction(action)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .disabled(gatewayStore.isBusy)
            }
        }
        .padding(10)
        .background(check.status.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func platformDependencyActionTitle(_ action: PlatformDependencyAction) -> String {
        switch action {
        case .installLarkOAPI:
            return "Install + Restart"
        case .restartGateway:
            return "Restart Gateway"
        case .openGatewayLog:
            return "Open Log"
        case .openEnvFile:
            return "Open .env"
        }
    }

    private func performPlatformDependencyAction(_ action: PlatformDependencyAction) {
        switch action {
        case .installLarkOAPI:
            gatewayStore.installPythonPackage(
                packageName: "lark-oapi",
                label: "Feishu dependency lark-oapi",
                restartGatewayAfterInstall: true
            )
        case .restartGateway:
            gatewayStore.restartService()
        case .openGatewayLog:
            gatewayStore.openGatewayLog()
        case .openEnvFile:
            profileStore.openEnvFile()
        }
    }

    private func platformDiagnosticBanner(_ message: String, isWarning: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isWarning ? Color.orange : Color.accentColor)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background((isWarning ? Color.orange : Color.accentColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func platformDiagnosticHints(
        for instance: PlatformInstance,
        runtimeState: RuntimePlatformState?,
        logLines: [String]
    ) -> [String] {
        let combinedContext = ([platformDiagnosticSummary ?? ""] + logLines).joined(separator: "\n").lowercased()
        var hints: [String] = []

        if !instance.isEnabled {
            hints.append("Fill every required field and save config before expecting the gateway to load this platform.")
            return hints
        }

        if gatewayStore.snapshot.runtimeIsStale {
            hints.append("The live gateway process exists, but gateway_state.json is stale. Treat runtime/platform state as unknown until the gateway refreshes that file.")
        }

        if runtimeState == nil {
            hints.append("The running gateway has not loaded this platform yet. Restart gateway after saving config so the adapter is created on startup.")
        }

        switch instance.platformID {
        case "email":
            if combinedContext.contains("unsafe login") || combinedContext.contains("kefu@188.com") {
                hints.append("The email credentials are present, but the provider rejected mailbox selection as an unsafe login. This is happening after IMAP login, so it is more specific than a bad password.")
                hints.append("For NetEase 163/188, this often means mailbox-side risk control or an IMAP client-identification requirement. HermesStation can preserve the config, but Hermes itself may still be blocked by the provider until the mailbox trust/security settings are cleared.")
                hints.append("Hermes now supports explicit `EMAIL_IMAP_SEND_ID` and `EMAIL_SMTP_SECURITY`. For 163/188, prefer `EMAIL_IMAP_SEND_ID=always` and keep port 465 on `EMAIL_SMTP_SECURITY=ssl`.")
            }

            if combinedContext.contains("could not select inbox") {
                hints.append("IMAP login succeeded, but the server refused INBOX selection. For 163/188 mailboxes this usually means account-security interception or missing IMAP authorization code.")
            }

            if combinedContext.contains("state auth") && combinedContext.contains("selected") {
                hints.append("IMAP login likely succeeded, but the adapter failed before selecting INBOX. This usually points to mailbox-selection compatibility, not a missing EMAIL_* field.")
                hints.append("Collect the gateway.log excerpt and patch Hermes email adapter to validate the result of `select(\"INBOX\")` before running SEARCH.")
            }

            if let imapHost = instance.configs["EMAIL_IMAP_HOST"]?.lowercased(), imapHost.contains("163.com") {
                hints.append("163 Mail typically uses IMAP SSL on port 993. If SMTP later fails, try setting `EMAIL_SMTP_PORT` to 465 (SSL) or 587 (STARTTLS) in Hermes config.")
            }

            if combinedContext.contains("email_address, email_password") {
                hints.append("Gateway still thinks required EMAIL_* values are missing. Re-save the platform config and restart gateway so runtime picks up the latest values.")
            }
        case "weixin":
            if combinedContext.contains("server disconnected") {
                hints.append("Server disconnected usually means an upstream or network interruption. If it keeps repeating, check network stability and the provider service health.")
            }
        case "feishu":
            if combinedContext.contains("lark-oapi not installed") {
                hints.append("Feishu config is present, but the Hermes Python environment is missing the optional `lark-oapi` package. Install the Feishu extra or run the package install command in this Hermes venv, then restart gateway.")
            }
            if combinedContext.contains("feishu_app_id/secret not set") {
                hints.append("Gateway did not see FEISHU_APP_ID/FEISHU_APP_SECRET at startup. Check the current profile's `.env`, then restart gateway through Hermes.")
            }
            if combinedContext.contains("no close frame received or sent") {
                hints.append("This websocket closed abnormally. Hermes usually reconnects automatically, but repeated failures point to network instability or the upstream websocket service.")
            }
        default:
            break
        }

        if runtimeState?.state == "disconnected" && runtimeState?.errorMessage == nil && logLines.isEmpty {
            hints.append("No recent matching error lines were found. Reproduce once, then reopen this panel or open gateway.log for the full trace.")
        }

        return Array(NSOrderedSet(array: hints)) as? [String] ?? hints
    }

    private static func loadPlatformDependencyChecks(
        for instance: PlatformInstance,
        runtimeState: RuntimePlatformState?,
        summary: String,
        logLines: [String],
        settings: AppSettings
    ) async -> [PlatformDependencyCheck] {
        guard instance.isEnabled else { return [] }

        let context = ([summary, runtimeState?.errorMessage ?? ""] + logLines)
            .joined(separator: "\n")
            .lowercased()
        var checks: [PlatformDependencyCheck] = []

        switch instance.platformID {
        case "feishu":
            let hasHealthyRuntime = runtimeState?.state == "connected"
                && (runtimeState?.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let missingKeys = ["FEISHU_APP_ID", "FEISHU_APP_SECRET"].filter { key in
                (instance.configs[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if missingKeys.isEmpty {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-env-ok",
                    status: .ok,
                    title: "Feishu credentials",
                    detail: "FEISHU_APP_ID and FEISHU_APP_SECRET are configured in this Hermes profile.",
                    action: nil
                ))
            } else {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-env-missing",
                    status: .blocker,
                    title: "Feishu credentials missing",
                    detail: "Fill \(missingKeys.joined(separator: " / ")) and save the platform config before restarting gateway.",
                    action: .openEnvFile
                ))
            }

            let hasRuntimeEnvMiss = context.contains("feishu_app_id/secret not set")
                || (context.contains("feishu_app_id") && context.contains("feishu_app_secret") && context.contains("not set"))
            if hasRuntimeEnvMiss && missingKeys.isEmpty && !hasHealthyRuntime {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-runtime-env-missing",
                    status: .warning,
                    title: "Gateway has stale Feishu env",
                    detail: "The profile has credentials, but the running gateway did not see them at startup. Restart gateway after saving config.",
                    action: .restartGateway
                ))
            }

            let importStatus = await checkHermesPythonImport("lark_oapi", settings: settings)
            let logSaysMissing = context.contains("lark-oapi not installed") || context.contains("lark_oapi")
            if importStatus == false {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-lark-oapi-missing",
                    status: .blocker,
                    title: "lark-oapi package missing",
                    detail: "Hermes can load Feishu credentials, but the selected Hermes Python environment cannot import lark_oapi.",
                    action: .installLarkOAPI
                ))
            } else if importStatus == true && logSaysMissing && !hasHealthyRuntime {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-lark-oapi-restart",
                    status: .warning,
                    title: "lark-oapi now installed",
                    detail: "The package is importable now, but recent logs still show an older missing-package error. Restart gateway to reload the adapter.",
                    action: .restartGateway
                ))
            } else if importStatus == true {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-lark-oapi-ok",
                    status: .ok,
                    title: "lark-oapi package",
                    detail: "The selected Hermes Python environment can import lark_oapi.",
                    action: nil
                ))
            } else if logSaysMissing {
                checks.append(PlatformDependencyCheck(
                    id: "feishu-python-unknown",
                    status: .blocker,
                    title: "Cannot verify Feishu Python dependency",
                    detail: "HermesStation could not find the Hermes Python executable, and recent logs show lark-oapi is missing.",
                    action: nil
                ))
            }

        case "email":
            let configText = [
                instance.configs["EMAIL_ADDRESS"],
                instance.configs["EMAIL_USER"],
                instance.configs["EMAIL_USERNAME"],
                instance.configs["EMAIL_IMAP_HOST"],
                instance.configs["EMAIL_SMTP_HOST"],
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: "\n")
            let isNeteaseMail = configText.contains("163.com") || configText.contains("188.com")
            let imapIDPolicy = (instance.configs["EMAIL_IMAP_SEND_ID"] ?? "auto").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let smtpSecurity = (instance.configs["EMAIL_SMTP_SECURITY"] ?? "auto").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let smtpPort = (instance.configs["EMAIL_SMTP_PORT"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let unsafeLogin = context.contains("unsafe login")
                || context.contains("login is unsafe")
                || context.contains("unsafe authentication")
            let inboxSelectFailure = context.contains("could not select inbox")

            if unsafeLogin {
                checks.append(PlatformDependencyCheck(
                    id: "email-unsafe-login",
                    status: .blocker,
                    title: "Mailbox Unsafe Login",
                    detail: "The 163/188 mailbox provider rejected the login as unsafe. Enable IMAP/SMTP authorization or app-specific password in the mailbox security settings, then restart gateway.",
                    action: .openGatewayLog
                ))
            } else if inboxSelectFailure {
                checks.append(PlatformDependencyCheck(
                    id: "email-inbox-select-failed",
                    status: .blocker,
                    title: "INBOX selection failed",
                    detail: "IMAP authentication succeeded, but the provider refused selecting INBOX. Check mailbox security settings and IMAP authorization before changing Hermes config.",
                    action: .openGatewayLog
                ))
            } else if isNeteaseMail {
                checks.append(PlatformDependencyCheck(
                    id: "email-netease-warning",
                    status: .info,
                    title: "163/188 security mode",
                    detail: "This mailbox family often requires IMAP/SMTP service to be enabled and an authorization code instead of the account password.",
                    action: nil
                ))

                if imapIDPolicy == "never" {
                    checks.append(PlatformDependencyCheck(
                        id: "email-netease-imap-id-disabled",
                        status: .warning,
                        title: "IMAP ID is disabled",
                        detail: "163/188 may reject INBOX access unless the client sends IMAP ID after LOGIN. Set EMAIL_IMAP_SEND_ID to auto or always.",
                        action: .openEnvFile
                    ))
                } else {
                    checks.append(PlatformDependencyCheck(
                        id: "email-netease-imap-id-ok",
                        status: .ok,
                        title: "IMAP ID policy",
                        detail: "EMAIL_IMAP_SEND_ID is \(imapIDPolicy.isEmpty ? "auto" : imapIDPolicy), which allows Hermes to send IMAP ID for 163/188.",
                        action: nil
                    ))
                }

                if smtpPort == "465" && !(smtpSecurity == "auto" || smtpSecurity == "ssl") {
                    checks.append(PlatformDependencyCheck(
                        id: "email-netease-smtp-security-mismatch",
                        status: .warning,
                        title: "SMTP security mismatches port 465",
                        detail: "Port 465 should usually use SSL, not STARTTLS. Set EMAIL_SMTP_SECURITY to auto or ssl.",
                        action: .openEnvFile
                    ))
                } else {
                    checks.append(PlatformDependencyCheck(
                        id: "email-netease-smtp-security-ok",
                        status: .ok,
                        title: "SMTP security mode",
                        detail: "EMAIL_SMTP_SECURITY is \(smtpSecurity.isEmpty ? "auto" : smtpSecurity). Port \(smtpPort.isEmpty ? "?" : smtpPort) will use the matching SMTP transport.",
                        action: nil
                    ))
                }
            }

            if context.contains("email_address, email_password") {
                checks.append(PlatformDependencyCheck(
                    id: "email-runtime-env-missing",
                    status: .warning,
                    title: "Gateway has stale EMAIL env",
                    detail: "Hermes config contains email fields, but the running gateway still reports missing EMAIL_* values. Re-save config and restart gateway.",
                    action: .restartGateway
                ))
            }

        default:
            break
        }

        if runtimeState == nil {
            checks.append(PlatformDependencyCheck(
                id: "\(instance.platformID)-runtime-missing",
                status: .warning,
                title: "Runtime adapter not loaded",
                detail: "The platform is configured, but the current gateway runtime has not loaded this adapter yet.",
                action: .restartGateway
            ))
        } else if checks.isEmpty && runtimeState?.state == "connected" {
            checks.append(PlatformDependencyCheck(
                id: "\(instance.platformID)-dependencies-ok",
                status: .ok,
                title: "No dependency blockers detected",
                detail: "HermesStation did not detect a known dependency or account-security blocker for this connected platform.",
                action: nil
            ))
        }

        return uniquedPlatformDependencyChecks(checks)
    }

    private static func checkHermesPythonImport(_ importName: String, settings: AppSettings) async -> Bool? {
        let python = HermesPaths(settings: settings).pythonExecutable
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            return nil
        }
        guard let result = try? await CommandRunner.run(python.path, ["-c", "import \(importName)"]) else {
            return nil
        }
        return result.status == 0
    }

    private static func uniquedPlatformDependencyChecks(_ checks: [PlatformDependencyCheck]) -> [PlatformDependencyCheck] {
        var seen = Set<String>()
        return checks.filter { check in
            if seen.contains(check.id) {
                return false
            }
            seen.insert(check.id)
            return true
        }
    }

    private func platformWizardFieldRow(_ field: PlatformConfigField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.system(size: 12, weight: .medium))
            if field.isSecret {
                SecureField(field.label, text: newPlatformConfigBinding(for: field.key))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(field.label, text: newPlatformConfigBinding(for: field.key))
                    .textFieldStyle(.roundedBorder)
            }
            if !field.helpText.isEmpty {
                Text(field.helpText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func platformRuntimeRow(key: String, state: RuntimePlatformState?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: platformIcon(key))
                    .font(.system(size: 24))
                    .foregroundStyle(platformColor(state?.state))
                Circle()
                    .fill(platformColor(state?.state))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(key.capitalized)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 6) {
                    Text(state?.state ?? "unknown")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(platformColor(state?.state).opacity(0.12))
                        .foregroundStyle(platformColor(state?.state))
                        .clipShape(Capsule())

                    if let errorCode = state?.errorCode, !errorCode.isEmpty {
                        Text(errorCode)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                }

                if let errorMessage = state?.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                if let updatedAt = state?.updatedAt, !updatedAt.isEmpty {
                    Text("Updated: \(updatedAt)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func platformIcon(_ key: String) -> String {
        switch key.lowercased() {
        case "telegram": return "paperplane.fill"
        case "discord": return "bubble.left.and.bubble.right.fill"
        case "slack": return "number"
        case "whatsapp": return "phone.fill"
        case "signal": return "wave.3.forward"
        case "matrix": return "grid"
        case "mattermost": return "message.fill"
        case "email", "mail": return "envelope.fill"
        case "sms": return "message.circle.fill"
        case "dingtalk": return "bell.fill"
        case "feishu", "lark": return "paperplane.circle.fill"
        case "wecom": return "building.2.fill"
        case "bluebubbles": return "bubble.fill"
        case "homeassistant", "home_assistant": return "house.fill"
        case "cli": return "terminal.fill"
        default: return "network"
        }
    }

    private func platformConnectionLabel(for instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> String {
        if let state = runtimeState?.state, !state.isEmpty {
            return state
        }
        if gatewayStore.snapshot.runtimeIsStale {
            return "runtime status stale"
        }
        return instance.isEnabled ? "not connected" : "configuration incomplete"
    }

    private func resolvePlatformInstances() -> [PlatformInstance] {
        let paths = HermesPaths(settings: settingsStore.settings)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let configValues = HermesProfileStore.parseConfigValues(from: paths.configURL)
        let discovered = PlatformDescriptorRegistry.discoverInstances(envValues: envValues, configValues: configValues)

        var byID = Dictionary(uniqueKeysWithValues: discovered.map { ($0.id, $0) })

        for (platformID, overrideConfigs) in platformDraftOverrides {
            guard let descriptor = PlatformDescriptorRegistry.descriptor(for: platformID) else { continue }
            let baseConfigs = byID[platformID]?.configs ?? [:]
            let mergedConfigs = mergedPlatformConfigs(for: platformID, base: baseConfigs.merging(overrideConfigs) { _, new in new })
            let isEnabled = byID[platformID]?.isEnabled ?? mergedConfigs.values.contains {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            byID[platformID] = PlatformInstance(
                id: platformID,
                platformID: platformID,
                displayName: descriptor.displayName,
                isEnabled: isEnabled,
                configs: mergedConfigs
            )
        }

        let order = Dictionary(uniqueKeysWithValues: PlatformDescriptorRegistry.allPlatforms.enumerated().map { ($1.id, $0) })
        return byID.values.sorted {
            (order[$0.platformID] ?? .max) < (order[$1.platformID] ?? .max)
        }
    }

    private func refreshPlatformInstances() {
        platformInstancesCache = resolvePlatformInstances()
    }

    private func refreshPlatformDiagnostics() {
        guard let instance = selectedPlatformInstance else {
            platformDiagnosticSummary = nil
            platformDiagnosticLines = []
            platformDependencyChecks = []
            isCheckingPlatformDependencies = false
            return
        }

        let runtimeState = gatewayStore.snapshot.runtime?.platforms[instance.platformID]
        let paths = HermesPaths(settings: settingsStore.settings)
        let settings = settingsStore.settings
        let platformID = instance.platformID
        let summary = platformDiagnosticSummaryText(for: instance, runtimeState: runtimeState)
        isCheckingPlatformDependencies = true

        Task(priority: .utility) {
            let lines = Self.loadPlatformDiagnosticLines(platformID: platformID, paths: paths)
            let dependencyChecks = await Self.loadPlatformDependencyChecks(
                for: instance,
                runtimeState: runtimeState,
                summary: summary,
                logLines: lines,
                settings: settings
            )
            await MainActor.run {
                guard selectedPlatformInstanceID == platformID else {
                    isCheckingPlatformDependencies = false
                    return
                }
                platformDiagnosticSummary = summary
                platformDiagnosticLines = lines
                platformDependencyChecks = dependencyChecks
                isCheckingPlatformDependencies = false
            }
        }
    }

    private func platformDiagnosticSummaryText(for instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> String {
        if !instance.isEnabled {
            return "Configuration incomplete. Fill all required fields before the gateway can load this platform."
        }
        guard gatewayStore.snapshot.authoritativeGatewayPID != nil || gatewayStore.snapshot.runtime?.gatewayState == "running" else {
            return "Gateway service is not running. Start or restart it after saving platform config."
        }
        if gatewayStore.snapshot.runtimeIsStale {
            return "Gateway process is alive, but gateway_state.json is stale. HermesStation is trusting launchd/ps/gateway.pid instead of the runtime file."
        }
        guard let runtimeState else {
            return "This platform is configured, but the running gateway has not loaded it into runtime yet. Restart gateway and check the logs below."
        }
        if let errorMessage = runtimeState.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        switch runtimeState.state {
        case "connected":
            return "Platform is connected."
        case "connecting":
            return "Platform is connecting."
        case "disconnected":
            return "Gateway loaded the platform, but it is disconnected. Check the logs below for the last adapter error."
        default:
            return "Platform runtime state is unknown. Check the logs below."
        }
    }

    private static func loadPlatformDiagnosticLines(platformID: String, paths: HermesPaths) -> [String] {
        let files = [
            ("gateway.log", paths.logsDir.appending(path: "gateway.log")),
            ("gateway.error.log", paths.logsDir.appending(path: "gateway.error.log")),
            ("errors.log", paths.logsDir.appending(path: "errors.log")),
        ]

        let keywords = platformDiagnosticKeywords(for: platformID)
        var matches: [String] = []

        for (name, url) in files where FileManager.default.fileExists(atPath: url.path) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .suffix(400)
                .map(String.init)
                .filter { line in
                    keywords.contains { keyword in
                        line.localizedCaseInsensitiveContains(keyword)
                    }
                }
                .suffix(6)

            matches.append(contentsOf: lines.map { "[\(name)] \($0)" })
        }

        return Array(matches.suffix(8))
    }

    private static func platformDiagnosticKeywords(for platformID: String) -> [String] {
        switch platformID {
        case "email":
            return ["[Email]", "Email:", "EMAIL_", "imap", "smtp"]
        case "feishu":
            return ["[Lark]", "[Feishu]", "Feishu", "Lark"]
        case "weixin":
            return ["weixin", "wechat", "[Weixin]"]
        case "wecom":
            return ["wecom", "WeCom"]
        case "matrix":
            return ["matrix", "[Matrix]"]
        default:
            return [platformID, platformID.replacingOccurrences(of: "_", with: " ")]
        }
    }

    private var selectedPlatformInstance: PlatformInstance? {
        platformInstancesCache.first { $0.id == selectedPlatformInstanceID }
    }

    private func loadPlatformConfigDraft(for instance: PlatformInstance) {
        platformConfigDrafts = mergedPlatformConfigs(for: instance.platformID, base: instance.configs)
        platformStatusMessage = nil
    }

    private func mergedPlatformConfigs(for platformID: String, base: [String: String]) -> [String: String] {
        var merged = base
        if let overrides = platformDraftOverrides[platformID] {
            merged.merge(overrides) { _, new in new }
        }
        return merged
    }

    private func platformConfigBinding(for key: String) -> Binding<String> {
        Binding(
            get: { platformConfigDrafts[key] ?? "" },
            set: { platformConfigDrafts[key] = $0 }
        )
    }

    private func newPlatformConfigBinding(for key: String) -> Binding<String> {
        Binding(
            get: { newPlatformConfigDrafts[key] ?? "" },
            set: { newPlatformConfigDrafts[key] = $0 }
        )
    }

    private func applyPlatformPreset(_ id: String) {
        guard let descriptor = PlatformDescriptorRegistry.descriptor(for: id) else { return }
        var drafts: [String: String] = [:]
        for field in descriptor.fields {
            drafts[field.key] = field.defaultValue ?? ""
        }
        newPlatformConfigDrafts = drafts
        platformStatusMessage = nil
    }

    private func openAddPlatformWizard() {
        newPlatformPresetID = ""
        newPlatformConfigDrafts = [:]
        platformStatusMessage = nil
        showAddPlatformWizard = true
    }

    private var canApplyNeteaseEmailPreset: Bool {
        guard let instance = selectedPlatformInstance, instance.platformID == "email" else { return false }
        let host = (platformConfigDrafts["EMAIL_IMAP_HOST"] ?? instance.configs["EMAIL_IMAP_HOST"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return host.contains("163.com") || host.contains("188.com")
    }

    private func applyNeteaseEmailPreset() {
        guard canApplyNeteaseEmailPreset else { return }
        isSavingPlatforms = true
        platformStatusMessage = nil

        var mergedDrafts = platformConfigDrafts
        if (mergedDrafts["EMAIL_SMTP_PORT"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mergedDrafts["EMAIL_SMTP_PORT"] = "465"
        }
        if (mergedDrafts["EMAIL_IMAP_PORT"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mergedDrafts["EMAIL_IMAP_PORT"] = "993"
        }
        mergedDrafts["EMAIL_IMAP_SEND_ID"] = "always"
        mergedDrafts["EMAIL_IMAP_ID_NAME"] = (mergedDrafts["EMAIL_IMAP_ID_NAME"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Hermes Agent"
            : mergedDrafts["EMAIL_IMAP_ID_NAME"]
        mergedDrafts["EMAIL_IMAP_ID_VENDOR"] = (mergedDrafts["EMAIL_IMAP_ID_VENDOR"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "HermesStation"
            : mergedDrafts["EMAIL_IMAP_ID_VENDOR"]
        mergedDrafts["EMAIL_SMTP_SECURITY"] = "ssl"

        Task {
            let result = await runPlatformConfigCommands(mergedDrafts.sorted { $0.key < $1.key })
            await MainActor.run {
                switch result {
                case .success:
                    self.platformConfigDrafts = mergedDrafts
                    if let instance = selectedPlatformInstance {
                        self.platformDraftOverrides[instance.platformID] = mergedDrafts
                    }
                    self.refreshPlatformInstances()
                    self.profileStore.load()
                    self.gatewayStore.restartService()
                    self.platformStatusMessage = "Applied 163/188 preset: IMAP ID enabled, SMTP 465 forced to SSL, gateway restarting."
                case .failure(let error):
                    self.platformStatusMessage = "Failed to apply 163/188 preset: \(error.localizedDescription)"
                }
                self.isSavingPlatforms = false
            }
        }
    }

    private func savePlatformConfig() {
        guard selectedPlatformInstance != nil else { return }
        isSavingPlatforms = true
        Task {
            let result = await runPlatformConfigCommands(platformConfigDrafts.sorted { $0.key < $1.key })
            await MainActor.run {
                isSavingPlatforms = false
                switch result {
                case .success:
                    platformStatusMessage = "Platform config saved to the current Hermes profile."
                    if let instance = selectedPlatformInstance {
                        platformDraftOverrides[instance.platformID] = platformConfigDrafts
                    }
                    refreshPlatformInstances()
                    profileStore.load()
                    gatewayStore.refresh()
                case .failure(let error):
                    platformStatusMessage = "Failed to save platform config: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deletePlatformConfig() {
        guard let instance = selectedPlatformInstance,
              let descriptor = PlatformDescriptorRegistry.descriptor(for: instance.platformID) else { return }
        isSavingPlatforms = true
        Task {
            let updates = descriptor.fields.map { ($0.key, "") }
            let result = await runPlatformConfigCommands(updates)
            await MainActor.run {
                isSavingPlatforms = false
                switch result {
                case .success:
                    platformStatusMessage = "Platform removed from the current Hermes profile."
                    platformDraftOverrides.removeValue(forKey: instance.platformID)
                    refreshPlatformInstances()
                    selectedPlatformInstanceID = nil
                    platformConfigDrafts = [:]
                    profileStore.load()
                    gatewayStore.refresh()
                case .failure(let error):
                    platformStatusMessage = "Failed to delete platform: \(error.localizedDescription)"
                }
            }
        }
    }

    private func commitNewPlatform() {
        guard !newPlatformPresetID.isEmpty,
              let descriptor = PlatformDescriptorRegistry.descriptor(for: newPlatformPresetID) else { return }
        isSavingPlatforms = true
        Task {
            let updates = descriptor.fields.map { field in
                (field.key, newPlatformConfigDrafts[field.key] ?? field.defaultValue ?? "")
            }
            let result = await runPlatformConfigCommands(updates)
            await MainActor.run {
                isSavingPlatforms = false
                switch result {
                case .success:
                    platformStatusMessage = "Platform added to the current Hermes profile."
                    platformDraftOverrides[newPlatformPresetID] = Dictionary(uniqueKeysWithValues: updates.map { ($0.0, $0.1) })
                    refreshPlatformInstances()
                    showAddPlatformWizard = false
                    profileStore.load()
                    gatewayStore.refresh()
                    selectedPlatformInstanceID = newPlatformPresetID
                    if let instance = platformInstancesCache.first(where: { $0.id == newPlatformPresetID }) {
                        loadPlatformConfigDraft(for: instance)
                    }
                case .failure(let error):
                    platformStatusMessage = "Failed to add platform: \(error.localizedDescription)"
                }
            }
        }
    }

    private func runPlatformConfigCommands(_ updates: [(key: String, value: String)]) async -> Result<Void, Error> {
        do {
            for (key, value) in updates {
                let result = try await CommandRunner.runHermes(settingsStore.settings, ["config", "set", key, value])
                guard result.status == 0 else {
                    let message = result.combinedOutput.isEmpty
                        ? "Command failed: hermes config set \(key)"
                        : result.combinedOutput
                    throw NSError(domain: "HermesStation.Platforms", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: message])
                }
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Environment

    private var environmentTab: some View {
        Form {
            hermesManagementSection

            Section("配置文件") {
                pathRow("config.yaml", path: profileStore.snapshot.configURL.path, action: profileStore.openConfigFile)
                pathRow(".env", path: profileStore.snapshot.envURL.path, action: profileStore.openEnvFile)
                pathRow("SOUL.md", path: profileStore.snapshot.soulURL.path, action: profileStore.openSoulFile)
                pathRow("auth.json", path: HermesPaths(settings: settingsStore.settings).authStore.path, action: gatewayStore.openAuthStore)
                pathRow("session_model_overrides.json", path: HermesPaths(settings: settingsStore.settings).sessionModelOverridesURL.path) {
                    openPath(HermesPaths(settings: settingsStore.settings).sessionModelOverridesURL)
                }
                if let latestDump = gatewayStore.snapshot.endpointTransparency?.latestRequestDump {
                    pathRow("latest request_dump", path: latestDump.fileURL.path, action: gatewayStore.openLatestRequestDump)
                }
            }

            Section("Utilities") {
                HStack {
                    Button("Logs") { gatewayStore.openLogs() }
                    Button("gateway.log") { gatewayStore.openGatewayLog() }
                    Button("error.log") { gatewayStore.openGatewayErrorLog() }
                }
                HStack {
                    Button("Hermes Config") { profileStore.openConfigFile() }
                    Button("Open Workspace") { gatewayStore.openWorkspace() }
                    Button("Open Hermes Home") { gatewayStore.openHermesHome() }
                    Button("Open Hermes Root") { gatewayStore.openHermesRoot() }
                }
            }

            hermesReleasesSection

            aliasScriptsSection

            Section("工作目录") {
                labeledField("terminal.cwd", text: $hermesDraft.terminalCwd)
                mappingHint("config.yaml → terminal.cwd")

                labeledField("MESSAGING_CWD", text: $hermesDraft.messagingCwd)
                mappingHint(".env → MESSAGING_CWD")

                if !hermesDraft.messagingCwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Button("Migrate MESSAGING_CWD") {
                            profileStore.migrateMessagingCwdToTerminalCwd(restartGateway: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profileStore.isSaving)

                        Text("Move the legacy `.env` working directory into `terminal.cwd`, clear the deprecated env var, and restart gateway.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            hermesNotesSection

            Section {
                HStack {
                    Button("Reload") {
                        profileStore.load()
                        hermesDraft = profileStore.snapshot.draft
                    }
                    Spacer()
                    Button("Save to Hermes") {
                        profileStore.save(hermesDraft)
                    }
                    .disabled(!canSaveHermes)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var hermesManagementSection: some View {
        Section("Hermes Management") {
            let alignment = gatewayStore.snapshot.profileAlignment
            let expected = alignment?.expectedProfile ?? settingsStore.settings.profileName
            let sticky = alignment?.stickyDisplayName ?? "unknown"
            let isAligned = alignment?.isAligned ?? false

            HStack(spacing: 8) {
                summaryPill(title: "App profile", value: expected.isEmpty ? "unset" : expected)
                summaryPill(title: "CLI default", value: sticky)
                summaryPill(title: "Gateway", value: gatewayStore.snapshot.runtime?.gatewayState ?? gatewayStore.snapshot.serviceStatus.rawValue)
                summaryPill(title: "launchd", value: gatewayStore.snapshot.serviceLoaded ? "loaded" : "not loaded")
            }

            if !isAligned {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hermes CLI default profile does not match this HermesStation profile.")
                            .font(.system(size: 12, weight: .medium))
                        Text("Bare `hermes ...` commands may manage \(sticky) while HermesStation is editing \(expected).")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Use \(expected)") {
                        gatewayStore.useCurrentHermesProfile()
                    }
                    .disabled(gatewayStore.isBusy || expected.isEmpty)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let alignment {
                managementPathRow("Hermes root", alignment.hermesRootPath)
                managementPathRow("Profile home", alignment.profileHomePath)
            }

            HStack {
                Button("Doctor --fix") {
                    gatewayStore.runDoctorFix()
                }
                .disabled(gatewayStore.isBusy)

                Button("Use This Profile") {
                    gatewayStore.useCurrentHermesProfile()
                }
                .disabled(gatewayStore.isBusy || expected.isEmpty)

                Button("Restart Gateway") {
                    gatewayStore.restartService()
                }
                .disabled(gatewayStore.isBusy)
            }

            if let report = gatewayStore.snapshot.doctorReport {
                doctorReportView(report)
            }

            Text("When an upgrade changes Hermes behavior, align the CLI profile first, then run Doctor --fix, then restart gateway.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func doctorReportView(_ report: HermesDoctorReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: doctorStatusIcon(report.status))
                    .foregroundStyle(doctorStatusColor(report.status))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Doctor Results")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Last run: \(doctorRunDateText(report.ranAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(doctorStatusLabel(report.status), color: doctorStatusColor(report.status))
                if report.fixedCount > 0 {
                    statusBadge("fixed \(report.fixedCount)", color: .green)
                }
                if report.issueCount > 0 {
                    statusBadge("issues \(report.issueCount)", color: .orange)
                }
            }

            Text(report.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let checks = Array(report.keyChecks.prefix(8))
            if !checks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(checks) { check in
                        doctorCheckRow(check)
                    }
                }
            }
        }
        .padding(10)
        .background(doctorStatusColor(report.status).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func doctorCheckRow(_ check: HermesDoctorCheck) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: doctorCheckIcon(check.state))
                .foregroundStyle(doctorCheckColor(check.state))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.system(size: 11, weight: .medium))
                HStack(spacing: 6) {
                    Text(check.section)
                    if let detail = check.detail, !detail.isEmpty {
                        Text(detail)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func doctorStatusLabel(_ status: HermesDoctorReportStatus) -> String {
        switch status {
        case .clean: return "clean"
        case .fixed: return "fixed"
        case .needsAttention: return "needs attention"
        case .failed: return "failed"
        case .unknown: return "unknown"
        }
    }

    private func doctorStatusIcon(_ status: HermesDoctorReportStatus) -> String {
        switch status {
        case .clean, .fixed: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func doctorStatusColor(_ status: HermesDoctorReportStatus) -> Color {
        switch status {
        case .clean, .fixed: return .green
        case .needsAttention: return .orange
        case .failed: return .red
        case .unknown: return .secondary
        }
    }

    private func doctorCheckIcon(_ state: HermesDoctorCheckState) -> String {
        switch state {
        case .ok, .fixed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func doctorCheckColor(_ state: HermesDoctorCheckState) -> Color {
        switch state {
        case .ok, .fixed: return .green
        case .warning: return .orange
        case .failure: return .red
        case .info: return .blue
        }
    }

    private func doctorRunDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Shared

    @ViewBuilder
    private var hermesReleasesSection: some View {
        let info = gatewayStore.snapshot.releaseInfo
        let updateState = gatewayStore.updater.state
        Section("Hermes Releases") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installed")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(info?.currentVersion ?? "Unknown")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(info?.latestVersion ?? "–")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if info?.isUpdateAvailable == true {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 20))
                    }
                }

                if let published = info?.publishedAt, !published.isEmpty {
                    Text("Published: \(published)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                if let error = info?.fetchError, !error.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = updateState.errorMessage, !error.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                if let path = info?.globalHermesPath, !path.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: info?.isGlobalHermesMatching == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(info?.isGlobalHermesMatching == true ? .green : .orange)
                            Text("Global hermes: \(path)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let target = info?.globalHermesTarget, !target.isEmpty, target != path {
                            Text("→ \(target)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.leading, 18)
                        }
                        if info?.isGlobalHermesMatching == false {
                            HStack(spacing: 6) {
                                Text("全局命令指向的安装与当前 profile 不一致")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                                Button("Fix Symlink") {
                                    Task {
                                        _ = await gatewayStore.updater.fixGlobalHermesSymlink()
                                        gatewayStore.refresh()
                                    }
                                }
                                .disabled(gatewayStore.isBusy || gatewayStore.updater.isBusy)
                                .font(.system(size: 10))
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                            .padding(.leading, 18)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("未检测到全局 hermes 命令 (PATH 中不存在)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Button("Create Symlink") {
                            Task {
                                _ = await gatewayStore.updater.fixGlobalHermesSymlink()
                                gatewayStore.refresh()
                            }
                        }
                        .disabled(gatewayStore.isBusy || gatewayStore.updater.isBusy)
                        .font(.system(size: 10))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                }

                switch updateState {
                case .idle, .failed:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if info?.isUpdateAvailable == true, let tag = info?.latestTag {
                                Button("Prepare \(tag)") {
                                    gatewayStore.updater.prepareUpdate(to: tag)
                                }
                                .disabled(gatewayStore.updater.isBusy)
                            }

                            Button("Run hermes update") {
                                gatewayStore.runHermesUpdate()
                            }
                            .disabled(gatewayStore.isBusy)

                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Button("Open Release Page") {
                                gatewayStore.openLatestReleasePage()
                            }
                            .disabled(info?.releaseURL == nil)

                            Button("Refresh") {
                                gatewayStore.refresh()
                            }
                            .disabled(gatewayStore.isBusy)

                            Spacer()
                        }
                    }

                case .preparing(_, let message):
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                case .ready(let tag, _):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(tag) ready")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Button("Apply & Restart") {
                                gatewayStore.applyPreparedUpdate()
                            }
                            .disabled(gatewayStore.isBusy || gatewayStore.updater.isBusy)

                            Button("Discard") {
                                gatewayStore.updater.discardPreparedUpdate()
                            }
                            .disabled(gatewayStore.isBusy)

                            Spacer()
                        }
                    }

                case .applying(_, let message):
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                case .completed(let tag):
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Updated to \(tag). Restarted.")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var aliasScriptsSection: some View {
        let aliases = gatewayStore.snapshot.aliases
        Section("Profile Aliases") {
            VStack(alignment: .leading, spacing: 8) {
                if aliases.isEmpty {
                    Text("No alias scripts found in ~/.local/bin for this profile.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(aliases) { alias in
                            HStack(spacing: 8) {
                                Image(systemName: alias.isStandard ? "checkmark.circle.fill" : "info.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(alias.isStandard ? .green : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alias.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .textSelection(.enabled)
                                    if !alias.isStandard {
                                        Text("Custom wrapper script (non-standard)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button("Remove") {
                                    gatewayStore.removeAlias(name: alias.name)
                                }
                                .disabled(gatewayStore.isBusy)
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("New alias name", text: $newAliasName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Create Alias") {
                        let name = newAliasName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        gatewayStore.createAlias(name: name)
                        newAliasName = ""
                    }
                    .disabled(gatewayStore.isBusy || newAliasName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if !aliases.isEmpty {
                    Text("Aliases let you run this profile from anywhere by typing the alias name in a terminal.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var hermesNotesSection: some View {
        let notes = profileStore.snapshot.notes
        let message = profileStore.lastSaveMessage
        if !notes.isEmpty || message != nil {
            Section {
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                if let message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(message.hasPrefix("已") ? Color.secondary : Color.red)
                }
            }
        }
    }

    private var profileMeaningOverview: some View {
        GroupBox("What This Profile Means") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("在 Hermes 里，profile 是一套命名的隔离环境。切换 profile，会把配置、密钥、SOUL、sessions、logs、gateway 状态，以及 CLI 的 `-p` 作用域一起切走。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                profileMeaningRow(
                    systemImage: "terminal.fill",
                    title: "CLI / Gateway Scope",
                    body: "这个 profile 会成为 Hermes 命令和 menubar Gateway 控制的默认目标。",
                    emphasis: "hermes -p \(profileIDPreview)"
                )
                profileMeaningRow(
                    systemImage: "gearshape.2.fill",
                    title: "Config & Secrets",
                    body: "会读取这一套 profile 自己的 `config.yaml` 和 `.env`，因此 provider、token、platform 配置彼此隔离。",
                    emphasis: profileDerivedPath(\.configURL)
                )
                profileMeaningRow(
                    systemImage: "person.crop.square.fill",
                    title: "Identity & Context",
                    body: "这个 profile 自己拥有 `SOUL.md`，也拥有 profile home 里的其余上下文资产。",
                    emphasis: profileDerivedPath(\.soulURL)
                )
                profileMeaningRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Runtime & History",
                    body: "sessions、logs、state.db 和 gateway_state 都属于这套环境，所以不同 profile 的历史与运行态不会混在一起。",
                    emphasis: profileDerivedPath(\.sessionsDir)
                )
            }
            .padding(.top, 4)
        }
    }

    private var activeProfileScopeBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Current isolated runtime: \(profileSwitcherLabel(for: settingsStore.settings))")
                    .font(.system(size: 11, weight: .medium))
                Text("Owns its own config.yaml, .env, SOUL.md, sessions, logs, and gateway state.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var profileScopePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            profileScopeRow(
                systemImage: "folder.fill",
                title: "Hermes Home",
                value: profileDerivedPath(\.hermesHome),
                detail: "这套 profile 的根目录。"
            )
            profileScopeRow(
                systemImage: "doc.text.fill",
                title: "config.yaml",
                value: profileDerivedPath(\.configURL),
                detail: "模型、路由和运行配置从这里读取。"
            )
            profileScopeRow(
                systemImage: "key.fill",
                title: ".env",
                value: profileDerivedPath(\.envURL),
                detail: "密钥、token 和环境变量属于这套 profile。"
            )
            profileScopeRow(
                systemImage: "person.text.rectangle.fill",
                title: "SOUL.md",
                value: profileDerivedPath(\.soulURL),
                detail: "定义这套 profile 的人格 / 语气 / 工作方式。"
            )
            profileScopeRow(
                systemImage: "tray.full.fill",
                title: "sessions / logs / state.db",
                value: profileDerivedRuntimePreview,
                detail: "会话历史、日志和运行状态会按 profile 分开。"
            )
            profileScopeRow(
                systemImage: "bolt.horizontal.circle.fill",
                title: "Gateway Service Label",
                value: profileLaunchAgentPreview,
                detail: "launchd 会按 profile 名字分隔服务实例。"
            )
            profileScopeRow(
                systemImage: "terminal",
                title: "Command Scope",
                value: "hermes -p \(profileIDPreview)",
                detail: "Hermes CLI 用这个 profile ID 切换到对应环境。"
            )
        }
    }

    private func profileMeaningRow(systemImage: String, title: String, body: String, emphasis: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(emphasis)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func profileScopeRow(systemImage: String, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var profileIDPreview: String {
        let id = appDraft.normalized.profileName
        return id.isEmpty ? "<unset-profile-id>" : id
    }

    private func profileSwitcherLabel(for profile: AppSettings) -> String {
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Profile"
            : profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileID = profile.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileID.isEmpty else { return "\(displayName) · profile id unset" }
        return "\(displayName) · -p \(profileID)"
    }

    private var profilePreviewPaths: HermesPaths? {
        let settings = appDraft.normalized
        guard !settings.projectRootPath.isEmpty, !settings.profileName.isEmpty else { return nil }
        return HermesPaths(settings: settings)
    }

    private func profileDerivedPath(_ keyPath: KeyPath<HermesPaths, URL>) -> String {
        guard let paths = profilePreviewPaths else {
            return "Set Project Root and Hermes Profile ID to preview this path."
        }
        return paths[keyPath: keyPath].path
    }

    private var profileDerivedRuntimePreview: String {
        guard let paths = profilePreviewPaths else {
            return "Set Project Root and Hermes Profile ID to preview runtime storage."
        }
        return "\(paths.sessionsDir.path) | \(paths.logsDir.path) | \(paths.stateDB.path)"
    }

    private var profileLaunchAgentPreview: String {
        guard let paths = profilePreviewPaths else {
            return "Set Hermes Profile ID to preview the launchd label."
        }
        return paths.launchAgentLabel
    }

    private var stationGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)]
    }

    private var stationIconColor: Color {
        switch gatewayStore.snapshot.serviceStatus {
        case .running:
            return .green
        case .degraded:
            return .orange
        case .stopped:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private var stationCapabilityCards: [HermesCapabilityCard] {
        HermesCapabilityEvaluator.evaluate(
            settings: settingsStore.settings,
            gatewaySnapshot: gatewayStore.snapshot,
            profileSnapshot: profileStore.snapshot,
            platformInstances: platformInstancesCache,
            memoryEntries: memoryEntries,
            skillEntries: skillEntries
        )
        .sorted { lhs, rhs in
            if lhs.readiness.rank != rhs.readiness.rank {
                return lhs.readiness.rank > rhs.readiness.rank
            }
            if lhs.warningDependencyCount != rhs.warningDependencyCount {
                return lhs.warningDependencyCount > rhs.warningDependencyCount
            }
            return lhs.domain.title < rhs.domain.title
        }
    }

    private var stationTopGapCard: HermesCapabilityCard? {
        stationCapabilityCards.first { $0.readiness != .ready }
    }

    private var stationCapabilityRecommendations: [HermesCapabilityRecommendation] {
        HermesCapabilityEvaluator.recommendations(
            from: stationCapabilityCards,
            platformInstances: platformInstancesCache
        )
    }

    private var stationDiagnosticsTrigger: String {
        [
            gatewayStore.snapshot.trustedRuntime?.updatedAt ?? "",
            gatewayStore.snapshot.serviceStatus.rawValue,
            selectedPlatformInstanceID ?? "",
            String(gatewayStore.snapshot.doctorReport?.ranAt.timeIntervalSinceReferenceDate ?? 0)
        ].joined(separator: "|")
    }

    private var agentSelectionTrigger: String {
        let ids = gatewayStore.snapshot.agentSessions.rows.map(\.id).joined(separator: ",")
        return [agentSearchText, agentFilter.rawValue, ids].joined(separator: "|")
    }

    private var memoryFilterTrigger: String {
        [memorySearchText, memorySourceFilter].joined(separator: "|")
    }

    private var skillFilterTrigger: String {
        let ids = skillEntries.map(\.id).joined(separator: ",")
        return [skillSearchText, skillFilter.rawValue, ids].joined(separator: "|")
    }

    private var gatewayRuntimeHeadline: String {
        if gatewayStore.snapshot.runtimeIsStale {
            return "stale runtime"
        }
        if let state = gatewayStore.snapshot.runtime?.gatewayState, !state.isEmpty {
            return state
        }
        return gatewayStore.snapshot.serviceStatus.rawValue
    }

    private var connectedPlatformCount: Int {
        platformInstancesCache.filter { instance in
            gatewayStore.snapshot.runtime?.platforms[instance.platformID]?.state == "connected"
        }.count
    }

    private var configuredPlatformCount: Int {
        platformInstancesCache.filter(\.isEnabled).count
    }

    private var profileOverviews: [HermesProfileOverview] {
        settingsStore.profiles.map(profileOverview(for:))
    }

    private func profileOverview(for settings: AppSettings) -> HermesProfileOverview {
        let paths = HermesPaths(settings: settings)
        let configValues = HermesProfileStore.parseConfigValues(from: paths.configURL)
        let envValues = HermesProfileStore.parseEnvValues(from: paths.envURL)
        let configuredPlatforms = PlatformDescriptorRegistry.discoverInstances(envValues: envValues, configValues: configValues)
        let totalModelCount = settings.modelProviders.reduce(into: 0) { partial, provider in
            partial += provider.models.count
        }

        return HermesProfileOverview(
            id: settings.id,
            settings: settings,
            paths: paths,
            configuredPlatforms: configuredPlatforms,
            enabledPlatformCount: configuredPlatforms.filter(\.isEnabled).count,
            totalModelCount: totalModelCount,
            configExists: FileManager.default.fileExists(atPath: paths.configURL.path),
            envExists: FileManager.default.fileExists(atPath: paths.envURL.path),
            soulExists: FileManager.default.fileExists(atPath: paths.soulURL.path),
            runtimeExists: FileManager.default.fileExists(atPath: paths.gatewayState.path)
        )
    }

    private func stationInfoBanner(title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(color)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationCapabilityCard(_ card: HermesCapabilityCard) -> some View {
        let highlightedDependencies = stationHighlightedDependencies(for: card)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: card.domain.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(stationCapabilityDomainColor(card.domain))
                    .frame(width: 24, alignment: .top)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.domain.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(card.domain.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                statusBadge(card.readiness.label, color: stationCapabilityReadinessColor(card.readiness))
            }

            Text(card.summary)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                summaryPill(title: "Readiness", value: card.progressLabel)
                if card.warningDependencyCount > 0 {
                    summaryPill(title: "Attention", value: "\(card.warningDependencyCount)")
                }
            }

            if let providerLine = card.providerLine, !providerLine.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(providerLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let evidenceLine = card.evidenceLine, !evidenceLine.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(evidenceLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(highlightedDependencies) { dependency in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(stationCapabilityDependencyColor(dependency.state))
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(dependency.title)
                                    .font(.system(size: 11, weight: .medium))
                                Text(dependency.state.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(stationCapabilityDependencyColor(dependency.state))
                            }
                            Text(dependency.detail)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack {
                Button(stationCapabilityPrimaryActionTitle(for: card)) {
                    performStationCapabilityPrimaryAction(for: card)
                }
                .buttonStyle(.borderedProminent)
                .disabled(gatewayStore.isBusy || profileStore.isSaving)

                Button(stationCapabilitySecondaryActionTitle(for: card)) {
                    performStationCapabilitySecondaryAction(for: card)
                }
                .disabled(gatewayStore.isBusy || profileStore.isSaving)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stationCapabilityRecommendationCard(_ recommendation: HermesCapabilityRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(recommendation.targetDomains.map(\.title).joined(separator: " + "))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(recommendation.summary)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)

            Text(recommendation.reason)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(recommendation.actionTitle) {
                performStationRecommendationAction(recommendation)
            }
            .buttonStyle(.borderedProminent)
            .disabled(gatewayStore.isBusy || profileStore.isSaving)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func packSheet(for pack: HermesPackKind) -> some View {
        switch pack {
        case .research:
            HermesPackSheetView(
                icon: "magnifyingglass.circle.fill",
                title: "Research Pack",
                intro: "这一版会自动完成 HermesStation 已经能安全托管的研究能力改动：搜索后端、CLI toolsets、内置 research/document skills，以及 doctor 校准。需要外部密钥或第三方依赖的部分会单独列出来，不会偷偷修改。",
                safeChangesDescription: "These steps are backed by Hermes CLI mutations and can be applied directly from HermesStation.",
                whyText: "Research Pack 把“研究助手”压成一个具体本地状态：可用的搜索后端、启用的 web/browser 工具、启用的 research/document skills，以及 doctor-backed trust baseline。",
                message: packMessages[.research],
                isLoading: isLoadingPacks,
                isApplyingAll: applyingPackKinds.contains(.research),
                steps: researchPackSnapshot?.steps ?? [],
                optionalUpgrades: researchPackSnapshot?.optionalUpgrades ?? [],
                receipts: packReceipts,
                inFlightStepIDs: inFlightPackStepIDs,
                supportActions: [
                    HermesPackSupportAction(id: "research-env", title: "Open .env") {
                        profileStore.openEnvFile()
                    },
                    HermesPackSupportAction(id: "research-tools", title: "Open Tools") {
                        selectedTab = .tools
                        activePackSheet = nil
                    },
                    HermesPackSupportAction(id: "research-skills", title: "Open Skills") {
                        selectedTab = .skills
                        activePackSheet = nil
                    }
                ],
                onRefresh: loadCapabilityPacks,
                onApplyAll: applyResearchPackSafeChanges,
                onApplyStep: applyResearchPackStep
            )

        case .content:
            HermesPackSheetView(
                icon: "paintpalette.fill",
                title: "Content Pack",
                intro: "这一版会自动补齐内容创作常用的 Hermes 基础能力：creative toolsets、内容 skills 和 doctor 校准。图像或高质量音频 provider 这类需要外部密钥的升级，会明确列成手动步骤。",
                safeChangesDescription: "These steps are safe CLI-backed mutations that move Hermes from generic chat toward repeatable content output.",
                whyText: "Content Pack 把“能产出”拆成可执行的配置面：image/tts/vision/skills toolsets、内容相关 skills，以及一条 doctor-backed trust path。",
                message: packMessages[.content],
                isLoading: isLoadingPacks,
                isApplyingAll: applyingPackKinds.contains(.content),
                steps: contentPackSnapshot?.steps ?? [],
                optionalUpgrades: contentPackSnapshot?.optionalUpgrades ?? [],
                receipts: packReceipts,
                inFlightStepIDs: inFlightPackStepIDs,
                supportActions: [
                    HermesPackSupportAction(id: "content-env", title: "Open .env") {
                        profileStore.openEnvFile()
                    },
                    HermesPackSupportAction(id: "content-models", title: "Open Models") {
                        selectedTab = .model
                        activePackSheet = nil
                    },
                    HermesPackSupportAction(id: "content-skills", title: "Open Skills") {
                        selectedTab = .skills
                        activePackSheet = nil
                    }
                ],
                onRefresh: loadCapabilityPacks,
                onApplyAll: applyContentPackSafeChanges,
                onApplyStep: applyContentPackStep
            )
        }
    }

    private func stationLatestRequestDumpCard(_ dump: LatestRequestDumpSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Latest API Failure")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let reason = dump.reason, !reason.isEmpty {
                    statusBadge(reason, color: .orange)
                }
            }

            if let model = dump.model, !model.isEmpty {
                detailRowCompact("Model", model)
            }
            if let requestURL = dump.requestURL, !requestURL.isEmpty {
                detailRowCompact("URL", requestURL)
            } else if let requestBaseURL = dump.requestBaseURL, !requestBaseURL.isEmpty {
                detailRowCompact("Base URL", requestBaseURL)
            }
            if let errorType = dump.errorType, !errorType.isEmpty {
                detailRowCompact("Error", errorType)
            }
            if let errorMessage = dump.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Open request_dump") {
                    gatewayStore.openLatestRequestDump()
                }
                if canAdoptOfficialKimiCodingPlanRoute && isLikelyKimiCodingPlanError(dump) {
                    Button("Adopt Official Route") {
                        profileStore.adoptKimiCodingPlanOfficialRoute(restartGateway: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profileStore.isSaving)
                }
                Button("Docs") {
                    openKimiCodingPlanDocs()
                }
                Button("模型页") {
                    selectedTab = .model
                }
                Button("环境页") {
                    selectedTab = .environment
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationPlatformCard(_ instance: PlatformInstance) -> some View {
        let runtimeState = gatewayStore.snapshot.runtime?.platforms[instance.platformID]
        let descriptor = PlatformDescriptorRegistry.descriptor(for: instance.platformID)
        let bindings = gatewayStore.snapshot.bindingEntries(for: instance.platformID)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: descriptor?.icon ?? "network")
                    .foregroundStyle(platformColor(runtimeState?.state))
                    .frame(width: 20)
                Text(instance.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                statusBadge(stationPlatformStatusText(instance, runtimeState: runtimeState), color: stationPlatformStatusColor(instance, runtimeState: runtimeState))
            }

            if let note = stationPlatformSpotlight(instance, runtimeState: runtimeState) {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detailRowCompact("Home", stationPlatformHome(instance))
            detailRowCompact("Allowed", stationPlatformAllowlist(instance))
            detailRowCompact("Transport", stationPlatformTransport(instance))
            if !bindings.isEmpty {
                detailRowCompact("Bindings", "\(bindings.count) session(s) · latest \(bindings[0].displayLabel)")
            }

            HStack {
                Button("Manage") {
                    selectedPlatformInstanceID = instance.id
                    loadPlatformConfigDraft(for: instance)
                    selectedTab = .platforms
                }
                .buttonStyle(.borderedProminent)

                Button("Logs") {
                    gatewayStore.openGatewayLog()
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationProfileRow(_ overview: HermesProfileOverview) -> some View {
        let isActive = overview.id == settingsStore.activeProfileID
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profileSwitcherLabel(for: overview.settings))
                        .font(.system(size: 13, weight: .semibold))
                    Text(overview.paths.hermesHome.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer()
                if isActive {
                    statusBadge("当前激活", color: .green)
                } else {
                    statusBadge("待切换", color: .secondary)
                }
            }

            HStack(spacing: 8) {
                summaryPill(title: "Platforms", value: "\(overview.enabledPlatformCount)/\(overview.configuredPlatforms.count)")
                summaryPill(title: "Providers", value: "\(overview.settings.modelProviders.count)")
                summaryPill(title: "Models", value: "\(overview.totalModelCount)")
                summaryPill(title: "Runtime", value: overview.runtimeExists ? "present" : "missing")
            }

            HStack(spacing: 8) {
                filePresenceBadge("config", exists: overview.configExists)
                filePresenceBadge("env", exists: overview.envExists)
                filePresenceBadge("soul", exists: overview.soulExists)
            }

            HStack {
                if !isActive {
                    Button("Switch Here") {
                        settingsStore.activateProfile(overview.id)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Open Home") {
                    openPath(overview.paths.hermesHome)
                }

                Button("Open Logs") {
                    openPath(overview.paths.logsDir)
                }
            }
        }
        .padding(12)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationPlatformStatusText(_ instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> String {
        if gatewayStore.snapshot.runtimeIsStale {
            return "stale"
        }
        if let state = runtimeState?.state, !state.isEmpty {
            return state
        }
        return instance.isEnabled ? "configured" : "partial"
    }

    private func stationPlatformStatusColor(_ instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> Color {
        if gatewayStore.snapshot.runtimeIsStale {
            return .orange
        }
        if let state = runtimeState?.state {
            return platformColor(state)
        }
        return instance.isEnabled ? .blue : .orange
    }

    private func stationPlatformHome(_ instance: PlatformInstance) -> String {
        switch instance.platformID {
        case "email":
            return firstNonEmpty(instance.configs["EMAIL_HOME_ADDRESS"], instance.configs["EMAIL_ADDRESS"]) ?? "not set"
        case "feishu":
            return firstNonEmpty(instance.configs["FEISHU_HOME_CHANNEL"], instance.configs["FEISHU_HOME_CHANNEL_NAME"]) ?? "not set"
        case "weixin":
            return firstNonEmpty(instance.configs["WEIXIN_HOME_CHANNEL"], instance.configs["WEIXIN_HOME_CHANNEL_NAME"]) ?? "not set"
        default:
            return firstNonEmpty(
                instance.configs["\(instance.platformID.uppercased())_HOME_CHANNEL"],
                instance.configs["\(instance.platformID.uppercased())_HOME_CHANNEL_NAME"]
            ) ?? "not set"
        }
    }

    private func stationPlatformAllowlist(_ instance: PlatformInstance) -> String {
        let keys: [String]
        switch instance.platformID {
        case "email":
            keys = ["EMAIL_ALLOWED_USERS", "EMAIL_ALLOW_ALL_USERS"]
        case "feishu":
            keys = ["FEISHU_ALLOWED_USERS"]
        case "weixin":
            keys = ["WEIXIN_ALLOWED_USERS", "WEIXIN_ALLOW_ALL_USERS"]
        default:
            keys = [
                "\(instance.platformID.uppercased())_ALLOWED_USERS",
                "\(instance.platformID.uppercased())_ALLOW_ALL_USERS"
            ]
        }

        if let allowAllKey = keys.first(where: { $0.hasSuffix("ALLOW_ALL_USERS") }),
           instance.configs[allowAllKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true" {
            return "allow all"
        }
        if let allowlistKey = keys.first(where: { $0.hasSuffix("ALLOWED_USERS") }),
           let raw = instance.configs[allowlistKey],
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let count = raw.split(separator: ",").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            return count == 0 ? "configured" : "\(count) entries"
        }
        return "not set"
    }

    private func stationPlatformTransport(_ instance: PlatformInstance) -> String {
        switch instance.platformID {
        case "email":
            let imap = firstNonEmpty(instance.configs["EMAIL_IMAP_HOST"], instance.configs["EMAIL_ADDRESS"]) ?? "IMAP"
            let smtp = firstNonEmpty(instance.configs["EMAIL_SMTP_HOST"], instance.configs["EMAIL_SMTP_PORT"]) ?? "SMTP"
            let imapIDPolicy = firstNonEmpty(instance.configs["EMAIL_IMAP_SEND_ID"]) ?? "auto"
            let smtpSecurity = firstNonEmpty(instance.configs["EMAIL_SMTP_SECURITY"]) ?? "auto"
            return "\(imap) -> \(smtp) · id:\(imapIDPolicy) · smtp:\(smtpSecurity)"
        case "feishu":
            let mode = firstNonEmpty(instance.configs["FEISHU_CONNECTION_MODE"]) ?? "default"
            if mode == "webhook" {
                let host = firstNonEmpty(instance.configs["FEISHU_WEBHOOK_HOST"]) ?? "127.0.0.1"
                let port = firstNonEmpty(instance.configs["FEISHU_WEBHOOK_PORT"]) ?? "8765"
                let path = firstNonEmpty(instance.configs["FEISHU_WEBHOOK_PATH"]) ?? "/feishu/webhook"
                return "webhook @ \(host):\(port)\(path)"
            }
            let domain = firstNonEmpty(instance.configs["FEISHU_DOMAIN"]) ?? "feishu"
            return "\(mode) · \(domain)"
        case "weixin":
            return firstNonEmpty(instance.configs["WEIXIN_BASE_URL"], instance.configs["WEIXIN_DM_POLICY"]) ?? "default"
        default:
            return descriptorTransportFallback(for: instance)
        }
    }

    private func descriptorTransportFallback(for instance: PlatformInstance) -> String {
        if let descriptor = PlatformDescriptorRegistry.descriptor(for: instance.platformID) {
            return descriptor.tokenVar
        }
        return "default"
    }

    private func stationPlatformSpotlight(_ instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> String? {
        if let errorMessage = runtimeState?.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        switch instance.platformID {
        case "email":
            if !instance.isEnabled {
                return "Email 需要 IMAP/SMTP 四件套齐全，配置好了以后再重启 gateway。"
            }
            if stationPlatformAllowlist(instance) == "not set" {
                return "建议立刻补上允许发件人列表，不然邮箱入口会过于暴露。"
            }
            if let host = instance.configs["EMAIL_IMAP_HOST"]?.lowercased(),
               (host.contains("163.com") || host.contains("188.com")) {
                let imapIDPolicy = firstNonEmpty(instance.configs["EMAIL_IMAP_SEND_ID"]) ?? "auto"
                let smtpSecurity = firstNonEmpty(instance.configs["EMAIL_SMTP_SECURITY"]) ?? "auto"
                return "163/188 已启用专项兼容参数：IMAP ID=\(imapIDPolicy)，SMTP=\(smtpSecurity)。"
            }
            return "邮箱是最容易掉线的入口之一，优先检查授权码、IMAP/SMTP 主机和 home address。"
        case "feishu":
            if !instance.isEnabled {
                return "Feishu 需要 App ID / Secret，connection mode 也要和实际部署方式一致。"
            }
            return "Feishu 出问题时，常见根因是 `lark-oapi` 缺失、App Secret 不一致，或者 websocket/webhook 模式选错。"
        case "weixin":
            return "Weixin 入口依赖账号侧稳定性，适合在这里集中看 token、home channel 和 group policy。"
        default:
            return nil
        }
    }

    private func detailRowCompact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func filePresenceBadge(_ name: String, exists: Bool) -> some View {
        statusBadge(name, color: exists ? .green : .orange)
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                continue
            }
            return trimmed
        }
        return nil
    }

    private func openPath(_ url: URL) {
        Task { _ = try? await CommandRunner.openPath(url) }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func pathRow(_ title: String, path: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Open", action: action)
            }
            Text(path)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func managementPathRow(_ title: String, _ path: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 90, alignment: .leading)
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func endpointSourceRow(_ row: EndpointSourceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(row.label)
                    .font(.system(size: 11, weight: .medium))
                statusBadge(row.isMismatch ? "mismatch" : "ok", color: row.isMismatch ? .orange : .green)
                Spacer()
            }
            Text(row.value ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(row.isMismatch ? Color.orange : Color.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = row.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background((row.isMismatch ? Color.orange : Color.secondary).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var endpointSyncTargetBaseURL: String? {
        let trimmed = hermesDraft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func syncEndpointTransparency(restartAfter: Bool) {
        guard let transparency = gatewayStore.snapshot.endpointTransparency,
              let targetBaseURL = endpointSyncTargetBaseURL else {
            return
        }
        gatewayStore.syncCredentialPoolBaseURL(
            providerID: transparency.provider,
            desiredBaseURL: targetBaseURL,
            apiKey: hermesDraft.apiKey,
            restartAfter: restartAfter
        )
    }

    private func mappingHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    private func oauthInfoBanner(authType: ProviderAuthType, forExistingProvider: Bool) -> some View {
        let (message, showOpenButton): (String, Bool) = {
            switch authType {
            case .oauth:
                return ("该 Provider 使用 OAuth 认证（如设备码登录）。你需要先在终端运行 `hermes model` 完成登录，之后回到这里点击 Import Current 导入。", true)
            case .mixed:
                return ("该 Provider 支持 OAuth 或 API Key。如果你已有 API Key，可直接填写；否则请在终端运行 `hermes model` 进行 OAuth 登录。", true)
            default:
                return ("", false)
            }
        }()

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showOpenButton {
                    Button("在终端打开 hermes model") {
                        openTerminalWithHermesModel()
                    }
                    .controlSize(.small)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationHighlightedDependencies(for card: HermesCapabilityCard) -> [HermesCapabilityDependency] {
        card.dependencies
            .sorted { lhs, rhs in
                let left = stationCapabilityDependencyRank(lhs.state)
                let right = stationCapabilityDependencyRank(rhs.state)
                if left != right {
                    return left > right
                }
                return lhs.title < rhs.title
            }
            .prefix(3)
            .map { $0 }
    }

    private func stationCapabilityDependencyRank(_ state: HermesCapabilityDependencyState) -> Int {
        switch state {
        case .blocked: return 3
        case .warning: return 2
        case .info: return 1
        case .ok: return 0
        }
    }

    private func stationCapabilityDomainColor(_ domain: HermesCapabilityDomain) -> Color {
        switch domain {
        case .identity: return .blue
        case .memory: return .purple
        case .perception: return .cyan
        case .expression: return .orange
        case .automation: return .green
        case .observability: return .pink
        }
    }

    private func stationCapabilityReadinessColor(_ readiness: HermesCapabilityReadiness) -> Color {
        switch readiness {
        case .ready: return .green
        case .partial: return .blue
        case .blocked: return .red
        case .unverified: return .secondary
        case .degraded: return .orange
        }
    }

    private func stationCapabilityDependencyColor(_ state: HermesCapabilityDependencyState) -> Color {
        switch state {
        case .ok: return .green
        case .info: return .blue
        case .warning: return .orange
        case .blocked: return .red
        }
    }

    private func stationCapabilityPrimaryActionTitle(for card: HermesCapabilityCard) -> String {
        switch card.domain {
        case .identity:
            return card.readiness == .blocked ? "Open Models" : "Open General"
        case .memory:
            return "Open Memory"
        case .perception:
            return "Open Platforms"
        case .expression:
            return "Open Models"
        case .automation:
            return "Open Cron"
        case .observability:
            if let doctorStatus = gatewayStore.snapshot.doctorReport?.status,
               doctorStatus == .needsAttention || doctorStatus == .failed {
                return "Doctor --fix"
            }
            if gatewayStore.snapshot.doctorReport == nil {
                return "Doctor --fix"
            }
            return "Open Usage"
        }
    }

    private func stationCapabilitySecondaryActionTitle(for card: HermesCapabilityCard) -> String {
        switch card.domain {
        case .identity:
            return "Open Hermes"
        case .memory:
            return "Open Skills"
        case .perception:
            return "Open Tools"
        case .expression:
            return "Open Tools"
        case .automation:
            return "Open Platforms"
        case .observability:
            return "Open Environment"
        }
    }

    private func performStationCapabilityPrimaryAction(for card: HermesCapabilityCard) {
        switch card.domain {
        case .identity:
            selectedTab = card.readiness == .blocked ? .model : .general
        case .memory:
            selectedTab = .memory
        case .perception:
            selectedTab = .platforms
        case .expression:
            selectedTab = .model
        case .automation:
            selectedTab = .cronjobs
        case .observability:
            if let doctorStatus = gatewayStore.snapshot.doctorReport?.status,
               doctorStatus == .needsAttention || doctorStatus == .failed {
                gatewayStore.runDoctorFix()
                return
            }
            if gatewayStore.snapshot.doctorReport == nil {
                gatewayStore.runDoctorFix()
                return
            }
            selectedTab = .usage
        }
    }

    private func performStationCapabilitySecondaryAction(for card: HermesCapabilityCard) {
        switch card.domain {
        case .identity:
            selectedTab = .station
        case .memory:
            selectedTab = .skills
        case .perception:
            selectedTab = .tools
        case .expression:
            selectedTab = .tools
        case .automation:
            selectedTab = .platforms
        case .observability:
            selectedTab = .environment
        }
    }

    private func performStationRecommendationAction(_ recommendation: HermesCapabilityRecommendation) {
        switch recommendation.id {
        case "baseline":
            if recommendation.actionTitle == "Open Models" {
                selectedTab = .model
            } else {
                selectedTab = .general
            }
        case "research":
            activePackSheet = .research
        case "content":
            activePackSheet = .content
        case "automation":
            if recommendation.actionTitle == "Open Platforms" {
                selectedTab = .platforms
            } else {
                selectedTab = .cronjobs
            }
        case "trust":
            gatewayStore.runDoctorFix()
        default:
            selectedTab = .station
        }
    }

    private func loadCapabilityPacks() {
        let settingsID = settingsStore.settings.id
        let currentSettings = settingsStore.settings
        let currentSkills = skillEntries
        let currentDoctor = gatewayStore.snapshot.doctorReport

        isLoadingPacks = true

        Task {
            let researchSnapshot = await HermesResearchPackPlanner.load(
                settings: currentSettings,
                skillEntries: currentSkills,
                doctorReport: currentDoctor
            )
            let contentSnapshot = await HermesContentPackPlanner.load(
                settings: currentSettings,
                skillEntries: currentSkills,
                doctorReport: currentDoctor
            )
            await MainActor.run {
                guard settingsStore.settings.id == settingsID else { return }
                researchPackSnapshot = researchSnapshot
                contentPackSnapshot = contentSnapshot
                isLoadingPacks = false
            }
        }
    }

    private func applyResearchPackSafeChanges() {
        guard let snapshot = researchPackSnapshot, !applyingPackKinds.contains(.research) else { return }
        applyPack(kind: .research) {
            try await HermesResearchPackPlanner.applySafeChanges(settings: settingsStore.settings, snapshot: snapshot)
        }
    }

    private func applyContentPackSafeChanges() {
        guard let snapshot = contentPackSnapshot, !applyingPackKinds.contains(.content) else { return }
        applyPack(kind: .content) {
            try await HermesContentPackPlanner.applySafeChanges(settings: settingsStore.settings, snapshot: snapshot)
        }
    }

    private func applyResearchPackStep(_ step: HermesResearchPackStep) {
        applyPackStep(kind: .research, step: step)
    }

    private func applyContentPackStep(_ step: HermesResearchPackStep) {
        applyPackStep(kind: .content, step: step)
    }

    private func applyPackStep(kind: HermesPackKind, step: HermesResearchPackStep) {
        guard step.canRunIndividually, !inFlightPackStepIDs.contains(step.id) else { return }
        inFlightPackStepIDs.insert(step.id)
        packMessages[kind] = nil

        Task {
            do {
                let receipt = try await HermesPackExecutor.apply(step: step, settings: settingsStore.settings)
                await MainActor.run {
                    inFlightPackStepIDs.remove(step.id)
                    packReceipts[step.id] = receipt
                    packMessages[kind] = receipt.summary
                    reloadSkillEntries()
                    gatewayStore.refresh()
                    loadCapabilityPacks()
                }
            } catch {
                await MainActor.run {
                    inFlightPackStepIDs.remove(step.id)
                    packReceipts[step.id] = HermesPackStepReceipt(
                        id: "\(step.id)-failure-\(UUID().uuidString)",
                        stepID: step.id,
                        status: .failure,
                        summary: "Failed to run \(step.title).",
                        output: error.localizedDescription,
                        ranAt: Date()
                    )
                    packMessages[kind] = "Failed to run \(step.title): \(error.localizedDescription)"
                    gatewayStore.refresh()
                    loadCapabilityPacks()
                }
            }
        }
    }

    private func applyPack(
        kind: HermesPackKind,
        task: @escaping () async throws -> [HermesPackStepReceipt]
    ) {
        guard !applyingPackKinds.contains(kind) else { return }
        applyingPackKinds.insert(kind)
        packMessages[kind] = nil

        Task {
            do {
                let receipts = try await task()
                await MainActor.run {
                    for receipt in receipts {
                        packReceipts[receipt.stepID] = receipt
                    }
                    packMessages[kind] = receipts.map(\.summary).joined(separator: "\n\n")
                    applyingPackKinds.remove(kind)
                    reloadSkillEntries()
                    gatewayStore.refresh()
                    loadCapabilityPacks()
                }
            } catch {
                await MainActor.run {
                    packMessages[kind] = "Failed to apply \(kind.title): \(error.localizedDescription)"
                    applyingPackKinds.remove(kind)
                    gatewayStore.refresh()
                    loadCapabilityPacks()
                }
            }
        }
    }

    private func skillRow(_ skill: SkillCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                skillStatusBadge(skill.isEnabled)
            }
            Text(skill.description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(skill.categoryPath)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .hoverPlate(cornerRadius: 6)
    }

    private func tokenWrap(_ values: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }

    private func skillStatusBadge(_ isEnabled: Bool) -> some View {
        statusBadge(isEnabled ? "enabled" : "disabled", color: isEnabled ? .green : .secondary)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func platformColor(_ state: String?) -> Color {
        switch state {
        case "connected": return .green
        case "disconnected": return .red
        case "connecting", "retrying": return .orange
        default: return .secondary
        }
    }

    private func providerSidebarRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16, height: 16)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .hoverPlate(cornerRadius: 6)
    }

    private func capabilityTagWrap(_ capabilities: [ModelCapability]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(capabilities) { capability in
                capabilityTag(capability)
            }
        }
    }

    private func capabilityTag(_ capability: ModelCapability) -> some View {
        Text(capability.title)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }

    private func capabilityToggle(_ capability: ModelCapability, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(capability.title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
                .hoverPlate(cornerRadius: 999)
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func usageRow(_ row: ModelUsageRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.model)
                        .font(.system(size: 13, weight: .medium))
                    Text("\(row.provider) · \(row.source)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isUsageRowCurrent(row) {
                    statusBadge("当前激活", color: .green)
                }
                if isUsageRowConfigured(row) {
                    statusBadge("已配置", color: .accentColor)
                }
            }

            HStack {
                summaryPill(title: "Sessions", value: "\(row.sessionCount)")
                summaryPill(title: "Tokens", value: compactCount(row.totalTokens))
                summaryPill(title: "Cost", value: compactCurrency(row.totalCostUSD))
            }

            Text("Last used: \(row.lastUsedText) · Tool calls: \(row.toolCallCount)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .hoverPlate(cornerRadius: 8)
    }

    @ViewBuilder
    private func validationIssueList(_ issues: [ValidationIssue]) -> some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: issue.severity.symbol)
                            .foregroundStyle(issue.severity.color)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.top, 2)
                        Text(issue.message)
                            .font(.system(size: 11))
                            .foregroundStyle(issue.severity.color)
                    }
                }
            }
        }
    }

    private func usageMetricValue(_ bucket: UsageTimeBucket) -> Double {
        switch selectedUsageMetric {
        case .sessions:
            return Double(bucket.sessionCount)
        case .tokens:
            return Double(bucket.totalTokens)
        case .cost:
            return bucket.totalCostUSD
        }
    }

    private var activeSettingsProfileID: Binding<UUID> {
        Binding(
            get: { settingsStore.activeProfileID },
            set: { settingsStore.activateProfile($0) }
        )
    }

    private var selectedModelProviderBinding: Binding<UUID?> {
        Binding(
            get: { selectedModelProviderID },
            set: { selectedModelProviderID = $0 }
        )
    }

    private var selectedModelSidebarBinding: Binding<ModelSidebarDestination?> {
        Binding(
            get: { selectedModelSidebarDestination },
            set: {
                if let value = $0 {
                    selectedModelSidebarDestination = value
                }
            }
        )
    }

    private func auxiliaryProviderBinding(for task: String) -> Binding<String> {
        Binding(
            get: { auxiliaryProviderDrafts[task] ?? "main" },
            set: { auxiliaryProviderDrafts[task] = $0 }
        )
    }

    private var selectedSkillEntryBinding: Binding<String?> {
        Binding(
            get: { selectedSkillEntryID },
            set: { selectedSkillEntryID = $0 }
        )
    }

    private var selectedMemoryEntry: MemoryCatalogEntry? {
        guard let selectedMemoryEntryID else { return filteredMemoryEntries.first }
        return filteredMemoryEntries.first(where: { $0.id == selectedMemoryEntryID }) ?? filteredMemoryEntries.first
    }

    private var selectedSkillEntry: SkillCatalogEntry? {
        guard let selectedSkillEntryID else { return filteredSkillEntries.first }
        return filteredSkillEntries.first(where: { $0.id == selectedSkillEntryID }) ?? filteredSkillEntries.first
    }

    private var memorySourceOptions: [String] {
        Array(Set(memoryEntries.map(\.source))).sorted()
    }

    private var filteredMemoryEntries: [MemoryCatalogEntry] {
        let sourceFiltered = memoryEntries.filter { entry in
            let matchesSource = memorySourceFilter == "All" || entry.source == memorySourceFilter
            return matchesSource
        }

        let query = memorySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sourceFiltered }

        return FuzzySearch.ranked(sourceFiltered, query: query) { entry in
            [entry.title, entry.preview, entry.source, entry.body]
        }
    }

    private var filteredSkillEntries: [SkillCatalogEntry] {
        skillEntries.filter { skill in
            let matchesFilter: Bool
            switch skillFilter {
            case .all:
                matchesFilter = true
            case .enabled:
                matchesFilter = skill.isEnabled
            case .disabled:
                matchesFilter = !skill.isEnabled
            }
            guard matchesFilter else { return false }

            let query = skillSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }

            let needle = query.lowercased()
            return skill.name.lowercased().contains(needle)
                || skill.description.lowercased().contains(needle)
                || skill.identifier.lowercased().contains(needle)
                || skill.categoryPath.lowercased().contains(needle)
                || skill.tags.contains(where: { $0.lowercased().contains(needle) })
        }
    }

    private var enabledSkillCount: Int {
        skillEntries.filter(\.isEnabled).count
    }

    private var skillCategoryCount: Int {
        Set(skillEntries.map(\.categoryPath)).count
    }

    private var currentHermesProviderDescriptor: HermesProviderDescriptor? {
        HermesProviderDescriptor.resolve(hermesDraft.provider)
    }

    private var providerPresetOptions: [ProviderPresetOption] {
        HermesProviderDescriptor.knownProviders.map {
            ProviderPresetOption(id: $0.id, label: $0.displayName)
        }
    }

    private var auxiliaryProviderOptions: [AuxiliaryProviderOption] {
        var options: [AuxiliaryProviderOption] = [
            .init(id: "main", label: "main · 跟随主模型"),
            .init(id: "auto", label: "auto · Hermes 自动解析")
        ]

        let savedProviderOptions = appDraft.modelProviders.map { provider in
            AuxiliaryProviderOption(
                id: provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines),
                label: provider.displayName.isEmpty ? provider.providerID : "\(provider.displayName) · \(provider.providerID)"
            )
        }.filter { !$0.id.isEmpty }

        for option in savedProviderOptions {
            if !options.contains(option) {
                options.append(option)
            }
        }

        for descriptor in HermesProviderDescriptor.knownProviders {
            let option = AuxiliaryProviderOption(id: descriptor.id, label: descriptor.displayName)
            if !options.contains(where: { $0.id == option.id }) {
                options.append(option)
            }
        }

        return options
    }

    private var selectedModelProviderIndex: Int? {
        guard let selectedModelProviderID else { return appDraft.modelProviders.isEmpty ? nil : 0 }
        return appDraft.modelProviders.firstIndex(where: { $0.id == selectedModelProviderID }) ?? (appDraft.modelProviders.isEmpty ? nil : 0)
    }

    private var selectedModelProvider: SavedProviderConnection {
        guard let index = selectedModelProviderIndex else { return .blank() }
        return appDraft.modelProviders[index]
    }

    private var selectedModelProviderDescriptor: HermesProviderDescriptor? {
        HermesProviderDescriptor.resolve(selectedModelProvider.providerID)
    }

    private var newProviderDescriptor: HermesProviderDescriptor? {
        HermesProviderDescriptor.resolve(newProviderDraft.providerID)
    }

    private var selectedSavedModelIndex: Int? {
        guard let providerIndex = selectedModelProviderIndex else { return nil }
        let models = appDraft.modelProviders[providerIndex].models
        guard let selectedSavedModelID else { return models.isEmpty ? nil : 0 }
        return models.firstIndex(where: { $0.id == selectedSavedModelID }) ?? (models.isEmpty ? nil : 0)
    }

    private var selectedSavedModel: SavedModelEntry {
        guard let providerIndex = selectedModelProviderIndex, let modelIndex = selectedSavedModelIndex else { return .blank() }
        return appDraft.modelProviders[providerIndex].models[modelIndex]
    }

    private var selectedProviderValidationIssues: [ValidationIssue] {
        validateProviderConnection(selectedModelProvider)
    }

    private var selectedModelValidationIssues: [ValidationIssue] {
        validateModelEntry(selectedSavedModel, on: selectedModelProvider)
    }

    private var newProviderValidationIssues: [ValidationIssue] {
        validateProviderConnection(newProviderDraft)
    }

    private var newProviderModelValidationIssues: [ValidationIssue] {
        guard let modelIndex = newProviderSelectedModelIndex else { return [] }
        return validateModelEntry(newProviderDraft.models[modelIndex], on: newProviderDraft)
    }

    private var selectedUsageTotals: UsageTotals {
        switch selectedUsageWindow {
        case .last24Hours:
            return gatewayStore.snapshot.usage.last24Hours
        case .last7Days:
            return gatewayStore.snapshot.usage.last7Days
        case .allTime:
            return gatewayStore.snapshot.usage.allTime
        }
    }

    private var selectedUsageRows: [ModelUsageRow] {
        switch selectedUsageWindow {
        case .last24Hours:
            return gatewayStore.snapshot.usage.last24HourRows
        case .last7Days:
            return gatewayStore.snapshot.usage.last7DayRows
        case .allTime:
            return gatewayStore.snapshot.usage.allTimeRows
        }
    }

    private var selectedUsageBuckets: [UsageTimeBucket] {
        switch selectedUsageWindow {
        case .last24Hours:
            return gatewayStore.snapshot.usage.last24HourBuckets
        case .last7Days:
            return gatewayStore.snapshot.usage.last7DayBuckets
        case .allTime:
            return gatewayStore.snapshot.usage.allTimeBuckets
        }
    }

    private var usageAxisFormat: Date.FormatStyle {
        switch selectedUsageWindow {
        case .last24Hours:
            return .dateTime.hour()
        case .last7Days:
            return .dateTime.month(.abbreviated).day()
        case .allTime:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private var providerDisplayNameBinding: Binding<String> {
        Binding(
            get: { selectedModelProvider.displayName },
            set: { newValue in
                guard let index = selectedModelProviderIndex else { return }
                appDraft.modelProviders[index].displayName = newValue
            }
        )
    }

    private var newProviderDisplayNameBinding: Binding<String> {
        Binding(
            get: { newProviderDraft.displayName },
            set: { newProviderDraft.displayName = $0 }
        )
    }

    private var providerIDBinding: Binding<String> {
        Binding(
            get: { selectedModelProvider.providerID },
            set: { newValue in
                guard let index = selectedModelProviderIndex else { return }
                appDraft.modelProviders[index].providerID = newValue
            }
        )
    }

    private var newProviderIDBinding: Binding<String> {
        Binding(
            get: { newProviderDraft.providerID },
            set: { newProviderDraft.providerID = $0 }
        )
    }

    private var providerBaseURLBinding: Binding<String> {
        Binding(
            get: { selectedModelProvider.baseURL },
            set: { newValue in
                guard let index = selectedModelProviderIndex else { return }
                appDraft.modelProviders[index].baseURL = newValue
            }
        )
    }

    private var newProviderBaseURLBinding: Binding<String> {
        Binding(
            get: { newProviderDraft.baseURL },
            set: { newProviderDraft.baseURL = $0 }
        )
    }

    private var providerAPIKeyBinding: Binding<String> {
        Binding(
            get: { selectedModelProvider.apiKey },
            set: { newValue in
                guard let index = selectedModelProviderIndex else { return }
                appDraft.modelProviders[index].apiKey = newValue
            }
        )
    }

    private var newProviderAPIKeyBinding: Binding<String> {
        Binding(
            get: { newProviderDraft.apiKey },
            set: { newProviderDraft.apiKey = $0 }
        )
    }

    private var providerEnabledBinding: Binding<Bool> {
        Binding(
            get: { selectedModelProvider.isEnabled },
            set: { newValue in
                guard let index = selectedModelProviderIndex else { return }
                appDraft.modelProviders[index].isEnabled = newValue
            }
        )
    }

    private var newProviderEnabledBinding: Binding<Bool> {
        Binding(
            get: { newProviderDraft.isEnabled },
            set: { newProviderDraft.isEnabled = $0 }
        )
    }

    private func modelDisplayNameBinding(providerIndex: Int, modelIndex: Int) -> Binding<String> {
        Binding(
            get: { appDraft.modelProviders[providerIndex].models[modelIndex].displayName },
            set: { appDraft.modelProviders[providerIndex].models[modelIndex].displayName = $0 }
        )
    }

    private func modelNameBinding(providerIndex: Int, modelIndex: Int) -> Binding<String> {
        Binding(
            get: { appDraft.modelProviders[providerIndex].models[modelIndex].modelName },
            set: { appDraft.modelProviders[providerIndex].models[modelIndex].modelName = $0 }
        )
    }

    private func modelEnabledBinding(providerIndex: Int, modelIndex: Int) -> Binding<Bool> {
        Binding(
            get: { appDraft.modelProviders[providerIndex].models[modelIndex].isEnabled },
            set: { appDraft.modelProviders[providerIndex].models[modelIndex].isEnabled = $0 }
        )
    }

    private var newProviderSelectedModelBinding: Binding<UUID?> {
        Binding(
            get: { newProviderSelectedModelID },
            set: { newProviderSelectedModelID = $0 }
        )
    }

    private var newProviderSelectedModelIndex: Int? {
        guard let newProviderSelectedModelID else { return newProviderDraft.models.isEmpty ? nil : 0 }
        return newProviderDraft.models.firstIndex(where: { $0.id == newProviderSelectedModelID }) ?? (newProviderDraft.models.isEmpty ? nil : 0)
    }

    private func newProviderModelDisplayNameBinding(modelIndex: Int) -> Binding<String> {
        Binding(
            get: { newProviderDraft.models[modelIndex].displayName },
            set: { newProviderDraft.models[modelIndex].displayName = $0 }
        )
    }

    private func newProviderModelNameBinding(modelIndex: Int) -> Binding<String> {
        Binding(
            get: { newProviderDraft.models[modelIndex].modelName },
            set: { newProviderDraft.models[modelIndex].modelName = $0 }
        )
    }

    private func newProviderModelEnabledBinding(modelIndex: Int) -> Binding<Bool> {
        Binding(
            get: { newProviderDraft.models[modelIndex].isEnabled },
            set: { newProviderDraft.models[modelIndex].isEnabled = $0 }
        )
    }

    private var filteredAgents: [AgentSessionRow] {
        let baseRows = gatewayStore.snapshot.agentSessions.rows.filter { agent in
            let matchesFilter: Bool
            switch agentFilter {
            case .all:
                matchesFilter = true
            case .running:
                matchesFilter = agent.isActive
            case .completed:
                matchesFilter = !agent.isActive
            }

            return matchesFilter
        }

        let query = agentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return baseRows }

        return FuzzySearch.ranked(baseRows, query: query) { agent in
            agentSearchFields(agent)
        }
    }

    private var filteredBoundAgents: [AgentSessionRow] {
        filteredAgents.filter { bindingEntry(for: $0) != nil }
    }

    private var filteredUnboundAgents: [AgentSessionRow] {
        filteredAgents.filter { bindingEntry(for: $0) == nil }
    }

    private var selectedAgent: AgentSessionRow? {
        guard let selectedAgentID else { return filteredAgents.first }
        return filteredAgents.first(where: { $0.id == selectedAgentID }) ?? filteredAgents.first
    }

    private var selectedAgentBindingEntry: SessionBindingEntry? {
        guard let selectedAgent else { return nil }
        return bindingEntry(for: selectedAgent)
    }

    private func bindingEntry(for agent: AgentSessionRow) -> SessionBindingEntry? {
        gatewayStore.snapshot.bindingEntry(for: agent.id)
    }

    private func agentSearchFields(_ agent: AgentSessionRow) -> [String] {
        [
            agent.title,
            agent.id,
            agent.source,
            agent.model,
            agentTranscriptSearchTextByID[agent.id] ?? "",
        ]
    }

    private var canSaveHermes: Bool {
        !profileStore.isSaving
            && !hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (hermesDraft.provider == "custom" || currentHermesProviderDescriptor != nil)
    }

    private var activeProviderTitle: String {
        if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: hermesDraft.provider, baseURL: hermesDraft.baseURL) {
            return "Kimi Coding Plan"
        }
        return currentHermesProviderDescriptor?.displayName ?? "手动 Provider"
    }

    private var activeProviderSubtitle: String {
        let providerID = hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerID.isEmpty {
            return "还没有设置 provider ID。"
        }
        if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: providerID, baseURL: hermesDraft.baseURL) {
            return "anthropic · 通过 https://api.kimi.com/coding/ 接入 Coding Plan"
        }
        return currentHermesProviderDescriptor == nil ? providerID : "\(providerID) · 已接入 menubar 映射"
    }

    private var canAdoptOfficialKimiCodingPlanRoute: Bool {
        if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: hermesDraft.provider, baseURL: hermesDraft.baseURL) {
            return false
        }

        let providerID = hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseURL = hermesDraft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modelName = hermesDraft.modelName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let apiKey = hermesDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let looksLikeKimiCoding = providerID == "kimi-coding"
            || baseURL.contains("api.kimi.com/coding")
            || modelName == "kimi-for-coding"
            || apiKey.hasPrefix("sk-kimi-")

        return looksLikeKimiCoding
    }

    private func isLikelyKimiCodingPlanError(_ dump: LatestRequestDumpSnapshot) -> Bool {
        let haystack = [
            dump.requestURL ?? "",
            dump.requestBaseURL ?? "",
            dump.model ?? "",
            dump.errorMessage ?? "",
            hermesDraft.provider,
            hermesDraft.baseURL
        ]
        .joined(separator: "\n")
        .lowercased()

        return haystack.contains("api.kimi.com/coding")
            || haystack.contains("kimi-for-coding")
            || haystack.contains("only 0.6 is allowed")
            || haystack.contains("resource_not_found_error")
    }

    private func openKimiCodingPlanDocs() {
        Task {
            _ = try? await CommandRunner.openLocation(kimiCodingPlanDocsURL)
        }
    }

    private func syncDrafts() {
        appDraft = settingsStore.settings
        hermesDraft = profileStore.snapshot.draft
        auxiliaryProviderDrafts = Dictionary(uniqueKeysWithValues: profileStore.snapshot.routing.auxiliaryRoutes.map { ($0.task, $0.provider) })
        syncSmartRoutingDrafts(from: profileStore.snapshot.routing)
        syncModelSelection()
        syncAgentSelection()
    }

    private func syncSmartRoutingDrafts(from routing: HermesRoutingSummary) {
        smartRoutingEnabledDraft = routing.smartRoutingEnabled
        smartRoutingProviderDraft = routing.smartRoutingTargetProvider.isEmpty ? "main" : routing.smartRoutingTargetProvider
        smartRoutingModelDraft = routing.smartRoutingTargetModel
        smartRoutingMaxSimpleCharsDraft = "\(routing.smartRoutingMaxSimpleChars)"
        smartRoutingMaxSimpleWordsDraft = "\(routing.smartRoutingMaxSimpleWords)"
    }

    private var canSaveSmartRouting: Bool {
        if !smartRoutingEnabledDraft {
            return true
        }
        return !smartRoutingProviderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !smartRoutingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Int(smartRoutingMaxSimpleCharsDraft) ?? 0) > 0
            && (Int(smartRoutingMaxSimpleWordsDraft) ?? 0) > 0
    }

    private func syncModelSelection() {
        switch selectedModelSidebarDestination {
        case .provider(let id):
            if appDraft.modelProviders.contains(where: { $0.id == id }) {
                selectedModelProviderID = id
                syncSelectedSavedModel()
                return
            }
            if let firstID = appDraft.modelProviders.first?.id {
                selectedModelProviderID = firstID
                selectedModelSidebarDestination = .provider(firstID)
            } else {
                selectedModelProviderID = nil
                selectedModelSidebarDestination = .current
            }
            syncSelectedSavedModel()

        case .current, .routing, .health:
            if let selectedModelProviderID, appDraft.modelProviders.contains(where: { $0.id == selectedModelProviderID }) {
                syncSelectedSavedModel()
            } else {
                selectedModelProviderID = appDraft.modelProviders.first?.id
                syncSelectedSavedModel()
            }
        }
    }

    private func syncSelectedSavedModel() {
        guard let providerIndex = selectedModelProviderIndex else {
            selectedSavedModelID = nil
            return
        }
        let models = appDraft.modelProviders[providerIndex].models
        if let selectedSavedModelID, models.contains(where: { $0.id == selectedSavedModelID }) {
            return
        }
        selectedSavedModelID = models.first?.id
    }

    private func openAddAPIWizard() {
        newProviderDraft = SavedProviderConnection.blank(name: "Provider \(appDraft.modelProviders.count + 1)")
        newProviderSelectedModelID = newProviderDraft.models.first?.id
        newProviderPresetID = "custom"
        addAPIWizardPage = .connection
        showAddAPIWizard = true
    }

    private func removeSelectedModelProvider() {
        guard let providerIndex = selectedModelProviderIndex else { return }
        appDraft.modelProviders.remove(at: providerIndex)
        selectedModelProviderID = appDraft.modelProviders.first?.id
        syncSelectedSavedModel()
        settingsStore.update(appDraft.normalized)
    }

    private func addModelToSelectedProvider() {
        guard let providerIndex = selectedModelProviderIndex else { return }
        let model = SavedModelEntry.blank(name: "Model \(appDraft.modelProviders[providerIndex].models.count + 1)")
        appDraft.modelProviders[providerIndex].models.append(model)
        selectedSavedModelID = model.id
    }

    private func removeSelectedSavedModel() {
        guard let providerIndex = selectedModelProviderIndex, let modelIndex = selectedSavedModelIndex else { return }
        appDraft.modelProviders[providerIndex].models.remove(at: modelIndex)
        selectedSavedModelID = appDraft.modelProviders[providerIndex].models.first?.id
    }

    private func addModelToNewProviderDraft() {
        let model = SavedModelEntry.blank(name: "Model \(newProviderDraft.models.count + 1)")
        newProviderDraft.models.append(model)
        newProviderSelectedModelID = model.id
    }

    private func removeSelectedDraftModel() {
        guard let index = newProviderSelectedModelIndex else { return }
        newProviderDraft.models.remove(at: index)
        if newProviderDraft.models.isEmpty {
            let fallback = SavedModelEntry.blank()
            newProviderDraft.models = [fallback]
            newProviderSelectedModelID = fallback.id
        } else {
            newProviderSelectedModelID = newProviderDraft.models.first?.id
        }
    }

    private func commitNewProviderDraft() {
        let normalizedProvider = normalizedDraftProvider(newProviderDraft)
        appDraft.modelProviders.append(normalizedProvider)
        let normalizedSettings = appDraft.normalized
        appDraft = normalizedSettings
        settingsStore.update(normalizedSettings)
        selectedModelProviderID = normalizedProvider.id
        selectedModelSidebarDestination = .provider(normalizedProvider.id)
        selectedSavedModelID = normalizedProvider.models.first?.id
        showAddAPIWizard = false
    }

    private func applyProviderPreset(_ presetID: String) {
        guard let descriptor = HermesProviderDescriptor.resolve(presetID) else { return }
        newProviderDraft.providerID = descriptor.id

        let trimmedName = newProviderDraft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName.hasPrefix("Provider ") || HermesProviderDescriptor.resolve(trimmedName) != nil {
            newProviderDraft.displayName = descriptor.displayName
        }

        if descriptor.authType == .oauth {
            newProviderDraft.baseURL = ""
            newProviderDraft.apiKey = ""
        }
    }

    private func openTerminalWithHermesModel() {
        let launcherPath = appDraft.launcherPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = launcherPath.isEmpty ? "hermes model" : "\(launcherPath) model"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(escaped)\""
        Task {
            _ = try? await CommandRunner.run("/usr/bin/osascript", ["-e", script])
        }
    }

    private func importCurrentHermesModel() {
        let providerID = hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = hermesDraft.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerID.isEmpty, !modelName.isEmpty else { return }

        let importedDisplayName: String
        if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: providerID, baseURL: hermesDraft.baseURL) {
            importedDisplayName = "Kimi Coding Plan (Anthropic-compatible)"
        } else {
            importedDisplayName = currentHermesProviderDescriptor?.displayName ?? providerID
        }

        if let existingProviderIndex = appDraft.modelProviders.firstIndex(where: {
            $0.providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == providerID.lowercased()
            && $0.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) == hermesDraft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }) {
            if !appDraft.modelProviders[existingProviderIndex].models.contains(where: { $0.modelName == modelName }) {
                let model = SavedModelEntry(
                    id: UUID(),
                    displayName: modelName,
                    modelName: modelName,
                    isEnabled: true,
                    capabilities: [.chat]
                )
                appDraft.modelProviders[existingProviderIndex].models.append(model)
                selectedSavedModelID = model.id
            }
            selectedModelProviderID = appDraft.modelProviders[existingProviderIndex].id
            selectedModelSidebarDestination = .provider(appDraft.modelProviders[existingProviderIndex].id)
            settingsStore.update(appDraft.normalized)
            return
        }

        let provider = SavedProviderConnection(
            id: UUID(),
            displayName: importedDisplayName,
            providerID: providerID,
            baseURL: hermesDraft.baseURL,
            apiKey: hermesDraft.apiKey,
            isEnabled: true,
            models: [
                SavedModelEntry(
                    id: UUID(),
                    displayName: modelName,
                    modelName: modelName,
                    isEnabled: true,
                    capabilities: [.chat]
                )
            ]
        )
        appDraft.modelProviders.append(provider)
        selectedModelProviderID = provider.id
        selectedModelSidebarDestination = .provider(provider.id)
        selectedSavedModelID = provider.models.first?.id
        settingsStore.update(appDraft.normalized)
    }

    private func activateSelectedSavedModel() {
        guard let providerIndex = selectedModelProviderIndex, let modelIndex = selectedSavedModelIndex else { return }
        let normalizedDraft = appDraft.normalized
        appDraft = normalizedDraft
        settingsStore.update(normalizedDraft)
        profileStore.activate(provider: normalizedDraft.modelProviders[providerIndex], model: normalizedDraft.modelProviders[providerIndex].models[modelIndex])
    }

    private var canActivateSelectedSavedModel: Bool {
        selectedModelProviderIndex != nil
            && selectedSavedModelIndex != nil
            && isModelAvailable(selectedModelProvider, selectedSavedModel)
            && !selectedProviderValidationIssues.contains(where: { $0.severity == .error })
            && !selectedModelValidationIssues.contains(where: { $0.severity == .error })
            && !profileStore.isSaving
    }

    private func toggleCapability(_ capability: ModelCapability, providerIndex: Int, modelIndex: Int) {
        if appDraft.modelProviders[providerIndex].models[modelIndex].capabilities.contains(capability) {
            appDraft.modelProviders[providerIndex].models[modelIndex].capabilities.removeAll { $0 == capability }
            if appDraft.modelProviders[providerIndex].models[modelIndex].capabilities.isEmpty {
                appDraft.modelProviders[providerIndex].models[modelIndex].capabilities = [.chat]
            }
        } else {
            appDraft.modelProviders[providerIndex].models[modelIndex].capabilities.append(capability)
        }
    }

    private func toggleDraftModelCapability(_ capability: ModelCapability, modelIndex: Int) {
        if newProviderDraft.models[modelIndex].capabilities.contains(capability) {
            newProviderDraft.models[modelIndex].capabilities.removeAll { $0 == capability }
            if newProviderDraft.models[modelIndex].capabilities.isEmpty {
                newProviderDraft.models[modelIndex].capabilities = [.chat]
            }
        } else {
            newProviderDraft.models[modelIndex].capabilities.append(capability)
        }
    }

    private func isProviderActive(_ provider: SavedProviderConnection) -> Bool {
        let providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentProviderID = hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard providerID == currentProviderID else { return false }
        let providerBaseURL = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentBaseURL = hermesDraft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return providerBaseURL == currentBaseURL || providerBaseURL.isEmpty || currentBaseURL.isEmpty
    }

    private func isUsageRowCurrent(_ row: ModelUsageRow) -> Bool {
        row.model == hermesDraft.modelName
            && row.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isUsageRowConfigured(_ row: ModelUsageRow) -> Bool {
        appDraft.modelProviders.contains { provider in
            provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == row.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            && provider.models.contains(where: { $0.modelName == row.model })
        }
    }

    private func isProviderAvailable(_ provider: SavedProviderConnection) -> Bool {
        guard provider.isEnabled else { return false }
        let providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerID.isEmpty else { return false }
        if providerID.lowercased() == "custom" {
            return !provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let descriptor = HermesProviderDescriptor.resolve(providerID) else { return false }
        if descriptor.primaryAPIKeyEnvVar != nil {
            return !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func isModelActive(_ provider: SavedProviderConnection, _ model: SavedModelEntry) -> Bool {
        isProviderActive(provider)
            && model.modelName.trimmingCharacters(in: .whitespacesAndNewlines) == hermesDraft.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isModelAvailable(_ provider: SavedProviderConnection, _ model: SavedModelEntry) -> Bool {
        provider.isEnabled
            && model.isEnabled
            && isProviderAvailable(provider)
            && !model.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func providerAvailabilityMessage(_ provider: SavedProviderConnection) -> String {
        if isProviderAvailable(provider) {
            return "连接可用。这个 API 下面的已启用模型都可以被激活。"
        }
        let providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerID.isEmpty {
            return "缺少 provider ID。"
        }
        if providerID.lowercased() == "custom" {
            return "Custom provider 需要同时配置 Base URL 和 API Key。"
        }
        if HermesProviderDescriptor.resolve(providerID) == nil {
            return "这个 provider 还没有在 menubar 里做映射，因此会显示为不可用。"
        }
        return "这个 provider 缺少启用它所需的连接信息。"
    }

    private func modelAvailabilityMessage(_ provider: SavedProviderConnection, _ model: SavedModelEntry) -> String {
        if isModelAvailable(provider, model) {
            return "模型条目可用。点击 “Activate Model In Hermes” 会立即切换当前生效模型。"
        }
        if model.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "缺少 Model ID。"
        }
        if !provider.isEnabled || !model.isEnabled {
            return "Provider 或模型条目已被禁用。"
        }
        return providerAvailabilityMessage(provider)
    }

    private func modelProviderSidebarSubtitle(_ provider: SavedProviderConnection) -> String {
        let activeText = isProviderActive(provider) ? "激活" : "未激活"
        let availableText = isProviderAvailable(provider) ? "可用" : "不可用"
        return "\(provider.providerID) · \(provider.models.count) models · \(activeText)/\(availableText)"
    }

    private var routingSidebarSubtitle: String {
        let auxCount = profileStore.snapshot.routing.auxiliaryRoutes.count
        let smart = profileStore.snapshot.routing.smartRoutingEnabled ? "smart on" : "smart off"
        return "\(auxCount) auxiliary · \(smart)"
    }

    private func validateProviderConnection(_ provider: SavedProviderConnection) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if providerID.isEmpty {
            issues.append(.init(severity: .error, message: "Provider ID 不能为空。"))
            return issues
        }

        if let canonical = HermesProviderDescriptor.suggestedCanonicalID(for: providerID),
           canonical != providerID.lowercased() {
            issues.append(.init(severity: .warning, message: "建议把 Provider ID 改成 `\(canonical)`，当前写法会被自动当作别名处理。"))
        }

        let resolved = HermesProviderDescriptor.resolve(providerID)
        if resolved == nil {
            issues.append(.init(severity: .error, message: "Provider ID 未映射。若你接的是 OpenAI-compatible / 自建网关，请直接填 `custom`。"))
        }

        if !baseURL.isEmpty && !looksLikeHTTPURL(baseURL) {
            issues.append(.init(severity: .error, message: "Base URL 不是合法的 http/https 地址。"))
        }

        if SavedProviderConnection.isKimiCodingPlanAnthropicRoute(providerID: providerID, baseURL: baseURL) {
            issues.append(.init(severity: .warning, message: "检测到 Kimi Coding Plan 官方兼容接法：`provider=anthropic` + `https://api.kimi.com/coding/`。Hermes 里这条链路比 OpenAI-compatible `/coding/v1` 更稳。"))
        } else if HermesProviderDescriptor.resolve(providerID)?.id == "kimi-coding",
                  baseURL.lowercased().contains("api.kimi.com/coding/v1") {
            issues.append(.init(severity: .warning, message: "当前是 Kimi Coding Plan 的 OpenAI-compatible `/coding/v1` 路由。若遇到 temperature / tool-calling 报错，建议切到 `provider=anthropic` + `https://api.kimi.com/coding/`。"))
        } else if SavedProviderConnection.hasKimiCodingV1Issue(providerID: providerID, baseURL: baseURL) {
            issues.append(.init(severity: .warning, message: "Kimi OpenAI-compatible endpoint 会自动补成 `https://api.kimi.com/coding/v1`。"))
        }

        let authType = resolved?.authType ?? .apiKey

        if resolved?.id == "custom" {
            if baseURL.isEmpty {
                issues.append(.init(severity: .error, message: "Custom provider 必须填写 Base URL。"))
            }
            if apiKey.isEmpty {
                issues.append(.init(severity: .error, message: "Custom provider 必须填写 API Key。"))
            }
        } else if authType == .apiKey, let resolved, resolved.primaryAPIKeyEnvVar != nil, apiKey.isEmpty {
            issues.append(.init(severity: .error, message: "\(resolved.displayName) 需要 API Key。"))
        }

        if !apiKey.isEmpty {
            if apiKey.contains(" ") {
                issues.append(.init(severity: .warning, message: "API Key 包含空格，通常这意味着粘贴有误。"))
            }
            if apiKey.count < 10 {
                issues.append(.init(severity: .warning, message: "API Key 看起来过短，建议再核对一次。"))
            }
        }

        return issues
    }

    private func validateModelEntry(_ model: SavedModelEntry, on provider: SavedProviderConnection) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let modelName = model.modelName.trimmingCharacters(in: .whitespacesAndNewlines)

        if modelName.isEmpty {
            issues.append(.init(severity: .error, message: "Model ID 不能为空。"))
        } else if modelName.contains(" ") {
            issues.append(.init(severity: .warning, message: "Model ID 包含空格，很多 provider 不接受这种写法，建议核对。"))
        }

        let unsupported = unsupportedCapabilities(for: provider, model: model)
        if !unsupported.isEmpty {
            let labels = unsupported.map(\.title).joined(separator: " / ")
            issues.append(.init(severity: .warning, message: "当前 provider 没有验证支持这些能力：\(labels)。"))
        }

        let informational = unverifiableCapabilities(for: model)
        if !informational.isEmpty {
            let labels = informational.map(\.title).joined(separator: " / ")
            issues.append(.init(severity: .warning, message: "这些能力目前只作为本地标签，不会被 Hermes 主动校验：\(labels)。"))
        }

        return issues
    }

    private func unsupportedCapabilities(for provider: SavedProviderConnection, model: SavedModelEntry) -> [ModelCapability] {
        let providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let verified: Set<ModelCapability>
        switch HermesProviderDescriptor.resolve(providerID)?.id {
        case "custom", "openrouter", "gemini", "anthropic", "zai", "xai", "openai-codex":
            verified = [.chat, .coding, .reasoning, .tools, .vision]
        case "minimax", "minimax-cn", "alibaba", "kimi-coding", "huggingface", "ai-gateway", "opencode-zen", "opencode-go", "kilocode", "xiaomi", "nous", "qwen-oauth", "copilot", "copilot-acp":
            verified = [.chat, .coding, .reasoning, .tools]
        default:
            verified = []
        }
        return model.capabilities.filter { !verified.contains($0) && $0 != .image && $0 != .audio && $0 != .web }
    }

    private func unverifiableCapabilities(for model: SavedModelEntry) -> [ModelCapability] {
        model.capabilities.filter { $0 == .web || $0 == .image || $0 == .audio }
    }

    private func looksLikeHTTPURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    private func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func compactCurrency(_ value: Double) -> String {
        if value <= 0 {
            return "$0"
        }
        if value < 0.01 {
            return String(format: "$%.3f", value)
        }
        if value < 1 {
            return String(format: "$%.2f", value)
        }
        return String(format: "$%.1f", value)
    }

    private var canAdvanceAddAPIWizard: Bool {
        !newProviderValidationIssues.contains(where: { $0.severity == .error })
    }

    private var canCreateNewProvider: Bool {
        canAdvanceAddAPIWizard && !newProviderModelValidationIssues.contains(where: { $0.severity == .error })
    }

    private var newProviderAvailabilityMessage: String {
        if !canAdvanceAddAPIWizard {
            return "至少要填写 Provider ID；Custom 还需要 Base URL 和 API Key。"
        }
        switch newProviderDescriptor?.authType {
        case .oauth:
            return "该 Provider 通过 OAuth 认证，不需要 API Key。继续下一页配置模型。"
        case .mixed:
            return "该 Provider 支持 OAuth 或 API Key。如未配置 OAuth，请填写 API Key。"
        default:
            return "连接信息足够，继续下一页配置模型。"
        }
    }

    private var newProviderModelMessage: String {
        if canCreateNewProvider {
            return "至少有一个模型具备 Model ID，可以创建 API 条目。"
        }
        return "至少填写一个模型的 Model ID。"
    }

    private func normalizedDraftProvider(_ provider: SavedProviderConnection) -> SavedProviderConnection {
        var normalized = provider
        normalized.displayName = provider.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.baseURL = SavedProviderConnection.normalizedBaseURL(
            providerID: normalized.providerID,
            baseURL: provider.baseURL
        )
        normalized.apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.displayName.isEmpty {
            normalized.displayName = normalized.providerID.isEmpty ? "Provider" : normalized.providerID
        }
        normalized.models = provider.models.map { model in
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
        if normalized.models.isEmpty {
            normalized.models = [SavedModelEntry.blank()]
        }
        return normalized
    }

    private func syncAgentSelection() {
        let rows = filteredAgents
        if let selectedAgentID, rows.contains(where: { $0.id == selectedAgentID }) {
            if let current = rows.first(where: { $0.id == selectedAgentID }) {
                agentRenameDraft = current.title
            }
            return
        }
        selectedAgentID = rows.first?.id
        agentRenameDraft = rows.first?.title ?? ""
        if rows.isEmpty {
            selectedAgentTranscript = nil
        }
    }

    private func reloadKnowledgeCatalogs() {
        reloadMemoryEntries()
        reloadSkillEntries()
    }

    private func reloadAgentSearchIndex() {
        let settingsID = settingsStore.settings.id
        let agents = gatewayStore.snapshot.agentSessions.rows
        let agentIDs = agents.map(\.id)
        let currentIDSet = Set(agentIDs)

        agentTranscriptSearchTextByID = agentTranscriptSearchTextByID.filter { currentIDSet.contains($0.key) }

        guard !agents.isEmpty else {
            isLoadingAgentSearchIndex = false
            syncAgentSelection()
            return
        }

        isLoadingAgentSearchIndex = true

        Task(priority: .utility) {
            var index: [String: String] = [:]

            for agent in agents {
                guard let transcript = SessionTranscriptLoader.load(from: agent.transcriptURL) else {
                    continue
                }

                let searchableText = transcript.searchableText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !searchableText.isEmpty else { continue }
                index[agent.id] = searchableText
            }

            await MainActor.run {
                guard settingsStore.settings.id == settingsID else { return }
                guard gatewayStore.snapshot.agentSessions.rows.map(\.id) == agentIDs else { return }

                agentTranscriptSearchTextByID = index
                isLoadingAgentSearchIndex = false
                syncAgentSelection()
            }
        }
    }

    private func reloadMemoryEntries() {
        let settingsID = settingsStore.settings.id
        let hermesHome = HermesPaths(settings: settingsStore.settings).hermesHome
        isLoadingMemoryEntries = true

        Task(priority: .utility) {
            let entries = HermesKnowledgeCatalog.loadMemoryEntries(from: hermesHome)
            await MainActor.run {
                guard settingsStore.settings.id == settingsID else { return }
                memoryEntries = entries
                isLoadingMemoryEntries = false
                syncMemorySelection()
            }
        }
    }

    private func reloadSkillEntries() {
        let settingsID = settingsStore.settings.id
        let hermesHome = HermesPaths(settings: settingsStore.settings).hermesHome
        isLoadingSkillEntries = true

        Task(priority: .utility) {
            let entries = HermesKnowledgeCatalog.loadSkills(from: hermesHome)
            await MainActor.run {
                guard settingsStore.settings.id == settingsID else { return }
                skillEntries = entries
                isLoadingSkillEntries = false
                syncSkillSelection()
            }
        }
    }

    private func syncMemorySelection() {
        if memorySourceFilter != "All", !memorySourceOptions.contains(memorySourceFilter) {
            memorySourceFilter = "All"
        }

        if let selectedMemoryEntryID, filteredMemoryEntries.contains(where: { $0.id == selectedMemoryEntryID }) {
            return
        }

        selectedMemoryEntryID = filteredMemoryEntries.first?.id
    }

    private func syncSkillSelection() {
        if let selectedSkillEntryID, filteredSkillEntries.contains(where: { $0.id == selectedSkillEntryID }) {
            return
        }

        selectedSkillEntryID = filteredSkillEntries.first?.id
    }

    private func toggleSkill(_ skill: SkillCatalogEntry) {
        let action = skill.isEnabled ? "disable" : "enable"
        isPerformingSkillAction = true
        skillActionMessage = nil

        Task {
            do {
                let result = try await CommandRunner.runHermes(settingsStore.settings, ["skills", action, skill.identifier])
                await MainActor.run {
                    let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if output.isEmpty {
                        skillActionMessage = "\(skill.name) \(skill.isEnabled ? "disabled" : "enabled")."
                    } else {
                        skillActionMessage = output
                    }
                    isPerformingSkillAction = false
                    reloadSkillEntries()
                }
            } catch {
                await MainActor.run {
                    skillActionMessage = error.localizedDescription
                    isPerformingSkillAction = false
                }
            }
        }
    }

    private func formatMemoryTimestamp(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return memoryTimestampFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatBindingTimestamp(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return bindingTimestampFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var memoryTimestampFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    private var bindingTimestampFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    private func focusAgentSession(_ sessionID: String) {
        selectedAgentID = sessionID
        selectedTab = .sessions
    }

    private func focusPlatform(_ platformID: String) {
        selectedPlatformInstanceID = platformID
        if let instance = platformInstancesCache.first(where: { $0.platformID == platformID || $0.id == platformID }) {
            loadPlatformConfigDraft(for: instance)
        }
        selectedTab = .platforms
    }

    private func openTranscript(for binding: SessionBindingEntry) {
        let transcriptURL = HermesPaths(settings: settingsStore.settings).transcriptURL(for: binding.sessionID)
        openPath(transcriptURL)
    }

    // MARK: - Model Health Helpers

    private var modelHealthSidebarSubtitle: String {
        let unhealthyCount = modelHealthResults.filter { !$0.status.isHealthy }.count
        if isCheckingModelHealth { return "检查中..." }
        if modelHealthResults.isEmpty { return "点击检查" }
        if unhealthyCount > 0 { return "\(unhealthyCount) 个模型异常" }
        return "全部正常"
    }

    private var modelHealthIconName: String {
        let unhealthyCount = modelHealthResults.filter { !$0.status.isHealthy }.count
        if isCheckingModelHealth { return "arrow.triangle.2.circlepath" }
        if modelHealthResults.isEmpty { return "stethoscope" }
        if unhealthyCount > 0 { return "xmark.octagon.fill" }
        return "checkmark.shield.fill"
    }

    private func runModelHealthChecks() {
        isCheckingModelHealth = true
        modelHealthFixMessage = nil
        modelHealthResults = []

        let mainProvider = hermesDraft.provider
        let mainModel = hermesDraft.modelName
        let routing = profileStore.snapshot.routing

        Task {
            var results: [HermesProfileStore.ModelHealthResult] = []

            let mainStatus = await modelHealthStatus(for: mainProvider, model: mainModel)
            results.append(HermesProfileStore.ModelHealthResult(provider: mainProvider, model: mainModel, status: mainStatus))

            if routing.smartRoutingEnabled, !routing.smartRoutingTargetModel.isEmpty {
                let cheapProvider = routing.smartRoutingTargetProvider.isEmpty ? mainProvider : routing.smartRoutingTargetProvider
                let cheapModel = routing.smartRoutingTargetModel
                let cheapStatus = await modelHealthStatus(for: cheapProvider, model: cheapModel)
                results.append(HermesProfileStore.ModelHealthResult(provider: cheapProvider, model: cheapModel, status: cheapStatus))
            }

            await MainActor.run {
                self.modelHealthResults = results
                self.isCheckingModelHealth = false
            }
        }
    }

    private func fixModelHealth(result: HermesProfileStore.ModelHealthResult) {
        modelHealthFixMessage = nil
        Task {
            let (success, message, _) = await profileStore.autoFixModel(provider: result.provider, model: result.model)
            await MainActor.run {
                self.modelHealthFixMessage = message
                if success {
                    self.runModelHealthChecks()
                }
            }
        }
    }

    private func canAutoFixModelHealth(_ result: HermesProfileStore.ModelHealthResult) -> Bool {
        let currentProvider = canonicalProviderID(hermesDraft.provider)
        let resultProvider = canonicalProviderID(result.provider)
        let currentModel = hermesDraft.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resultModel = result.model.trimmingCharacters(in: .whitespacesAndNewlines)
        return resultProvider == currentProvider && resultModel == currentModel
    }

    private func modelHealthStatus(for provider: String, model: String) async -> HermesProfileStore.ModelHealthStatus {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { return .noModel }

        guard let target = resolvedModelHealthProbeTarget(provider: provider, model: trimmedModel) else {
            return .unhealthy("未找到对应的 Provider 配置", nil)
        }
        guard !target.baseURL.isEmpty else {
            return .unhealthy("缺少 Base URL", nil)
        }
        guard !target.apiKey.isEmpty else {
            return .unhealthy("缺少 API Key", nil)
        }

        return await profileStore.checkModelHealth(
            provider: target.provider,
            baseURL: target.baseURL,
            apiKey: target.apiKey,
            model: target.model
        )
    }

    private func resolvedModelHealthProbeTarget(provider: String, model: String) -> ModelHealthProbeTarget? {
        let canonicalTargetProvider = canonicalProviderID(provider)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonicalTargetProvider.isEmpty, !trimmedModel.isEmpty else { return nil }

        let currentProvider = canonicalProviderID(hermesDraft.provider)
        if canonicalTargetProvider == currentProvider {
            return ModelHealthProbeTarget(
                provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
                model: trimmedModel,
                baseURL: effectiveHealthBaseURL(
                    providerID: hermesDraft.provider,
                    baseURL: hermesDraft.baseURL,
                    apiKey: hermesDraft.apiKey
                ),
                apiKey: hermesDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let candidates = appDraft.modelProviders.filter { savedProvider in
            canonicalProviderID(savedProvider.providerID) == canonicalTargetProvider
        }
        let exactModelCandidates = candidates.filter { savedProvider in
            savedProvider.models.contains { savedModel in
                savedModel.modelName.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedModel
            }
        }
        let chosenProvider = exactModelCandidates.first(where: { isProviderAvailable($0) })
            ?? exactModelCandidates.first
            ?? candidates.first(where: { isProviderAvailable($0) })
            ?? candidates.first

        guard let chosenProvider else { return nil }
        return ModelHealthProbeTarget(
            provider: chosenProvider.providerID.trimmingCharacters(in: .whitespacesAndNewlines),
            model: trimmedModel,
            baseURL: effectiveHealthBaseURL(
                providerID: chosenProvider.providerID,
                baseURL: chosenProvider.baseURL,
                apiKey: chosenProvider.apiKey
            ),
            apiKey: chosenProvider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func effectiveHealthBaseURL(providerID: String, baseURL: String, apiKey: String) -> String {
        let normalizedBaseURL = SavedProviderConnection.normalizedBaseURL(providerID: providerID, baseURL: baseURL)
        if !normalizedBaseURL.isEmpty {
            return normalizedBaseURL
        }

        switch canonicalProviderID(providerID) {
        case "kimi-coding":
            let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedAPIKey.hasPrefix("sk-kimi-") {
                return "https://api.kimi.com/coding/v1"
            }
            return "https://api.moonshot.ai/v1"
        default:
            return ""
        }
    }

    private func canonicalProviderID(_ providerID: String) -> String {
        HermesProviderDescriptor.resolve(providerID)?.id
            ?? providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func healthIcon(for status: HermesProfileStore.ModelHealthStatus) -> String {
        switch status {
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .healthy: return "checkmark.circle.fill"
        case .unhealthy: return "xmark.octagon.fill"
        case .authError: return "exclamationmark.triangle.fill"
        case .noModel: return "minus.circle"
        }
    }

    private func healthColor(for status: HermesProfileStore.ModelHealthStatus) -> Color {
        switch status {
        case .unknown, .checking: return .secondary
        case .healthy: return .green
        case .unhealthy: return .red
        case .authError: return .orange
        case .noModel: return .gray
        }
    }
}

private extension AppSettings {
    var normalized: AppSettings {
        var copy = self
        copy.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.profileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.projectRootPath = projectRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.workspaceRootPath = workspaceRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.launcherPath = launcherPath.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.refreshIntervalSeconds = max(2, min(30, refreshIntervalSeconds))
        copy.modelProviders = modelProviders.map { provider in
            var normalizedProvider = provider
            normalizedProvider.displayName = provider.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedProvider.providerID = provider.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedProvider.baseURL = SavedProviderConnection.normalizedBaseURL(
                providerID: normalizedProvider.providerID,
                baseURL: provider.baseURL
            )
            normalizedProvider.apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedProvider.displayName.isEmpty {
                normalizedProvider.displayName = normalizedProvider.providerID.isEmpty ? "Provider" : normalizedProvider.providerID
            }
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
        if copy.displayName.isEmpty {
            copy.displayName = copy.profileName.isEmpty ? "Profile" : copy.profileName
        }
        return copy
    }
}
