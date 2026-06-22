import SwiftUI

struct DiagnosticsCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
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
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

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
                            Text(String(format: "%.1f", tools.ping.stats.avgRtt)).font(.system(size: Metrics.heroNumber, weight: .bold, design: .monospaced))
                            Text("ms avg").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                        DashboardSparkline(data: tools.ping.results.suffix(Metrics.sparklineWindow).map { $0.rtt }, color: isRunning ? .green : .blue)
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
}
