import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    // Grid and Sizing Constants for Symmetry and Breathing Room
    private let toolCardMinHeight: CGFloat = 160
    private let connectivityCardMinHeight: CGFloat = 140
    private let sectionSpacing: CGFloat = 52
    private let gridSpacing: CGFloat = 24
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerSection
                
                VStack(spacing: sectionSpacing) {
                    // SECTION 1: ACTIVE DIAGNOSTICS
                    SectionView(title: "Diagnostic Control Center", icon: "bolt.shield.fill", description: "Real-time monitoring and active diagnostic management.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: gridSpacing) {
                            pingSummaryCard
                            multiPingSummaryCard
                            portScanSummaryCard
                        }
                    }
                    
                    // SECTION 2: NETWORK INFRASTRUCTURE
                    SectionView(title: "Connectivity Infrastructure", icon: "wifi.router.fill", description: "Current status of local interfaces and wireless analytics.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: gridSpacing) {
                            wifiSummaryCard
                            interfaceSummaryCard
                        }
                    }
                    
                    // SECTION 3: SECURITY & ANALYTICS
                    SectionView(title: "Security & Traffic Insights", icon: "shield.checkerboard", description: "Deep analysis of encryption protocols and data throughput.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: gridSpacing) {
                            bandwidthSummaryCard
                            dnsSummaryCard
                        }
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
        }
        .background {
            ZStack {
                Color(.windowBackgroundColor)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.02), Color.clear],
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
        VStack(alignment: .leading, spacing: 32) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mission Control")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                    Text(Host.current().localizedName ?? "macOS Workstation")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 12) {
                    let cpuUsage = tools.system.cpuUsage
                    let cpuColor: Color = cpuUsage > 70 ? .red : (cpuUsage > 40 ? .orange : .green)
                    SystemStatBadge(icon: "cpu", label: "CPU", value: String(format: "%.0f%%", cpuUsage), color: cpuColor)
                        .help("System-wide processor load.")
                    
                    let memColor: Color = tools.system.memoryColor == "red" ? .red : (tools.system.memoryColor == "orange" ? .orange : .blue)
                    SystemStatBadge(icon: "memorychip", label: "RAM", value: tools.system.memoryPressure.uppercased(), color: memColor)
                        .help("System memory pressure status.")
                }
            }
            
            // Identity Bar
            HStack(spacing: 16) {
                if let localIP = tools.interfaces.interfaces.first(where: { $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty })?.ipv4.first {
                    IdentityBadge(label: "LOCAL GATEWAY", value: localIP, icon: "house.fill", color: .blue)
                }
                
                IdentityBadge(label: "PUBLIC GATEWAY", value: tools.externalIP, icon: "globe", color: .accentColor)
                
                if let vpnIface = tools.interfaces.interfaces.first(where: { $0.name.starts(with: "utun") && $0.isUp && !$0.ipv4.isEmpty }) {
                    IdentityBadge(label: "VPN TUNNEL", value: vpnIface.ipv4.first ?? "Active", icon: "lock.shield.fill", color: .green)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    StatusIndicator(isActive: isRunning)
                    Text(isRunning ? "Monitoring Latency" : "System Idle")
                        .font(.subheadline.bold())
                }
                
                if !tools.ping.results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        let stats = tools.ping.stats
                        HStack(alignment: .bottom) {
                            MetricView(label: "Average", value: String(format: "%.1f ms", stats.avgRtt), color: .primary)
                            Spacer()
                            DashboardSparkline(data: tools.ping.results.suffix(25).map { $0.rtt }, color: isRunning ? .green : .secondary)
                                .frame(width: 80, height: 28)
                        }
                        MetricView(label: "Packet Loss", value: String(format: "%.0f%%", stats.loss), color: stats.loss > 0 ? .red : .secondary)
                    }
                } else {
                    Text("Ready to measure connection stability.")
                        .font(.system(size: 12))
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
            VStack(alignment: .leading, spacing: 16) {
                Text("\(activeCount) Active / \(totalCount) Targets")
                    .font(.subheadline.bold())
                
                if totalCount > 0 {
                    let avgLoss = tools.multiPing.slots.map { $0.loss }.reduce(0, +) / Double(totalCount)
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: Double(activeCount), total: Double(max(totalCount, 1)))
                            .progressViewStyle(.linear)
                            .tint(avgLoss > 10 ? .red : .accentColor)
                            .scaleEffect(y: 0.8)
                        
                        HStack(spacing: 6) {
                            ForEach(tools.multiPing.slots.prefix(12)) { slot in
                                Circle()
                                    .fill(slot.isRunning ? (slot.loss > 0 ? Color.orange : Color.green) : Color.secondary.opacity(0.15))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                } else {
                    Text("Bulk monitor server reachability.")
                        .font(.system(size: 12))
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
            VStack(alignment: .leading, spacing: 16) {
                if isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        let progress = Double(tools.portScan.scanned) / Double(max(tools.portScan.total, 1))
                        Text("Audit In Progress (\(Int(progress * 100))%)")
                            .font(.subheadline.bold())
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                        Text("\(tools.portScan.openCount) Open Ports Found")
                            .font(.system(size: 12, weight: .bold))
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
                    Text("Detect exposed network services.")
                        .font(.system(size: 12))
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
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(info.ssid ?? "Connected")
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
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(rssi >= -60 ? .green : .orange)
                            Text("dBm").font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                        }
                    }
                    
                    if !tools.wifi.rssiHistory.isEmpty {
                        DashboardSparkline(data: tools.wifi.rssiHistory.suffix(20).map { Double($0) }, color: .blue)
                            .frame(width: 70, height: 30)
                    }
                }
            } else {
                Text("No Wi-Fi association detected.")
                    .font(.system(size: 12))
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
            VStack(alignment: .leading, spacing: 10) {
                if activeIfaces.isEmpty {
                    Text("No active IP connections.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeIfaces.prefix(2)) { iface in
                        let ip = iface.ipv4.first ?? ""
                        let details = IPAddressDetails(address: ip)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: iface.typeIcon)
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                Text(iface.name).font(.system(size: 11, weight: .bold))
                                Spacer()
                                Text(ip).font(.system(size: 11))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 6) {
                                BadgeLabel(text: "CLASS \(details.ipClass)", color: .blue)
                                BadgeLabel(text: details.isPrivate ? "PRIVATE" : "PUBLIC", color: details.isPrivate ? .orange : .green)
                            }
                            .padding(.leading, 18)
                        }
                    }
                }
            }
        }
    }
    
    private var bandwidthSummaryCard: some View {
        DashboardCard(title: "Bandwidth Monitor", icon: "chart.bar.xaxis", color: .pink) {
            selection = .bandwidth
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Traffic Throughput")
                    .font(.subheadline.bold())
                Text("Live RX/TX rates per adapter.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dnsSummaryCard: some View {
        DashboardCard(title: "Security & DNS", icon: "lock.shield", color: .cyan) {
            selection = .ssl
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("SSL & Resolver Audit")
                    .font(.subheadline.bold())
                Text("Audit TLS and query records.")
                    .font(.system(size: 12))
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .kerning(1.2)
                }
                Text(description)
                    .font(.subheadline)
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
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(color)
                        }
                        Text(title)
                            .font(.system(.subheadline).bold())
                    }
                    Spacer()
                    if let quickAction {
                        Button(action: quickAction) {
                            Image(systemName: quickActionIcon)
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(color)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                content
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isHovered ? color.opacity(0.4) : Color(.separatorColor).opacity(0.2), lineWidth: isHovered ? 2 : 1)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline).bold())
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
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)
                .kerning(1)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.system(.subheadline).bold())
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(color)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

struct SystemStatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(color)
            .background(color.opacity(0.08))
            .cornerRadius(8)
        }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
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
                Gradient(colors: [color.opacity(0.15), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}
