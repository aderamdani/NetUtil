import SwiftUI

struct DNSView: View {
    @ObservedObject var vm: DNSViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var recordType = DNSRecordType.a
    @State private var server = DNSServer.system
    @State private var showRaw = false
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
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

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("DNS Lookup")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    TextField("Domain name or IP", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .frame(width: 250)
                        .onSubmit(startLookup)
                        .overlay(alignment: .trailing) {
                            if !history.hosts.isEmpty {
                                Menu {
                                    ForEach(history.hosts, id: \.self) { h in
                                        Button(h) { host = h; startLookup() }
                                    }
                                    Divider()
                                    Button("Clear History", role: .destructive) { history.clear() }
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.secondary)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 28)
                                .padding(.trailing, 4)
                            }
                        }

                    HStack(spacing: 8) {
                        Picker("", selection: $recordType) {
                            ForEach(DNSRecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        
                        Picker("", selection: $server) {
                            ForEach(DNSServer.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    if let result = vm.result, !result.records.isEmpty {
                        Menu {
                            Button("Copy All Values") {
                                let val = result.records.map { $0.value }.joined(separator: "\n")
                                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(val, forType: .string)
                            }
                            Button("Export CSV") { Exporter.save(string: exportCSV(result), defaultName: "dns-\(host).csv", ext: "csv") }
                        } label: {
                            Label("Report", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: startLookup) {
                        Label(vm.isRunning ? "Stop" : "Lookup", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && host.isEmpty)
                    
                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
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
                tHeader("Resource Name", flexible: true)
                tHeader("TTL", width: 80)
                tHeader("Type", width: 80)
                tHeader("Record Value", flexible: true)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            if let res = vm.result {
                LazyVStack(spacing: 0) {
                    ForEach(res.records, id: \.value) { r in
                        HStack(spacing: 0) {
                            Text(r.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("\(r.ttl)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            DNSTypeBadge(type: r.type)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(r.value)
                                .font(.system(size: 11, design: .monospaced).weight(.medium))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 16)
                        
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
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(minHeight: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Lookup Performed")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a domain to resolve its global DNS resource records.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Querying Name Servers...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func startLookup() {
        guard !host.isEmpty, !vm.isRunning else { return }; history.record(host); vm.lookup(host: host, type: recordType, server: server)
    }

    private func exportCSV(_ result: DNSResult) -> String {
        var lines = ["name,ttl,type,value"]
        for r in result.records { lines.append("\(r.name),\(r.ttl),\(r.type),\"\(r.value)\"") }
        return lines.joined(separator: "\n")
    }
}

private struct DNSTypeBadge: View {
    let type: String
    var body: some View {
        Text(type)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
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
