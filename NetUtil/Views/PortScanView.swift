import SwiftUI
import Combine

struct PortScanView: View {
    @StateObject private var vm = PortScanViewModel()
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var preset = PortPreset.common
    @State private var customRange = "1-1024"
    @AppStorage("portScanConcurrency") private var defaultConcurrency = 50
    @AppStorage("portScanTimeout")     private var defaultTimeout     = 1.5
    @State private var concurrency = 50
    @State private var timeout = 1.5
    @State private var showOnlyOpen = false
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
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if vm.total > 0 {
                progressBar
            }
            if !vm.results.isEmpty {
                statsBar
            }
            HStack {
                Toggle("Open only", isOn: $showOnlyOpen)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                if !vm.results.isEmpty {
                    exportMenu
                }
            }
            resultsTable
        }
        .padding()
        .onReceive(timer) { _ in tick += 1 }
        .onAppear {
            concurrency = defaultConcurrency
            timeout = defaultTimeout
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Hostname or IP", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                if !history.hosts.isEmpty {
                    Menu {
                        ForEach(history.hosts, id: \.self) { h in
                            Button(h) { host = h }
                        }
                        Divider()
                        Button("Clear History", role: .destructive) { history.clear() }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            }

            Picker("", selection: $preset) {
                ForEach(PortPreset.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .frame(width: 130)

            if preset == .custom {
                TextField("e.g. 1-1024, 80, 443", text: $customRange)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 170)
            }

            HStack(spacing: 4) {
                Text("Threads:")
                Stepper("\(concurrency)", value: $concurrency, in: 1...200)
                    .frame(width: 110)
            }

            Spacer()

            if vm.isRunning {
                Text(formatElapsed()).font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .onReceive(timer) { _ in }
            }

            Button(vm.isRunning ? "Stop" : "Scan") {
                if vm.isRunning {
                    vm.stop()
                } else {
                    guard !host.isEmpty, !portsToScan.isEmpty else { return }
                    history.record(host)
                    vm.scan(host: host, ports: portsToScan,
                            concurrency: concurrency, timeout: timeout)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && (host.isEmpty || portsToScan.isEmpty))
            .keyboardShortcut(.return)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(vm.scanned) / \(vm.total) ports")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                if let eta = vm.eta, vm.isRunning {
                    Text("ETA \(formatSeconds(eta))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            ProgressView(value: Double(vm.scanned), total: Double(max(vm.total, 1)))
                .progressViewStyle(.linear)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 14) {
            statChip("Scanned", "\(vm.scanned)", .primary)
            statChip("Open", "\(vm.openCount)", vm.openCount > 0 ? .green : .secondary)
            statChip("Closed/Filtered",
                     "\(vm.scanned - vm.openCount)",
                     .secondary)
        }
    }

    private func statChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var resultsTable: some View {
        Group {
            if displayResults.isEmpty && !vm.isRunning && vm.total == 0 {
                emptyState
            } else {
                Table(displayResults) {
                    TableColumn("Port") { r in
                        Text("\(r.port)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(65)

                    TableColumn("Service") { r in
                        Text(r.service ?? "—")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(r.service == nil ? .secondary : .primary)
                    }
                    .width(110)

                    TableColumn("Status") { r in
                        statusBadge(r.status)
                    }
                    .width(90)

                    TableColumn("Response") { r in
                        if let ms = r.responseMs {
                            Text(String(format: "%.1f ms", ms))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                        } else {
                            Text("—")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(90)
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: PortStatus) -> some View {
        let (bg, fg): (Color, Color) = switch status {
        case .open:     (.green.opacity(0.15), .green)
        case .closed:   (.red.opacity(0.1),    .red)
        case .filtered: (.orange.opacity(0.12),.orange)
        }
        Text(status.label)
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundColor(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "checklist")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Enter a host and press Scan")
                .foregroundColor(.secondary)
                .font(.callout)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private var exportMenu: some View {
        Menu {
            Button("Export All (CSV)") {
                exportCSV(vm.results.sorted { $0.port < $1.port })
            }
            Button("Export Open Ports (CSV)") {
                exportCSV(vm.results.filter { $0.status == .open }.sorted { $0.port < $1.port })
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 32)
    }

    private func exportCSV(_ rows: [PortResult]) {
        var lines = ["port,service,status,response_ms"]
        for r in rows {
            let ms = r.responseMs.map { String(format: "%.1f", $0) } ?? ""
            lines.append("\(r.port),\(r.service ?? ""),\(r.status.label),\(ms)")
        }
        Exporter.save(string: lines.joined(separator: "\n"),
                      defaultName: "portscan-\(host).csv", ext: "csv")
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
            let t = token.trimmingCharacters(in: .whitespaces)
            if let single = Int(t), (1...65535).contains(single) {
                ports.insert(single)
            } else {
                let parts = t.components(separatedBy: "-")
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
