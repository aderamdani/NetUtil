import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    // Define consistent card heights and grid layouts for symmetry
    private let toolCardMinHeight: CGFloat = 150
    private let connectivityCardMinHeight: CGFloat = 130
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                
                VStack(spacing: 28) {
                    // SECTION 1: ACTIVE DIAGNOSTICS
                    SectionView(title: "Diagnostic Control Center", icon: "bolt.shield.fill", description: "Monitor and manage your active network probes.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            pingSummaryCard
                            multiPingSummaryCard
                            portScanSummaryCard
                        }
                    }
                    
                    // SECTION 2: NETWORK INFRASTRUCTURE
                    SectionView(title: "Connectivity Infrastructure", icon: "wifi.router.fill", description: "Detailed status of your local and wireless connection points.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            wifiSummaryCard
                            interfaceSummaryCard
                        }
                    }
                    
                    // SECTION 3: SECURITY & ANALYTICS
                    SectionView(title: "Security & Traffic Insights", icon: "shield.checkerboard", description: "Deep analysis of security protocols and data flow.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            bandwidthSummaryCard
                            dnsSummaryCard
                        }
                    }
                }
            }
            .padding(32)
        }
        .background {
            ZStack {
                Color(.windowBackgroundColor)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            tools.wifi.start()
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mission Control")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text(Host.current().localizedName ?? "macOS Workstation")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 10) {
                    let cpuColor: Color = tools.system.cpuUsage > 70 ? .red : (tools.system.cpuUsage > 40 ? .orange : .green)
                    SystemStatBadge(icon: "cpu", value: String(format: "CPU %.0f%%", tools.system.cpuUsage), color: cpuColor)
                        .help("Real-time processor utilization. Lower is better for stable network measurement.")
                    
                    let memColor: Color = tools.system.memoryColor == "red" ? .red : (tools.system.memoryColor == "orange" ? .orange : .blue)
                    SystemStatBadge(icon: "memorychip", value: "RAM \(tools.system.memoryPressure.uppercased())", color: memColor)
                        .help("System memory pressure status. High pressure can affect app responsiveness.")
                }
                .padding(.top, 4)
            }
            
            // Identity Bar with Educational Tooltips
            HStack(spacing: 12) {
                if let localIP = tools.interfaces.interfaces.first(where: { $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty })?.ipv4.first {
                    IdentityBadge(label: "LOCAL GATEWAY", value: localIP, icon: "house.fill", color: .blue)
                        .help("Your private IP address on the local network (LAN).")
                }
                
                IdentityBadge(label: "PUBLIC GATEWAY", value: tools.externalIP, icon: "globe", color: .accentColor)
                    .help("Your global IP address as seen by the outside world.")
                
                if let vpnIface = tools.interfaces.interfaces.first(where: { $0.name.starts(with: "utun") && $0.isUp && !$0.ipv4.isEmpty }) {
                    IdentityBadge(label: "VPN TUNNEL", value: vpnIface.ipv4.first ?? "Active", icon: "lock.shield.fill", color: .green)
                        .help("Encrypted VPN tunnel IP address.")
                }
            }
        }
    }
    
    // MARK: - Diagnostic Cards
    
    private var pingSummaryCard: some View {
        let isRunning = tools.ping.isRunning
        return DashboardCard(title: "Advanced Ping", icon: "antenna.radiowaves.left.and.right", color: isRunning ? .green : .secondary, minHeight: toolCardMinHeight) {
            selection = .ping
        } quickAction: {
            if isRunning { tools.ping.stop() }
            else if !tools.ping.currentHost.isEmpty { tools.ping.start(host: tools.ping.currentHost, count: nil, interval: 1.0) }
            else { selection = .ping }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    StatusIndicator(isActive: isRunning)
                    Text(isRunning ? "Monitoring..." : "System Idle")
                        .font(.subheadline.bold())
                }
                .help(isRunning ? "Actively measuring round-trip time to \(tools.ping.currentHost)." : "No active probe.")
                
                if !tools.ping.results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        let stats = tools.ping.stats
                        HStack(alignment: .bottom) {
                            MetricView(label: "Avg Latency", value: String(format: "%.1fms", stats.avgRtt), color: .primary)
                            Spacer()
                            DashboardSparkline(data: tools.ping.results.suffix(25).map { $0.rtt }, color: isRunning ? .green : .secondary)
                                .frame(width: 70, height: 25)
                        }
                        MetricView(label: "Packet Loss", value: String(format: "%.0f%%", stats.loss), color: stats.loss > 0 ? .red : .secondary)
                    }
                } else {
                    Text("Select a host to visualize real-time network latency trends.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var multiPingSummaryCard: some View {
        let activeCount = tools.multiPing.slots.filter { $0.isRunning }.count
        let totalCount = tools.multiPing.slots.count
        return DashboardCard(title: "Multi-Ping", icon: "dot.radiowaves.left.and.right", color: activeCount > 0 ? .accentColor : .secondary, minHeight: toolCardMinHeight) {
            selection = .multiPing
        } quickAction: {
            if activeCount > 0 { tools.multiPing.stopAll() }
            else { tools.multiPing.startAll() }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(activeCount) active / \(totalCount) targets")
                    .font(.subheadline.bold())
                
                if totalCount > 0 {
                    let avgLoss = tools.multiPing.slots.map { $0.loss }.reduce(0, +) / Double(totalCount)
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(activeCount), total: Double(max(totalCount, 1)))
                            .progressViewStyle(.linear)
                            .tint(avgLoss > 10 ? .red : .accentColor)
                            .scaleEffect(x: 1, y: 0.5, anchor: .center)
                        
                        HStack(spacing: 4) {
                            ForEach(tools.multiPing.slots.prefix(12)) { slot in
                                Circle()
                                    .fill(slot.isRunning ? (slot.loss > 0 ? Color.orange : Color.green) : Color.secondary.opacity(0.2))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .help("Status dots for monitored hosts. Green is stable.")
                    }
                } else {
                    Text("Monitor multiple servers simultaneously to compare availability.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var portScanSummaryCard: some View {
        let isRunning = tools.portScan.isRunning
        return DashboardCard(title: "Port Scanner", icon: "checklist", color: isRunning ? .orange : .secondary, minHeight: toolCardMinHeight) {
            selection = .portScan
        } quickAction: {
            if isRunning { tools.portScan.stop() }
            else { selection = .portScan }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        let progress = Double(tools.portScan.scanned) / Double(max(tools.portScan.total, 1))
                        Text("Audit: \(Int(progress * 100))%")
                            .font(.subheadline.bold())
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                            .scaleEffect(x: 1, y: 0.5, anchor: .center)
                        Text("\(tools.portScan.openCount) Ports Found")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Text("\(tools.portScan.openCount) Open Ports")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Identify exposed services on your target infrastructure.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Connectivity Cards
    
    private var wifiSummaryCard: some View {
        DashboardCard(title: "Wi-Fi Analytics", icon: "wifi", color: .blue, minHeight: connectivityCardMinHeight) {
            selection = .wifi
        } quickAction: {
            tools.wifi.refresh()
        } content: {
            if let info = tools.wifi.info {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.ssid ?? "Broadcasting")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            BadgeLabel(text: info.band ?? "WLAN", color: .secondary)
                            BadgeLabel(text: "CH \(info.channel ?? 0)", color: .secondary)
                        }
                    }
                    Spacer()
                    
                    if let rssi = info.rssi {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(rssi)")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(rssi >= -60 ? .green : .orange)
                            Text("dBm").font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                        }
                        .help("Signal strength. Closer to 0 is stronger.")
                    }
                    
                    if !tools.wifi.rssiHistory.isEmpty {
                        DashboardSparkline(data: tools.wifi.rssiHistory.suffix(20).map { Double($0) }, color: .blue)
                            .frame(width: 60, height: 25)
                    }
                }
            } else {
                Text("Interface not connected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var interfaceSummaryCard: some View {
        let activeIfaces = tools.interfaces.interfaces.filter { $0.isUp && !$0.ipv4.isEmpty }
        return DashboardCard(title: "System Interfaces", icon: "network", color: .purple, minHeight: connectivityCardMinHeight) {
            selection = .interfaces
        } quickAction: {
            tools.interfaces.refresh()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                if activeIfaces.isEmpty {
                    Text("No active connections.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeIfaces.prefix(2)) { iface in
                        let ip = iface.ipv4.first ?? ""
                        let details = IPAddressDetails(address: ip)
                        
                        HStack(spacing: 10) {
                            Image(systemName: iface.typeIcon)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(iface.name).font(.system(size: 10, weight: .bold))
                                    Spacer()
                                    Text(ip).font(.system(size: 10, design: .monospaced))
                                }
                                HStack(spacing: 4) {
                                    BadgeLabel(text: details.ipClass, color: .blue)
                                    BadgeLabel(text: details.isPrivate ? "PRIVATE" : "PUBLIC", color: details.isPrivate ? .orange : .green)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Insight Cards
    
    private var bandwidthSummaryCard: some View {
        DashboardCard(title: "Bandwidth Monitor", icon: "chart.bar.xaxis", color: .pink) {
            selection = .bandwidth
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Traffic Flow")
                    .font(.subheadline.bold())
                Text("Monitor real-time upload/download rates.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dnsSummaryCard: some View {
        DashboardCard(title: "Security & DNS", icon: "lock.shield", color: .cyan) {
            selection = .ssl
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Security Audit")
                    .font(.subheadline.bold())
                Text("Inspect TLS chains and DNS records.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let description: String
    let content: Content
    
    init(title: String, icon: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.5)
                }
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            content
        }
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var minHeight: CGFloat? = nil
    let action: () -> Void
    var quickAction: (() -> Void)? = nil
    let content: Content
    
    @State private var isHovered = false
    
    init(title: String, icon: String, color: Color = .accentColor, minHeight: CGFloat? = nil, action: @escaping () -> Void, quickAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.minHeight = minHeight
        self.action = action
        self.quickAction = quickAction
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(color)
                        }
                        Text(title)
                            .font(.system(.subheadline, design: .rounded).bold())
                    }
                    Spacer()
                    if let quickAction {
                        Button(action: quickAction) {
                            Image(systemName: quickActionIcon)
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(color)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                content
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isHovered ? color.opacity(0.4) : Color(.separatorColor).opacity(0.15), lineWidth: isHovered ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var quickActionIcon: String {
        if title.contains("Ping") || title.contains("Scanner") { return "play.fill" }
        return "arrow.clockwise"
    }
}

struct MetricView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(color)
        }
    }
}

struct IdentityBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
                .kerning(1)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.system(.caption, design: .monospaced).bold())
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .black))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundColor(color)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }
}

struct SystemStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 10, weight: .black, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(color)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.4) : Color.clear, lineWidth: 4)
                    .scaleEffect(isActive && pulse ? 2.2 : 1.0)
                    .opacity(isActive && pulse ? 0 : 1)
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
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(path, with: .color(color), lineWidth: 2)
            
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            
            context.fill(fillPath, with: .linearGradient(
                Gradient(colors: [color.opacity(0.2), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}
