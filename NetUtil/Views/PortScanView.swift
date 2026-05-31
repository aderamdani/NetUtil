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
            PortScanControlBar(
                host: $host,
                isRunning: vm.isRunning,
                portRangeType: $preset,
                customPorts: $customRange,
                onStart: startAction,
                onShowGuide: { showLearningGuide = true },
                onExportPDF: { /* TODO */ },
                onExportCSV: { exportCSV(displayResults) },
                hasResults: !vm.results.isEmpty,
                history: history
            )
            
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
                                    .accessibilityLabel("Show open ports only")
                                Spacer()
                                Text("\(displayResults.count) Ports Displayed")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                            }
                            
                            PortScanTable(results: displayResults, resolvedIP: nil)
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

    // REMOVED: controlBar (now in Components/PortScanControlBar.swift)

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Ports Scanned", value: "\(vm.scanned)", icon: "checklist")
                .accessibilityElement(children: .combine)
            StatCard(title: "Open Ports", value: "\(vm.openCount)", icon: "lock.open.fill", color: vm.openCount > 0 ? .green : .primary)
                .accessibilityElement(children: .combine)
            StatCard(title: "Filtered", value: "\(vm.scanned - vm.openCount)", icon: "lock.shield.fill", color: .secondary)
                .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan progress: \(Int(progress * 100)) percent")
    }

    // REMOVED: resultsGrid

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
        .accessibilityLabel("Error: \(msg)")
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
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel("Scanning network ports, please wait")
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

// REMOVED: PortResultCard and PortStatusBadge (now in Components/PortScanTable.swift)
