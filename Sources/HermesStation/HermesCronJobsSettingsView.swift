import SwiftUI

private struct HermesCronSchedule: Codable, Hashable {
    let kind: String?
    let expr: String?
    let display: String?
    let minutes: Int?
    let runAt: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case expr
        case display
        case minutes
        case runAt = "run_at"
    }
}

private struct HermesCronRepeat: Codable, Hashable {
    let times: Int?
    let completed: Int?
}

private struct HermesCronJobDocument: Codable {
    let jobs: [HermesCronJob]
    let updatedAt: String?
}

private struct HermesCronJob: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let prompt: String?
    let skills: [String]?
    let skill: String?
    let model: String?
    let provider: String?
    let baseURL: String?
    let script: String?
    let schedule: HermesCronSchedule?
    let scheduleDisplay: String?
    let repeatInfo: HermesCronRepeat?
    let enabled: Bool?
    let state: String?
    let pausedAt: String?
    let pausedReason: String?
    let createdAt: String?
    let nextRunAt: String?
    let lastRunAt: String?
    let lastStatus: String?
    let lastError: String?
    let lastDeliveryError: String?
    let deliver: String?
    let origin: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case prompt
        case skills
        case skill
        case model
        case provider
        case baseURL = "base_url"
        case script
        case schedule
        case scheduleDisplay = "schedule_display"
        case repeatInfo = "repeat"
        case enabled
        case state
        case pausedAt = "paused_at"
        case pausedReason = "paused_reason"
        case createdAt = "created_at"
        case nextRunAt = "next_run_at"
        case lastRunAt = "last_run_at"
        case lastStatus = "last_status"
        case lastError = "last_error"
        case lastDeliveryError = "last_delivery_error"
        case deliver
        case origin
    }

    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? id : trimmed
    }

    var scheduleText: String {
        if let scheduleDisplay, !scheduleDisplay.isEmpty {
            return scheduleDisplay
        }
        if let display = schedule?.display, !display.isEmpty {
            return display
        }
        if let expr = schedule?.expr, !expr.isEmpty {
            return expr
        }
        return "No schedule"
    }

    var effectiveSkills: [String] {
        if let skills, !skills.isEmpty {
            return skills
        }
        if let skill, !skill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [skill]
        }
        return []
    }

    var isEnabled: Bool {
        enabled ?? true
    }

    var stateLabel: String {
        let rawState = state?.lowercased() ?? ""
        if rawState == "paused" {
            return "Paused"
        }
        if rawState == "completed" {
            return "Completed"
        }
        if isEnabled {
            return "Active"
        }
        return "Disabled"
    }

    var stateColor: Color {
        let rawState = state?.lowercased() ?? ""
        if rawState == "completed" {
            return .blue
        }
        if rawState == "paused" {
            return .orange
        }
        return isEnabled ? .green : .secondary
    }
}

private struct HermesCronJobForm {
    var name: String = ""
    var schedule: String = ""
    var prompt: String = ""
    var deliver: String = ""
    var repeatText: String = ""
    var skillsText: String = ""
    var script: String = ""

    init(job: HermesCronJob? = nil) {
        guard let job else { return }
        name = job.name ?? ""
        schedule = job.scheduleText
        prompt = job.prompt ?? ""
        deliver = job.deliver ?? ""
        if let repeatTimes = job.repeatInfo?.times {
            repeatText = "\(repeatTimes)"
        }
        skillsText = job.effectiveSkills.joined(separator: ", ")
        script = job.script ?? ""
    }

    var normalizedSkills: [String] {
        skillsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private enum HermesCronDates {
    private static func formatters() -> [ISO8601DateFormatter] {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return [withFractional, plain]
    }

    private static func displayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static func parse(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        for formatter in formatters() {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    static func display(_ rawValue: String?, fallback: String = "Never") -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        guard let date = parse(rawValue) else { return rawValue }
        return displayFormatter().string(from: date)
    }
}

struct HermesCronJobsSettingsView: View {
    let settings: AppSettings

    @EnvironmentObject private var gatewayStore: GatewayStore

    @State private var jobs: [HermesCronJob] = []
    @State private var selectedJobID: String?
    @State private var statusMessage: String?
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var showJobEditor = false
    @State private var editingJobID: String?
    @State private var form = HermesCronJobForm()
    @State private var availableSkills: [SkillCatalogEntry] = []

    private var paths: HermesPaths {
        HermesPaths(settings: settings)
    }

    private var selectedJob: HermesCronJob? {
        guard let selectedJobID else { return jobs.first }
        return jobs.first(where: { $0.id == selectedJobID }) ?? jobs.first
    }

    private var activeJobCount: Int {
        jobs.filter(\.isEnabled).count
    }

    private var pausedJobCount: Int {
        jobs.filter { !$0.isEnabled }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showJobEditor) {
            jobEditorSheet
        }
        .onAppear {
            guard jobs.isEmpty && availableSkills.isEmpty else { return }
            loadData()
        }
        .onChange(of: settings) { _, _ in
            loadData()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedJobID) {
                Section("Jobs") {
                    ForEach(jobs) { job in
                        cronJobRow(job)
                            .tag(job.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    summaryPill(title: "Active", value: "\(activeJobCount)", tint: .green)
                    summaryPill(title: "Paused", value: "\(pausedJobCount)", tint: .orange)
                }

                HStack {
                    Button("New Job") {
                        openCreateSheet()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh") {
                        loadData()
                    }
                    .disabled(isLoading || isPerformingAction)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Text("Jobs are read from the active profile's `cron/jobs.json`, while mutations go through `hermes cron ...` so schedule semantics stay aligned with Hermes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .frame(minWidth: 320, idealWidth: 340, maxWidth: 380, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func cronJobRow(_ job: HermesCronJob) -> some View {
        Button {
            selectedJobID = job.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(job.stateColor)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(job.scheduleText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("Next: \(HermesCronDates.display(job.nextRunAt, fallback: job.isEnabled ? "Pending" : "Stopped"))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let selectedJob {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "clock.badge")
                            .font(.system(size: 28))
                            .foregroundStyle(selectedJob.stateColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedJob.displayName)
                                .font(.system(size: 20, weight: .semibold))
                            Text(selectedJob.id)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        statusBadge(title: selectedJob.stateLabel, tint: selectedJob.stateColor)
                    }

                    if gatewayStore.snapshot.serviceStatus != .running {
                        messageBanner("Gateway is not currently running. Cron jobs can still be edited here, but they will not fire automatically until the Hermes gateway service is up.", isError: true)
                    }

                    if let statusMessage {
                        messageBanner(statusMessage, isError: statusMessage.hasPrefix("Failed"))
                    }

                    GroupBox("Overview") {
                        VStack(alignment: .leading, spacing: 12) {
                            detailRow("Schedule", selectedJob.scheduleText)
                            detailRow("Next Run", HermesCronDates.display(selectedJob.nextRunAt, fallback: selectedJob.isEnabled ? "Pending" : "Stopped"))
                            detailRow("Last Run", HermesCronDates.display(selectedJob.lastRunAt))
                            detailRow("Delivery", selectedJob.deliver ?? "local")
                            if let script = selectedJob.script, !script.isEmpty {
                                detailRow("Script", script)
                            }
                            if !selectedJob.effectiveSkills.isEmpty {
                                detailRow("Skills", selectedJob.effectiveSkills.joined(separator: ", "))
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Prompt") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text((selectedJob.prompt ?? "").isEmpty ? "No prompt body saved." : (selectedJob.prompt ?? ""))
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let lastStatus = selectedJob.lastStatus, !lastStatus.isEmpty {
                                detailRow("Last Status", lastStatus == "ok" ? "ok" : "\(lastStatus) · \(selectedJob.lastError ?? "")")
                            }

                            if let deliveryError = selectedJob.lastDeliveryError, !deliveryError.isEmpty {
                                detailRow("Delivery Error", deliveryError)
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Actions") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button("Edit Job") {
                                    openEditSheet(for: selectedJob)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isPerformingAction)

                                Button(selectedJob.isEnabled ? "Pause" : "Resume") {
                                    performJobAction(selectedJob.isEnabled ? "pause" : "resume", for: selectedJob)
                                }
                                .disabled(isPerformingAction)

                                Button("Run Next Tick") {
                                    performJobAction("run", for: selectedJob)
                                }
                                .disabled(isPerformingAction)

                                Button("Delete") {
                                    performJobAction("remove", for: selectedJob)
                                }
                                .foregroundStyle(.red)
                                .disabled(isPerformingAction)
                            }

                            HStack {
                                Button("Open jobs.json") {
                                    openPath(paths.cronJobsURL)
                                }
                                .disabled(isPerformingAction)

                                Button("Open Output Folder") {
                                    openPath(latestOutputURL(for: selectedJob) ?? paths.cronOutputDir(for: selectedJob.id))
                                }
                                .disabled(isPerformingAction)

                                if isPerformingAction {
                                    ProgressView()
                                        .scaleEffect(0.8)
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
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No cron job selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Create a Hermes cron job, or pick one from the left to inspect and manage it.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var jobEditorSheet: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(editingJobID == nil ? "New Cron Job" : "Edit Cron Job")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                    }

                    GroupBox("Schedule") {
                        VStack(alignment: .leading, spacing: 10) {
                            labeledField("Name", text: $form.name, placeholder: "Optional display name")
                            labeledField("Schedule", text: $form.schedule, placeholder: "every 30m, 0 9 * * *, or 2026-04-20T09:00")
                            Text("Supported formats: one-shot durations like `30m`, repeating intervals like `every 2h`, cron expressions like `0 9 * * *`, or ISO timestamps.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Task") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Prompt")
                                .font(.system(size: 12, weight: .medium))
                            TextEditor(text: $form.prompt)
                                .font(.system(size: 12))
                                .frame(minHeight: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )

                            labeledField("Skills", text: $form.skillsText, placeholder: "Comma-separated skill IDs")
                            if !availableSkills.isEmpty {
                                skillSuggestions
                            }

                            labeledField("Script Path", text: $form.script, placeholder: "Optional Python script path")
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Delivery") {
                        VStack(alignment: .leading, spacing: 10) {
                            labeledField("Deliver To", text: $form.deliver, placeholder: "origin, local, feishu:chat_id, telegram:chat_id...")
                            labeledField("Repeat Count", text: $form.repeatText, placeholder: "Optional; leave empty for default/forever")
                        }
                        .padding(.top, 4)
                    }

                    if let statusMessage {
                        messageBanner(statusMessage, isError: statusMessage.hasPrefix("Failed"))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    showJobEditor = false
                    statusMessage = nil
                }
                Spacer()
                Button(editingJobID == nil ? "Create Job" : "Save Changes") {
                    saveJob()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPerformingAction)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 620, idealHeight: 700)
    }

    private var skillSuggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Available Skills")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                ForEach(Array(availableSkills.prefix(12))) { skill in
                    Button {
                        appendSkill(skill.identifier)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(skill.isEnabled ? Color.green : Color.secondary)
                            Text(skill.identifier)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openCreateSheet() {
        editingJobID = nil
        form = HermesCronJobForm()
        statusMessage = nil
        showJobEditor = true
    }

    private func openEditSheet(for job: HermesCronJob) {
        editingJobID = job.id
        form = HermesCronJobForm(job: job)
        statusMessage = nil
        showJobEditor = true
    }

    private func loadData() {
        loadJobs()
        loadAvailableSkills()
    }

    private func loadJobs() {
        isLoading = true

        let jobsURL = paths.cronJobsURL

        Task {
            let loadedJobs: [HermesCronJob]
            do {
                if FileManager.default.fileExists(atPath: jobsURL.path) {
                    let data = try Data(contentsOf: jobsURL)
                    let decoder = JSONDecoder()
                    let document = try decoder.decode(HermesCronJobDocument.self, from: data)
                    loadedJobs = document.jobs.sorted { lhs, rhs in
                        let lhsDate = HermesCronDates.parse(lhs.nextRunAt) ?? HermesCronDates.parse(lhs.createdAt) ?? .distantFuture
                        let rhsDate = HermesCronDates.parse(rhs.nextRunAt) ?? HermesCronDates.parse(rhs.createdAt) ?? .distantFuture
                        if lhsDate != rhsDate {
                            return lhsDate < rhsDate
                        }
                        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                    }
                } else {
                    loadedJobs = []
                }

                await MainActor.run {
                    jobs = loadedJobs
                    if let selectedJobID, loadedJobs.contains(where: { $0.id == selectedJobID }) {
                        self.selectedJobID = selectedJobID
                    } else {
                        self.selectedJobID = loadedJobs.first?.id
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    jobs = []
                    selectedJobID = nil
                    statusMessage = "Failed to load cron jobs: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func loadAvailableSkills() {
        let hermesHome = paths.hermesHome
        Task {
            let loadedSkills = HermesKnowledgeCatalog.loadSkills(from: hermesHome)
            await MainActor.run {
                availableSkills = loadedSkills
            }
        }
    }

    private func saveJob() {
        let trimmedSchedule = form.schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = form.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScript = form.script.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSchedule.isEmpty else {
            statusMessage = "Failed to save cron job: schedule is required."
            return
        }

        guard !trimmedPrompt.isEmpty || !trimmedScript.isEmpty else {
            statusMessage = "Failed to save cron job: provide a prompt or a script."
            return
        }

        let currentSettings = settings
        let currentForm = form
        let editingJobID = editingJobID

        isPerformingAction = true
        statusMessage = nil

        Task {
            do {
                let result: CommandResult
                if let editingJobID {
                    var args = ["cron", "edit", editingJobID, "--schedule", trimmedSchedule, "--clear-skills"]

                    let trimmedName = currentForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        args += ["--name", trimmedName]
                    }

                    args += ["--prompt", trimmedPrompt]

                    let trimmedDeliver = currentForm.deliver.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedDeliver.isEmpty {
                        args += ["--deliver", trimmedDeliver]
                    }

                    let trimmedRepeat = currentForm.repeatText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedRepeat.isEmpty {
                        args += ["--repeat", trimmedRepeat]
                    }

                    for skill in currentForm.normalizedSkills {
                        args += ["--skill", skill]
                    }

                    args += ["--script", trimmedScript]
                    result = try await CommandRunner.runHermes(currentSettings, args)
                } else {
                    var args = ["cron", "create"]

                    let trimmedName = currentForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        args += ["--name", trimmedName]
                    }

                    let trimmedDeliver = currentForm.deliver.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedDeliver.isEmpty {
                        args += ["--deliver", trimmedDeliver]
                    }

                    let trimmedRepeat = currentForm.repeatText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedRepeat.isEmpty {
                        args += ["--repeat", trimmedRepeat]
                    }

                    for skill in currentForm.normalizedSkills {
                        args += ["--skill", skill]
                    }

                    if !trimmedScript.isEmpty {
                        args += ["--script", trimmedScript]
                    }

                    args += [trimmedSchedule, trimmedPrompt]
                    result = try await CommandRunner.runHermes(currentSettings, args)
                }

                let output = result.combinedOutput
                await MainActor.run {
                    isPerformingAction = false
                    if result.status == 0 {
                        statusMessage = output.isEmpty ? "Saved cron job." : output
                        showJobEditor = false
                    } else {
                        statusMessage = "Failed to save cron job: \(output.isEmpty ? "Unknown error" : output)"
                    }
                }

                if result.status == 0 {
                    loadJobs()
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    statusMessage = "Failed to save cron job: \(error.localizedDescription)"
                }
            }
        }
    }

    private func performJobAction(_ action: String, for job: HermesCronJob) {
        let currentSettings = settings
        isPerformingAction = true
        statusMessage = nil

        Task {
            do {
                let result = try await CommandRunner.runHermes(currentSettings, ["cron", action, job.id])
                let output = result.combinedOutput
                await MainActor.run {
                    isPerformingAction = false
                    statusMessage = result.status == 0
                        ? (output.isEmpty ? "Updated \(job.displayName)." : output)
                        : "Failed to \(action) \(job.displayName): \(output.isEmpty ? "Unknown error" : output)"
                }
                loadJobs()
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    statusMessage = "Failed to \(action) \(job.displayName): \(error.localizedDescription)"
                }
            }
        }
    }

    private func latestOutputURL(for job: HermesCronJob) -> URL? {
        let outputDirectory = paths.cronOutputDir(for: job.id)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }.first
    }

    private func openPath(_ url: URL) {
        Task {
            _ = try? await CommandRunner.openPath(url)
        }
    }

    private func appendSkill(_ identifier: String) {
        let skills = form.normalizedSkills
        guard !skills.contains(identifier) else { return }

        if form.skillsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            form.skillsText = identifier
        } else {
            form.skillsText += ", \(identifier)"
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13))
                .textSelection(.enabled)
        }
    }

    private func summaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private func messageBanner(_ message: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color.red : Color.green)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background((isError ? Color.red : Color.green).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
