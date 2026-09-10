import SwiftUI

struct TrafficCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Network & Traffic", icon: "wifi.router.fill")

            // Row 1: Bandwidth, Statistics, Interfaces
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    bandwidthCard
                    statisticsCard
                    interfacesCard
                }
            }
            // Row 2: Wi-Fi, Traceroute, Route Table
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    wifiCard
                    tracerouteCard
                    routeTableCard
                }
            }
            // Row 3: SSL/TLS, HTTP Latency, DNS Lookup
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    sslCard
                    httpCard
                    dnsCard
                }
            }
            // Row 4: Speed Test, Subnet Scanner
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    speedTestCard
                    subnetScannerCard
                }
            }
        }
    }

    private var bandwidthCard: some View {
        BentoCard(
            title: "Bandwidth Monitor",
            icon: "chart.bar.xaxis",
            color: .blue,
            action: { selection = .bandwidth },
            helpText: "Real-time network throughput. See live download/upload speeds, peak rates, and historical charts."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RatePill(dir: "↓", val: tools.bandwidth.totalRxBps, color: .blue)
                    Spacer()
                    RatePill(dir: "↑", val: tools.bandwidth.totalTxBps, color: .orange)
                }
                HStack {
                    Label("Peak ↓ \(NetworkMath.formatRate(tools.bandwidth.peakRx))", systemImage: "arrow.up.right")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                    Spacer()
                    if tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 {
                        Label("Active", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private var statisticsCard: some View {
        BentoCard(
            title: "Traffic Statistics",
            icon: "chart.line.uptrend.xyaxis",
            color: .orange,
            action: { selection = .statistics },
            helpText: "Daily, weekly, and monthly data usage totals. Track your bandwidth consumption over time."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Usage").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                Text(NetworkMath.formatBytes(tools.statistics.todayRx + tools.statistics.todayTx))
                    .font(.subheadline.monospaced().weight(.bold))
                    .contentTransition(.numericText())
                if tools.statistics.todayRx + tools.statistics.todayTx > 0 {
                    HStack(spacing: 16) {
                        Label("↓ \(NetworkMath.formatBytes(tools.statistics.todayRx))", systemImage: "arrow.down")
                            .font(.caption2.monospaced())
                            .foregroundColor(.blue)
                        Label("↑ \(NetworkMath.formatBytes(tools.statistics.todayTx))", systemImage: "arrow.up")
                            .font(.caption2.monospaced())
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    private var interfacesCard: some View {
        let active = tools.interfaces.interfaces.filter(\.isUp).count
        let total = tools.interfaces.interfaces.count
        return BentoCard(
            title: "Network Interfaces",
            icon: "network",
            color: .purple,
            action: { selection = .interfaces },
            helpText: "View all network adapters with IP addresses, MAC addresses, and traffic stats for each."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(active) of \(total) active")
                        .font(.subheadline.bold())
                    if active == total && total > 0 {
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

    private var wifiCard: some View {
        BentoCard(
            title: "Wi-Fi",
            icon: "wifi",
            color: .indigo,
            action: { selection = .wifi },
            helpText: "View connected network details: SSID, signal strength (RSSI), channel, security type, and noise."
        ) {
            if let info = tools.wifi.info {
                VStack(alignment: .leading, spacing: 4) {
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
                        HStack(spacing: 4) {
                            Text("\(rssi) dBm")
                                .font(.caption.monospaced())
                                .foregroundColor(rssi > -60 ? .green : (rssi > -75 ? .orange : .red))
                            SignalQualityBadge(rssi: rssi)
                        }
                    }
                    if let channel = info.channel {
                        Text("Channel \(channel)\(info.band != nil ? " (\(info.band!))" : "")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
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
                        HStack(spacing: 8) {
                            Label("\(tools.traceroute.hops.count) hops", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            if let lastHop = tools.traceroute.hops.last,
                               let avgRtt = lastHop.avgRtt {
                                Label("\(Int(avgRtt)) ms to destination", systemImage: "speedometer")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Path Discovery")
                            .font(.subheadline.bold())
                        Text("Enter a host to trace network path")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            status: "IPv4 & IPv6 Routes",
            action: { selection = .routes },
            helpText: "View system routing tables. See default gateways, interface routes, and network prefixes.",
            detail: "macOS routing"
        )
    }

    private var sslCard: some View {
        let items    = tools.sslWatchlist.items
        let expiring = items.filter { $0.status == .warning || $0.status == .critical || $0.status == .expired }
        let critical = items.filter { $0.status == .critical || $0.status == .expired }
        let cardColor: Color = critical.isEmpty ? .teal : .red
        return BentoCard(
            title: "SSL/TLS Certificates",
            icon: "lock.shield",
            color: cardColor,
            action: { selection = .ssl },
            helpText: "Monitor SSL certificate expiration for your domains. Get alerts before certificates expire."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if !items.isEmpty {
                    HStack {
                        Text("\(items.count) watched")
                            .font(.subheadline.bold())
                        Spacer()
                        if critical.isEmpty && expiring.isEmpty {
                            Label("All valid", systemImage: "checkmark.shield.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    if expiring.isEmpty {
                        Label("All certificates are valid", systemImage: "checkmark.circle.fill")
                            .font(.caption2.monospaced())
                            .foregroundColor(.green)
                    } else {
                        HStack(spacing: 8) {
                            Label("\(expiring.count) need attention", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.monospaced())
                                .foregroundColor(critical.isEmpty ? .orange : .red)
                            if !critical.isEmpty {
                                Label("\(critical.count) critical", systemImage: "xmark.octagon.fill")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    // Show nearest expiry
                    if let nearest = items.min(by: { 
                        let d0 = ($0.expiryDate.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }) ?? 0
                        let d1 = ($1.expiryDate.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }) ?? 0
                        return d0 < d1
                    }),
                    let expiryDate = nearest.expiryDate {
                        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
                        Text("Expires in \(daysUntil) days (\(nearest.domain))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Certificate Audit")
                            .font(.subheadline.bold())
                        Text("Add domains to monitor SSL certificates")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var httpCard: some View {
        BentoCard(
            title: "HTTP Latency",
            icon: "stopwatch",
            color: .pink,
            action: { selection = .httpLatency },
            helpText: "Measure website response time breakdown: DNS, TCP, TLS, TTFB, and download phases."
        ) {
            if let result = tools.httpLatency.result {
                let host = URL(string: result.url)?.host ?? result.url
                let ttfb = result.phases.first(where: { $0.phase == .ttfb })?.durationMs
                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if let ttfb {
                        HStack(spacing: 8) {
                            Label("TTFB: \(String(format: "%.1f", ttfb)) ms", systemImage: "timer")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            Label("\(result.phases.count) phases", systemImage: "list.number")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TTFB Breakdown")
                        .font(.subheadline.bold())
                    Text("Enter a URL to analyze HTTP response time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
            helpText: "Query DNS records (A, AAAA, CNAME, MX, TXT, NS). See response times and record details."
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
                    // Show record types found
                    let types = Set(result.records.map { $0.type })
                    if !types.isEmpty {
                        Text(types.sorted().joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resolver Audit")
                        .font(.subheadline.bold())
                    Text("Enter a domain to query DNS records")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var speedTestCard: some View {
        BentoCard(
            title: "Speed Test",
            icon: "speedometer",
            color: .green,
            action: { selection = .speedTest },
            helpText: "Run a full internet speed test using Cloudflare. Measures download, upload, latency, and jitter."
        ) {
            if let result = tools.speedTest.lastResult {
                VStack(alignment: .leading, spacing: 4) {
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
                    HStack(spacing: 16) {
                        Text(String(format: "↑ %.1f Mbps", result.uploadMbps))
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                        Text("Latency: \(Int(result.pingMs)) ms")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run Speed Test")
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

    private var subnetScannerCard: some View {
        BentoCard(
            title: "Subnet Scanner",
            icon: "network.badge.shield.half.filled",
            color: .purple,
            action: { selection = .subnetScan },
            helpText: "Discover all devices on your local network. Shows IP, MAC, hostname, and vendor for each host."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !tools.subnetScan.results.isEmpty {
                        Text(tools.subnetScan.cidrInput)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        HStack(spacing: 12) {
                            Label("\(tools.subnetScan.scanStats.alive) devices found", systemImage: "checkmark.circle.fill")
                                .font(.caption2.monospaced())
                                .foregroundColor(.green)
                            if tools.subnetScan.scanStats.total > 0 {
                                Label("\(tools.subnetScan.scanStats.total) scanned", systemImage: "scope")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Network Discovery")
                            .font(.subheadline.bold())
                        Text("Enter a CIDR range (e.g., 192.168.1.0/24)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tools.subnetScan.isRunning { PulsingIndicator(color: .purple) }
            }
        }
    }

    private func RatePill(dir: String, val: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(NetworkMath.formatRate(val)).font(.callout.monospaced().weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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