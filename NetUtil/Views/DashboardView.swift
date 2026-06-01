import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    @State private var launchDate = Date()
    @State private var uptimeString = "0m"
    @State private var localHostName = Host.current().localizedName ?? "Local Mac"

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            healthSummaryBar

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DashboardHeroSection(selection: $selection)

                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Core Diagnostics", icon: "bolt.shield.fill")

                        HStack(spacing: 12) {
                            pingCard.frame(maxWidth: .infinity)
                            VStack(spacing: 12) {
                                multiPingCard
                                portScanCard
                            }
                            .frame(width: 280)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Network & Traffic", icon: "wifi.router.fill")

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            bandwidthCard
                            statisticsCard
                            interfacesCard
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            wifiCard
                            tracerouteCard
                            routeTableCard
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            sslCard
                            httpCard
                            dnsCard
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            speedTestCard
                            subnetScannerCard
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Infrastructure Lookup", icon: "magnifyingglass.circle.fill")

                        HStack(spacing: 12) {
                            whoisCard
                            subnetCard
                            topProcessesCard
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Color(.windowBackgroundColor).ignoresSafeArea())
        .task {
            uptimeString = formatUptime(from: launchDate)
            while true {
                try? await Task.sleep(for: .seconds(60))
                uptimeString = formatUptime(from: launchDate)
            }
        }
        .onAppear {
            tools.wifi.start()
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localHostName)
                        .font(.system(.title3, design: .default).bold())
                        .tracking(-0.2)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 ? .green : .secondary)
                                .font(.system(size: 10))
                            Text(tools.currentConnectionName)
                                .font(.system(.caption, design: .default).weight(.semibold))
                        }

                        Divider().frame(height: 10)

                        gatewayChip(label: "Local", value: tools.primaryLocalIP)
                        gatewayChip(label: "Public", value: tools.externalIP)

                        if tools.isVPNActive {
                            Text("VPN")
                                .font(.system(.caption2, design: .default).weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }

                        Divider().frame(height: 10)

                        Text("Uptime: \(uptimeString)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    healthGauge(
                        label: "CPU",
                        value: String(format: "%.0f%%", tools.system.cpuUsage),
                        progress: tools.system.cpuUsage / 100,
                        color: tools.system.cpuUsage > 75 ? .red : .accentColor
                    )
                    .help(String(format: "CPU: %.0f%% — %d cores", tools.system.cpuUsage, ProcessInfo.processInfo.processorCount))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("CPU Usage")
                    .accessibilityValue(String(format: "%.0f percent", tools.system.cpuUsage))

                    let ramPct = tools.system.ramTotalGB > 0
                        ? tools.system.ramUsedGB / tools.system.ramTotalGB
                        : 0.3
                    healthGauge(
                        label: "RAM",
                        value: tools.system.memoryPressure.capitalized,
                        subtitle: String(format: "%.1f / %.0f GB", tools.system.ramUsedGB, tools.system.ramTotalGB),
                        progress: tools.system.memoryColor == "red" ? 0.9 : (tools.system.memoryColor == "orange" ? 0.6 : ramPct),
                        color: tools.system.memoryColor == "red" ? .red : (tools.system.memoryColor == "orange" ? .orange : .accentColor)
                    )
                    .help(String(format: "RAM: %.1f / %.0f GB (%.0f%%)", tools.system.ramUsedGB, tools.system.ramTotalGB, ramPct * 100))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Memory Pressure")
                    .accessibilityValue(tools.system.memoryPressure)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()
        }
        .background(.regularMaterial)
    }

    // MARK: - Health Summary Bar

    private var healthSummaryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: tools.healthIcon)
                .foregroundColor(tools.healthColor == "red" ? .red : (tools.healthColor == "orange" ? .orange : .green))
                .font(.system(.callout, weight: .semibold))
            Text(tools.healthMessage)
                .font(.callout)
                .foregroundColor(tools.healthColor == "green" ? .secondary : (tools.healthColor == "red" ? .red : .orange))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func formatUptime(from date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let hours   = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(max(minutes, 0))m"
    }

    // MARK: - Sub-components

    private func gatewayChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(value).font(.system(.caption2, design: .monospaced).weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) IP address")
        .accessibilityValue(value)
    }

    private func healthGauge(label: String, value: String, subtitle: String? = nil, progress: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(value)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundColor(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.1)).frame(width: 40, height: 4)
                    Capsule().fill(color).frame(width: 40 * max(0.05, min(progress, 1.0)), height: 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Core Diagnostics Cards

    private var pingCard: some View {
        BentoCard(title: "Advanced Ping", icon: "antenna.radiowaves.left.and.right", color: .blue, action: { selection = .ping }) {
            let isRunning = tools.ping.isRunning
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tools.ping.currentHost.isEmpty ? "Idle" : tools.ping.currentHost)
                            .font(.headline).lineLimit(1)
                        if isRunning {
                            Text("Monitoring Latency").font(.caption).foregroundColor(.green).bold()
                        }
                    }
                    Spacer()
                    if isRunning { PulsingIndicator(color: .green) }
                }
                if !tools.ping.results.isEmpty {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%.1f", tools.ping.stats.avgRtt)).font(.system(size: 28, weight: .bold, design: .monospaced))
                            Text("ms avg").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                        DashboardSparkline(data: tools.ping.results.suffix(40).map { $0.rtt }, color: isRunning ? .green : .blue)
                            .frame(width: 140, height: 32)
                    }
                } else {
                    Text("Enter a host to analyze latency performance and jitter.")
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var multiPingCard: some View {
        BentoCard(title: "Multi-Ping", icon: "dot.radiowaves.left.and.right", color: .accentColor, action: { selection = .multiPing }) {
            HStack {
                Text("\(tools.multiPing.slots.count) Nodes").font(.subheadline.bold())
                Spacer()
                if tools.multiPing.slots.contains(where: { $0.isRunning }) { PulsingIndicator(color: .accentColor) }
            }
        }
    }

    private var portScanCard: some View {
        BentoCard(title: "Port Scanner", icon: "checklist", color: .orange, action: { selection = .portScan }) {
            HStack {
                Text(tools.portScan.isRunning ? "Scanning..." : "\(tools.portScan.openCount) Open").font(.subheadline.bold())
                Spacer()
                if tools.portScan.isRunning { PulsingIndicator(color: .orange) }
            }
        }
    }

    // MARK: - Network & Traffic Cards

    private var bandwidthCard: some View {
        BentoCard(title: "Bandwidth", icon: "chart.bar.xaxis", color: .blue, action: { selection = .bandwidth }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    rateMini(dir: "↓", val: tools.bandwidth.totalRxBps, color: .blue)
                    Spacer()
                    rateMini(dir: "↑", val: tools.bandwidth.totalTxBps, color: .orange)
                }
                Text("Peak: \(NetworkMath.formatRate(tools.bandwidth.peakRx))").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
                    Text("\(info.rssi ?? 0) dBm").font(.system(size: 11, design: .monospaced))
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
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
        BentoCard(title: "Route Table", icon: "arrow.triangle.branch", color: .teal, action: { selection = .routes }) {
            Text("IPv4/IPv6 Matrix").font(.subheadline.bold())
        }
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
                        Text("All Valid").font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                    } else {
                        Text("\(expiring.count) Expiring")
                            .font(.system(size: 10, design: .monospaced))
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
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
                    Text(detail).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
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
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    } else {
                        Text("Network Discovery").font(.subheadline.bold())
                    }
                }
                Spacer()
                if tools.subnetScan.isScanning { PulsingIndicator(color: .purple) }
            }
        }
    }

    // MARK: - Infrastructure Cards

    private var whoisCard: some View {
        BentoCard(title: "WHOIS", icon: "magnifyingglass.circle", color: .gray, action: { selection = .whois }) {
            if !tools.whois.lastQuery.isEmpty {
                Text(tools.whois.lastQuery).font(.subheadline.bold()).lineLimit(1)
            } else {
                Text("Domain Registry").font(.subheadline.bold())
            }
        }
    }

    private var subnetCard: some View {
        BentoCard(title: "Subnet Calc", icon: "number.square", color: .green, action: { selection = .subnet }) {
            Text("CIDR Toolbox").font(.subheadline.bold())
        }
    }

    private var topProcessesCard: some View {
        BentoCard(title: "Top Apps", icon: "chart.bar.xaxis", color: .orange, action: { selection = .topApps }) {
            Text("Process Monitor").font(.subheadline.bold())
        }
    }

    private func rateMini(dir: String, val: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(NetworkMath.formatRate(val)).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }
}

// MARK: - Bento Components

struct BentoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let content: Content

    @State private var isHovered = false

    init(title: String, icon: String, color: Color, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.icon    = icon
        self.color   = color
        self.action  = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.1)).frame(width: 24, height: 24)
                        Image(systemName: icon).font(.system(.caption, design: .default).weight(.bold)).foregroundColor(color)
                    }
                    Text(title).font(.system(.caption, design: .default).weight(.bold)).foregroundColor(.secondary)
                }
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isHovered ? color.opacity(0.3) : Color(.separatorColor).opacity(0.1), lineWidth: 1))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) Diagnostic Card")
            .accessibilityHint("Tap to open \(title)")
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct PulsingIndicator: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 3)
                    .scaleEffect(pulse ? 2.5 : 1.0)
                    .opacity(pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

struct DashboardSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range  = max(maxVal - minVal, 1.0)
            let stepX  = size.width / CGFloat(data.count - 1)
            var path   = Path()
            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((value - minVal) / range) * size.height
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(color), lineWidth: 2)
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(0.15), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
        }
        .accessibilityLabel("Trend sparkline")
    }
}
