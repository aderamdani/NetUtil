import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                
                SectionView(title: "Active Tools Status", icon: "bolt.fill") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 20) {
                        pingSummaryCard
                        multiPingSummaryCard
                        portScanSummaryCard
                    }
                }
                
                SectionView(title: "Connectivity & Environment", icon: "wifi") {
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
        .background(Color(.windowBackgroundColor))
        .onAppear {
            tools.wifi.start()
            tools.interfaces.refresh()
        }
    }
    
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Overview")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Real-time diagnostic summary of your network environment.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            // System Stats Badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 12) {
                    SystemStatBadge(icon: "cpu", value: "Low Load", color: .green)
                    SystemStatBadge(icon: "memorychip", value: "Healthy", color: .blue)
                }
                Text("macOS 15+ Sequoia Native")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }
    
    // MARK: - Tool Summaries
    
    private var pingSummaryCard: some View {
        let isRunning = tools.ping.isRunning
        return DashboardCard(title: "Advanced Ping", icon: "antenna.radiowaves.left.and.right", color: isRunning ? .green : .secondary) {
            selection = .ping
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusIndicator(isActive: isRunning)
                    Text(isRunning ? "Monitoring \(tools.ping.currentHost)" : "Idle")
                        .font(.headline)
                        .lineLimit(1)
                }
                
                if isRunning {
                    let stats = tools.ping.stats
                    HStack(spacing: 16) {
                        MiniStat(label: "Avg RTT", value: String(format: "%.1fms", stats.avgRtt ?? 0))
                        MiniStat(label: "Packet Loss", value: String(format: "%.0f%%", stats.loss))
                        MiniStat(label: "Jitter", value: String(format: "%.1fms", stats.jitter))
                    }
                } else {
                    Text("Start a ping session for live metrics.")
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
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(activeCount) active / \(totalCount) targets")
                    .font(.headline)
                
                if totalCount > 0 {
                    let avgLoss = tools.multiPing.slots.map { $0.loss }.reduce(0, +) / Double(totalCount)
                    HStack {
                        ProgressView(value: Double(activeCount), total: Double(max(totalCount, 1)))
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                            .frame(width: 60)
                        
                        Text("Loss: \(String(format: "%.1f%%", avgLoss))")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(avgLoss > 10 ? .red : .secondary)
                    }
                } else {
                    Text("Quickly monitor multiple hosts.")
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
                    Text("From last session")
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
        } content: {
            if let info = tools.wifi.info {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.ssid ?? "Connected")
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(info.band ?? "WLAN")
                            Text("·")
                            Text(info.security ?? "Secure")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let rssi = info.rssi {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(rssi)")
                                .font(.system(.title2, design: .monospaced).bold())
                                .foregroundColor(rssi >= -60 ? .green : .orange)
                            Text("dBm").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
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
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                if activeIfaces.isEmpty {
                    Text("No active IP connections.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activeIfaces.prefix(2)) { iface in
                        HStack(spacing: 8) {
                            Image(systemName: iface.typeIcon)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Text(iface.name)
                                .font(.caption.bold())
                            Spacer()
                            Text(iface.ipv4.first ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    if activeIfaces.count > 2 {
                        Text("+ \(activeIfaces.count - 2) additional interfaces")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }
    
    private var bandwidthSummaryCard: some View {
        DashboardCard(title: "Bandwidth Monitor", icon: "chart.bar.xaxis", color: .pink) {
            selection = .bandwidth
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live RX/TX Throughput")
                    .font(.headline)
                Text("View real-time traffic charts for all interfaces.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dnsSummaryCard: some View {
        DashboardCard(title: "Security & DNS", icon: "lock.shield", color: .cyan) {
            selection = .ssl
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Certificates & Records")
                    .font(.headline)
                Text("Inspector for SSL/TLS and DNS resolution.")
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
    let content: Content
    
    @State private var isHovered = false
    
    init(title: String, icon: String, color: Color = .accentColor, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).bold())
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                content
                
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovered ? color.opacity(0.5) : Color(.separatorColor).opacity(0.3), lineWidth: isHovered ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(color.opacity(0.1))
        .cornerRadius(6)
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
                    .scaleEffect(isActive && pulse ? 1.8 : 1.0)
                    .opacity(isActive && pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }
}
