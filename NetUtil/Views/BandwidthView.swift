import SwiftUI
import Charts
import Observation

struct BandwidthView: View {
    @Environment(ToolStore.self) private var tools
    private     var vm: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false
    @State private var selectedTime: Date? = nil

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            bandwidthMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    aggregateStatsSection
                    aggregateChartSection
                    interfaceListSection
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Bandwidth Monitor") }
        .onAppear { vm.isUIActive = true }
        .onDisappear { vm.isUIActive = false }
    }

    private var bandwidthMoodBar: some View {
        let rx = vm.totalRxBps
        let tx = vm.totalTxBps
        let active = vm.interfaces.filter { !$0.isLoopback && vm.hasTraffic($0.name) }.count
        let (icon, color, msg): (String, Color, String) = {
            if vm.isPaused { return ("pause.fill", .orange, "Monitoring paused") }
            if rx > 0 || tx > 0 {
                return ("arrow.up.arrow.down.circle.fill", .green,
                        "↓ \(NetworkMath.formatRate(rx))  ↑ \(NetworkMath.formatRate(tx))  —  \(active) active interface\(active == 1 ? "" : "s")")
            }
            return ("circle.fill", .secondary, "No active traffic detected")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Bandwidth Monitor")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Bandwidth Monitor Tool")

                Spacer()

                HStack(spacing: 12) {
                    Toggle("Active Only", isOn: Binding(
                        get: { vm.showActiveOnly },
                        set: { vm.showActiveOnly = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.subheadline)
                    .accessibilityLabel("Show active interfaces only")

                    ReportMenuButton(
                        onExportPDF: { Exporter.saveBandwidthPDF(interfaces: vm.interfaces, history: vm.history) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: exportCSV(),
                                          defaultName: "NetUtil-Bandwidth-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )

                    Button {
                        vm.isPaused.toggle()
                    } label: {
                        Label(vm.isPaused ? "Resume" : "Pause",
                              systemImage: vm.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(vm.isPaused ? "Resume monitoring" : "Pause monitoring")

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Divider()
        }
    }

    // MARK: - Aggregate Stats

    private var aggregateStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Download",
                     value: formatBps(vm.totalRxBps).value,
                     unit: formatBps(vm.totalRxBps).unit,
                     icon: "arrow.down.circle.fill",
                     color: vm.totalRxBps > 0 ? .blue : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(formatBps(vm.totalRxBps).value) \(formatBps(vm.totalRxBps).unit) download")

            StatCard(title: "Upload",
                     value: formatBps(vm.totalTxBps).value,
                     unit: formatBps(vm.totalTxBps).unit,
                     icon: "arrow.up.circle.fill",
                     color: vm.totalTxBps > 0 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(formatBps(vm.totalTxBps).value) \(formatBps(vm.totalTxBps).unit) upload")

            StatCard(title: "Peak Down",
                     value: formatBps(vm.peakRx).value,
                     unit: formatBps(vm.peakRx).unit,
                     icon: "arrow.down.to.line",
                     color: .secondary)
                .accessibilityElement(children: .combine)

            StatCard(title: "Peak Up",
                     value: formatBps(vm.peakTx).value,
                     unit: formatBps(vm.peakTx).unit,
                     icon: "arrow.up.to.line",
                     color: .secondary)
                .accessibilityElement(children: .combine)

            if vm.peakRx > 0 || vm.peakTx > 0 {
                Button {
                    vm.resetPeaks()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset Peaks")
                .accessibilityLabel("Reset peak values")
            }
        }
    }

    // MARK: - Aggregate Chart

    private var aggregateWindow: [BandwidthSample] {
        Array(vm.totalHistory.suffix(Metrics.healthStripWindow))
    }

    private var aggregateSelectedSample: BandwidthSample? {
        guard let selectedTime else { return nil }
        return aggregateWindow.min(by: {
            abs($0.timestamp.timeIntervalSince(selectedTime)) < abs($1.timestamp.timeIntervalSince(selectedTime))
        })
    }

    private var aggregateChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aggregate Throughput")
                        .font(.headline)
                    Text("Combined download and upload across all connections — last 60 seconds")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if vm.isPaused {
                    Text("Paused")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            let peak = aggregateWindow.map { $0.rxBps + $0.txBps }.max() ?? 0
            let domainTop = peak <= 0 ? 1024 : Metrics.niceCeiling(peak * 1.25)
            Chart {
                ForEach(aggregateWindow) { s in
                    AreaMark(
                        x: .value("Time", s.timestamp),
                        y: .value("Rate", s.rxBps),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("Direction", "Download"))
                    .interpolationMethod(.monotone)
                    AreaMark(
                        x: .value("Time", s.timestamp),
                        y: .value("Rate", s.txBps),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("Direction", "Upload"))
                    .interpolationMethod(.monotone)
                }
                if let selected = aggregateSelectedSample {
                    RuleMark(x: .value("Cursor", selected.timestamp))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(
                            position: .top,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            HStack(spacing: 8) {
                                tooltipRate(dir: "↓", bps: selected.rxBps, color: .blue)
                                tooltipRate(dir: "↑", bps: selected.txBps, color: .orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartForegroundStyleScale(ThroughputStyle.scale)
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartXSelection(value: $selectedTime)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...domainTop)
            .frame(height: 140)
            .drawingGroup()
            .accessibilityLabel("Stacked throughput chart. Hover to inspect exact download and upload rates.")

            HStack(spacing: 16) {
                legendDot(.blue, "Download")
                legendDot(.orange, "Upload")
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func tooltipRate(dir: String, bps: Double, color: Color) -> some View {
        let fmt = formatBps(bps)
        return HStack(spacing: 4) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text("\(fmt.value) \(fmt.unit)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundColor(color)
        }
    }

    // MARK: - Interface List

    private var interfaceListSection: some View {
        let ifaces = vm.showActiveOnly
            ? vm.interfaces.filter { !$0.isLoopback && vm.hasTraffic($0.name) }
            : vm.interfaces.filter { !$0.isLoopback }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interfaces")
                        .font(.headline)
                    Text(vm.showActiveOnly ? "Showing interfaces with recent traffic" : "All non-loopback interfaces")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Updated \(vm.lastUpdated, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if ifaces.isEmpty {
                Text(vm.showActiveOnly ? "No interfaces with active traffic" : "No interfaces found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TableHeader("Interface", width: 100)
                        TableHeader("Type",      width: 90)
                        TableHeader("IP",        width: 120)
                        TableHeader("Download",  width: 110)
                        TableHeader("Upload",    width: 110)
                        TableHeader("Sparkline", flexible: true)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(.regularMaterial)

                    Divider()

                    LazyVStack(spacing: 0) {
                        ForEach(ifaces) { iface in
                            interfaceRow(iface)
                            if iface.id != ifaces.last?.id {
                                Divider().padding(.horizontal, 16).opacity(0.5)
                            }
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            }
        }
    }

    private func interfaceRow(_ iface: NetworkInterface) -> some View {
        let samples = vm.history[iface.name] ?? []
        let rx = samples.last?.rxBps ?? 0
        let tx = samples.last?.txBps ?? 0
        let rxFmt = formatBps(rx)
        let txFmt = formatBps(tx)

        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: iface.typeIcon)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                Text(iface.name)
                    .font(.caption.monospaced().weight(.semibold))
            }
            .frame(width: 100, alignment: .leading)

            Text(iface.typeName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(iface.ipv4.first ?? "—")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 2) {
                Text(rxFmt.value)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundColor(rx > 0 ? .blue : .primary)
                Text(rxFmt.unit)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
            .frame(width: 110, alignment: .leading)

            HStack(spacing: 2) {
                Text(txFmt.value)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundColor(tx > 0 ? .orange : .primary)
                Text(txFmt.unit)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
            .frame(width: 110, alignment: .leading)

            InterfaceSparkline(samples: samples)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
        }
        .padding(.vertical, 8).padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(iface.name) — \(iface.typeName) — Download: \(rxFmt.value) \(rxFmt.unit) Upload: \(txFmt.value) \(txFmt.unit)")
    }



    // MARK: - Helpers

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
        }
    }

    private func formatBps(_ bps: Double) -> (value: String, unit: String) {
        if bps >= 1_000_000_000 { return (String(format: "%.2f", bps / 1_000_000_000), "Gbps") }
        if bps >= 1_000_000     { return (String(format: "%.1f", bps / 1_000_000),     "Mbps") }
        if bps >= 1_000         { return (String(format: "%.0f", bps / 1_000),         "Kbps") }
        if bps > 0              { return (String(format: "%.0f", bps),                  "bps")  }
        return ("0", "bps")
    }

    private func exportCSV() -> String {
        let fmt = ISO8601DateFormatter()
        var lines = ["timestamp,interface,rx_bps,tx_bps"]
        for iface in vm.interfaces {
            guard let samples = vm.history[iface.name] else { continue }
            for s in samples {
                lines.append("\(fmt.string(from: s.timestamp)),\(iface.name),\(Int(s.rxBps)),\(Int(s.txBps))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Per-interface sparkline with hover inspection. Extracted as its own view
/// so each row owns its selection state independently.
private struct InterfaceSparkline: View {
    let samples: [BandwidthSample]
    @State private var selectedTime: Date? = nil

    private var recent: [BandwidthSample] {
        Array(samples.suffix(30))
    }

    private var selectedSample: BandwidthSample? {
        guard let selectedTime else { return nil }
        return recent.min(by: {
            abs($0.timestamp.timeIntervalSince(selectedTime)) < abs($1.timestamp.timeIntervalSince(selectedTime))
        })
    }

    var body: some View {
        let maxVal = recent.map { $0.rxBps + $0.txBps }.max() ?? 1
        return Chart {
            ForEach(recent) { s in
                AreaMark(
                    x: .value("T", s.timestamp),
                    y: .value("Rate", s.rxBps),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Direction", "Download"))
                .interpolationMethod(.monotone)
                AreaMark(
                    x: .value("T", s.timestamp),
                    y: .value("Rate", s.txBps),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
                .interpolationMethod(.monotone)
            }
            if let selected = selectedSample {
                RuleMark(x: .value("Cursor", selected.timestamp))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        HStack(spacing: 6) {
                            Text("↓ \(NetworkMath.formatRate(selected.rxBps))")
                                .font(.caption2.monospaced().weight(.semibold))
                                .foregroundColor(.blue)
                            Text("↑ \(NetworkMath.formatRate(selected.txBps))")
                                .font(.caption2.monospaced().weight(.semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
            }
        }
        .chartForegroundStyleScale(ThroughputStyle.scale)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartXSelection(value: $selectedTime)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(maxVal * 1.2, 1))
        .drawingGroup()
        .accessibilityLabel("Interface throughput trend. Hover to inspect values.")
    }
}
