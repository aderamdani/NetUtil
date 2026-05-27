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
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
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
            // STANDARD HEADER (Fixed Top)
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
                    
                    if vm.total > 0 || !vm.results.isEmpty {
                        interpretationHeader
                        
                        statsBar
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("AUDIT RESULTS")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                
                                Spacer()
                                
                                Toggle("SHOW OPEN ONLY", isOn: $showOnlyOpen)
                                    .font(.system(size: 9, weight: .bold))
                                    .toggleStyle(.checkbox)
                            }
                            
                            resultsGrid
                        }
                    } else {
                        emptyState
                    }
                }
            }
        }
        .padding(32)
        .onReceive(timer) { _ in tick += 1 }
        .onAppear {
            concurrency = defaultConcurrency
            timeout = defaultTimeout
        }
        .sheet(isPresented: $showLearningGuide) {
            learningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("Target host to audit.")
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

            // 2. Variable Settings
            Picker("", selection: $preset) {
                ForEach(PortPreset.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            if preset == .custom {
                TextField("Range...", text: $customRange)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }

            HStack(spacing: 4) {
                Text("Threads:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Stepper("\(concurrency)", value: $concurrency, in: 1...200)
                    .frame(width: 90)
            }

            Spacer()

            // 3. Action Group
            if !vm.results.isEmpty {
                Menu {
                    Button("Export as PDF Report...") {
                        // Future implementation
                    }
                    Divider()
                    Button("Export All (CSV)") {
                        exportCSV(vm.results.sorted { $0.port < $1.port })
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Start Scan")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && (host.isEmpty || portsToScan.isEmpty))
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Port Scanner Learning Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let interpretation = interpretScanStatus()
            Image(systemName: interpretation.icon)
                .font(.title2)
                .foregroundColor(interpretation.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(interpretation.status)
                    .font(.headline)
                Text(interpretation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if vm.total > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    let progress = Double(vm.scanned) / Double(max(vm.total, 1))
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .frame(width: 150)
                    
                    Text("\(Int(progress * 100))% Complete")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "TOTAL SCANNED", value: "\(vm.scanned)", icon: "checklist")
            StatCard(title: "OPEN PORTS", value: "\(vm.openCount)", icon: "lock.open.fill", color: vm.openCount > 0 ? .green : .secondary)
            StatCard(title: "FILTERED/CLOSED",
                     value: "\(vm.scanned - vm.openCount)",
                     icon: "lock.shield.fill",
                     color: .secondary)
            Spacer()
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
            ForEach(displayResults) { r in
                PortResultCard(result: r)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "checklist").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready for security audit. Enter a target host and select a port preset to begin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }
    
    private func interpretScanStatus() -> (status: String, description: String, icon: String, color: Color) {
        if vm.isRunning {
            return ("Auditing", "Actively probing network interfaces for exposed services.", "shield.lefthalf.filled", .accentColor)
        } else if vm.openCount > 5 {
            return ("High Exposure", "Multiple open ports detected. Review your firewall settings.", "exclamationmark.shield.fill", .red)
        } else if vm.openCount > 0 {
            return ("Services Detected", "Target host is listening on specific ports.", "lock.open.fill", .orange)
        } else if vm.total > 0 {
            return ("Secure / Stealth", "No common open ports found on the target host.", "checkmark.shield.fill", .green)
        } else {
            return ("System Ready", "Awaiting target infrastructure identification.", "terminal.fill", .secondary)
        }
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Port Scanner Learning Guide").font(.title2.bold())
                    Text("Learn how to audit network services and security.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is a Port?", icon: "door.right.hand.open") {
                        Text("Ports are virtual doors on a computer. Each port (from 1 to 65535) can be used by a different service, like 80 for websites (HTTP) or 22 for secure logins (SSH).")
                    }
                    
                    GuideSection(title: "Understanding Status", icon: "shield.lefthalf.filled") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "OPEN", desc: "The service is listening and accepting connections. These are your target's 'exposed' services.")
                            GuidePoint(title: "CLOSED", desc: "No service is listening on this port. The computer explicitly says 'no entry'.")
                            GuidePoint(title: "FILTERED", desc: "No response was received. Usually indicates a firewall is silently dropping the packets.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }

    private func startAction() {
        if vm.isRunning {
            vm.stop()
        } else {
            guard !host.isEmpty, !portsToScan.isEmpty else { return }
            history.record(host)
            vm.scan(host: host, ports: portsToScan,
                    concurrency: concurrency, timeout: timeout)
        }
    }

    private func exportCSV(_ rows: [PortResult]) {
        var lines = ["port,service,status,response_ms"]
        for r in rows {
            let ms = r.responseMs.map { String(format: "%.1f", $0) } ?? ""
            lines.append("\(r.port),\(r.service ?? ""),\(r.status.label),\(ms)")
        }
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let fileDate = formatter.string(from: date)
        Exporter.save(string: lines.joined(separator: "\n"),
                      defaultName: "NetUtil-PortScan-\(host)-\(fileDate).csv", ext: "csv")
    }

    private func formatElapsed() -> String {
        let t = vm.startTime.map { Date().timeIntervalSince($0) } ?? 0
        return formatSeconds(t)
    }

    private func formatSeconds(_ s: TimeInterval) -> String {
        if s < 60 { return String(format: "%.0fs", s) }
        return String(format: "%.0fm %.0fs", s / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private func parseRange(_ input: String) -> [Int] {
        var ports: Set<Int> = []
        for token in input.components(separatedBy: ",") {
            let tokenClean = token.trimmingCharacters(in: .whitespaces)
            if let single = Int(tokenClean), (1...65535).contains(single) {
                ports.insert(single)
            } else {
                let parts = tokenClean.components(separatedBy: "-")
                if parts.count == 2,
                   let lo = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                   let hi = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                   lo <= hi {
                    let clamped = max(1, lo)...min(65535, hi)
                    clamped.forEach { ports.insert($0) }
                }
            }
        }
        return ports.sorted()
    }
}

// MARK: - Sub-Components

struct PortResultCard: View {
    let result: PortResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(result.port)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                statusBadge
            }
            
            Text(result.service ?? "Unknown Service")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let ms = result.responseMs {
                Text(String(format: "%.1f ms", ms))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        let (bg, fg): (Color, Color) = switch result.status {
        case .open:     (.green.opacity(0.12), .green)
        case .closed:   (.red.opacity(0.08),    .secondary)
        case .filtered: (.orange.opacity(0.1),.orange)
        }
        Text(result.status.label.uppercased())
            .font(.system(size: 8, weight: .black))
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(4)
    }
}
