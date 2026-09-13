import SwiftUI


/// Compact launcher grid for the essential tools. The dashboard hero and
/// Network Details answer "is my connection OK?"; this grid is for jumping
/// into a specific tool, with a light live-status hint where it helps.
struct EssentialToolsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?


    private struct ToolInfo: Identifiable {
        let tool: Tool
        let title: String
        let icon: String
        let summary: String
        var id: Tool { tool }
    }


    private let items: [ToolInfo] = [
        .init(tool: .ping, title: "Ping", icon: "antenna.radiowaves.left.and.right", summary: "Check latency and stability to any host"),
        .init(tool: .traceroute, title: "Traceroute", icon: "point.3.connected.trianglepath.dotted", summary: "See the path packets take to a destination"),
        .init(tool: .speedTest, title: "Speed Test", icon: "speedometer", summary: "Measure real download and upload speed"),
        .init(tool: .bandwidth, title: "Bandwidth", icon: "chart.bar.xaxis", summary: "Live download and upload throughput"),
        .init(tool: .dns, title: "DNS Lookup", icon: "globe", summary: "Look up a domain's DNS records"),
        .init(tool: .portScan, title: "Port Scanner", icon: "checklist", summary: "Find open ports on a device"),
        .init(tool: .wifi, title: "Wi-Fi", icon: "wifi", summary: "Signal strength, channel, and security"),
        .init(tool: .interfaces, title: "Interfaces", icon: "network", summary: "All network adapters and addresses")
    ]


    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            SectionHeader(title: "Network Tools", icon: "square.grid.2x2")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: Metrics.spacingMD)],
                spacing: Metrics.spacingMD
            ) {
                ForEach(items) { item in
                    launcher(item)
                }
            }
        }
    }


    private func launcher(_ item: ToolInfo) -> some View {
        Button {
            selection = item.tool
        } label: {
            HStack(spacing: Metrics.spacingMD) {
                ZStack {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(item.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Metrics.spacingSM)
                status(for: item.tool)
            }
            .padding(Metrics.spacingMD)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD)
                    .stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(item.summary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.summary).")
    }


    @ViewBuilder
    private func status(for tool: Tool) -> some View {
        switch tool {
        case .ping:
            if tools.ping.isRunning {
                PulsingIndicator(color: .green)
            } else if !tools.ping.results.isEmpty {
                statusText(String(format: "%.0f ms", tools.ping.stats.avgRtt))
            }
        case .traceroute:
            if tools.traceroute.isRunning {
                PulsingIndicator(color: .accentColor)
            } else if !tools.traceroute.hops.isEmpty {
                statusText("\(tools.traceroute.hops.count) hops")
            }
        case .speedTest:
            if tools.speedTest.isRunning {
                PulsingIndicator(color: .green)
            } else if let r = tools.speedTest.lastResult {
                statusText(String(format: "↓ %.0f", r.downloadMbps))
            }
        case .bandwidth:
            statusText("↓ \(NetworkMath.shortRate(tools.bandwidth.totalRxBps))")
        case .dns:
            if !tools.dns.lastQuery.isEmpty, let r = tools.dns.result {
                statusText("\(r.records.count) recs")
            }
        case .portScan:
            if tools.portScan.isRunning {
                PulsingIndicator(color: .orange)
            } else if tools.portScan.openCount > 0 {
                statusText("\(tools.portScan.openCount) open")
            }
        case .wifi:
            if let rssi = tools.wifi.info?.rssi {
                SignalQualityBadge(rssi: rssi)
            }
        case .interfaces:
            let active = tools.interfaces.interfaces.filter(\.isUp).count
            let total = tools.interfaces.interfaces.count
            if total > 0 {
                statusText("\(active)/\(total) up")
            }
        default:
            EmptyView()
        }
    }


    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced().weight(.medium))
            .foregroundColor(.secondary)
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
