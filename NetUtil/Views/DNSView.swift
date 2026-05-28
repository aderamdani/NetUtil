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
            controlBar.padding(.bottom, 24)
            
            if let err = vm.error {
                errorBanner(err).padding(.bottom, 16)
            }
            
            if let result = vm.result {
                statsBar(result).padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("", selection: $showRaw) { Text("Data").tag(false); Text("Raw").tag(true) }.pickerStyle(.segmented).frame(width: 150)
                        Spacer()
                    }
                    
                    if showRaw { rawOutput } else { recordsTable }
                }
                .frame(maxHeight: .infinity)
            } else if vm.isRunning {
                loadingState
            } else {
                emptyState
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { dnsLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Domain name or IP", text: $host)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(width: 250).onSubmit(startLookup)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { host = h; startLookup() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }.menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Picker("", selection: $recordType) { ForEach(DNSRecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).frame(width: 90)
                Picker("", selection: $server) { ForEach(DNSServer.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).frame(width: 150)
            }

            Spacer()

            if let result = vm.result, !result.records.isEmpty {
                Menu {
                    Button("Copy All Values") {
                        let val = result.records.map { $0.value }.joined(separator: "\n")
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(val, forType: .string)
                    }
                    Button("Export CSV") { Exporter.save(string: exportCSV(result), defaultName: "dns-\(host).csv", ext: "csv") }
                } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: startLookup) {
                HStack(spacing: 6) { Image(systemName: vm.isRunning ? "stop.fill" : "play.fill"); Text(vm.isRunning ? "Stop" : "Lookup") }.font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }.buttonStyle(.borderedProminent).tint(vm.isRunning ? .red : .accentColor).disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }

    private var recordsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Name", flexible: true)
                tHeader("TTL", width: 70)
                tHeader("Type", width: 70)
                tHeader("Value", flexible: true)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            Divider()
            ScrollView {
                if let res = vm.result {
                    LazyVStack(spacing: 0) {
                        ForEach(res.records, id: \.value) { r in
                            HStack(spacing: 0) {
                                Text(r.name).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(r.ttl)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
                                Text(r.type).font(.system(size: 10, weight: .semibold)).foregroundColor(typeColor(r.type)).padding(.horizontal, 6).padding(.vertical, 2).background(typeColor(r.type).opacity(0.1)).cornerRadius(4).frame(width: 70, alignment: .leading)
                                Text(r.value).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var rawOutput: some View {
        ScrollView {
            Text(vm.rawOutput).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func statsBar(_ r: DNSResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Records", value: "\(r.records.count)", icon: "list.bullet.rectangle")
            if let ms = r.queryTimeMs { StatCard(title: "Query Time", value: "\(ms)", unit: "ms", icon: "timer", color: ms < 50 ? .green : .orange) }
            StatCard(title: "Server", value: r.server.components(separatedBy: " ").first ?? "System", icon: "server.rack")
            Spacer()
        }
    }
    
    private func typeColor(_ type: String) -> Color {
        switch type { case "A": return .blue; case "AAAA": return .purple; case "MX": return .orange; case "NS": return .green; case "CNAME": return .teal; default: return .primary }
    }

    private func errorBanner(_ msg: String) -> some View { Text(msg).foregroundColor(.red).font(.system(size: 12, weight: .medium)) }

    private var emptyState: some View {
        VStack { Spacer(); Text("No Target Selected").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack { Spacer(); ProgressView(); Text("Querying DNS records...").font(.subheadline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startLookup() {
        guard !host.isEmpty, !vm.isRunning else { return }; history.record(host); vm.lookup(host: host, type: recordType, server: server)
    }

    private func exportCSV(_ result: DNSResult) -> String {
        var lines = ["name,ttl,type,value"]
        for r in result.records { lines.append("\(r.name),\(r.ttl),\(r.type),\"\(r.value)\"") }
        return lines.joined(separator: "\n")
    }

    private var dnsLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("DNS Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is DNS?", icon: "globe") { Text("The phonebook of the Internet, translating names to IPs.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}
