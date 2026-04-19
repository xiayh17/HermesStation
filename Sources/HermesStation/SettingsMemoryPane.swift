import SwiftUI

struct SettingsMemoryPane: View {
    let entries: [MemoryCatalogEntry]
    let sourceOptions: [String]
    @Binding var sourceFilter: String
    @Binding var searchText: String
    let filteredEntries: [MemoryCatalogEntry]
    @Binding var selectedEntryID: String?
    let selectedEntry: MemoryCatalogEntry?
    let isLoading: Bool
    let onReload: () -> Void
    let onOpenPath: (URL) -> Void
    let formatTimestamp: (Date?) -> String

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
                summaryPill(title: "Entries", value: "\(entries.count)")
                summaryPill(title: "Sources", value: "\(sourceOptions.count)")
                Spacer()
                Button {
                    onReload()
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

            Picker("Source", selection: $sourceFilter) {
                Text("All").tag("All")
                ForEach(sourceOptions, id: \.self) { source in
                    Text(source).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            TextField("Fuzzy search memory title / content / source", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 12)
            }

            List(selection: $selectedEntryID) {
                ForEach(filteredEntries) { entry in
                    memoryRow(entry)
                        .tag(entry.id)
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
        if let entry = selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 18, weight: .semibold))
                            Text(entry.fileURL.lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        memorySourceBadge(entry.source)
                    }

                    GroupBox("Actions") {
                        HStack {
                            Button("Open File") {
                                onOpenPath(entry.fileURL)
                            }
                            Button("Open Folder") {
                                onOpenPath(entry.fileURL.deletingLastPathComponent())
                            }
                            Button("Refresh") {
                                onReload()
                            }
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow("Source", entry.source)
                            detailRow("Path", entry.fileURL.path)
                            detailRow("Updated", formatTimestamp(entry.modifiedAt))
                            detailRow("Preview", entry.preview)
                        }
                        .padding(.top, 4)
                    }

                    GroupBox("Content") {
                        Text(entry.body)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No memory entry selected")
                    .font(.system(size: 18, weight: .semibold))
                Text("Pick a memory item from the left to inspect persisted notes for the active Hermes profile.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func memoryRow(_ entry: MemoryCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                memorySourceBadge(entry.source)
            }
            Text(entry.preview)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(formatTimestamp(entry.modifiedAt))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
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

    private func memorySourceBadge(_ source: String) -> some View {
        Text(source)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((source == "USER" ? Color.blue : Color.secondary).opacity(0.12))
            .foregroundStyle(source == "USER" ? Color.blue : Color.secondary)
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
}
