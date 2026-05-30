import SwiftUI
import Combine
import Observation

struct PortScanView: View {
    var vm: PortScanViewModel
    @State private var history = HostHistory.shared
    @State private var host = ""
    @State private var preset = PortPreset.common
    @State private var customRange = "1-1024"
    @AppStorage("portScanConcurrency") private var defaultConcurrency = 50
    @AppStorage("portScanTimeout")     private var defaultTimeout     = 1.5
    @State private var concurrency = 50
    @State private var timeout = 1.5
    @State private var showOnlyOpen = false
    @State private var showLearningGuide = false

    private var portsToScan: [Int] {
        if let p = preset.ports { return p }
        return parseRange(customRange)
    }

    private var displayResults: [PortResult] {
        let sorted = vm.results.sorted { $0.port < $1.port }
        return showOnlyOpen ? sorted.filter { $0.status == .open } : sorted
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if vm.total > 0 || !vm.results.isEmpty {
                        statsBarSection
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Audit Results")
                                        .font(.headline)
                                    Text("Status of targeted network ports")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if vm.total > 0 {
                                    scanProgressView
                                }
                            }
                            
                            HStack {
                                Toggle("Open Only", isOn: $showOnlyOpen)
                                    .font(.subheadline)
                                    .toggleStyle(.checkbox)
                                Spacer()
                                Text("\(displayResults.count) Ports Displayed")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                            }
                            
                            resultsGrid
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
        .onAppear {
            concurrency = defaultConcurrency
            timeout = defaultTimeout
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Port Scanner") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Port Scanner")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Hostname or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(startAction)
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { host = h; startAction() }
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

                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("", selection: $preset) {
                            ForEach(PortPreset.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)

                        if preset == .custom {
                            TextField("Range...", text: $customRange)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }

                        HStack(spacing: 4) {
                            Text("Threads")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.secondary)
                            Stepper("\(concurrency)", value: $concurrency, in: 1...200)
                                .frame(width: 80)
                        }
                    }

                    if !vm.results.isEmpty {
                        Button { exportCSV(vm.results.sorted { $0.port < $1.port }) } label: {
                            Label("Report", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: startAction) {
                        Label(vm.isRunning ? "Stop" : "Scan", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && (host.isEmpty || portsToScan.isEmpty))
                    
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

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Ports Scanned", value: "\(vm.scanned)", icon: "checklist")
            StatCard(title: "Open Ports", value: "\(vm.openCount)", icon: "lock.open.fill", color: vm.openCount > 0 ? .green : .primary)
            StatCard(title: "Filtered", value: "\(vm.scanned - vm.openCount)", icon: "lock.shield.fill", color: .secondary)
        }
    }

    private var scanProgressView: some View {
        let progress = Double(vm.scanned) / Double(max(vm.total, 1))
        return HStack(spacing: 12) {
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 100)
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(displayResults) { r in
                PortResultCard(result: r)
            }
        }
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
            Text("No Target Audited")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a host and select a port range to begin discovery.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning Network Ports...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("\(result.port)")
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                PortStatusBadge(status: result.status)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.service ?? "Unknown Service")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let ms = result.responseMs {
                    Text(String(format: "%.1f ms", ms))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}

private struct PortStatusBadge: View {
    let status: PortStatus
    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private var color: Color {
        switch status {
        case .open: .green
        case .closed: .secondary
        case .filtered: .orange
        }
    }
}
