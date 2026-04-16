import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject private var store: GatewayStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var profileStore: HermesProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            serviceSection
            Divider()
            usageSection
            Divider()
            platformSection
            if let output = store.snapshot.lastCommandOutput, !output.isEmpty {
                Divider()
                Text(output)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Divider()
            footerSection
        }
        .padding(12)
        .frame(width: 340)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: store.snapshot.menuBarSymbol)
                    .foregroundStyle(iconColor)
                Text("Hermes Station")
                    .font(.headline)
                Spacer()
                Menu(settingsStore.settings.displayName) {
                    ForEach(settingsStore.profiles) { profile in
                        Button {
                            settingsStore.activateProfile(profile.id)
                        } label: {
                            if profile.id == settingsStore.activeProfileID {
                                Label(profile.displayName, systemImage: "checkmark")
                            } else {
                                Text(profile.displayName)
                            }
                        }
                    }
                }
                .font(.system(size: 11))
                Button("Refresh") { store.refresh() }
                    .font(.system(size: 11))
            }
            Text(profileLine)
                .font(.subheadline)
            Text("Model: \(activeModelLine)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(AppBuildInfo.versionLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(statusLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gateway")
                .font(.headline)
            HStack {
                statusPill("Installed", value: store.snapshot.serviceInstalled ? "yes" : "no")
                statusPill("Loaded", value: store.snapshot.serviceLoaded ? "yes" : "no")
                statusPill("Agents", value: "\(store.snapshot.runtime?.activeAgents ?? 0)")
            }
            Text(serviceDetailLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                if !store.snapshot.serviceInstalled {
                    Button("Install") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                } else if !store.snapshot.serviceLoaded {
                    Button("Repair") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                    Button("Start") { store.startService() }
                        .disabled(store.isBusy)
                } else {
                    Button("Restart") { store.restartService() }
                        .disabled(store.isBusy)
                    Button("Stop") { store.stopService() }
                        .disabled(store.isBusy)
                    Button("Reinstall") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                }
            }
        }
    }

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Platforms")
                .font(.headline)
            ForEach(Array((store.snapshot.runtime?.platforms ?? [:]).keys.sorted()), id: \.self) { key in
                let value = store.snapshot.runtime?.platforms[key]
                HStack {
                    Circle()
                        .fill(platformColor(value?.state))
                        .frame(width: 8, height: 8)
                    Text(key.capitalized)
                    Spacer()
                    Text(value?.state ?? "unknown")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var usageSection: some View {
        let usage = store.snapshot.usage
        let last24h = usage.last24Hours

        return VStack(alignment: .leading, spacing: 8) {
            Text("Usage")
                .font(.headline)
            HStack {
                statusPill("24h Sessions", value: "\(last24h.sessionCount)")
                statusPill("24h Tokens", value: compactCount(last24h.totalTokens))
                statusPill("24h Cost", value: compactCurrency(last24h.totalCostUSD))
            }
            Text(topUsageLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Settings…") {
                SettingsWindowController.shared.show(
                    settingsStore: settingsStore,
                    profileStore: profileStore,
                    gatewayStore: store
                )
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }

    private var statusLine: String {
        if let runtime = store.snapshot.runtime {
            return "state: \(runtime.gatewayState ?? "unknown") · updated: \(runtime.updatedAt ?? "n/a")"
        }
        return "state: no runtime status file yet"
    }

    private var activeModelLine: String {
        let model = profileStore.snapshot.draft.modelName
        let provider = profileStore.snapshot.draft.provider
        guard !model.isEmpty else { return "not configured" }
        guard !provider.isEmpty else { return model }
        return "\(model) (\(provider))"
    }

    private var profileLine: String {
        let settings = settingsStore.settings
        if settings.displayName == settings.profileName || settings.displayName.isEmpty {
            return "Profile: \(settings.profileName)"
        }
        return "Profile: \(settings.displayName) (\(settings.profileName))"
    }

    private var serviceDetailLine: String {
        switch store.snapshot.serviceStatus {
        case .running:
            if let pid = store.snapshot.runtime?.pid {
                return "launchd loaded · pid \(pid)"
            }
            return "launchd loaded"
        case .degraded:
            return "service loaded, but one or more platforms are degraded"
        case .stopped:
            return "service installed but not running"
        case .unknown:
            return "service not installed yet"
        }
    }

    private var topUsageLine: String {
        guard let top = store.snapshot.usage.last7DayRows.first ?? store.snapshot.usage.allTimeRows.first else {
            return "No model usage recorded yet."
        }
        return "Top model: \(top.model) · \(top.provider) · \(top.sessionCount) sessions"
    }

    private var iconColor: Color {
        switch store.snapshot.serviceStatus {
        case .running: return .green
        case .degraded: return .orange
        case .stopped: return .red
        case .unknown: return .secondary
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

    private func statusPill(_ title: String, value: String) -> some View {
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
}
