import SwiftUI

struct TrafficCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Network & Traffic", icon: "wifi.router.fill")

            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    bandwidthCard
                    statisticsCard
                    interfacesCard
                }
            }
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    wifiCard
                    tracerouteCard
                    routeTableCard
                }
            }
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    sslCard
                    httpCard
                    dnsCard
                }
            }
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    speedTestCard
                    subnetScannerCard
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var bandwidthCard: some View {
        BentoCard(title: "Bandwidth", icon: "chart.bar.xaxis", color: .blue, action: { selection = .bandwidth }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    rateMini(dir: "↓", val: tools.bandwidth.totalRxBps, color: .blue)
                    Spacer()
                    rateMini(dir: "↑", val: tools.bandwidth.totalTxBps, color: .orange)
                }
                Text("Peak: \(NetworkMath.formatRate(tools.bandwidth.peakRx))").font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
            }
        }
    }

    private var statisticsCard: some View {
        BentoCard(title: "Statistics", icon: "chart.line.uptrend.xyaxis", color: .orange, action: { selection = .statistics }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Traffic").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                Text(NetworkMath.formatBytes(tools.statistics.todayRx + tools.statistics.todayTx))
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
            }
        }
    }

    private var interfacesCard: some View {
        let active = tools.interfaces.interfaces.filter(\.isUp).count
        return BentoCard(title: "Interfaces", icon: "network", color: .purple, action: { selection = .interfaces }) {
            HStack {
                Text("\(active) Active").font(.subheadline.bold())
                Spacer()
                Image(systemName: "checklist").foregroundColor(.secondary)
            }
        }
    }

    private var wifiCard: some View {
        BentoCard(title: "Wi-Fi", icon: "wifi", color: .indigo, action: { selection = .wifi }) {
            if let info = tools.wifi.info {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.ssid ?? "Connected").font(.subheadline.bold()).lineLimit(1)
                    Text("\(info.rssi ?? 0) dBm").font(.system(.caption, design: .monospaced))
                        .foregroundColor((info.rssi ?? -100) > -60 ? .green : .orange)
                }
            } else {
                Text("Not Connected").font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private var tracerouteCard: some View {
        BentoCard(title: "Traceroute", icon: "point.3.connected.trianglepath.dotted", color: .blue, action: { selection = .traceroute }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !tools.traceroute.hops.isEmpty {
                        Text(tools.traceroute.currentHost)
                            .font(.subheadline.bold()).lineLimit(1)
                        Text("\(tools.traceroute.hops.count) hops")
                            .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                    } else {
                        Text("Path Discovery").font(.subheadline.bold())
                    }
                }
                Spacer()
                if tools.traceroute.isRunning { PulsingIndicator(color: .blue) }
            }
        }
    }

    private var routeTableCard: some View {
        BentoStatusCard(
            title: "Route Table",
            icon: "arrow.triangle.branch",
            color: .teal,
            status: "IPv4/IPv6 Matrix",
            action: { selection = .routes }
        )
    }

    private var sslCard: some View {
        let items    = tools.sslWatchlist.items
        let expiring = items.filter { $0.status == .warning || $0.status == .critical || $0.status == .expired }
        let critical = items.filter { $0.status == .critical || $0.status == .expired }
        let cardColor: Color = critical.isEmpty ? .teal : .red
        return BentoCard(title: "SSL/TLS", icon: "lock.shield", color: cardColor, action: { selection = .ssl }) {
            VStack(alignment: .leading, spacing: 4) {
                if !items.isEmpty {
                    Text("\(items.count) Watched").font(.subheadline.bold())
                    if expiring.isEmpty {
                        Text("All Valid").font(.system(.caption2, design: .monospaced)).foregroundColor(.green)
                    } else {
                        Text("\(expiring.count) Expiring")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(critical.isEmpty ? .orange : .red)
                    }
                } else {
                    Text("Certificate Audit").font(.subheadline.bold())
                }
            }
        }
    }

    private var httpCard: some View {
        BentoCard(title: "HTTP Latency", icon: "stopwatch", color: .pink, action: { selection = .httpLatency }) {
            if let result = tools.httpLatency.result {
                let host = URL(string: result.url)?.host ?? result.url
                let ttfb = result.phases.first(where: { $0.phase == .ttfb })?.durationMs
                VStack(alignment: .leading, spacing: 2) {
                    Text(host).font(.subheadline.bold()).lineLimit(1)
                    if let ttfb {
                        Text(String(format: "TTFB: %.1f ms", ttfb))
                            .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                    }
                }
            } else {
                Text("TTFB Breakdown").font(.subheadline.bold())
            }
        }
    }

    private var dnsCard: some View {
        BentoCard(title: "DNS Lookup", icon: "globe", color: .blue, action: { selection = .dns }) {
            if let result = tools.dns.result, !tools.dns.lastQuery.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tools.dns.lastQuery).font(.subheadline.bold()).lineLimit(1)
                    let detail = [
                        result.queryTimeMs.map { "\($0) ms" },
                        "\(result.records.count) records"
                    ].compactMap { $0 }.joined(separator: " · ")
                    Text(detail).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                }
            } else {
                Text("Resolver Audit").font(.subheadline.bold())
            }
        }
    }

    private var speedTestCard: some View {
        BentoCard(title: "Speed Test", icon: "speedometer", color: .green, action: { selection = .speedTest }) {
            if let result = tools.speedTest.lastResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "↓ %.1f", result.downloadMbps))
                                .font(.system(size: Metrics.subMetricNumber, weight: .bold, design: .monospaced))
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
                    Text(String(format: "↑ %.1f Mbps", result.uploadMbps))
                        .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                }
            } else {
                Text("Run Speed Test").font(.subheadline.bold())
            }
        }
    }

    private var subnetScannerCard: some View {
        BentoCard(title: "Subnet Scanner", icon: "network.badge.shield.half.filled", color: .purple, action: { selection = .subnetScan }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !tools.subnetScan.results.isEmpty {
                        Text(tools.subnetScan.cidrInput).font(.subheadline.bold()).lineLimit(1)
                        Text("\(tools.subnetScan.scanStats.alive) alive")
                            .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                    } else {
                        Text("Network Discovery").font(.subheadline.bold())
                    }
                }
                Spacer()
                if tools.subnetScan.isRunning { PulsingIndicator(color: .purple) }
            }
        }
    }

    private func rateMini(dir: String, val: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(NetworkMath.formatRate(val)).font(.system(.callout, design: .monospaced).weight(.bold))
        }
    }
}
