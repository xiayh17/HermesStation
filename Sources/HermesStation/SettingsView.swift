import SwiftUI
import Charts

private enum SettingsTab: Hashable {
    case general
    case model
    case sessions
    case usage
    case platforms
    case environment
}

private enum AgentPanelFilter: String, CaseIterable, Identifiable {
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
    @State private var hoveredAgentPreviewID: String?
    @State private var agentSearchText: String = ""
    @State private var agentFilter: AgentPanelFilter = .all
    @State private var agentRenameDraft: String = ""
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
    @State private var modelHealthResults: [HermesProfileStore.ModelHealthResult] = []
    @State private var isCheckingModelHealth = false
    @State private var modelHealthFixMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            modelTab
                .tabItem { Label("模型", systemImage: "cpu") }
                .tag(SettingsTab.model)
            agentTab
                .tabItem { Label("Sessions", systemImage: "person.2") }
                .tag(SettingsTab.sessions)
            usageTab
                .tabItem { Label("Usage", systemImage: "chart.bar") }
                .tag(SettingsTab.usage)
            platformsTab
                .tabItem { Label("Platforms", systemImage: "network") }
                .tag(SettingsTab.platforms)
            environmentTab
                .tabItem { Label("环境", systemImage: "folder") }
                .tag(SettingsTab.environment)
        }
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 620, idealHeight: 720)
        .onAppear {
            guard !hasLoadedDraft else { return }
            syncDrafts()
            refreshPlatformInstances()
            hasLoadedDraft = true
        }
        .onChange(of: settingsStore.settings) { _, newValue in
            appDraft = newValue
            platformDraftOverrides = [:]
            platformStatusMessage = nil
            selectedPlatformInstanceID = nil
            refreshPlatformInstances()
            syncModelSelection()
        }
        .onChange(of: profileStore.snapshot) { _, newValue in
            hermesDraft = newValue.draft
            auxiliaryProviderDrafts = Dictionary(uniqueKeysWithValues: newValue.routing.auxiliaryRoutes.map { ($0.task, $0.provider) })
            syncSmartRoutingDrafts(from: newValue.routing)
            refreshPlatformInstances()
            refreshPlatformDiagnostics()
        }
        .onChange(of: gatewayStore.snapshot.runtime?.updatedAt) { _, _ in
            refreshPlatformDiagnostics()
        }
        .onChange(of: gatewayStore.snapshot.serviceStatus) { _, _ in
            refreshPlatformDiagnostics()
        }
        .onChange(of: selectedPlatformInstanceID) { _, _ in
            refreshPlatformDiagnostics()
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
        .onChange(of: gatewayStore.snapshot.agentSessions.totalCount) { _, _ in
            syncAgentSelection()
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
        HStack(spacing: 0) {
            agentSidebar
            Divider()
            agentDetailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var agentSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryPill(title: "Active", value: "\(gatewayStore.snapshot.agentSessions.activeCount)")
                summaryPill(title: "Tracked", value: "\(gatewayStore.snapshot.agentSessions.totalCount)")
                summaryPill(title: "Runtime", value: "\(gatewayStore.snapshot.runtime?.activeAgents ?? 0)")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Picker("Filter", selection: $agentFilter) {
                ForEach(AgentPanelFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            TextField("Search title / id / source / model", text: $agentSearchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            List(selection: selectedAgentBinding) {
                ForEach(filteredAgents) { agent in
                    agentRow(agent)
                        .onHover { isHovering in
                            hoveredAgentPreviewID = isHovering ? agent.id : (hoveredAgentPreviewID == agent.id ? nil : hoveredAgentPreviewID)
                        }
                        .popover(
                            isPresented: Binding(
                                get: { hoveredAgentPreviewID == agent.id },
                                set: { isPresented in
                                    if !isPresented, hoveredAgentPreviewID == agent.id {
                                        hoveredAgentPreviewID = nil
                                    }
                                }
                            ),
                            arrowEdge: .trailing
                        ) {
                            sessionPreviewPopover(agent)
                        }
                        .tag(agent.id)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var agentDetailPanel: some View {
        if let agent = selectedAgent {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: agent.isActive ? "bolt.circle.fill" : "clock.arrow.circlepath")
                                    .foregroundStyle(agent.isActive ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.title)
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(agent.id)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Text(agent.statusText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((agent.isActive ? Color.green : Color.secondary).opacity(0.12))
                                    .foregroundStyle(agent.isActive ? .green : .secondary)
                                    .clipShape(Capsule())
                            }
                        }

                        GroupBox("Actions") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    TextField("Session title", text: $agentRenameDraft)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Rename") {
                                        gatewayStore.renameAgentSession(id: agent.id, title: agentRenameDraft)
                                    }
                                    .disabled(gatewayStore.isBusy || agentRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                                HStack {
                                    Button("Open Transcript") {
                                        gatewayStore.openTranscript(for: agent)
                                    }
                                    Button("Open Log Excerpt") {
                                        gatewayStore.openLogExcerpt(for: agent)
                                    }
                                    Button("Export JSONL") {
                                        gatewayStore.exportAgentSession(id: agent.id)
                                    }
                                    Button("Delete") {
                                        showDeleteAgentAlert = true
                                    }
                                    .foregroundStyle(.red)
                                }
                            }
                            .padding(.top, 4)
                        }

                        GroupBox("Conversation") {
                            VStack(alignment: .leading, spacing: 12) {
                                if isLoadingTranscript {
                                    ProgressView()
                                        .padding(.vertical, 20)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else if let transcript = selectedAgentTranscript {
                                    if transcript.messages.isEmpty {
                                        Text("No messages in transcript.")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        LazyVStack(alignment: .leading, spacing: 16) {
                                            ForEach(transcript.messages) { message in
                                                transcriptMessageRow(message)
                                            }
                                        }
                                    }
                                } else {
                                    Text("Transcript not available.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }

                        GroupBox("Details") {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRow("Source", agent.source)
                                detailRow("Model", agent.model)
                                detailRow("Started", agent.startedAtText)
                                detailRow("Ended", agent.endedAtText)
                                detailRow("Status", agent.statusText)
                                detailRow("End Reason", agent.endReason.isEmpty ? "n/a" : agent.endReason)
                                detailRow("Messages", "\(agent.messageCount)")
                                detailRow("Tool Calls", "\(agent.toolCallCount)")
                                detailRow("Input Tokens", "\(agent.inputTokens)")
                                detailRow("Output Tokens", "\(agent.outputTokens)")
                                detailRow("Cost", agent.estimatedCostText)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No agent selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Pick a session from the left to inspect and manage it.")
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

    @ViewBuilder
    private func transcriptMessageRow(_ message: TranscriptMessage) -> some View {
        switch message.role {
        case "user":
            HStack {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content ?? "")
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 480, alignment: .trailing)
            }
        case "assistant":
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if let reasoning = message.reasoning, !reasoning.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text(reasoning)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(4)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                        ForEach(toolCalls) { toolCall in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(toolCall.function?.name ?? "Tool Call")
                                        .font(.system(size: 11, weight: .semibold))
                                    if let args = toolCall.function?.arguments, !args.isEmpty {
                                        Text(args)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if let content = message.content, !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 560, alignment: .leading)
                Spacer(minLength: 40)
            }
        case "tool":
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 10))
                        Text("Tool Result")
                            .font(.system(size: 10, weight: .semibold))
                        if let toolCallId = message.toolCallId, !toolCallId.isEmpty {
                            Text(toolCallId)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.secondary)
                    Text(message.content ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 520, alignment: .leading)
                Spacer(minLength: 40)
            }
        default:
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.role.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(message.content ?? "")
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer(minLength: 40)
            }
        }
    }

    private func sessionPreviewPopover(_ agent: AgentSessionRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(agent.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Text(agent.id)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            detailRow("Model", agent.model)
            detailRow("Source", agent.source)
            detailRow("Started", agent.startedAtText)
            detailRow("Status", agent.statusText)
            detailRow("Tokens", compactCount(agent.inputTokens + agent.outputTokens))
            detailRow("Cost", agent.estimatedCostText)
        }
        .padding(12)
        .frame(width: 320)
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
        return Button {
            selectedPlatformInstanceID = instance.id
            loadPlatformConfigDraft(for: instance)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: descriptor?.icon ?? "network")
                    .font(.system(size: 16))
                    .foregroundStyle(platformColor(runtimeState?.state))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(platformConnectionLabel(for: instance, runtimeState: runtimeState))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(platformColor(runtimeState?.state))
                    .frame(width: 8, height: 8)
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
        let activeSessions = gatewayStore.snapshot.runtime?.activeSessions?[instance.platformID] ?? []
        let modelOverrides = gatewayStore.snapshot.runtime?.modelOverrides?[instance.platformID] ?? []

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
            }

            if !activeSessions.isEmpty || !modelOverrides.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Sessions & Bindings")
                        .font(.system(size: 12, weight: .medium))

                    ForEach(activeSessions, id: \.sessionKey) { session in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.sessionKey ?? "unknown")
                                    .font(.system(size: 10, design: .monospaced))
                                if let model = session.model, !model.isEmpty {
                                    Text("model: \(model)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Menu {
                                Button("Reset Session") {
                                    if let sk = session.sessionKey {
                                        gatewayStore.submitPendingAction(type: "reset_session", sessionKey: sk)
                                    }
                                }
                                Button("Clear Model Binding") {
                                    if let sk = session.sessionKey {
                                        gatewayStore.submitPendingAction(type: "clear_model_override", sessionKey: sk)
                                    }
                                }
                                Button("Evict Cached Agent") {
                                    if let sk = session.sessionKey {
                                        gatewayStore.submitPendingAction(type: "evict_agent", sessionKey: sk)
                                    }
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

        if runtimeState == nil {
            hints.append("The running gateway has not loaded this platform yet. Restart gateway after saving config so the adapter is created on startup.")
        }

        switch instance.platformID {
        case "email":
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
            return
        }

        let runtimeState = gatewayStore.snapshot.runtime?.platforms[instance.platformID]
        let paths = HermesPaths(settings: settingsStore.settings)
        let platformID = instance.platformID
        let summary = platformDiagnosticSummaryText(for: instance, runtimeState: runtimeState)

        Task(priority: .utility) {
            let lines = Self.loadPlatformDiagnosticLines(platformID: platformID, paths: paths)
            await MainActor.run {
                guard selectedPlatformInstanceID == platformID else { return }
                platformDiagnosticSummary = summary
                platformDiagnosticLines = lines
            }
        }
    }

    private func platformDiagnosticSummaryText(for instance: PlatformInstance, runtimeState: RuntimePlatformState?) -> String {
        if !instance.isEnabled {
            return "Configuration incomplete. Fill all required fields before the gateway can load this platform."
        }
        guard gatewayStore.snapshot.serviceLoaded else {
            return "Gateway service is not running. Start or restart it after saving platform config."
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
            Section("配置文件") {
                pathRow("config.yaml", path: profileStore.snapshot.configURL.path, action: profileStore.openConfigFile)
                pathRow(".env", path: profileStore.snapshot.envURL.path, action: profileStore.openEnvFile)
                pathRow("SOUL.md", path: profileStore.snapshot.soulURL.path, action: profileStore.openSoulFile)
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
                }
            }

            Section("工作目录") {
                labeledField("terminal.cwd", text: $hermesDraft.terminalCwd)
                mappingHint("config.yaml → terminal.cwd")

                labeledField("MESSAGING_CWD", text: $hermesDraft.messagingCwd)
                mappingHint(".env → MESSAGING_CWD")
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

    // MARK: - Shared

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

    private func agentRow(_ agent: AgentSessionRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(agent.isActive ? .green : .secondary)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(agent.source) · \(agent.model)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(agent.startedAtText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .hoverPlate(cornerRadius: 6)
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
        case "connecting": return .orange
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

    private var selectedAgentBinding: Binding<String?> {
        Binding(
            get: { selectedAgentID },
            set: { selectedAgentID = $0 }
        )
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
        gatewayStore.snapshot.agentSessions.rows.filter { agent in
            let matchesFilter: Bool
            switch agentFilter {
            case .all:
                matchesFilter = true
            case .running:
                matchesFilter = agent.isActive
            case .completed:
                matchesFilter = !agent.isActive
            }

            guard matchesFilter else { return false }

            let query = agentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            let haystack = [agent.title, agent.id, agent.source, agent.model].joined(separator: " ").lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    private var selectedAgent: AgentSessionRow? {
        guard let selectedAgentID else { return filteredAgents.first ?? gatewayStore.snapshot.agentSessions.rows.first }
        return gatewayStore.snapshot.agentSessions.rows.first(where: { $0.id == selectedAgentID })
    }

    private var canSaveHermes: Bool {
        !profileStore.isSaving
            && !hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (hermesDraft.provider == "custom" || currentHermesProviderDescriptor != nil)
    }

    private var activeProviderTitle: String {
        currentHermesProviderDescriptor?.displayName ?? "手动 Provider"
    }

    private var activeProviderSubtitle: String {
        let providerID = hermesDraft.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerID.isEmpty {
            return "还没有设置 provider ID。"
        }
        return currentHermesProviderDescriptor == nil ? providerID : "\(providerID) · 已接入 menubar 映射"
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
            displayName: currentHermesProviderDescriptor?.displayName ?? providerID,
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

        if SavedProviderConnection.hasKimiCodingV1Issue(providerID: providerID, baseURL: baseURL) {
            issues.append(.init(severity: .warning, message: "Kimi Coding endpoint 应为 `https://api.kimi.com/coding/v1`。当前 `.../coding` 会在 Hermes 运行时触发 404；保存时 menubar 会自动修正。"))
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
        let rows = gatewayStore.snapshot.agentSessions.rows
        if let selectedAgentID, rows.contains(where: { $0.id == selectedAgentID }) {
            if let current = rows.first(where: { $0.id == selectedAgentID }) {
                agentRenameDraft = current.title
            }
            return
        }
        selectedAgentID = rows.first?.id
        agentRenameDraft = rows.first?.title ?? ""
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
