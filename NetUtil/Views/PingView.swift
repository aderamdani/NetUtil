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
    @AppStorage("pingAlerts")          private var alertsEnabled: Bool = false
    @State private var countText = ""
    @State private var intervalText = ""
    @State private var packetSizeText = ""
    @State private var infinite = false
    @State private var showRaw = false
    @State private var showLearningGuide = false
    @State private var hoveredPoint: PingResult? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var chartWidth: CGFloat = Metrics.chartDefaultWidth
    @State private var selectedProfile: LinkProfile? = nil

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
                alertsEnabled: $alertsEnabled,
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
                VStack(spacing: Metrics.spacingXL) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }

                    if !vm.results.isEmpty {
                        statsBarSection

                        qualityCard

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

                        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
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
                .padding(Metrics.spacingXL)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Ping") }
        .onAppear {
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
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
        HStack(spacing: Metrics.spacingMD) {
            StatCard(title: "Transmitted", value: "\(vm.stats.transmitted)", icon: "paperplane")
                .accessibilityElement(children: .combine)
            StatCard(title: "Received", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
                .accessibilityElement(children: .combine)
            StatCard(title: "Packet Loss", value: String(format: "%.1f%%", vm.stats.loss), icon: "exclamationmark.triangle", color: vm.stats.loss > 0 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent", vm.stats.loss))
            StatCard(title: "Average RTT", value: String(format: "%.1f", vm.stats.avgRtt), unit: "ms", icon: "equal", color: rttColor(vm.stats.avgRtt))
                .accessibilityElement(children: .combine)
                .accessibilityValue(Self.spokenMilliseconds(vm.stats.avgRtt))
            StatCard(title: "Recent Avg", value: String(format: "%.1f", vm.stats.recentAvgRtt), unit: "ms", icon: "clock.arrow.circlepath", color: rttColor(vm.stats.recentAvgRtt))
                .accessibilityElement(children: .combine)
                .accessibilityValue(Self.spokenMilliseconds(vm.stats.recentAvgRtt) + ", last 20 packets")
            StatCard(title: "Jitter", value: String(format: "%.1f", vm.stats.jitter), unit: "ms", icon: "waveform.path.ecg", color: vm.stats.jitter > 10 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Self.spokenMilliseconds(vm.stats.jitter))
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }

    /// Pure VoiceOver/display strings — testable without rendering the view.
    static func spokenMilliseconds(_ ms: Double) -> String {
        "\(Int(ms)) milliseconds"
    }

    static func linkTypeAccessibilityLabel(title: String, typical: String) -> String {
        "\(title), typical latency \(typical)"
    }

    static func linkTypeMatchText(prefix: String, title: String, typical: String) -> String {
        "\(prefix)\(title) · typical \(typical)"
    }

    static func linkTypeDetailsLabel(title: String, typical: String, blurb: String) -> String {
        "Link type details. \(title), typical latency \(typical). \(blurb)"
    }

    static func signalStrengthText(rssi: Int) -> String {
        "\(rssi) dBm"
    }

    static func wifiSummary(parts: [String]) -> String {
        "Wi-Fi · " + parts.joined(separator: " · ")
    }

    // MARK: - Quality & Link Classification

    /// Plain-language verdict card: a rating anyone can understand, which
    /// local link carried the packets, and an explorable estimate of the
    /// internet link type (LAN / fiber / mobile / satellite).
    private var qualityCard: some View {
        let verdict = quality
        let matched = LinkProfile.match(avgMs: vm.stats.avgRtt)
        let shown = selectedProfile ?? matched
        let link = measuredLink
        return VStack(alignment: .leading, spacing: Metrics.spacingMD) {
            HStack(spacing: Metrics.spacingMD) {
                Image(systemName: verdict.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(verdict.color)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    HStack(spacing: Metrics.spacingSM) {
                        Text("Connection Quality")
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

            Divider().opacity(0.5)

            HStack(spacing: Metrics.spacingSM) {
                Text("Measured over")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .frame(width: 96, alignment: .leading)
                Image(systemName: link.icon)
                    .foregroundColor(.accentColor)
                Text(link.detail)
                    .font(.subheadline.monospaced())
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Measured over \(link.detail)")

            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                Text("Link type — tap a type to learn what it means")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                HStack(spacing: Metrics.spacingSM) {
                    ForEach(LinkProfile.allCases, id: \.self) { profile in
                        let isShown = profile == shown
                        Button {
                            selectedProfile = (selectedProfile == profile) ? nil : profile
                        } label: {
                            Text(profile.shortLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(isShown ? .white : .secondary)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background((isShown ? Color.accentColor : Color.secondary.opacity(0.12)), in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.linkTypeAccessibilityLabel(title: profile.title, typical: profile.typical))
                        .accessibilityHint(isShown ? "Showing details below" : "Tap to learn about this link type")
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.linkTypeMatchText(prefix: selectedProfile == nil ? "Likely match: " : "", title: shown.title, typical: shown.typical))
                        .font(.caption.monospaced().weight(.semibold))
                    Text(shown.blurb)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Self.linkTypeDetailsLabel(title: shown.title, typical: shown.typical, blurb: shown.blurb))
            }
        }
        .padding(Metrics.spacingLG)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var quality: QualityVerdict {
        let s = vm.stats
        let profile = LinkProfile.match(avgMs: s.avgRtt)
        if s.loss >= 20 {
            return QualityVerdict(title: "Unstable", icon: "xmark.circle.fill", color: .red,
                message: "About 1 in 5 packets never arrives. Check your Wi-Fi signal, move closer to the router, or plug in a cable.")
        }
        if profile == .satellite {
            if s.loss > 5 {
                return QualityVerdict(title: "Fair", icon: "exclamationmark.triangle.fill", color: .orange,
                    message: "Satellite links are slow by nature, but packets are also being lost — bad weather or dish alignment may be the cause.")
            }
            return QualityVerdict(title: "Normal for satellite", icon: "checkmark.circle.fill", color: .green,
                message: "Around half a second of delay is expected on satellite (VSAT) — fine for browsing, weak for gaming and video calls.")
        }
        if s.loss > 5 {
            return QualityVerdict(title: "Fair", icon: "exclamationmark.triangle.fill", color: .orange,
                message: "Some packets are lost. Browsing still works, but calls and gaming may stutter.")
        }
        if s.avgRtt < rttWarn && s.jitter <= 10 {
            return QualityVerdict(title: "Excellent", icon: "checkmark.circle.fill", color: .green,
                message: "Great for video calls, online gaming, and browsing.")
        }
        if s.avgRtt < rttCrit {
            return QualityVerdict(title: "Good", icon: "checkmark.circle", color: .green,
                message: "Fine for calls and streaming. Fast-paced gaming may feel slightly delayed.")
        }
        return QualityVerdict(title: "Slow", icon: "xmark.circle.fill", color: .red,
            message: "Latency is high — video calls and gaming will suffer. Try a closer server or a wired connection.")
    }

    /// The factual local link carrying the packets, from the primary interface.
    private var measuredLink: (icon: String, detail: String) {
        if let iface = tools.primaryInterface {
            switch iface.ifType {
            case 161:
                var parts = [tools.currentConnectionName]
                if let rssi = tools.wifi.info?.rssi { parts.append(Self.signalStrengthText(rssi: rssi)) }
                return ("wifi", Self.wifiSummary(parts: parts))
            case 6:
                return ("cable.connector", "Ethernet · \(tools.currentConnectionName)")
            case 23, 150:
                return ("antenna.radiowaves.left.and.right", "Cellular · \(tools.currentConnectionName)")
            default:
                return (iface.typeIcon, "\(iface.typeName) · \(tools.currentConnectionName)")
            }
        }
        return ("network", "Unknown link")
    }

    private var rttLegend: some View {
        HStack(spacing: Metrics.spacingLG) {
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
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
        .frame(minHeight: 400)
        .scrollContentBackground(.hidden)
        .scrollPosition(id: .constant(vm.rawLines.last?.id))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; selectedProfile = nil; history.record(host); vm.start(host: host, count: infinite ? nil : Int(resolvedCount), interval: Double(resolvedInterval) ?? defaultInterval, packetSize: resolvedPacketSize) }
    }
}

// MARK: - Link Quality Model

private struct QualityVerdict {
    let title: String
    let icon: String
    let color: Color
    let message: String
}

/// Internet link-type estimate from measured latency. Bands are typical
/// values, surfaced as "likely" — not a detection, so the UI must keep the
/// "Likely match" wording and let users explore every type.
private enum LinkProfile: String, CaseIterable, Hashable {
    case lan, fiber, mobile, distant, satellite

    var shortLabel: String {
        switch self {
        case .lan: return "LAN"
        case .fiber: return "Fiber"
        case .mobile: return "4G"
        case .distant: return "Far"
        case .satellite: return "Sat"
        }
    }

    var title: String {
        switch self {
        case .lan: return "Local network (LAN)"
        case .fiber: return "Fiber (FO)"
        case .mobile: return "Mobile (4G/5G)"
        case .distant: return "Distant route"
        case .satellite: return "Satellite (VSAT)"
        }
    }

    var typical: String {
        switch self {
        case .lan: return "< 3 ms"
        case .fiber: return "5–45 ms"
        case .mobile: return "45–130 ms"
        case .distant: return "130–450 ms"
        case .satellite: return "500–700 ms"
        }
    }

    var blurb: String {
        switch self {
        case .lan: return "The target is on your own network — just your Wi-Fi or cable to the router."
        case .fiber: return "Fast landline such as fiber optic — great for everything, including gaming."
        case .mobile: return "Mobile data or a far-away server — fine for browsing and streaming."
        case .distant: return "A very distant or busy route — calls and gaming may lag."
        case .satellite: return "The signal travels to space and back, so a long delay is normal here."
        }
    }

    static func match(avgMs: Double) -> LinkProfile {
        if avgMs < 3 { return .lan }
        if avgMs < 45 { return .fiber }
        if avgMs < 130 { return .mobile }
        if avgMs < 450 { return .distant }
        return .satellite
    }
}
