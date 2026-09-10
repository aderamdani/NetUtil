import SwiftUI

struct DiagnosticsCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Core Diagnostics", icon: "bolt.shield.fill")

            GlassEffectContainer {
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
        }
    }

    private var pingCard: some View {
        BentoCard(
            title: "Advanced Ping",
            icon: "antenna.radiowaves.left.and.right",
            color: .blue,
            action: { selection = .ping },
            helpText: "Measure connection latency and stability to any host. Shows response time, jitter, and packet loss."
        ) {
            let isRunning = tools.ping.isRunning
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tools.ping.currentHost.isEmpty ? "Idle — Enter a host to begin" : tools.ping.currentHost)
                            .font(.headline).lineLimit(1)
                        if isRunning {
                            Label("Monitoring latency & jitter", systemImage: "waveform.path.ecg")
                                .font(.caption)
                                .foregroundColor(.green)
                                .bold()
                        } else if !tools.ping.currentHost.isEmpty {
                            Label("Ready — Click to start", systemImage: "play.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Label("Enter a hostname or IP address", systemImage: "text.cursor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isRunning { PulsingIndicator(color: .green) }
                }

                if !tools.ping.results.isEmpty {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%.1f", tools.ping.stats.avgRtt))
                                .font(.system(size: Metrics.heroNumber, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                            Text("ms average").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                        }
                        Spacer()
                        DashboardSparkline(
                            data: tools.ping.results.suffix(Metrics.sparklineWindow).map { $0.rtt },
                            color: isRunning ? .green : .blue
                        )
                        .frame(width: 140, height: 32)
                        .help("Response time over last \(Metrics.sparklineWindow) pings")
                    }
                    // Quick stats row
                    HStack(spacing: 20) {
                        Label("\(tools.ping.stats.loss, specifier: "%.1f")% loss", systemImage: "exclamationmark.triangle")
                            .font(.caption2.monospaced())
                            .foregroundColor(tools.ping.stats.loss > 0 ? .orange : .green)
                        Label("Jitter ±\(tools.ping.stats.jitter, specifier: "%.1f")ms", systemImage: "waveform.path")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                        Label("\(tools.ping.results.count) samples", systemImage: "number")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What this does:")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            HelpRow(icon: "speedometer", text: "Measures round-trip time to any server")
                            HelpRow(icon: "waveform.path.ecg", text: "Detects connection jitter (variance)")
                            HelpRow(icon: "exclamationmark.triangle", text: "Reports packet loss percentage")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var multiPingCard: some View {
        BentoCard(
            title: "Multi-Ping",
            icon: "dot.radiowaves.left.and.right",
            color: .accentColor,
            action: { selection = .multiPing },
            helpText: "Ping multiple hosts at once. Compare latency across different servers or network paths."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(tools.multiPing.slots.count) targets configured")
                        .font(.subheadline.bold())
                    if tools.multiPing.slots.isEmpty {
                        Text("Add hosts to compare latency side-by-side")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tools.multiPing.slots.contains(where: { $0.isRunning }) {
                    PulsingIndicator(color: .accentColor)
                }
            }
        }
    }

    private var portScanCard: some View {
        BentoCard(
            title: "Port Scanner",
            icon: "checklist",
            color: .orange,
            action: { selection = .portScan },
            helpText: "Find open ports on any device. Useful for checking firewall rules, exposed services, and security auditing."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if tools.portScan.isRunning {
                        Text("Scanning ports…")
                            .font(.subheadline.bold())
                    } else if tools.portScan.openCount > 0 {
                        Text("\(tools.portScan.openCount) open ports found")
                            .font(.subheadline.bold())
                    } else {
                        Text("Port Scanner")
                            .font(.subheadline.bold())
                    }
                    if !tools.portScan.isRunning && tools.portScan.openCount == 0 && !tools.portScan.currentHost.isEmpty {
                        Text("Last scan: \(tools.portScan.currentHost) — no open ports")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if tools.portScan.isRunning {
                        Text("Checking common service ports…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tools.portScan.isRunning { PulsingIndicator(color: .orange) }
            }
        }
    }
}

struct HelpRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 12)
            Text(text)
        }
    }
}