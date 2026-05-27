import SwiftUI
import Combine

struct PortScanView: View {
    @ObservedObject var vm: PortScanViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var preset = PortPreset.common
    @State private var customRange = "1-1024"
    @AppStorage("portScanConcurrency") private var defaultConcurrency = 50
    @AppStorage("portScanTimeout")     private var defaultTimeout     = 1.5
    @State private var concurrency = 50
    @State private var timeout = 1.5
    @State private var showOnlyOpen = false
    @State private var showLearningGuide = false
    @State private var tick = 0

    private var portsToScan: [Int] {
        if let p = preset.ports { return p }
        return parseRange(customRange)
    }

    private var displayResults: [PortResult] {
        let sorted = vm.results.sorted { $0.port < $1.port }
        return showOnlyOpen ? sorted.filter { $0.status == .open } : sorted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar
                .padding(.bottom, 24)
            
            if let err = vm.error {
                errorBanner(err).padding(.bottom, 16)
            }
            
            if vm.total > 0 || !vm.results.isEmpty {
                statsBar.padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        sectionHeader("Audit Results")
                        Spacer()
                        if vm.total > 0 {
                            let progress = Double(vm.scanned) / Double(max(vm.total, 1))
                            HStack(spacing: 8) {
                                Text("\(Int(progress * 100))%").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                                ProgressView(value: progress).progressViewStyle(.linear).frame(width: 80)
                            }
                        }
                    }
                    
                    HStack {
                        Toggle("Open Only", isOn: $showOnlyOpen)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.checkbox)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    resultsGrid
                }
                .frame(maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .padding(32)
        .onAppear {
            concurrency = defaultConcurrency
            timeout = defaultTimeout
        }
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .onSubmit(startAction)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { host = h; startAction() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }
                        .menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Picker("", selection: $preset) { ForEach(PortPreset.allCases) { p in Text(p.rawValue).tag(p) } }
                .pickerStyle(.menu).frame(width: 110)

                if preset == .custom {
                    TextField("Range...", text: $customRange).textFieldStyle(.roundedBorder).frame(width: 100)
                }

                HStack(spacing: 4) {
                    Text("Threads:").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Stepper("\(concurrency)", value: $concurrency, in: 1...200).frame(width: 80)
                }
            }

            Spacer()

            if !vm.results.isEmpty {
                Menu {
                    Button("Export CSV") { exportCSV(vm.results.sorted { $0.port < $1.port }) }
                } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                    Text(vm.isRunning ? "Stop" : "Scan")
                }
                .font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }.buttonStyle(.borderedProminent).tint(vm.isRunning ? .red : .accentColor).disabled(!vm.isRunning && (host.isEmpty || portsToScan.isEmpty))
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Scanned", value: "\(vm.scanned)", icon: "checklist")
            StatCard(title: "Open Ports", value: "\(vm.openCount)", icon: "lock.open.fill", color: vm.openCount > 0 ? .green : .primary)
            StatCard(title: "Filtered", value: "\(vm.scanned - vm.openCount)", icon: "lock.shield.fill", color: .secondary)
            Spacer()
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(displayResults) { r in PortResultCard(result: r) }
            }
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private func errorBanner(_ msg: String) -> some View { Text(msg).foregroundColor(.red).font(.system(size: 12, weight: .medium)) }

    private var emptyState: some View {
        VStack { Spacer(); Text("No Target Selected").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty, !portsToScan.isEmpty else { return }; history.record(host); vm.scan(host: host, ports: portsToScan, concurrency: concurrency, timeout: timeout) }
    }

    private func exportCSV(_ rows: [PortResult]) {
        var lines = ["port,service,status,response_ms"]
        for r in rows { lines.append("\(r.port),\(r.service ?? ""),\(r.status.label),\(r.responseMs.map { String(format: "%.1f", $0) } ?? "")") }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        Exporter.save(string: lines.joined(separator: "\n"), defaultName: "portscan-\(host)-\(f.string(from: Date())).csv", ext: "csv")
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Scanner Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is a Port?", icon: "door.right.hand.open") { Text("Virtual doors used by services.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
    
    private func parseRange(_ input: String) -> [Int] {
        var ports: Set<Int> = []
        for token in input.components(separatedBy: ",") {
            let t = token.trimmingCharacters(in: .whitespaces)
            if let s = Int(t), (1...65535).contains(s) { ports.insert(s) }
            else {
                let parts = t.components(separatedBy: "-")
                if parts.count == 2, let lo = Int(parts[0]), let hi = Int(parts[1]), lo <= hi { (max(1, lo)...min(65535, hi)).forEach { ports.insert($0) } }
            }
        }
        return ports.sorted()
    }
}

struct PortResultCard: View {
    let result: PortResult
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("\(result.port)").font(.system(size: 14, weight: .semibold, design: .monospaced))
                Spacer()
                Circle().fill(statusColor).frame(width: 6, height: 6)
            }
            Text(result.service ?? "Unknown").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
            if let ms = result.responseMs { Text(String(format: "%.1f ms", ms)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    private var statusColor: Color { switch result.status { case .open: .green; case .closed: .secondary; case .filtered: .orange } }
}
