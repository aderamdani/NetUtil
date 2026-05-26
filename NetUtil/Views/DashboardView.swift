import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                
                SectionView(title: "Active Tools Control", icon: "bolt.fill") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                        pingSummaryCard
                        multiPingSummaryCard
                        portScanSummaryCard
                    }
                }
                
                SectionView(title: "Connectivity Environment", icon: "wifi") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        wifiSummaryCard
                        interfaceSummaryCard
                    }
                }
                
                SectionView(title: "Quick Insights", icon: "chart.pie.fill") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 20) {
                        bandwidthSummaryCard
                        dnsSummaryCard
                    }
                }
            }
            .padding(32)
        }
        .background {
            ZStack {
                Color(.windowBackgroundColor)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.clear],
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Overview")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(Host.current().localizedName ?? "macOS System")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Comprehensive Network Identity
            HStack(spacing: 12) {
                // Local IP
                if let localIP = tools.interfaces.interfaces.first(where: { $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty })?.ipv4.first {
                    IdentityBadge(label: "LOCAL IP", value: localIP, icon: "house.fill", color: .blue)
                }
                
                // Public IP
                IdentityBadge(label: "PUBLIC IP", value: tools.externalIP, icon: "globe", color: .accentColor)
                
                // VPN IP
                if let vpnIface = tools.interfaces.interfaces.first(where: { $0.name.starts(with: "utun") && $0.isUp && !$0.ipv4.isEmpty }) {
                    IdentityBadge(label: "VPN IP", value: vpnIface.ipv4.first ?? "Active", icon: "lock.shield.fill", color: .green)
                }
                
                Spacer()
                
                // System Stats Badge
                HStack(spacing: 8) {
                    SystemStatBadge(icon: "cpu", value: "Low", color: .green)
                    SystemStatBadge(icon: "memorychip", value: "Healthy", color: .blue)
                }
            }
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
            } else {
                selection = .ping
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusIndicator(isActive: isRunning)
                    Text(isRunning ? "Monitoring \(tools.ping.currentHost)" : (tools.ping.currentHost.isEmpty ? "Idle" : "Ready: \(tools.ping.currentHost)"))
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if !tools.ping.results.isEmpty {
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            let stats = tools.ping.stats
                            MiniStat(label: "Avg RTT", value: String(format: "%.1fms", stats.avgRtt ?? 0))
                            MiniStat(label: "Loss", value: String(format: "%.0f%%", stats.loss))
                        }
                        
                        Spacer()
                        
                        // Mini Sparkline
                        DashboardSparkline(data: tools.ping.results.suffix(30).map { $0.rtt }, color: .green)
                            .frame(width: 80, height: 30)
                    }
                } else {
                    Text("No recent session data available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("\(activeCount) active / \(totalCount) targets")
                    .font(.headline)
                
                if totalCount > 0 {
                    let avgLoss = tools.multiPing.slots.map { $0.loss }.reduce(0, +) / Double(totalCount)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            ProgressView(value: Double(activeCount), total: Double(max(totalCount, 1)))
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                            Text("\(String(format: "%.0f%%", avgLoss)) Loss")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(avgLoss > 10 ? .red : .secondary)
                        }
                        
                        HStack(spacing: 4) {
                            ForEach(tools.multiPing.slots.prefix(8)) { slot in
                                Circle()
                                    .fill(slot.isRunning ? (slot.loss > 0 ? Color.orange : Color.green) : Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                } else {
                    Text("Add targets to monitor multiple hosts.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            VStack(alignment: .leading, spacing: 10) {
                if isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        let progress = Double(tools.portScan.scanned) / Double(max(tools.portScan.total, 1))
                        HStack {
                            Text("Scanning...").font(.headline)
                            Spacer()
                            Text("\(Int(progress * 100))%").font(.caption.monospacedDigit())
                        }
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                        Text("\(tools.portScan.openCount) Open Ports Found")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Text("\(tools.portScan.openCount) Open Ports")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Ready for security auditing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Connectivity Summaries
    
    private var wifiSummaryCard: some View {
        DashboardCard(title: "Wi-Fi Status", icon: "wifi", color: .blue) {
            selection = .wifi
        } quickAction: {
            tools.wifi.refresh()
        } content: {
            if let info = tools.wifi.info {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.ssid ?? "Connected")
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(info.band ?? "WLAN") · \(info.channel) · \(info.security ?? "Secure")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if !tools.wifi.rssiHistory.isEmpty {
                        DashboardSparkline(data: tools.wifi.rssiHistory.suffix(20).map { Double($0) }, color: .blue)
                            .frame(width: 60, height: 25)
                    }
                    
                    if let rssi = info.rssi {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(rssi)")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(rssi >= -60 ? .green : .orange)
                            Text("dBm").font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Not Connected")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var interfaceSummaryCard: some View {
        let activeIfaces = tools.interfaces.interfaces.filter { $0.isUp && !$0.ipv4.isEmpty }
        return DashboardCard(title: "Network Interfaces", icon: "network", color: .purple) {
            selection = .interfaces
        } quickAction: {
            tools.interfaces.refresh()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                if activeIfaces.isEmpty {
                    Text("No active IP connections.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeIfaces.prefix(2)) { iface in
                        let ip = iface.ipv4.first ?? ""
                        let details = IPAddressDetails(address: ip)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: iface.typeIcon)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Text(iface.name)
                                    .font(.caption.bold())
                                Spacer()
                                Text(ip)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(spacing: 6) {
                                BadgeLabel(text: "Class \(details.ipClass)", color: .blue)
                                BadgeLabel(text: details.isPrivate ? "Private" : "Public", color: details.isPrivate ? .orange : .green)
                                if let mask = iface.netmasks.first {
                                    Text("Mask: \(mask)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 18)
                        }
                    }
                    
                    if activeIfaces.count > 2 {
                        Text("+ \(activeIfaces.count - 2) additional interfaces")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 18)
                    }
                }
            }
        }
    }
    
    private var bandwidthSummaryCard: some View {
        DashboardCard(title: "Bandwidth Monitor", icon: "chart.bar.xaxis", color: .pink) {
            selection = .bandwidth
        } quickAction: {
            selection = .bandwidth
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Traffic Throughput")
                    .font(.headline)
                Text("Monitor live upload and download rates per interface.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dnsSummaryCard: some View {
        DashboardCard(title: "Security & DNS", icon: "lock.shield", color: .cyan) {
            selection = .ssl
        } quickAction: {
            selection = .dns
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Certificates & DNS")
                    .font(.headline)
                Text("Query DNS records and analyze TLS certificate chains.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct IdentityBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.system(.subheadline, design: .monospaced).bold())
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundColor(color)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.secondary)
                    .kerning(1.2)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(color)
                        }
                        
                        Text(title)
                            .font(.system(.subheadline, design: .rounded).bold())
                        
                        Spacer()
                        
                        if let quickAction {
                            Button(action: quickAction) {
                                Image(systemName: quickActionIcon)
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(color)
                                    .clipShape(Circle())
                                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .help("Quick Action")
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                    
                    content
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isHovered ? color.opacity(0.4) : Color(.separatorColor).opacity(0.2), lineWidth: isHovered ? 2 : 1)
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var quickActionIcon: String {
        if title == "Advanced Ping" || title == "Multi-Ping" || title == "Port Scanner" {
            // Assume if it can run, we show play/stop
            return "play.fill"
        }
        return "arrow.clockwise"
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
            
            // Fill area
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            
            context.fill(fillPath, with: .linearGradient(
                Gradient(colors: [color.opacity(0.3), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}

struct SystemStatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundColor(color)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MiniStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .lineLimit(1)
        }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.5))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 4)
                    .scaleEffect(isActive && pulse ? 2.0 : 1.0)
                    .opacity(isActive && pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }
}
