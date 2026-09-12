import SwiftUI
import Observation
import CoreLocation

struct TracerouteView: View {
    var vm: TracerouteViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var host = ""
    @AppStorage("defaultMaxHops")       private var defaultMaxHops = 30
    @AppStorage("defaultTraceInterval")  private var defaultInterval = 5.0
    @AppStorage("rttWarnThreshold")      private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")      private var rttCrit: Double = 100.0
    @State private var maxHops = 30
    @State private var traceInterval = 5.0
    @State private var viewMode: ViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showLearningGuide = false

    enum ViewMode: String, CaseIterable, Identifiable {
        case hops, timeline, map, raw
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            TracerouteControlBar(
                host: $host,
                isRunning: vm.isRunning,
                maxHops: $maxHops,
                traceInterval: $traceInterval,
                round: vm.round,
                onStart: startAction,
                onShowGuide: { showLearningGuide = true },
                history: history,
                hasHops: !vm.hops.isEmpty,
                onExportPDF: { Exporter.saveTraceroutePDF(hops: vm.hops, host: host, round: vm.round) },
                onExportCSV: {
                    let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                    Exporter.save(string: Exporter.csvString(from: vm.hops), defaultName: "NetUtil-Traceroute-\(host)-\(date.string(from: Date())).csv", ext: "csv")
                },
                onCopySummary: {
                    let avg = vm.pathAvgRtt.map { String(format: "%.1f ms", $0) } ?? "—"
                    let summary = "Host: \(host)\nHops: \(vm.hops.count)\nAvg RTT: \(avg)\nMax loss: \(String(format: "%.0f%%", vm.pathLoss))"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary, forType: .string)
                },
                isFavorite: tools.favorites.isFavorite(host),
                onToggleFavorite: { tools.favorites.toggle(host: host) }
            )

            traceMoodBar

            ScrollView {
                VStack(spacing: Metrics.spacingXL) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }
                    
                    if !vm.hops.isEmpty {
                        pathSummarySection

                        pathVerdictCard

                        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
                            HStack {
                                SectionHeader(title: "Path Visualization", icon: "map.fill")
                                Spacer()
                                Picker("", selection: $viewMode) {
                                    ForEach(ViewMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue.capitalized).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                .accessibilityLabel("Visualization Mode")
                            }
                            
                            contentArea
                                .frame(minHeight: 450)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
                                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                        }
                        
                        if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                            hopQuickDetail(hop)
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
            maxHops = defaultMaxHops
            traceInterval = defaultInterval
            if let h = vm.quickLaunchHost { host = h; vm.quickLaunchHost = nil; startAction() }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Traceroute") }
    }

    private var traceMoodBar: some View {
        let (icon, color): (String, Color) = {
            if vm.isRunning { return ("hourglass", .secondary) }
            if vm.hops.isEmpty { return ("point.3.connected.trianglepath.dotted", .secondary) }
            if vm.pathLoss > 0 { return ("exclamationmark.triangle.fill", .orange) }
            return ("checkmark.circle.fill", .green)
        }()
        let msg: String = {
            if vm.isRunning {
                return Self.tracingMessage(host: vm.currentHost, round: vm.round, hopCount: vm.hops.count)
            }
            if vm.hops.isEmpty {
                return "Enter a host to map the network path"
            }
            let avg = vm.pathAvgRtt.map { String(format: "%.1f ms", $0) } ?? "—"
            if vm.pathLoss > 0 {
                return Self.pathLossMessage(loss: vm.pathLoss, hopCount: vm.hops.count, avg: avg)
            }
            return Self.pathCleanMessage(hopCount: vm.hops.count, avg: avg)
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    /// Pure MoodBar/VoiceOver messages — testable without rendering the view.
    static func tracingMessage(host: String, round: Int, hopCount: Int) -> String {
        "Tracing \(host) — round \(round + 1), \(hopCount) hops"
    }

    static func pathLossMessage(loss: Double, hopCount: Int, avg: String) -> String {
        String(format: "%.1f%% loss on path — %d hops, avg %@", loss, hopCount, avg)
    }

    static func pathCleanMessage(hopCount: Int, avg: String) -> String {
        "\(hopCount) hops — path avg \(avg)"
    }

    static func spokenMilliseconds(_ ms: Double) -> String {
        "\(Int(ms)) milliseconds"
    }

    // MARK: - Components

    private var pathSummarySection: some View {
        HStack(spacing: Metrics.spacingMD) {
            StatCard(title: "Path Depth", value: "\(vm.hops.count)", unit: "Hops", icon: "arrow.triangle.branch")
                .accessibilityElement(children: .combine)
            StatCard(title: "Path Loss", value: String(format: "%.1f%%", vm.pathLoss), icon: "exclamationmark.triangle", color: vm.pathLoss > 0 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent", vm.pathLoss))
            if let avg = vm.pathAvgRtt {
                StatCard(title: "Avg Latency", value: String(format: "%.1f", avg), unit: "ms", icon: "timer", color: avg < rttWarn ? .primary : .orange)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(Self.spokenMilliseconds(avg))
            }
            if let last = vm.hops.last?.displayHost {
                StatCard(title: "Target Host", value: last, icon: "target")
                    .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Path Verdict

    /// Plain-language verdict: where the path slows down most (bottleneck),
    /// whether packets are lost, or whether the trace looks clean.
    private var pathVerdictCard: some View {
        let verdict = pathVerdict
        return HStack(spacing: Metrics.spacingMD) {
            Image(systemName: verdict.icon)
                .font(.title2.weight(.semibold))
                .foregroundColor(verdict.color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                HStack(spacing: Metrics.spacingSM) {
                    Text("Path Verdict")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                    Text(verdict.title)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(verdict.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(verdict.color)
                }
                Text(verdict.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var pathVerdict: PathVerdict {
        if vm.pathLoss >= 20 {
            return PathVerdict(title: "Lossy path", icon: "xmark.circle.fill", color: .red,
                message: "Packets are being dropped along the way (\(String(format: "%.0f", vm.pathLoss))% at the worst hop). Streaming and calls may stutter.")
        }
        if let slow = bottleneck {
            return PathVerdict(title: "Bottleneck at hop \(slow.hop.hop)", icon: "exclamationmark.triangle.fill", color: .orange,
                message: "Delay jumps +\(String(format: "%.0f", slow.addedMs)) ms at \(slow.hop.displayHost). Everything past this hop inherits the wait — the slowdown is here, not at your target.")
        }
        if vm.hops.last?.avgRtt == nil {
            return PathVerdict(title: "Incomplete trace", icon: "questionmark.circle.fill", color: .orange,
                message: "The final target never answered. It may block traceroute probes, or the path breaks near the end.")
        }
        return PathVerdict(title: "Clean path", icon: "checkmark.circle.fill", color: .green,
            message: "Each hop hands off smoothly to the next — no single slowdown point on this route.")
    }

    /// The hop adding the most latency versus the previous hop — a jump of
    /// at least the warn threshold counts as significant.
    private var bottleneck: (hop: TracerouteHop, addedMs: Double)? {
        let timed = vm.hops.compactMap { hop -> (TracerouteHop, Double)? in
            guard let avg = hop.avgRtt else { return nil }
            return (hop, avg)
        }
        guard timed.count >= 2 else { return nil }
        var best: (hop: TracerouteHop, addedMs: Double)? = nil
        for i in 1..<timed.count {
            let added = timed[i].1 - timed[i - 1].1
            if added >= rttWarn {
                if let current = best {
                    if added > current.addedMs { best = (timed[i].0, added) }
                } else {
                    best = (timed[i].0, added)
                }
            }
        }
        return best
    }

    /// Plain-language role of a hop: your router, your target, or a
    /// carrier router in between.
    private func hopRole(_ hop: TracerouteHop) -> String {
        if hop.hop == 1 { return "Your router — the first step out of your home network." }
        if hop.id == vm.hops.last?.id { return "Your destination — the server you asked about." }
        return "A router along the way — run by your provider or a carrier."
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewMode {
        case .hops:
            TracerouteHopsTable(hops: vm.hops, selectedHopID: selectedHopID, rttWarn: rttWarn, rttCrit: rttCrit, bottleneckHopID: bottleneck?.hop.id, bottleneckAddedMs: bottleneck?.addedMs, onSelect: { selectedHopID = $0 }, onInfo: { infoHop = $0 })
        case .timeline:
            TracerouteTimelineView(hops: vm.hops, rttWarn: rttWarn, rttCrit: rttCrit, selectedHopID: selectedHopID, onSelect: { selectedHopID = $0 })
        case .map:
            TracerouteMapView(hops: vm.hops)
        case .raw:
            rawOutputView
        }
    }

    private func hopQuickDetail(_ hop: TracerouteHop) -> some View {
        let isBottleneck = bottleneck?.hop.id == hop.id
        return VStack(alignment: .leading, spacing: Metrics.spacingMD) {
            HStack {
                Text("Hop \(hop.hop) Detail")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button { selectedHopID = nil } label: { Image(systemName: "xmark").font(.caption2) }.buttonStyle(.plain).foregroundColor(.secondary)
                    .accessibilityLabel("Close Detail")
            }

            Text(hopRole(hop))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isBottleneck, let added = bottleneck?.addedMs {
                Text("Slowest jump on this path — +\(String(format: "%.0f", added)) ms added here.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Metrics.spacingXL) {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Host / IP").font(.caption2.bold()).foregroundColor(.secondary)
                    Text(hop.displayHost).font(.subheadline.monospaced().weight(.bold))
                }
                .accessibilityElement(children: .combine)
                
                if let geo = hop.geo {
                    VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                        Text("Location").font(.caption2.bold()).foregroundColor(.secondary)
                        Text("\(geo.flag) \(geo.city), \(geo.country)")
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
                
                Spacer()
                
                HStack(spacing: Metrics.spacingMD) {
                    StatCardMini(label: "Min", value: hop.minRtt.map { String(format: "%.1f", $0) } ?? "—")
                    StatCardMini(label: "Max", value: hop.maxRtt.map { String(format: "%.1f", $0) } ?? "—")
                    StatCardMini(label: "Jitter", value: hop.jitter.map { String(format: "%.1f", $0) } ?? "—")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var rawOutputView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.spacingXS) {
                ForEach(vm.rawLines) { line in
                    Text(line.text)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .accessibilityLabel("Raw traceroute output")
    }



    private var emptyState: some View {
        ToolStateView.empty(title: "No Active Trace",
                            subtitle: "Enter a target to map the layer 3 network path.")
        .accessibilityElement(children: .combine)
    }

    private var loadingState: some View {
        ToolStateView.loading(message: "Discovering Network Hops...")
            .accessibilityLabel("Discovering network hops, please wait")
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, maxHops: maxHops, interval: traceInterval) }
    }
    
    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct PathVerdict {
    let title: String
    let icon: String
    let color: Color
    let message: String
}

private struct StatCardMini: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(value).font(.caption.monospaced().weight(.bold))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct TracerouteIPInfoSheet: View {
    let hop: TracerouteHop
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXL) {
            HStack {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Hop \(hop.hop)").font(.headline)
                    Text(hop.displayHost).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.glassProminent)
                    .accessibilityLabel("Close IP info sheet")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: Metrics.spacingLG) {
                infoRow(label: "IP Address", value: hop.ip ?? "Unknown")
                if let geo = hop.geo {
                    infoRow(label: "Location", value: "\(geo.flag) \(geo.city), \(geo.country)")
                    if let coord = geo.coordinate {
                        let lat = coord.latitude
                        let lon = coord.longitude
                        infoRow(label: "Coordinates", value: String(format: "%.4f, %.4f", lat, lon))
                    }
                    infoRow(label: "Organization", value: geo.org)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 450)
        .background(.regularMaterial)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text(label).font(.caption2.bold()).foregroundColor(.secondary)
            Text(value).font(.subheadline.monospaced()).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
