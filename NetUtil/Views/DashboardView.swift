import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var tools: ToolStore
    @Binding var selection: Tool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Diagnostics", icon: "bolt.shield.fill")

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
                    sectionHeader("Connectivity", icon: "wifi.router.fill")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        wifiCard
                        interfacesCard
                        bandwidthCard
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Security & Lookup", icon: "lock.shield.fill")

                    HStack(spacing: 12) {
                        sslCard
                        dnsCard
                        whoisCard
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor).ignoresSafeArea())
        .onAppear {
            tools.wifi.start()
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
        }
    }
    
    // MARK: - Header Components
    
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Host.current().localizedName ?? "Local Mac")
                    .font(.system(.title, design: .default).bold())
                    .tracking(-0.2)
                
                HStack(spacing: 12) {
                    gatewayChip(label: "LOCAL IP", value: tools.interfaces.interfaces.first(where: { $0.isUp && !$0.isLoopback })?.ipv4.first ?? "127.0.0.1")
                    gatewayChip(label: "PUBLIC IP", value: tools.externalIP)
                    if tools.isVPNActive {
                        Label("VPN Active", systemImage: "lock.shield.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                healthGauge(label: "CPU", value: String(format: "%.0f%%", tools.system.cpuUsage), color: tools.system.cpuUsage > 70 ? .red : .primary)
                healthGauge(label: "RAM", value: tools.system.memoryPressure.capitalized, color: tools.system.memoryColor == "red" ? .red : .primary)
            }
        }
    }
    
    private func gatewayChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.medium)).foregroundColor(.secondary)
            Text(value).font(.system(.caption, design: .monospaced).weight(.semibold))
        }
        .padding(.trailing, 12)
    }

    private func healthGauge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.caption2.weight(.medium)).foregroundColor(.secondary)
            Text(value).font(.system(.title3, design: .monospaced).weight(.bold)).foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.headline)
            Text(title).font(.headline)
        }
    }

    // MARK: - Bento Cards (Diagnostics)

    private var pingCard: some View {
        BentoCard(title: "Ping", icon: "antenna.radiowaves.left.and.right", color: .blue, action: { selection = .ping }) {
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
                    if isRunning { Circle().fill(Color.green).frame(width: 6, height: 6).shadow(color: .green, radius: 3) }
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
                Text(tools.portScan.isRunning ? "Auditing..." : "\(tools.portScan.openCount) Open").font(.subheadline.bold())
                Spacer()
                if tools.portScan.isRunning { PulsingIndicator(color: .orange) }
            }
        }
    }

    // MARK: - Connectivity Cards

    private var wifiCard: some View {
        BentoCard(title: "Wi-Fi", icon: "wifi", color: .indigo, action: { selection = .wifi }) {
            if let info = tools.wifi.info {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.ssid ?? "Connected").font(.subheadline.bold()).lineLimit(1)
                    Text("\(info.rssi ?? 0) dBm").font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(info.rssi ?? -100 > -60 ? .green : .orange)
                }
            } else {
                Text("Disconnected").font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private var interfacesCard: some View {
        let active = tools.interfaces.interfaces.filter(\.isUp).count
        return BentoCard(title: "Interfaces", icon: "network", color: .purple, action: { selection = .interfaces }) {
            Text("\(active) Active").font(.subheadline.bold())
        }
    }

    private var bandwidthCard: some View {
        BentoCard(title: "Bandwidth", icon: "chart.bar.xaxis", color: .pink, action: { selection = .bandwidth }) {
            Text("Real-time Stats").font(.subheadline.bold()).foregroundColor(.secondary)
        }
    }

    private var sslCard: some View {
        BentoCard(title: "SSL/TLS", icon: "lock.shield", color: .teal, action: { selection = .ssl }) {
            Text("Certificate Audit").font(.subheadline.bold()).foregroundColor(.secondary)
        }
    }

    private var dnsCard: some View {
        BentoCard(title: "DNS", icon: "globe", color: .blue, action: { selection = .dns }) {
            Text("Resolver Audit").font(.subheadline.bold()).foregroundColor(.secondary)
        }
    }

    private var whoisCard: some View {
        BentoCard(title: "WHOIS", icon: "magnifyingglass.circle", color: .gray, action: { selection = .whois }) {
            Text("Domain Registry").font(.subheadline.bold()).foregroundColor(.secondary)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundColor(color)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isHovered ? color.opacity(0.25) : Color(.separatorColor).opacity(0.12), lineWidth: 1))
            .scaleEffect(isHovered ? 1.005 : 1.0)
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
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 4)
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
