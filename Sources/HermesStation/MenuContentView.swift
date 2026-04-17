import SwiftUI
import AppKit
import Charts

struct MenuContentView: View {
    @EnvironmentObject private var store: GatewayStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var profileStore: HermesProfileStore
    @State private var hoveredUsageChart = false

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
                Text("HermesStation")
                    .font(.headline)
                Spacer()
                Menu(settingsStore.settings.displayName) {
                    ForEach(settingsStore.profiles) { profile in
                        Button {
                            settingsStore.activateProfile(profile.id)
                        } label: {
                            if profile.id == settingsStore.activeProfileID {
                                Label(profileMenuLabel(for: profile), systemImage: "checkmark")
                            } else {
                                Text(profileMenuLabel(for: profile))
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
            Text(profileScopeLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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

            if store.snapshot.hasDuplicateGatewayProcesses {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("检测到 \(store.snapshot.gatewayProcesses.count) 个 gateway 进程同时运行")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Kill Others") {
                        store.killDuplicateGateways()
                    }
                    .disabled(store.isBusy)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if store.snapshot.gatewayProcesses.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.snapshot.gatewayProcesses) { process in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(process.isAuthoritative ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("PID \(process.id)")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(processLine(process: process))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if !process.isAuthoritative {
                                Button("Primary") {
                                    store.promoteToAuthoritative(pid: process.id)
                                }
                                .disabled(store.isBusy)
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                Button("Kill") {
                                    store.killGateway(pid: process.id)
                                }
                                .disabled(store.isBusy)
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack {
                statusPill("Installed", value: store.snapshot.serviceInstalled ? "yes" : "no")
                statusPill("Loaded", value: store.snapshot.serviceLoaded ? "yes" : "no")
                statusPill("Agents", value: "\(store.snapshot.trustedRuntime?.activeAgents ?? 0)")
            }
            Text(serviceDetailLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                if !store.snapshot.serviceInstalled {
                    Button("Install") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                } else if !store.snapshot.serviceLoaded {
                    Button("Repair") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                    Button("Start") { store.startService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                } else {
                    Button("Restart") { store.restartService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                    Button("Stop") { store.stopService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                    Button("Reinstall") { store.installOrRepairService() }
                        .disabled(store.isBusy)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .hoverPlate(cornerRadius: 6)
                }
            }

            if !store.snapshot.aliases.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Aliases: \(store.snapshot.aliases.map(\.name).joined(separator: ", "))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Platforms")
                .font(.headline)
            if store.snapshot.runtimeIsStale {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Runtime file stale; showing cached platforms")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            }
            ForEach(Array((store.snapshot.displayPlatforms ?? [:]).keys.sorted()), id: \.self) { key in
                let value = store.snapshot.displayPlatforms?[key]
                HStack {
                    Circle()
                        .fill(platformColor(value?.state))
                        .frame(width: 8, height: 8)
                    Text(key.capitalized)
                    Spacer()
                    Text(value?.state ?? "unknown")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .hoverPlate(cornerRadius: 6)
            }
        }
    }

    private var usageSection: some View {
        let usage = store.snapshot.usage
        let last24h = usage.last24Hours
        let buckets = menuUsageBuckets

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.headline)
                Spacer()
                if !buckets.isEmpty {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onHover { isHovering in
                            hoveredUsageChart = isHovering
                        }
                        .background(
                            PopoverChartTrigger(isPresented: $hoveredUsageChart) {
                                usageChartPopover(buckets: buckets)
                            }
                        )
                }
            }
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

    private func usageChartPopover(buckets: [UsageTimeBucket]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens over time")
                .font(.system(size: 12, weight: .semibold))
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Time", Date(timeIntervalSince1970: bucket.bucketStart)),
                    y: .value("Tokens", bucket.totalTokens)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: menuChartDateFormat)
                }
            }
            .chartYAxis(.hidden)
            .frame(width: 180, height: 90)
        }
        .padding(12)
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
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .hoverPlate(cornerRadius: 6)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .hoverPlate(cornerRadius: 6)
        }
    }

    private var statusLine: String {
        if let runtime = store.snapshot.trustedRuntime {
            return "state: \(runtime.gatewayState ?? "unknown") · updated: \(runtime.updatedAt ?? "n/a")"
        }
        if let pid = store.snapshot.authoritativeGatewayPID {
            if store.snapshot.runtimeIsStale {
                return "state: live pid \(pid) · runtime file stale"
            }
            return "state: process alive · pid \(pid)"
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
        return "Profile: \(profileMenuLabel(for: settings))"
    }

    private var profileScopeLine: String {
        let profileID = settingsStore.settings.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileID.isEmpty else { return "Isolated Hermes environment · config/.env/SOUL/sessions split by profile" }
        return "Isolated Hermes environment · config/.env/SOUL/sessions · -p \(profileID)"
    }

    private func profileMenuLabel(for profile: AppSettings) -> String {
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Profile"
            : profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileID = profile.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profileID.isEmpty else { return "\(displayName) · profile id unset" }
        return "\(displayName) · -p \(profileID)"
    }

    private func processLine(process: GatewayProcessInfo) -> String {
        var parts: [String] = []
        if process.isLaunchdManaged {
            parts.append("launchd")
        }
        if process.isAuthoritative {
            parts.append("authoritative")
        }
        if let startTime = process.startTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            parts.append(formatter.localizedString(for: startTime, relativeTo: Date()))
        }
        if parts.isEmpty {
            return process.command
        }
        return parts.joined(separator: " · ")
    }

    private var serviceDetailLine: String {
        if store.snapshot.hasDuplicateGatewayProcesses {
            let pids = store.snapshot.duplicateGatewayPIDs.map(String.init).joined(separator: ", ")
            return "⚠️ PIDs: \(pids)。多实例会抢消息，导致 404 和状态抖动。"
        }
        if let pid = store.snapshot.authoritativeGatewayPID {
            if let reason = store.snapshot.runtimeStaleReason, !reason.isEmpty {
                return "live pid \(pid) · trusting launchd/ps/gateway.pid · stale runtime: \(reason)"
            }
            if store.snapshot.serviceLoaded {
                return "launchd loaded · pid \(pid)"
            }
            return "gateway process alive · pid \(pid)"
        }
        switch store.snapshot.serviceStatus {
        case .running:
            return "launchd loaded"
        case .degraded:
            if store.snapshot.serviceLoaded {
                return "launchd loaded, but no trusted live gateway process was detected"
            }
            return "service metadata exists, but no trusted live gateway process was detected"
        case .stopped:
            return "service installed but not running"
        case .unknown:
            return "service not installed yet"
        }
    }

    private var menuUsageBuckets: [UsageTimeBucket] {
        let usage = store.snapshot.usage
        if usage.last24HourBuckets.count >= 2 {
            return usage.last24HourBuckets
        }
        if usage.last7DayBuckets.count >= 2 {
            return usage.last7DayBuckets
        }
        return []
    }

    private var menuChartDateFormat: Date.FormatStyle {
        let buckets = menuUsageBuckets
        let isHourly = buckets.count >= 2 &&
            (buckets[1].bucketStart - buckets[0].bucketStart) < 86400
        if isHourly {
            return .dateTime.hour()
        }
        return .dateTime.month(.abbreviated).day()
    }

    private var topUsageLine: String {
        guard let top = store.snapshot.usage.last7DayRows.first ?? store.snapshot.usage.allTimeRows.first else {
            return "No model usage recorded yet."
        }
        return "Top model: \(top.model) · \(top.provider) · \(top.sessionCount) sessions"
    }

    private var iconColor: Color {
        if store.snapshot.hasDuplicateGatewayProcesses {
            return .red
        }
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
