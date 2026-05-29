import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // HERO SECTION: Network Activity
                    networkHeroSection

                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Core Diagnostics", icon: "bolt.shield.fill")

                        HStack(spacing: 12) {
                            pingCard
                                .frame(maxWidth: .infinity)

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
        .onAppear {
            tools.wifi.start()
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
        }
    }
    
    // MARK: - Header Components
    
    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Host.current().localizedName ?? "Local Mac")
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
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    healthGauge(label: "CPU", value: String(format: "%.0f%%", tools.system.cpuUsage), progress: tools.system.cpuUsage / 100, color: tools.system.cpuUsage > 75 ? .red : .accentColor)
                    healthGauge(label: "RAM", value: tools.system.memoryPressure.capitalized, progress: tools.system.memoryColor == "red" ? 0.9 : (tools.system.memoryColor == "orange" ? 0.6 : 0.3), color: tools.system.memoryColor == "red" ? .red : (tools.system.memoryColor == "orange" ? .orange : .accentColor))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
        .background(.regularMaterial)
    }
    
    private func gatewayChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(value).font(.system(.caption2, design: .monospaced).weight(.medium))
        }
    }

    private func healthGauge(label: String, value: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundColor(.primary)
                
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
    }

    // MARK: - Hero Section

    private var networkHeroSection: some View {
        Button { selection = .bandwidth } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Activity")
                            .font(.headline)
                        Text("Live aggregate throughput")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 16) {
                        heroRateMetric(label: "Download", value: tools.bandwidth.totalRxBps, color: .blue)
                        heroRateMetric(label: "Upload", value: tools.bandwidth.totalTxBps, color: .orange)
                    }
                }
                
                Chart {
                    ForEach(tools.bandwidth.totalHistory) { s in
                        AreaMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                        AreaMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.15), .orange.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 80)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func heroRateMetric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(NetworkMath.formatRate(value))
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(color)
        }
    }

    // MARK: - Bento Cards (Diagnostics)

    private var pingCard: some View {
        BentoCard(title: "Advanced Ping", icon: "antenna.radiowaves.left.and.right", color: .blue, action: { selection = .ping }) {
            let isRunning = tools.ping.isRunning
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tools.ping.currentHost.isEmpty ? "Idle" : tools.ping.currentHost)
                            .font(.headline)
                            .lineLimit(1)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
                if tools.multiPing.slots.contains(where: { $0.isRunning }) {
                    PulsingIndicator(color: .accentColor)
                }
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

    // MARK: - Network Cards

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
                        .foregroundColor(info.rssi ?? -100 > -60 ? .green : .orange)
                }
            } else {
                Text("Not Connected").font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private var tracerouteCard: some View {
        BentoCard(title: "Traceroute", icon: "point.3.connected.trianglepath.dotted", color: .blue, action: { selection = .traceroute }) {
            HStack {
                Text("Path Discovery").font(.subheadline.bold())
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
        BentoCard(title: "SSL/TLS", icon: "lock.shield", color: .teal, action: { selection = .ssl }) {
            Text("Certificate Audit").font(.subheadline.bold())
        }
    }

    private var httpCard: some View {
        BentoCard(title: "HTTP Latency", icon: "stopwatch", color: .pink, action: { selection = .httpLatency }) {
            Text("TTFB Breakdown").font(.subheadline.bold())
        }
    }

    private var dnsCard: some View {
        BentoCard(title: "DNS Lookup", icon: "globe", color: .blue, action: { selection = .dns }) {
            Text("Resolver Audit").font(.subheadline.bold())
        }
    }

    private var whoisCard: some View {
        BentoCard(title: "WHOIS", icon: "magnifyingglass.circle", color: .gray, action: { selection = .whois }) {
            Text("Domain Registry").font(.subheadline.bold())
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
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.1))
                            .frame(width: 24, height: 24)
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
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
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
            let range = max(maxVal - minVal, 1.0)
            let stepX = size.width / CGFloat(data.count - 1)
            var path = Path()
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - CGFloat((value - minVal) / range) * size.height
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), lineWidth: 2)
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .linearGradient(Gradient(colors: [color.opacity(0.15), color.opacity(0.0)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
        }
    }
}
