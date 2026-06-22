import SwiftUI

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
                    DiagnosticsCardsSection(selection: $selection)
                    TrafficCardsSection(selection: $selection)
                    LookupCardsSection(selection: $selection)
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
                                .font(.caption2)
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
                                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundColor(.green)
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
        .glassEffect(in: .rect(cornerRadius: 10))
    }
}
