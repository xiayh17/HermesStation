import SwiftUI

struct HermesPackSupportAction: Identifiable {
    let id: String
    let title: String
    let action: () -> Void
}

struct HermesPackSheetView: View {
    let icon: String
    let title: String
    let intro: String
    let safeChangesDescription: String
    let whyText: String
    let message: String?
    let isLoading: Bool
    let isApplyingAll: Bool
    let steps: [HermesResearchPackStep]
    let optionalUpgrades: [HermesResearchPackStep]
    let receipts: [String: HermesPackStepReceipt]
    let inFlightStepIDs: Set<String>
    let supportActions: [HermesPackSupportAction]
    let onRefresh: () -> Void
    let onApplyAll: () -> Void
    let onApplyStep: (HermesResearchPackStep) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .semibold))
                        Text(intro)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                if let message, !message.isEmpty {
                    messageBanner(
                        title: message.hasPrefix("Failed") ? "\(title) Failed" : "\(title) Status",
                        message: message,
                        color: message.hasPrefix("Failed") ? .red : .blue
                    )
                }

                if isLoading && steps.isEmpty && optionalUpgrades.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading \(title) state...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    GroupBox("Safe Changes") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(safeChangesDescription)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            ForEach(steps) { step in
                                packStepRow(step)
                            }

                            HStack {
                                Button("Apply Safe Changes") {
                                    onApplyAll()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(steps.filter(\.canRunIndividually).isEmpty || isApplyingAll)

                                Button("Refresh Pack") {
                                    onRefresh()
                                }
                                .disabled(isLoading || isApplyingAll)

                                if isApplyingAll {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    if !optionalUpgrades.isEmpty {
                        GroupBox("External Upgrades") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("These upgrades are useful, but HermesStation will not apply them automatically without your explicit external setup.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                ForEach(optionalUpgrades) { step in
                                    packStepRow(step)
                                }

                                if !supportActions.isEmpty {
                                    HStack {
                                        ForEach(supportActions) { action in
                                            Button(action.title) {
                                                action.action()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    GroupBox("Why This Pack Exists") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(whyText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .frame(width: 760, alignment: .topLeading)
        }
    }

    private func packStepRow(_ step: HermesResearchPackStep) -> some View {
        let receipt = receipts[step.id]
        let inFlight = inFlightStepIDs.contains(step.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(packStepColor(step.state))
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(step.title)
                            .font(.system(size: 12, weight: .medium))
                        badge(step.state.label, color: packStepColor(step.state))
                        if let receipt {
                            badge(receipt.status == .success ? "Receipt" : "Failed", color: receipt.status == .success ? .green : .red)
                        }
                    }
                    Text(step.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)

                if step.canRunIndividually {
                    Button(receipt == nil ? "Run Step" : "Run Again") {
                        onApplyStep(step)
                    }
                    .buttonStyle(.bordered)
                    .disabled(inFlight || isApplyingAll)
                }
            }

            if !step.commandPreview.isEmpty {
                ForEach(step.commandPreview, id: \.self) { command in
                    Text(command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if let receipt {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.summary)
                        .font(.system(size: 10, weight: .medium))
                    Text(relativeTimestamp(receipt.ranAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if !receipt.output.isEmpty && receipt.output != receipt.summary {
                        Text(receipt.output)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .background((receipt.status == .success ? Color.green : Color.red).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if inFlight {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Running \(step.title)...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(packStepColor(step.state).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func packStepColor(_ state: HermesResearchPackStepState) -> Color {
        switch state {
        case .ready: return .green
        case .actionNeeded: return .orange
        case .externalUpgrade: return .blue
        case .warning: return .purple
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func messageBanner(title: String, message: String, color: Color) -> some View {
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

    private func relativeTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
