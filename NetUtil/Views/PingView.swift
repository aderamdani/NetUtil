import SwiftUI
import Observation

struct PingView: View {
    var vm: PingViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var host = ""
    @AppStorage("defaultPingCount")    private var defaultCount: Int = 20
    @AppStorage("defaultPingInterval") private var defaultInterval: Double = 1.0
    @AppStorage("rttWarnThreshold")    private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")    private var rttCrit: Double = 100.0
    @AppStorage("pingBeepOnLoss")      private var beepOnLoss: Bool = false
    @State private var countText = ""
    @State private var intervalText = ""
    @State private var packetSizeText = ""
    @State private var infinite = false
    @State private var showRaw = false
    @State private var showLearningGuide = false
    @State private var hoveredPoint: PingResult? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var chartWidth: CGFloat = Metrics.chartDefaultWidth

    private var resolvedCount: String { countText.isEmpty ? "\(defaultCount)" : countText }
    private var resolvedInterval: String { intervalText.isEmpty ? String(format: "%.1f", defaultInterval) : intervalText }
    private var resolvedPacketSize: Int? { Int(packetSizeText) }

    var body: some View {
        VStack(spacing: 0) {
            PingControlBar(
                host: $host,
                countText: $countText,
                intervalText: $intervalText,
                packetSizeText: $packetSizeText,
                infinite: $infinite,
                beepOnLoss: $beepOnLoss,
                vm: vm,
                history: history,
                onStartStop: startAction,
                onHelp: { showLearningGuide = true },
                onExportPDF: { Exporter.savePingPDF(results: vm.results, stats: vm.stats, host: host, resolvedIP: vm.resolvedIP) },
                onExportCSV: {
                    let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                    Exporter.save(string: Exporter.csvString(from: vm.results), defaultName: "NetUtil-Ping-\(host)-\(date.string(from: Date())).csv", ext: "csv")
                }
            )

            pingMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }

                    if !vm.results.isEmpty {
                        statsBarSection

                        PingLatencyChartView(
                            results: vm.results,
                            chartData: vm.chartResults,
                            stats: vm.stats,
                            rttWarn: rttWarn,
                            rttCrit: rttCrit,
                            hoveredPoint: $hoveredPoint,
                            hoverLocation: $hoverLocation,
                            chartWidth: $chartWidth
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Picker("", selection: $showRaw) {
                                    Text("Analysis").tag(false)
                                    Text("Console Log").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)

                                Spacer()
                                rttLegend
                            }

                            if showRaw {
                                rawOutput
                            } else {
                                PingResultsTable(
                                    results: vm.results,
                                    resolvedIP: vm.resolvedIP,
                                    rttWarn: rttWarn,
                                    rttCrit: rttCrit
                                )
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
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Advanced Ping") }
        .onAppear {
            if let h = vm.quickLaunchHost {
                host = h
                vm.quickLaunchHost = nil
                startAction()
            }
        }
    }

    private var pingMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning {
                return ("hourglass", .secondary, String(format: "Pinging %@  —  %d sent, %.1f%% loss", vm.currentHost, vm.stats.transmitted, vm.stats.loss))
            }
            guard !vm.results.isEmpty else {
                return ("antenna.radiowaves.left.and.right", .secondary, "Enter a host to measure round-trip latency")
            }
            let s = vm.stats
            if s.loss > 5 {
                return ("exclamationmark.triangle.fill", .orange, String(format: "%.1f%% packet loss to %@  —  avg %.1f ms", s.loss, vm.currentHost, s.avgRtt))
            }
            return ("checkmark.circle.fill", .green, String(format: "%d packets, %.1f%% loss  —  avg %.1f ms", s.transmitted, s.loss, s.avgRtt))
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Components

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Transmitted", value: "\(vm.stats.transmitted)", icon: "paperplane")
                .accessibilityElement(children: .combine)
            StatCard(title: "Received", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
                .accessibilityElement(children: .combine)
            StatCard(title: "Packet Loss", value: String(format: "%.1f%%", vm.stats.loss), icon: "exclamationmark.triangle", color: vm.stats.loss > 0 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent", vm.stats.loss))
            StatCard(title: "Average RTT", value: String(format: "%.1f", vm.stats.avgRtt), unit: "ms", icon: "equal", color: rttColor(vm.stats.avgRtt))
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(Int(vm.stats.avgRtt)) milliseconds")
            StatCard(title: "Jitter", value: String(format: "%.1f", vm.stats.jitter), unit: "ms", icon: "waveform.path.ecg", color: vm.stats.jitter > 10 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(Int(vm.stats.jitter)) milliseconds")
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
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }

    private var rttLegend: some View {
        HStack(spacing: 16) {
            ForEach([("Normal", Color.green), ("High", Color.orange), ("Critical", Color.red), ("Loss", Color.purple)], id: \.0) { item in
                HStack(spacing: 6) {
                    Circle().fill(item.1).frame(width: 6, height: 6)
                    Text(item.0).font(.caption2.weight(.bold)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Host Target",
                            subtitle: "Enter an IP or hostname to analyze network performance.")
    }

    private var loadingState: some View {
        ToolStateView.loading(message: "Waiting for ICMP sequence...")
    }

    private var rawOutput: some View {
        List {
            ForEach(vm.rawLines) { line in
                Text(line.text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
        .frame(minHeight: 400)
        .scrollContentBackground(.hidden)
        .scrollPosition(id: .constant(vm.rawLines.last?.id))
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, count: infinite ? nil : Int(resolvedCount), interval: Double(resolvedInterval) ?? defaultInterval, packetSize: resolvedPacketSize) }
    }
}
