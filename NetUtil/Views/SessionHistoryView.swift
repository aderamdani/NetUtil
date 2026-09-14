import SwiftUI

struct SessionHistoryView: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?
    @State private var filterTool: String = "All"
    @State private var filterDate: DateFilter = .all
    @State private var searchText = ""
    @State private var showLearningGuide = false
    @State private var showClearConfirm = false

    private var history: SessionHistory { tools.sessionHistory }

    enum DateFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case week  = "Week"
        case all   = "All"
        var id: String { rawValue }
    }

    private var availableTools: [String] {
        let all = Set(history.records.map { $0.tool })
        return ["All"] + all.sorted()
    }

    private var filtered: [SessionRecord] {
        history.records.filter { record in
            let toolMatch = filterTool == "All" || record.tool == filterTool
            let searchMatch = searchText.isEmpty || record.target.localizedCaseInsensitiveContains(searchText)
            let dateMatch: Bool
            switch filterDate {
            case .today:
                dateMatch = Calendar.current.isDateInToday(record.timestamp)
            case .week:
                let week = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                dateMatch = record.timestamp >= week
            case .all:
                dateMatch = true
            }
            return toolMatch && searchMatch && dateMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            historyMoodBar

            if history.records.isEmpty {
                emptyState
            } else {
                recordsList
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Session History") }
        .alert("Clear All History", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) { history.clear() }
        } message: {
            Text("This will permanently delete all \(history.records.count) session records.")
        }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Session History")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Session History Tool")

                Divider().frame(height: 16).padding(.horizontal, Metrics.spacingXS)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
                    TextField("Filter by host...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .frame(width: 140)
                        .accessibilityLabel("Filter by host")
                }
                .padding(.horizontal, Metrics.spacingSM).padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))

                Spacer()

                HStack(spacing: Metrics.spacingMD) {
                    Picker("Tool", selection: $filterTool) {
                        ForEach(availableTools, id: \.self) { Text(toolLabel($0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .accessibilityLabel("Filter by tool")

                    Picker("Date", selection: $filterDate) {
                        ForEach(DateFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                    .accessibilityLabel("Filter by date range")

                    ReportMenuButton(
                        onExportPDF: { Exporter.saveSessionHistoryPDF(records: filtered) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: history.csvString(for: filtered),
                                          defaultName: "NetUtil-SessionHistory-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )

                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .disabled(history.records.isEmpty)
                    .accessibilityLabel("Clear all session history")

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, Metrics.spacingXL).padding(.vertical, Metrics.spacingLG)
            Divider()
        }
    }

    private var historyMoodBar: some View {
        let n = history.records.count
        let msg: String = n == 0 ? "No sessions recorded yet" : "\(n) session\(n == 1 ? "" : "s") recorded  —  \(filtered.count) shown"
        return MoodBar(icon: "clock.fill", color: .accentColor, message: msg)
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { record in
                    SessionRecordRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture { navigate(to: record) }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.rowAccessibilityLabel(
                            tool: SessionToolNames.label(record.tool),
                            target: record.target,
                            status: record.status.rawValue.capitalized,
                            summary: record.summary,
                            time: record.timestamp.formatted(date: .omitted, time: .standard)))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Open this session's tool")
                        .contextMenu {
                            Button(role: .destructive) { history.remove(id: record.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if record.id != filtered.last?.id {
                        Divider().padding(.horizontal, Metrics.spacingXL).opacity(0.5)
                    }
                }
            }
            .padding(.vertical, Metrics.spacingLG)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .padding(Metrics.spacingXL)
        }
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Sessions Yet",
                            subtitle: "Run any tool to start logging.")
            .frame(maxHeight: .infinity)
    }

    private func navigate(to record: SessionRecord) {
        guard let tool = Tool(persistenceKey: record.tool) else { return }
        setQuickLaunch(host: record.target, tool: tool)
        selection = tool
    }

    private func setQuickLaunch(host: String, tool: Tool) {
        switch tool {
        case .ping:      tools.ping.quickLaunchHost = host
        case .traceroute: tools.traceroute.quickLaunchHost = host
        case .portScan:  tools.portScan.quickLaunchHost = host
        default: break
        }
    }

    private func toolLabel(_ key: String) -> String {
        key == "All" ? "All Tools" : SessionToolNames.label(key)
    }

    /// VoiceOver label for a session row — pure, so the spacing/pluralization
    /// is unit-tested without rendering the view.
    static func rowAccessibilityLabel(tool: String, target: String, status: String,
                                      summary: String, time: String) -> String {
        "\(tool) session for \(target). Status \(status). \(summary). Recorded at \(time)."
    }
}

/// Shared mapping from SessionRecord.tool keys to display metadata.
/// Keys are `Tool.persistenceKey`; unknown keys pass through untouched.
enum SessionToolNames {
    static func label(_ key: String) -> String {
        Tool(persistenceKey: key)?.displayName ?? key
    }

    static func icon(_ key: String) -> String {
        Tool(persistenceKey: key)?.icon ?? "network"
    }
}

// MARK: - Row

private struct SessionRecordRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: Metrics.spacingMD) {
            Image(systemName: toolIcon(record.tool))
                .foregroundColor(statusColor)
                .frame(width: 20)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.spacingSM) {
                    Text(toolLabel(record.tool)).font(.caption2.weight(.bold)).foregroundColor(.secondary)
                    Text(record.target).font(.subheadline.monospaced()).lineLimit(1)
                }
                Text(record.summary).font(.caption2.monospaced()).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            HStack(spacing: 2) {
                Text(record.timestamp, style: .time).font(.caption2.monospaced()).foregroundColor(.secondary).lineLimit(1)
            }

            statusBadge
        }
        .padding(.horizontal, Metrics.spacingXL)
        .padding(.vertical, Metrics.spacingSM)
    }

    private var statusColor: Color {
        switch record.status {
        case .success: return .green
        case .partial:  return .orange
        case .failed:   return .red
        }
    }

    private var statusBadge: some View {
        Text(record.status.rawValue.capitalized)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .foregroundColor(statusColor)
    }

    private func toolIcon(_ key: String) -> String {
        SessionToolNames.icon(key)
    }

    private func toolLabel(_ key: String) -> String {
        SessionToolNames.label(key)
    }
}
