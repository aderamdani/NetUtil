import SwiftUI

struct SystemSecurityCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("System & Security", icon: "lock.shield.fill")

            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    doctorCard
                    netQualityCard
                    portListenerCard
                }
            }
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    connectionsCard
                    neighborsCard
                    historyCard
                }
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

    private var doctorCard: some View {
        let passed = tools.doctor.checks.filter { if case .passed = $0.state { return true } else { return false } }.count
        let failed = tools.doctor.checks.filter { if case .failed = $0.state { return true } else { return false } }.count
        let total = tools.doctor.checks.count
        let color: Color = failed > 0 ? .red : (tools.doctor.isRunning ? .blue : .green)
        return BentoCard(title: "Doctor", icon: "stethoscope", color: color, action: { selection = .doctor }) {
            VStack(alignment: .leading, spacing: 4) {
                if tools.doctor.isRunning {
                    Text("Running Checks...").font(.subheadline.bold())
                } else if total == 0 {
                    Text("Connectivity Check").font(.subheadline.bold())
                } else {
                    Text("\(passed)/\(total) Passed").font(.subheadline.bold())
                    if failed > 0 {
                        Text("\(failed) Failed")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.red)
                    } else {
                        Text("All Layers Healthy")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                if tools.doctor.isRunning { PulsingIndicator(color: .blue) }
            }
        }
    }

    private var netQualityCard: some View {
        BentoCard(title: "Net Quality", icon: "gauge.with.dots.needle.67percent", color: .blue, action: { selection = .netQuality }) {
            if let result = tools.netQuality.result {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "↓ %.0f", result.downloadMbps))
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            Text("Mbps").font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        let grade = result.rpmGrade
                        Text("\(result.responsivenessRPM) RPM")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundColor(grade.color == "green" ? .green : (grade.color == "orange" ? .orange : .red))
                    }
                    Text("↑ \(String(format: "%.0f", result.uploadMbps)) Mbps")
                        .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                }
            } else if tools.netQuality.isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measuring...").font(.subheadline.bold())
                    PulsingIndicator(color: .blue)
                }
            } else {
                Text("Link Quality Probe").font(.subheadline.bold())
            }
        }
    }

    private var portListenerCard: some View {
        BentoCard(title: "Port Listener", icon: "ear", color: .purple, action: { selection = .portListener }) {
            VStack(alignment: .leading, spacing: 4) {
                if tools.portListener.isRunning {
                    Text("Listening :\(tools.portListener.port)")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    Text("\(tools.portListener.events.count) Events")
                        .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                    PulsingIndicator(color: .purple)
                } else {
                    Text("Not Active").font(.subheadline.bold())
                    Text("Starts a local listener")
                        .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var connectionsCard: some View {
        let established = tools.connections.connections.filter { $0.state == "ESTABLISHED" }.count
        return BentoStatusCard(
            title: "Connections",
            icon: "app.connected.to.app.below.fill",
            color: .teal,
            status: "\(established) Established",
            action: { selection = .connections }
        )
    }

    private var neighborsCard: some View {
        BentoStatusCard(
            title: "Neighbors",
            icon: "person.2.wave.2",
            color: .green,
            status: "\(tools.neighbors.visibleEntries.count) on LAN",
            action: { selection = .neighbors }
        )
    }

    private var historyCard: some View {
        BentoCard(title: "History", icon: "clock.arrow.circlepath", color: .gray, action: { selection = .sessionHistory }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tools.sessionHistory.records.count) Sessions")
                    .font(.subheadline.bold())
                Text("Past 90 Days")
                    .font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
            }
        }
    }
}
