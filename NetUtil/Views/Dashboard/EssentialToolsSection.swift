import SwiftUI

/// Curated dashboard grid: the core network utilities with live status.
/// Everything else stays reachable from the sidebar — the Dashboard only
/// surfaces what an operator needs at a glance.
struct EssentialToolsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            SectionHeader(title: "Network Tools", icon: "network")

            GlassEffectContainer {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: Metrics.spacingMD
                ) {
                    doctorCard
                    pingCard
                    tracerouteCard
                    trafficCard
                    wifiCard
                    interfacesCard
                    speedTestCard
                    dnsCard
                    portScanCard
                }
            }
        }
    }

    // MARK: - Diagnostics

    private var doctorCard: some View {
        let passed = tools.doctor.checks.filter { if case .passed = $0.state { return true } else { return false } }.count
        let failed = tools.doctor.checks.filter { if case .failed = $0.state { return true } else { return false } }.count
        let total = tools.doctor.checks.count
        let color: Color = failed > 0 ? .red : (tools.doctor.isRunning ? .blue : .green)
        let statusText: String = {
            if tools.doctor.isRunning { return "Running checks…" }
            if total == 0 { return "Not yet run" }
            return failed > 0 ? "\(failed) of \(total) failed" : "All \(total) checks passed"
        }()
        let statusColor: Color = failed > 0 ? .red : (total == 0 ? .secondary : .green)

        return BentoCard(
            title: "Connectivity Doctor",
            icon: "stethoscope",
            color: color,
            action: { selection = .doctor },
            helpText: "Automated checks: gateway reachability, DNS, internet connectivity, and captive portal detection."
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                HStack {
                    Text(statusText)
                        .font(.subheadline.bold())
                        .foregroundColor(statusColor)
                    Spacer()
                    if tools.doctor.isRunning { PulsingIndicator(color: .blue) }
                }
                if tools.doctor.isRunning {
                    Text("Gateway → DNS → Internet → Captive Portal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if total > 0 {
                    HStack(spacing: Metrics.spacingLG) {
                        Label("\(passed) passed", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        if failed > 0 {
                            Label("\(failed) failed", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Text("Run a full connectivity check")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var pingCard: some View {
        BentoCard(
            title: "Advanced Ping",
            icon: "antenna.radiowaves.left.and.right",
            color: .blue,
            action: { selection = .ping },
            helpText: "Measure connection latency and stability to any host. Shows response time, jitter, and packet loss."
        ) {
            let isRunning = tools.ping.isRunning
            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tools.ping.currentHost.isEmpty ? "Idle" : tools.ping.currentHost)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        if isRunning {
                            Label("Monitoring latency & jitter", systemImage: "waveform.path.ecg")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .bold()
                        } else if !tools.ping.currentHost.isEmpty {
                            Label("Ready to start", systemImage: "play.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Measure latency, jitter, and loss")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isRunning { PulsingIndicator(color: .green) }
                }

                if !tools.ping.results.isEmpty {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%.1f", tools.ping.stats.avgRtt))
                                .font(.system(size: Metrics.heroNumber, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                            Text("ms average").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                        DashboardSparkline(
                            data: tools.ping.results.suffix(Metrics.sparklineWindow).map { $0.rtt },
                            color: isRunning ? .green : .blue
                        )
                        .frame(width: 120, height: 32)
                        .help("Response time over last \(Metrics.sparklineWindow) pings")
                    }
                    HStack(spacing: Metrics.spacingLG) {
                        Label("\(tools.ping.stats.loss, specifier: "%.1f")% loss", systemImage: "exclamationmark.triangle")
                            .font(.caption2.monospaced())
                            .foregroundColor(tools.ping.stats.loss > 0 ? .orange : .green)
                        Label("±\(tools.ping.stats.jitter, specifier: "%.1f") ms", systemImage: "waveform.path")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var tracerouteCard: some View {
        BentoCard(
            title: "Traceroute",
            icon: "point.3.connected.trianglepath.dotted",
            color: .blue,
            action: { selection = .traceroute },
            helpText: "Trace the path packets take to a destination. See each hop, latency, and ASN ownership."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !tools.traceroute.hops.isEmpty {
                        Text(tools.traceroute.currentHost)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        HStack(spacing: Metrics.spacingSM) {
                            Label("\(tools.traceroute.hops.count) hops", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            if let lastHop = tools.traceroute.hops.last,
                               let avgRtt = lastHop.avgRtt {
                                Label("\(Int(avgRtt)) ms", systemImage: "speedometer")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Path Discovery")
                            .font(.subheadline.bold())
                        Text("Map the route to any host")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tools.traceroute.isRunning { PulsingIndicator(color: .blue) }
            }
        }
    }

    // MARK: - Traffic

    private var trafficCard: some View {
        BentoCard(
            title: "Bandwidth & Usage",
            icon: "chart.bar.xaxis",
            color: .blue,
            action: { selection = .bandwidth },
            helpText: "Live download/upload throughput, peak rate, and today's total data usage."
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                HStack {
                    RatePill(dir: "↓", val: tools.bandwidth.totalRxBps, color: .blue)
                    Spacer()
                    RatePill(dir: "↑", val: tools.bandwidth.totalTxBps, color: .orange)
                }
                Divider().opacity(0.5)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Today").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                        Text(NetworkMath.formatBytes(tools.statistics.todayRx + tools.statistics.todayTx))
                            .font(.subheadline.monospaced().weight(.bold))
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Peak ↓").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                        Text(NetworkMath.formatRate(tools.bandwidth.peakRx))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var wifiCard: some View {
        BentoCard(
            title: "Wi-Fi",
            icon: "wifi",
            color: .indigo,
            action: { selection = .wifi },
            helpText: "Connected network details: SSID, signal strength (RSSI), channel, and security."
        ) {
            if let info = tools.wifi.info {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    HStack {
                        Text(info.ssid ?? "Connected")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        if let rssi = info.rssi {
                            Image(systemName: rssi > -60 ? "wifi" : (rssi > -75 ? "wifi.exclamationmark" : "wifi.slash"))
                                .foregroundColor(rssi > -60 ? .green : (rssi > -75 ? .orange : .red))
                                .font(.caption)
                        }
                    }
                    if let rssi = info.rssi {
                        HStack(spacing: Metrics.spacingXS) {
                            Text("\(rssi) dBm")
                                .font(.caption.monospaced())
                                .foregroundColor(rssi > -60 ? .green : (rssi > -75 ? .orange : .red))
                            SignalQualityBadge(rssi: rssi)
                        }
                    }
                    if let channel = info.channel {
                        Text("Channel \(channel)\(info.band.map { " (\($0))" } ?? "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Not Connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Enable Wi-Fi to see network details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var interfacesCard: some View {
        let active = tools.interfaces.interfaces.filter(\.isUp).count
        let total = tools.interfaces.interfaces.count
        return BentoCard(
            title: "Interfaces",
            icon: "network",
            color: .purple,
            action: { selection = .interfaces },
            helpText: "All network adapters with IP addresses, MAC addresses, and per-interface traffic."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(active) of \(total) active")
                        .font(.subheadline.bold())
                    if total > 0 && active == total {
                        Label("All interfaces up", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if active < total {
                        Label("\(total - active) down", systemImage: "xmark.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Performance & Discovery

    private var speedTestCard: some View {
        BentoCard(
            title: "Speed Test",
            icon: "speedometer",
            color: .green,
            action: { selection = .speedTest },
            helpText: "Run a full internet speed test using Cloudflare. Measures download, upload, latency, and jitter."
        ) {
            if let result = tools.speedTest.lastResult {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "↓ %.1f", result.downloadMbps))
                                .font(.system(size: Metrics.subMetricNumber, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                            Text("Mbps").font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        if tools.speedTest.history.count > 1 {
                            DashboardSparkline(
                                data: tools.speedTest.history.suffix(20).compactMap { $0.kind == .speed ? $0.downloadMbps : nil },
                                color: .green
                            )
                            .frame(width: 60, height: 24)
                        }
                    }
                    HStack(spacing: Metrics.spacingLG) {
                        Text(String(format: "↑ %.1f Mbps", result.uploadMbps))
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                        Text("Latency: \(Int(result.pingMs)) ms")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text(tools.speedTest.isRunning ? "Running…" : "Not yet run")
                        .font(.subheadline.bold())
                    Text("Measures real-world internet performance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if tools.speedTest.isRunning {
                        PulsingIndicator(color: .green)
                    }
                }
            }
        }
    }

    private var dnsCard: some View {
        BentoCard(
            title: "DNS Lookup",
            icon: "globe",
            color: .blue,
            action: { selection = .dns },
            helpText: "Query DNS records (A, AAAA, CNAME, MX, TXT, NS) with response times and record details."
        ) {
            if let result = tools.dns.result, !tools.dns.lastQuery.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tools.dns.lastQuery)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    let detail = [
                        result.queryTimeMs.map { "\($0) ms" },
                        "\(result.records.count) records"
                    ].compactMap { $0 }.joined(separator: " · ")
                    Text(detail)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                    let types = Set(result.records.map { $0.type })
                    if !types.isEmpty {
                        Text(types.sorted().joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Resolver Audit")
                        .font(.subheadline.bold())
                    Text("Query any domain's DNS records")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var portScanCard: some View {
        BentoCard(
            title: "Port Scanner",
            icon: "checklist",
            color: .orange,
            action: { selection = .portScan },
            helpText: "Find open ports on any device. Useful for checking firewall rules and exposed services."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    if tools.portScan.isRunning {
                        Text("Scanning ports…")
                            .font(.subheadline.bold())
                    } else if tools.portScan.openCount > 0 {
                        Text("\(tools.portScan.openCount) open ports")
                            .font(.subheadline.bold())
                    } else {
                        Text("Port Scanner")
                            .font(.subheadline.bold())
                    }
                    if tools.portScan.isRunning {
                        Text("Checking common service ports…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if tools.portScan.openCount == 0 && !tools.portScan.currentHost.isEmpty {
                        Text("Last scan: \(tools.portScan.currentHost) — no open ports")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Audit exposed services on a host")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tools.portScan.isRunning { PulsingIndicator(color: .orange) }
            }
        }
    }

    private func RatePill(dir: String, val: Double, color: Color) -> some View {
        HStack(spacing: Metrics.spacingXS) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(NetworkMath.formatRate(val)).font(.callout.monospaced().weight(.bold))
        }
        .padding(.horizontal, Metrics.spacingSM)
        .padding(.vertical, Metrics.spacingXS)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct SignalQualityBadge: View {
    let rssi: Int

    var body: some View {
        let (label, color) = qualityLabel(for: rssi)
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func qualityLabel(for rssi: Int) -> (String, Color) {
        switch rssi {
        case ..<(-85): return ("Weak", .red)
        case -85..<(-70): return ("Fair", .orange)
        case -70..<(-55): return ("Good", .green)
        default: return ("Excellent", .green)
        }
    }
}
