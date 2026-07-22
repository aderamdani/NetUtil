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
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Session History")
                        .font(.headline)
                }

                Divider().frame(height: 16).padding(.horizontal, 4)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
                    TextField("Filter by host...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .frame(width: 180)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))

                Spacer()

                HStack(spacing: 12) {
                    Picker("Tool", selection: $filterTool) {
                        ForEach(availableTools, id: \.self) { Text(toolLabel($0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)

                    Picker("Date", selection: $filterDate) {
                        ForEach(DateFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)

                    ReportMenuButton(
                        onExportPDF: { Exporter.saveSessionHistoryPDF(records: history.records) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: history.csvString(),
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

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
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
                        .contextMenu {
                            Button(role: .destructive) { history.remove(id: record.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if record.id != filtered.last?.id {
                        Divider().padding(.horizontal, 20).opacity(0.5)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .padding(24)
        }
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Sessions Recorded",
                            subtitle: "Run any tool to start logging.")
            .frame(maxHeight: .infinity)
    }

    private func navigate(to record: SessionRecord) {
        guard let tool = Tool(rawValue: record.tool) ?? toolFromKey(record.tool) else { return }
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

    private func toolFromKey(_ key: String) -> Tool? {
        switch key {
        case "ping":        return .ping
        case "traceroute":  return .traceroute
        case "portScan":    return .portScan
        case "dns":         return .dns
        case "whois":       return .whois
        case "ssl":         return .ssl
        case "httpLatency": return .httpLatency
        case "speedTest":   return .speedTest
        default:            return nil
        }
    }

    private func toolLabel(_ key: String) -> String {
        key == "All" ? "All Tools" : SessionToolNames.label(key)
    }
}

/// Shared mapping from SessionRecord.tool keys to display metadata.
enum SessionToolNames {
    static func label(_ key: String) -> String {
        switch key {
        case "ping":        return "Ping"
        case "traceroute":  return "Traceroute"
        case "portScan":    return "Port Scanner"
        case "dns":         return "DNS Lookup"
        case "whois":       return "WHOIS"
        case "ssl":         return "SSL/TLS"
        case "httpLatency": return "HTTP Latency"
        case "speedTest":   return "Speed Test"
        default:            return key
        }
    }

    static func icon(_ key: String) -> String {
        switch key {
        case "ping":        return "antenna.radiowaves.left.and.right"
        case "traceroute":  return "point.3.connected.trianglepath.dotted"
        case "portScan":    return "checklist"
        case "dns":         return "globe"
        case "whois":       return "magnifyingglass.circle"
        case "ssl":         return "lock.shield"
        case "httpLatency": return "stopwatch"
        case "speedTest":   return "speedometer"
        default:            return "network"
        }
    }
}

// MARK: - Row

private struct SessionRecordRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toolIcon(record.tool))
                .foregroundColor(statusColor)
                .frame(width: 20)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(toolLabel(record.tool)).font(.caption2.weight(.bold)).foregroundColor(.secondary)
                    Text(record.target).font(.system(.subheadline, design: .monospaced)).lineLimit(1)
                }
                Text(record.summary).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.timestamp, style: .time).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                Text(record.timestamp, style: .date).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
            }

            statusBadge
        }
        .padding(.vertical, 6)
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
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(statusColor)
    }

    private func toolIcon(_ key: String) -> String {
        SessionToolNames.icon(key)
    }

    private func toolLabel(_ key: String) -> String {
        SessionToolNames.label(key)
    }
}
