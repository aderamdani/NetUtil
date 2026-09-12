import SwiftUI

struct DashboardView: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    @State private var launchDate = Date()
    @State private var uptimeString = "0m"
    @State private var localHostName = Host.current().localizedName ?? "Local Mac"
    @State private var uptimeTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            healthSummaryBar

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                    DashboardHeroSection(selection: $selection)
                    EssentialToolsSection(selection: $selection)
                }
                .padding(Metrics.spacingXL)
            }
        }
        .background(Color(.windowBackgroundColor).ignoresSafeArea())
        .onAppear {
            uptimeString = formatUptime(from: launchDate)
            // Run the uptime ticker once. Using onAppear (not .task) avoids
            // SwiftUI re-running the loop every time `body` recomputes due to
            // frequently-changing observed state (e.g. live bandwidth rates).
            uptimeTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    uptimeString = formatUptime(from: launchDate)
                }
            }
            tools.wifi.start()
            tools.interfaces.refresh()
            tools.refreshGlobalStatus()
        }
        .onDisappear {
            uptimeTask?.cancel()
            tools.wifi.stop()
        }
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localHostName)
                        .font(.title3.bold())
                        .tracking(-0.2)

                    HStack(spacing: Metrics.spacingMD) {
                        HStack(spacing: Metrics.spacingXS) {
                            Image(systemName: tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 ? .green : .secondary)
                                .font(.caption2)
                            Text(tools.currentConnectionName)
                                .font(.caption.weight(.semibold))
                        }

                        Divider().frame(height: 10)

                        gatewayChip(label: "Local", value: tools.primaryLocalIP)
                        gatewayChip(label: "Public", value: tools.externalIP)

                        if tools.isVPNActive {
                            Text("VPN")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Uptime")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                    Text(uptimeString)
                        .font(.caption.monospaced().weight(.medium))
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Uptime")
                .accessibilityValue(uptimeString)
            }
            .padding(.horizontal, Metrics.spacingXL)
            .padding(.vertical, Metrics.spacingLG)

            Divider()
        }
        .background(.regularMaterial)
    }

    private var healthSummaryBar: some View {
        MoodBar(icon: tools.healthIcon,
                color: tools.healthColor == "red" ? .red : (tools.healthColor == "orange" ? .orange : .green),
                message: tools.healthMessage,
                messageColor: tools.healthColor == "green" ? .secondary : (tools.healthColor == "red" ? .red : .orange))
    }

    private func formatUptime(from date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let hours   = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(max(minutes, 0))m"
    }

    private func gatewayChip(label: String, value: String) -> some View {
        HStack(spacing: Metrics.spacingXS) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(value).font(.caption2.monospaced().weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) IP address")
        .accessibilityValue(value)
    }
}
