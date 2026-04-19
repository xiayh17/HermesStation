import SwiftUI

struct SettingsAgentSessionsPane: View {
    let activeCount: Int
    let trackedCount: Int
    let boundCount: Int
    let liveCountText: String
    @Binding var filter: AgentPanelFilter
    @Binding var searchText: String
    let isLoadingSearchIndex: Bool
    let filteredBoundAgents: [AgentSessionRow]
    let filteredUnboundAgents: [AgentSessionRow]
    @Binding var selectedAgentID: String?
    let selectedAgent: AgentSessionRow?
    let bindingForAgentID: (String) -> SessionBindingEntry?
    let selectedBindingEntry: SessionBindingEntry?
    let selectedTranscript: SessionTranscript?
    let isLoadingTranscript: Bool
    @Binding var agentRenameDraft: String
    let isBusy: Bool
    let formatBindingTimestamp: (Date?) -> String
    let onRename: (AgentSessionRow, String) -> Void
    let onOpenTranscript: (AgentSessionRow) -> Void
    let onOpenLogExcerpt: (AgentSessionRow) -> Void
    let onExport: (AgentSessionRow) -> Void
    let onDelete: () -> Void
    let onFocusPlatform: (String) -> Void
    let onSubmitPendingAction: (String, String) -> Void

    @State private var hoveredAgentPreviewID: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                summaryPill(title: "Active", value: "\(activeCount)")
                summaryPill(title: "Tracked", value: "\(trackedCount)")
                summaryPill(title: "Bound", value: "\(boundCount)")
                summaryPill(title: "Live", value: liveCountText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Picker("Filter", selection: $filter) {
                ForEach(AgentPanelFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            TextField("Fuzzy search title / id / source / model / transcript", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            if isLoadingSearchIndex {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing transcript content for fuzzy search...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }

            List(selection: $selectedAgentID) {
                if !filteredBoundAgents.isEmpty {
                    Section("Bound Sessions") {
                        ForEach(filteredBoundAgents) { agent in
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
                }

                if !filteredUnboundAgents.isEmpty {
                    Section(filteredBoundAgents.isEmpty ? "Sessions" : "Other Sessions") {
                        ForEach(filteredUnboundAgents) { agent in
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
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detailPanel: some View {
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
                    }

                    GroupBox("Actions") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Session title", text: $agentRenameDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Rename") {
                                    onRename(agent, agentRenameDraft)
                                }
                                .disabled(isBusy || agentRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            HStack {
                                Button("Open Transcript") {
                                    onOpenTranscript(agent)
                                }
                                Button("Open Log Excerpt") {
                                    onOpenLogExcerpt(agent)
                                }
                                Button("Export JSONL") {
                                    onExport(agent)
                                }
                                Button("Delete") {
                                    onDelete()
                                }
                                .foregroundStyle(.red)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let binding = selectedBindingEntry {
                        GroupBox("Binding") {
                            VStack(alignment: .leading, spacing: 10) {
                                detailRow("Platform", binding.resolvedPlatformID)
                                detailRow("Session Key", binding.sessionKey)
                                detailRow("Bound To", binding.displayLabel)
                                if !binding.displaySubtitle.isEmpty {
                                    detailRow("Context", binding.displaySubtitle)
                                }
                                detailRow("Updated", formatBindingTimestamp(binding.updatedAtDate))

                                HStack {
                                    Button("Show Platform") {
                                        onFocusPlatform(binding.resolvedPlatformID)
                                    }
                                    Button("Reset Binding") {
                                        onSubmitPendingAction("reset_session", binding.sessionKey)
                                    }
                                    Button("Clear Model Binding") {
                                        onSubmitPendingAction("clear_model_override", binding.sessionKey)
                                    }
                                    Button("Evict Cached Agent") {
                                        onSubmitPendingAction("evict_agent", binding.sessionKey)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    GroupBox("Conversation") {
                        VStack(alignment: .leading, spacing: 12) {
                            if isLoadingTranscript {
                                ProgressView()
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else if let transcript = selectedTranscript {
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

    private func agentRow(_ agent: AgentSessionRow) -> some View {
        let binding = bindingForAgentID(agent.id)
        return HStack(alignment: .top, spacing: 10) {
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
                if let binding {
                    HStack(spacing: 6) {
                        statusBadge(binding.resolvedPlatformID, color: .blue)
                        Text(binding.displayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
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

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
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

    private func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
