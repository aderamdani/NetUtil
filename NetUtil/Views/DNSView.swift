import SwiftUI
import Observation

struct DNSView: View {
    var vm: DNSViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var host = ""
    @State private var recordType = DNSRecordType.a
    @State private var server = DNSServer.system
    @State private var showRaw = false
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            dnsMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }
                    
                    if let result = vm.result {
                        statsBarSection(result)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Picker("", selection: $showRaw) {
                                    Text("Structured Records").tag(false)
                                    Text("Raw Output").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                
                                Spacer()
                                if !showRaw {
                                    Text("\(result.records.count) Records Found")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if showRaw {
                                rawOutput
                            } else {
                                recordsTable
                            }
                        }
                    } else if vm.isRunning {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "DNS Lookup") }
    }

    // MARK: - Components

    private var dnsMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .secondary, "Resolving \(vm.lastQuery.isEmpty ? "query" : vm.lastQuery)...") }
            guard let result = vm.result else {
                return ("globe", .secondary, "Enter a domain to perform DNS lookup")
            }
            let n = result.records.count
            let ms = result.queryTimeMs.map { "\($0) ms" } ?? "—"
            if n == 0 { return ("questionmark.circle.fill", .orange, "No records found for \(vm.lastQuery)  —  \(ms)") }
            return ("checkmark.circle.fill", .green, "\(n) record\(n == 1 ? "" : "s") resolved  —  \(ms)  —  via \(result.server)")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private var controlBar: some View {
        ToolControlBar(icon: "globe", title: "DNS Lookup",
                       host: $host, placeholder: "Domain name or IP", textFieldWidth: 190,
                       textFieldAccessibilityLabel: "Target Host Input",
                       history: history, onSubmit: startLookup) {
            HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("", selection: $recordType) {
                            ForEach(DNSRecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        .accessibilityLabel("DNS Record Type")
                        
                        Picker("", selection: $server) {
                            ForEach(DNSServer.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .accessibilityLabel("DNS Server")
                    }

                    if let result = vm.result, !result.records.isEmpty {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveDNSPDF(result: result, host: host) },
                            onExportCSV: {
                                let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: exportCSV(result), defaultName: "NetUtil-DNS-\(host)-\(ts.string(from: Date())).csv", ext: "csv")
                            },
                            onCopySummary: {
                                let n = result.records.count
                                let summary = "Query: \(host)\nType: \(recordType.rawValue)\nServer: \(result.server)\nRecords: \(n)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(summary, forType: .string)
                            }
                        )
                    }

                    Button(action: { vm.isRunning ? vm.stop() : startLookup() }) {
                        Label(vm.isRunning ? "Stop" : "Lookup", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && host.isEmpty)
                    .accessibilityLabel(vm.isRunning ? "Stop Lookup" : "Start Lookup")
                    
                    if !host.isEmpty {
                        let isFav = tools.favorites.isFavorite(host)
                        Button { tools.favorites.toggle(host: host) } label: {
                            Image(systemName: isFav ? "star.fill" : "star").foregroundColor(isFav ? .orange : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                    }

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
        }
    }

    private func statsBarSection(_ r: DNSResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Records Found", value: "\(r.records.count)", icon: "list.bullet.rectangle")
            if let ms = r.queryTimeMs {
                StatCard(title: "Resolution Time", value: "\(ms)", unit: "ms", icon: "timer", color: ms < 50 ? .green : .orange)
            }
            StatCard(title: "Authority Server", value: r.server.components(separatedBy: " ").first ?? "System", icon: "server.rack")
        }
    }

    private var recordsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TableHeader("Resource Name", flexible: true)
                TableHeader("TTL", width: 80)
                TableHeader("Type", width: 80)
                TableHeader("Record Value", flexible: true)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(.regularMaterial)
            
            Divider()
            
            if let res = vm.result {
                LazyVStack(spacing: 0) {
                    ForEach(res.records) { r in
                        HStack(spacing: 0) {
                            Text(r.name)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("\(r.ttl)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            DNSTypeBadge(type: r.type)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(r.value)
                                .font(.system(.caption, design: .monospaced).weight(.medium))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("DNS Record \(r.name). Type \(r.type). TTL \(r.ttl). Value: \(r.value)")
                        
                        if r.value != res.records.last?.value {
                            Divider().padding(.horizontal, 16).opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var rawOutput: some View {
        ScrollView {
            Text(vm.rawOutput)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(minHeight: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Lookup Performed",
                            subtitle: "Enter a domain to resolve its global DNS resource records.")
    }

    private var loadingState: some View {
        ToolStateView.loading(message: "Querying Name Servers...")
    }

    private func startLookup() {
        guard !host.isEmpty, !vm.isRunning else { return }; history.record(host); vm.start(host: host, type: recordType, server: server)
    }

    private func exportCSV(_ result: DNSResult) -> String {
        var lines = ["name,ttl,type,value"]
        for r in result.records { lines.append("\(Exporter.csvField(r.name)),\(r.ttl),\(r.type),\(Exporter.csvField(r.value))") }
        return lines.joined(separator: "\n")
    }
}

private struct DNSTypeBadge: View {
    let type: String
    var body: some View {
        Text(type)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(color)
    }
    
    private var color: Color {
        switch type {
        case "A": return .blue
        case "AAAA": return .purple
        case "MX": return .orange
        case "NS": return .green
        case "CNAME": return .teal
        case "TXT": return .gray
        default: return .secondary
        }
    }
}
