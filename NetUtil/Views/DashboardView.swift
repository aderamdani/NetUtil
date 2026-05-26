import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                
                VStack(spacing: 32) {
                    SectionView(title: "Active Control Center", icon: "bolt.fill", description: "Real-time monitoring and diagnostic controls.") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 20) {
                            pingSummaryCard
                            multiPingSummaryCard
                            portScanSummaryCard
                        }
                    }
                    
                    SectionView(title: "Local Infrastructure", icon: "wifi", description: "Current connectivity and interface status.") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            wifiSummaryCard
                            interfaceSummaryCard
                        }
                    }
                    
                    SectionView(title: "Additional Insights", icon: "chart.pie.fill", description: "Deep analysis and traffic monitoring.") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 20) {
                            bandwidthSummaryCard
                            dnsSummaryCard
                        }
                    }
                }
            }
            .padding(40)
        }
        .background {
            ZStack {
                Color(.windowBackgroundColor)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.05), Color.clear],
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
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Network Overview")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text(Host.current().localizedName ?? "macOS Workstation")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 12) {
                    SystemStatBadge(icon: "cpu", value: "CPU Normal", color: .green)
                    SystemStatBadge(icon: "memorychip", value: "RAM Healthy", color: .blue)
                }
                .padding(.top, 8)
            }
            
            // Network Identity Bar
            HStack(spacing: 16) {
                if let localIP = tools.interfaces.interfaces.first(where: { $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty })?.ipv4.first {
                    IdentityBadge(label: "LOCAL GATEWAY", value: localIP, icon: "house.fill", color: .blue)
                }
                
                IdentityBadge(label: "PUBLIC GATEWAY", value: tools.externalIP, icon: "globe", color: .accentColor)
                
                if let vpnIface = tools.interfaces.interfaces.first(where: { $0.name.starts(with: "utun") && $0.isUp && !$0.ipv4.isEmpty }) {
                    IdentityBadge(label: "VPN TUNNEL", value: vpnIface.ipv4.first ?? "Connected", icon: "lock.shield.fill", color: .green)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Tool Summaries
    
    private var pingSummaryCard: some View {
        let isRunning = tools.ping.isRunning
        return DashboardCard(title: "Advanced Ping", icon: "antenna.radiowaves.left.and.right", color: isRunning ? .green : .secondary) {
            selection = .ping
        } quickAction: {
            if isRunning { tools.ping.stop() }
            else if !tools.ping.currentHost.isEmpty { 
                tools.ping.start(host: tools.ping.currentHost, count: nil, interval: 1.0)
            } else { selection = .ping }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusIndicator(isActive: isRunning)
                    Text(isRunning ? "Monitoring \(tools.ping.currentHost)" : (tools.ping.currentHost.isEmpty ? "System Idle" : "Target: \(tools.ping.currentHost)"))
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if !tools.ping.results.isEmpty {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            let stats = tools.ping.stats
                            MetricView(label: "Avg Latency", value: String(format: "%.1fms", stats.avgRtt ?? 0), color: .primary)
                            MetricView(label: "Packet Loss", value: String(format: "%.0f%%", stats.loss), color: stats.loss > 0 ? .orange : .secondary)
                        }
                        Spacer()
                        DashboardSparkline(data: tools.ping.results.suffix(30).map { $0.rtt }, color: isRunning ? .green : .secondary)
                            .frame(width: 100, height: 35)
                    }
                } else {
                    Text("No active session. Start a probe to see real-time latency trends.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var multiPingSummaryCard: some View {
        let activeCount = tools.multiPing.slots.filter { $0.isRunning }.count
        let totalCount = tools.multiPing.slots.count
        return DashboardCard(title: "Multi-Ping", icon: "dot.radiowaves.left.and.right", color: activeCount > 0 ? .accentColor : .secondary) {
            selection = .multiPing
        } quickAction: {
            if activeCount > 0 { tools.multiPing.stopAll() }
            else { tools.multiPing.startAll() }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(activeCount) active / \(totalCount) monitored hosts")
                    .font(.headline)
                
                if totalCount > 0 {
                    let avgLoss = tools.multiPing.slots.map { $0.loss }.reduce(0, +) / Double(totalCount)
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(activeCount), total: Double(max(totalCount, 1)))
                            .progressViewStyle(.linear)
                            .tint(avgLoss > 10 ? .red : .accentColor)
                        
                        HStack {
                            Text("Aggregated Path Loss")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f%%", avgLoss))")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(avgLoss > 10 ? .red : .primary)
                        }
                        
                        HStack(spacing: 4) {
                            ForEach(tools.multiPing.slots.prefix(12)) { slot in
                                Circle()
                                    .fill(slot.isRunning ? (slot.loss > 0 ? Color.orange : Color.green) : Color.secondary.opacity(0.2))
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }
                } else {
                    Text("Quickly monitor availability for a list of servers or gateways.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var portScanSummaryCard: some View {
        let isRunning = tools.portScan.isRunning
        return DashboardCard(title: "Port Scanner", icon: "checklist", color: isRunning ? .orange : .secondary) {
            selection = .portScan
        } quickAction: {
            if isRunning { tools.portScan.stop() }
            else { selection = .portScan }
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        let progress = Double(tools.portScan.scanned) / Double(max(tools.portScan.total, 1))
                        HStack {
                            Text("Security Audit in Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(.caption, design: .monospaced).bold())
                        }
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                        Text("\(tools.portScan.openCount) Vulnerabilities / Open Ports Found")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Text("\(tools.portScan.openCount) Open Ports Detected")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Identify exposed services on your target infrastructure.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // MARK: - Connectivity
    
    private var wifiSummaryCard: some View {
        DashboardCard(title: "Wi-Fi Analytics", icon: "wifi", color: .blue) {
            selection = .wifi
        } quickAction: {
            tools.wifi.refresh()
        } content: {
            if let info = tools.wifi.info {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.ssid ?? "Broadcasting")
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Label(info.band ?? "WLAN", systemImage: "antenna.radiowaves.left.and.right")
                            Text("·")
                            Text("CH \(info.channel)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if !tools.wifi.rssiHistory.isEmpty {
                        DashboardSparkline(data: tools.wifi.rssiHistory.suffix(20).map { Double($0) }, color: .blue)
                            .frame(width: 80, height: 35)
                    }
                    
                    if let rssi = info.rssi {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(rssi)")
                                .font(.system(.title2, design: .monospaced).bold())
                                .foregroundColor(rssi >= -60 ? .green : .orange)
                            Text("RSSI (dBm)").font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Interface Disconnected")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var interfaceSummaryCard: some View {
        let activeIfaces = tools.interfaces.interfaces.filter { $0.isUp && !$0.ipv4.isEmpty }
        return DashboardCard(title: "System Interfaces", icon: "network", color: .purple) {
            selection = .interfaces
        } quickAction: {
            tools.interfaces.refresh()
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                if activeIfaces.isEmpty {
                    Text("No active stack detected.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeIfaces.prefix(2)) { iface in
                        let ip = iface.ipv4.first ?? ""
                        let details = IPAddressDetails(address: ip)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: iface.typeIcon)
                                    .foregroundColor(.accentColor)
                                Text(iface.name)
                                    .font(.caption.bold())
                                Spacer()
                                Text(ip)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            
                            HStack(spacing: 6) {
                                BadgeLabel(text: "Class \(details.ipClass)", color: .blue)
                                BadgeLabel(text: details.isPrivate ? "PRIVATE" : "PUBLIC", color: details.isPrivate ? .orange : .green)
                                if let mask = iface.netmasks.first {
                                    Text(mask)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 20)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Real-time Throughput")
                    .font(.headline)
                Text("Visualize live RX/TX traffic rates across all system adapters.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dnsSummaryCard: some View {
        DashboardCard(title: "Security & Resolution", icon: "lock.shield", color: .cyan) {
            selection = .ssl
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text("SSL & DNS Inspector")
                    .font(.headline)
                Text("Audit certificate chains and query global DNS records.")
                    .font(.caption)
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.primary)
                        .kerning(1.5)
                }
                Text(description)
                    .font(.caption)
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
    let action: () -> Void
    var quickAction: (() -> Void)? = nil
    let content: Content
    
    @State private var isHovered = false
    
    init(title: String, icon: String, color: Color = .accentColor, action: @escaping () -> Void, quickAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.quickAction = quickAction
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(color)
                            }
                            
                            Text(title)
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                        
                        Spacer()
                        
                        if let quickAction {
                            Button(action: quickAction) {
                                Image(systemName: quickActionIcon)
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(width: 26, height: 26)
                                    .background(color)
                                    .clipShape(Circle())
                                    .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .help("Quick Action")
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
                    
                    content
                }
                .padding(24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isHovered ? color.opacity(0.5) : Color(.separatorColor).opacity(0.2), lineWidth: isHovered ? 2 : 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var quickActionIcon: String {
        if title.contains("Ping") || title.contains("Scanner") {
            return "play.fill"
        }
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
                .font(.system(size: 9, weight: .black))
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
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)
                .kerning(1)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.system(.subheadline, design: .monospaced).bold())
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.15), lineWidth: 1)
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
            .font(.system(size: 9, weight: .black))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(color)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

struct SystemStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundColor(color)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.5))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.4) : Color.clear, lineWidth: 5)
                    .scaleEffect(isActive && pulse ? 2.2 : 1.0)
                    .opacity(isActive && pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
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
            
            context.stroke(path, with: .color(color), lineWidth: 2.5)
            
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
