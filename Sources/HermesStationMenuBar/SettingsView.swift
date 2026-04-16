import SwiftUI
import Charts

private enum SettingsTab: Hashable {
    case general
    case model
    case sessions
    case usage
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
    case provider(UUID)
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
            environmentTab
                .tabItem { Label("环境", systemImage: "folder") }
                .tag(SettingsTab.environment)
        }
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 620, idealHeight: 720)
        .onAppear {
            guard !hasLoadedDraft else { return }
            syncDrafts()
            hasLoadedDraft = true
        }
        .onChange(of: settingsStore.settings) { _, newValue in
            appDraft = newValue
            syncModelSelection()
        }
        .onChange(of: profileStore.snapshot) { _, newValue in
            hermesDraft = newValue.draft
            auxiliaryProviderDrafts = Dictionary(uniqueKeysWithValues: newValue.routing.auxiliaryRoutes.map { ($0.task, $0.provider) })
            syncSmartRoutingDrafts(from: newValue.routing)
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
                return
            }
            agentRenameDraft = agent.title
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
                        Text(profile.displayName).tag(profile.id)
                    }
                }

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

                mappingHint("切换后，菜单栏监控、Gateway 控制和模型配置都会指向当前激活的 profile。")
            }

            Section("Menubar 应用") {
                labeledField("Display Name", text: $appDraft.displayName)
                labeledField("Hermes Profile", text: $appDraft.profileName)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hermes Home")
                        .font(.system(size: 12, weight: .medium))
                    Text(HermesPaths(settings: appDraft).hermesHome.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
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
                }

                Section("Provider APIs") {
                    ForEach(appDraft.modelProviders) { provider in
                        providerSidebarRow(
                            title: provider.displayName,
                            subtitle: modelProviderSidebarSubtitle(provider),
                            systemImage: isProviderActive(provider) ? "checkmark.circle.fill" : "network"
                        )
                        .tag(ModelSidebarDestination.provider(provider.id))
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
                labeledField("Base URL", text: providerBaseURLBinding)

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium))
                    SecureField("API key", text: providerAPIKeyBinding)
                        .textFieldStyle(.roundedBorder)
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
                        removeSelectedModelProvider()
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
            labeledField("Base URL", text: newProviderBaseURLBinding)

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.system(size: 12, weight: .medium))
                SecureField("API key", text: newProviderAPIKeyBinding)
                    .textFieldStyle(.roundedBorder)
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
                        Text("Hermes currently exposes session-level management. Rename, export, delete, transcript, and log actions below are real CLI-backed operations.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
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
                            Text("Terminate / restart a single running agent is not exposed by the current Hermes CLI, so this panel does not fake that control.")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
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

    // MARK: - Environment

    private var environmentTab: some View {
        Form {
            Section("配置文件") {
                pathRow("config.yaml", path: profileStore.snapshot.configURL.path, action: profileStore.openConfigFile)
                pathRow(".env", path: profileStore.snapshot.envURL.path, action: profileStore.openEnvFile)
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

        case .current, .routing:
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

        if resolved?.id == "custom" {
            if baseURL.isEmpty {
                issues.append(.init(severity: .error, message: "Custom provider 必须填写 Base URL。"))
            }
            if apiKey.isEmpty {
                issues.append(.init(severity: .error, message: "Custom provider 必须填写 API Key。"))
            }
        } else if let resolved, resolved.primaryAPIKeyEnvVar != nil, apiKey.isEmpty {
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
        if canAdvanceAddAPIWizard {
            return "连接信息足够，继续下一页配置模型。"
        }
        return "至少要填写 Provider ID；Custom 还需要 Base URL 和 API Key。"
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
        normalized.baseURL = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
            normalizedProvider.baseURL = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
