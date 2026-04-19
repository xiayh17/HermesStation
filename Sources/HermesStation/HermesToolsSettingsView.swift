import SwiftUI

private struct HermesToolPlatformOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
}

private struct HermesToolEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let label: String
    let sectionTitle: String
    let isEnabled: Bool

    var detail: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseList(_ output: String) -> [HermesToolEntry] {
        var entries: [HermesToolEntry] = []
        var currentSection = "Built-in toolsets"

        for rawLine in output.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasSuffix(":") {
                currentSection = String(line.dropLast())
                continue
            }

            let pieces = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard pieces.count == 4 else { continue }

            let state = String(pieces[1]).lowercased()
            let name = String(pieces[2])
            let label = String(pieces[3])

            guard state == "enabled" || state == "disabled" else { continue }

            entries.append(
                HermesToolEntry(
                    id: name,
                    name: name,
                    label: label,
                    sectionTitle: currentSection,
                    isEnabled: state == "enabled"
                )
            )
        }

        return entries
    }
}

struct HermesToolsSettingsView: View {
    let settings: AppSettings

    @State private var selectedPlatformID = "cli"
    @State private var entries: [HermesToolEntry] = []
    @State private var selectedEntryID: String?
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var statusMessage: String?

    private var platformOptions: [HermesToolPlatformOption] {
        var options: [HermesToolPlatformOption] = [
            .init(id: "cli", title: "CLI", icon: "terminal")
        ]

        for platform in PlatformDescriptorRegistry.allPlatforms {
            options.append(.init(id: platform.id, title: platform.displayName, icon: platform.icon))
        }

        return options
    }

    private var selectedEntry: HermesToolEntry? {
        guard let selectedEntryID else { return entries.first }
        return entries.first(where: { $0.id == selectedEntryID }) ?? entries.first
    }

    private var enabledCount: Int {
        entries.filter(\.isEnabled).count
    }

    private var disabledCount: Int {
        entries.count - enabledCount
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard entries.isEmpty else { return }
            loadToolsets()
        }
        .onChange(of: settings) { _, _ in
            loadToolsets()
        }
        .onChange(of: selectedPlatformID) { _, _ in
            loadToolsets()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Platform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Picker("Platform", selection: $selectedPlatformID) {
                    ForEach(platformOptions) { option in
                        Label(option.title, systemImage: option.icon).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(12)

            List(selection: $selectedEntryID) {
                Section("Toolsets") {
                    ForEach(entries) { entry in
                        toolRow(entry)
                            .tag(entry.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    summaryPill(title: "Enabled", value: "\(enabledCount)", tint: .green)
                    summaryPill(title: "Disabled", value: "\(disabledCount)", tint: .secondary)
                }

                HStack {
                    Button("Refresh") {
                        loadToolsets()
                    }
                    .disabled(isLoading || isPerformingAction)

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Text("This panel mirrors `hermes tools list --platform \(selectedPlatformID)` and applies changes through `hermes tools enable/disable`.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func toolRow(_ entry: HermesToolEntry) -> some View {
        Button {
            selectedEntryID = entry.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(entry.isEnabled ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(entry.detail)
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
        if let selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: selectedEntry.isEnabled ? "checkmark.circle.fill" : "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(selectedEntry.isEnabled ? Color.green : Color.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedEntry.name)
                                .font(.system(size: 20, weight: .semibold))
                            Text(selectedEntry.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        statusBadge(title: selectedEntry.isEnabled ? "Enabled" : "Disabled", tint: selectedEntry.isEnabled ? .green : .secondary)
                    }

                    if let statusMessage {
                        messageBanner(statusMessage, isError: statusMessage.hasPrefix("Failed"))
                    }

                    GroupBox("Configuration") {
                        VStack(alignment: .leading, spacing: 12) {
                            detailRow("Platform", platformOptions.first(where: { $0.id == selectedPlatformID })?.title ?? selectedPlatformID)
                            detailRow("Section", selectedEntry.sectionTitle)
                            detailRow("Command", "hermes tools \(selectedEntry.isEnabled ? "disable" : "enable") --platform \(selectedPlatformID) \(selectedEntry.name)")

                            HStack {
                                Button(selectedEntry.isEnabled ? "Disable Toolset" : "Enable Toolset") {
                                    setEnabled(for: selectedEntry, to: !selectedEntry.isEnabled)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isPerformingAction)

                                Button("Refresh") {
                                    loadToolsets()
                                }
                                .disabled(isLoading || isPerformingAction)

                                if isPerformingAction {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("What This Changes") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hermes persists tool visibility per platform in the profile config. HermesStation is deliberately using the CLI mutation path so it stays aligned with the current Hermes version and any plugin-provided toolsets.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                Text("No toolset selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Pick a Hermes toolset on the left to inspect or toggle it.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func loadToolsets() {
        let currentSettings = settings
        let platformID = selectedPlatformID

        isLoading = true

        Task {
            do {
                let result = try await CommandRunner.runHermes(currentSettings, ["tools", "list", "--platform", platformID])
                let output = result.combinedOutput

                guard result.status == 0 else {
                    await MainActor.run {
                        entries = []
                        selectedEntryID = nil
                        statusMessage = "Failed to load Hermes tools: \(output.isEmpty ? "Unknown error" : output)"
                        isLoading = false
                    }
                    return
                }

                let parsed = HermesToolEntry.parseList(output)
                await MainActor.run {
                    entries = parsed
                    if let selectedEntryID, parsed.contains(where: { $0.id == selectedEntryID }) {
                        self.selectedEntryID = selectedEntryID
                    } else {
                        self.selectedEntryID = parsed.first?.id
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    entries = []
                    selectedEntryID = nil
                    statusMessage = "Failed to load Hermes tools: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func setEnabled(for entry: HermesToolEntry, to enabled: Bool) {
        let currentSettings = settings
        let platformID = selectedPlatformID

        isPerformingAction = true
        statusMessage = nil

        Task {
            do {
                let args = ["tools", enabled ? "enable" : "disable", "--platform", platformID, entry.name]
                let result = try await CommandRunner.runHermes(currentSettings, args)
                let output = result.combinedOutput

                await MainActor.run {
                    isPerformingAction = false
                    statusMessage = result.status == 0
                        ? (output.isEmpty ? "\(enabled ? "Enabled" : "Disabled") \(entry.name)." : output)
                        : "Failed to \(enabled ? "enable" : "disable") \(entry.name): \(output.isEmpty ? "Unknown error" : output)"
                }
                loadToolsets()
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    statusMessage = "Failed to \(enabled ? "enable" : "disable") \(entry.name): \(error.localizedDescription)"
                }
            }
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
