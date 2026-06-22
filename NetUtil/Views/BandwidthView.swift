import SwiftUI
import Charts
import Observation

struct BandwidthView: View {
    @Environment(ToolStore.self) private var tools
    private var vm: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false

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
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(msg).font(.callout).foregroundColor(color == .secondary ? .secondary : .primary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
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
                        onExportPDF: {},
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
            .padding(.vertical, 14)
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
                     color: vm.totalRxBps > 0 ? .green : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(formatBps(vm.totalRxBps).value) \(formatBps(vm.totalRxBps).unit) download")

            StatCard(title: "Upload",
                     value: formatBps(vm.totalTxBps).value,
                     unit: formatBps(vm.totalTxBps).unit,
                     icon: "arrow.up.circle.fill",
                     color: vm.totalTxBps > 0 ? .blue : .primary)
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

    private var aggregateChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aggregate Throughput")
                        .font(.headline)
                    Text("All non-loopback interfaces combined — 60 second window")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if vm.isPaused {
                    Text("Paused")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
            }

            let samples = vm.totalHistory.suffix(Metrics.healthStripWindow)
            let maxRX = samples.map(\.rxBps).max() ?? 1
            let maxTX = samples.map(\.txBps).max() ?? 1
            let domainTop    = max(maxRX, 1024) * 1.25
            let domainBottom = -max(maxTX, 1024) * 1.25
            Chart {
                ForEach(Array(samples), id: \.id) { s in
                    AreaMark(x: .value("Time", s.timestamp),
                             y: .value("RX", s.rxBps))
                        .foregroundStyle(LinearGradient(colors: [Color.green.opacity(0.4), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", s.timestamp),
                             y: .value("RX", s.rxBps))
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Time", s.timestamp),
                             y: .value("TX", -s.txBps))
                        .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.4), .clear],
                                                        startPoint: .bottom, endPoint: .top))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", s.timestamp),
                             y: .value("TX", -s.txBps))
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: domainBottom...domainTop)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            let abs = Swift.abs(v)
                            Text(abs < 1 ? "0" : formatBps(abs).value + " " + formatBps(abs).unit)
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
            .frame(height: 140)
            .drawingGroup()

            HStack(spacing: 16) {
                legendDot(.green, "Download (↑ axis)")
                legendDot(.blue,  "Upload (↓ axis)")
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
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
                        tHeader("Interface", width: 100)
                        tHeader("Type",      width: 90)
                        tHeader("IP",        width: 120)
                        tHeader("Download",  width: 110)
                        tHeader("Upload",    width: 110)
                        tHeader("Sparkline", flexible: true)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 16)
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
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
            }
            .frame(width: 100, alignment: .leading)

            Text(iface.typeName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(iface.ipv4.first ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 2) {
                Text(rxFmt.value)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(rx > 0 ? .green : .primary)
                Text(rxFmt.unit)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 110, alignment: .leading)

            HStack(spacing: 2) {
                Text(txFmt.value)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(tx > 0 ? .blue : .primary)
                Text(txFmt.unit)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 110, alignment: .leading)

            sparkline(samples: samples)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(iface.name) — \(iface.typeName) — Download: \(rxFmt.value) \(rxFmt.unit) Upload: \(txFmt.value) \(txFmt.unit)")
    }

    private func sparkline(samples: [BandwidthSample]) -> some View {
        let recent = samples.suffix(30)
        let maxVal = recent.map { max($0.rxBps, $0.txBps) }.max() ?? 1
        return Chart {
            ForEach(Array(recent), id: \.id) { s in
                LineMark(x: .value("T", s.timestamp), y: .value("RX", s.rxBps))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("T", s.timestamp), y: .value("TX", s.txBps))
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(maxVal * 1.2, 1))
        .drawingGroup()
    }

    // MARK: - Helpers

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
        }
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
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
