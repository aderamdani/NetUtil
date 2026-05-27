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
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let err = vm.error {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                            Text(err)
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .bold))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if let result = vm.result {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader(result)
                        
                        // 3. STATS BAR
                        statsBar(result)
                        
                        // 4. RESULTS TABLE/RAW
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("", selection: $showRaw) {
                                    Text("Record Table").tag(false)
                                    Text("Raw Output").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                
                                Spacer()
                            }
                            
                            if showRaw {
                                rawOutput
                            } else {
                                recordsTable
                            }
                        }
                    } else if !vm.isRunning {
                        emptyState
                    }
                    
                    if vm.isRunning {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Querying domain name systems...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            dnsLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("Hostname or IP", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("Domain to resolve.")
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

            // 2. Settings Group
            HStack(spacing: 8) {
                Picker("Type", selection: $recordType) {
                    ForEach(DNSRecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Picker("Server", selection: $server) {
                    ForEach(DNSServer.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            Spacer()

            // 3. Action Group
            if let result = vm.result, !result.records.isEmpty {
                Menu {
                    Button("Copy All Values") {
                        let values = result.records.map { $0.value }.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(values, forType: .string)
                    }
                    Divider()
                    Button("Export CSV") {
                        Exporter.save(string: exportCSV(result), defaultName: "dns-\(host).csv", ext: "csv")
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: startLookup) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Lookup")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("DNS Learning Guide")
        }
    }
    
    private func interpretationHeader(_ r: DNSResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let hasRecords = !r.records.isEmpty
            Image(systemName: hasRecords ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(hasRecords ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hasRecords ? "Resolved Successfully" : "No Records Found")
                    .font(.headline)
                Text(hasRecords ? "DNS records retrieved from \(r.server)." : "The query returned no results for the requested type.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func statsBar(_ r: DNSResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "RECORDS", value: "\(r.records.count)", icon: "list.bullet.rectangle")
            if let ms = r.queryTimeMs {
                StatCard(title: "QUERY TIME", value: "\(ms)", unit: "ms", icon: "timer", color: ms < 50 ? .green : .orange)
            }
            StatCard(title: "AUTH SERVER", value: r.server.components(separatedBy: " ").first ?? "Local", icon: "server.rack")
            Spacer()
        }
    }

    private var recordsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("Name", flexible: true)
                headerCell("TTL", width: 80)
                headerCell("Type", width: 80)
                headerCell("Value", flexible: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(.windowBackgroundColor))
            
            Divider()

            ScrollView {
                if let result = vm.result, !result.records.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(result.records, id: \.value) { r in
                            HStack(spacing: 0) {
                                Text(r.name)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("\(r.ttl)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(r.type)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(typeColor(r.type))
                                    .cornerRadius(4)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(r.value)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            
                            Divider().opacity(0.2)
                        }
                    }
                }
            }
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }

    private var rawOutput: some View {
        ScrollView {
            Text(vm.rawOutput.isEmpty ? "No output yet" : vm.rawOutput)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .textSelection(.enabled)
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "globe").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready to query DNS records. Enter a domain and press Lookup.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }
    
    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.secondary)
            .kerning(1)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func startLookup() {
        guard !host.isEmpty, !vm.isRunning else { return }
        history.record(host)
        vm.lookup(host: host, type: recordType, server: server)
    }

    private func exportCSV(_ result: DNSResult) -> String {
        var lines = ["name,ttl,type,value"]
        for r in result.records {
            lines.append("\(r.name),\(r.ttl),\(r.type),\"\(r.value)\"")
        }
        return lines.joined(separator: "\n")
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "A":     return .blue
        case "AAAA":  return .purple
        case "MX":    return .orange
        case "NS":    return .green
        case "CNAME": return .teal
        case "TXT":   return .secondary
        default:      return .gray
        }
    }

    private var dnsLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DNS Learning Guide").font(.title2.bold())
                    Text("Learn how domain resolution works.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is DNS?", icon: "globe") {
                        Text("The Domain Name System (DNS) is the phonebook of the Internet. It translates human-readable domain names (like google.com) into machine-readable IP addresses.")
                    }
                    
                    GuideSection(title: "Common Record Types", icon: "list.bullet") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "A / AAAA", desc: "Maps a domain to an IPv4 (A) or IPv6 (AAAA) address.")
                            GuidePoint(title: "MX (Mail Exchange)", desc: "Directs email to a mail server.")
                            GuidePoint(title: "CNAME", desc: "Aliases one domain to another.")
                            GuidePoint(title: "NS (Name Server)", desc: "Specifies which servers are authoritative for a domain.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}
