import SwiftUI

struct SystemSecurityCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            SectionHeader(title: "System & Security", icon: "lock.shield.fill")

            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Metrics.spacingMD) {
                    doctorCard
                    netQualityCard
                    portListenerCard
                }
            }
            GlassEffectContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Metrics.spacingMD) {
                    connectionsCard
                    neighborsCard
                    historyCard
                }
            }
        }
    }

    private var doctorCard: some View {
        let passed = tools.doctor.checks.filter { if case .passed = $0.state { return true } else { return false } }.count
        let failed = tools.doctor.checks.filter { if case .failed = $0.state { return true } else { return false } }.count
        let total = tools.doctor.checks.count
        let color: Color = failed > 0 ? .red : (tools.doctor.isRunning ? .blue : .green)
        let statusText: String = {
            if tools.doctor.isRunning { return "Running connectivity checks…" }
            if total == 0 { return "Run a full connectivity check" }
            return failed > 0 ? "\(failed) of \(total) checks failed" : "All \(total) checks passed"
        }()
        let statusColor: Color = failed > 0 ? .red : .green

        return BentoCard(
            title: "Connectivity Doctor",
            icon: "stethoscope",
            color: color,
            action: { selection = .doctor },
            helpText: "Run automated checks: gateway reachability, DNS resolution, internet connectivity, and captive portal detection."
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                HStack {
                    Text(statusText)
                        .font(.subheadline.bold())
                        .foregroundColor(statusColor)
                    Spacer()
                    if tools.doctor.isRunning { PulsingIndicator(color: .blue) }
                }
                if !tools.doctor.isRunning && total > 0 {
                    HStack(spacing: Metrics.spacingLG) {
                        Label("\(passed) passed", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        if failed > 0 {
                            Label("\(failed) failed", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                } else if tools.doctor.isRunning {
                    Text("Checking gateway, DNS, internet, and captive portal…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Verifies: Gateway → DNS → Internet → Captive Portal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var netQualityCard: some View {
        BentoCard(
            title: "Network Quality",
            icon: "gauge.with.dots.needle.67percent",
            color: .blue,
            action: { selection = .netQuality },
            helpText: "Apple's networkQuality tool. Measures download/upload throughput, latency, and responsiveness (RPM)."
        ) {
            if let result = tools.netQuality.result {
                let grade = result.rpmGrade
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    HStack(alignment: .bottom, spacing: Metrics.spacingSM) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "↓ %.0f", result.downloadMbps))
                                .font(.subheadline.monospaced().weight(.bold))
                                .contentTransition(.numericText())
                            Text("Mbps").font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: Metrics.spacingXS) {
                            Text("\(result.responsivenessRPM) RPM")
                                .font(.caption.monospaced().weight(.bold))
                            Image(systemName: grade.color == "green" ? "checkmark.circle.fill" : (grade.color == "orange" ? "exclamationmark.triangle.fill" : "xmark.octagon.fill"))
                                .font(.caption)
                        }
                        .foregroundColor(grade.color == "green" ? .green : (grade.color == "orange" ? .orange : .red))
                    }
                    HStack(spacing: Metrics.spacingMD) {
                        Text("↑ \(String(format: "%.0f", result.uploadMbps)) Mbps")
                            .font(.caption2.monospaced()).foregroundColor(.secondary)
                        if let baseRtt = result.baseRttMs {
                            Text("Base RTT: \(Int(baseRtt)) ms")
                                .font(.caption2.monospaced()).foregroundColor(.secondary)
                        }
                    }
                    Text(grade.label)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(grade.color == "green" ? .green : (grade.color == "orange" ? .orange : .red))
                }
            } else if tools.netQuality.isRunning {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Measuring network quality…")
                        .font(.subheadline.bold())
                    Text("Running download, upload, and responsiveness tests")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    PulsingIndicator(color: .blue)
                }
            } else {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Link Quality Probe")
                        .font(.subheadline.bold())
                    Text("Measures throughput, latency, and responsiveness (RPM)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var portListenerCard: some View {
        BentoCard(
            title: "Port Listener",
            icon: "ear",
            color: .purple,
            action: { selection = .portListener },
            helpText: "Start a TCP or UDP listener on any port. Useful for testing firewall rules, port forwarding, and service connectivity."
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                if tools.portListener.isRunning {
                    Text("Listening on port \(tools.portListener.port)")
                        .font(.subheadline.monospaced().weight(.bold))
                    Text("\(tools.portListener.events.count) connection\(tools.portListener.events.count == 1 ? "" : "s") received")
                        .font(.caption2.monospaced()).foregroundColor(.secondary)
                    PulsingIndicator(color: .purple)
                } else {
                    Text("Not Active")
                        .font(.subheadline.bold())
                    Text("Start a listener to test inbound connections")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var connectionsCard: some View {
        let established = tools.connections.connections.filter { $0.state == "ESTABLISHED" }.count
        let listening = tools.connections.connections.filter { $0.state == "LISTEN" }.count
        return BentoStatusCard(
            title: "Active Connections",
            icon: "app.connected.to.app.below.fill",
            color: .teal,
            status: "\(established) established",
            action: { selection = .connections },
            helpText: "View all network connections: established, listening, and their process names.",
            detail: "\(listening) listening"
        )
    }

    private var neighborsCard: some View {
        let visible = tools.neighbors.visibleEntries.count
        return BentoStatusCard(
            title: "LAN Neighbors",
            icon: "person.2.wave.2",
            color: .green,
            status: "\(visible) device\(visible == 1 ? "" : "s") on LAN",
            action: { selection = .neighbors },
            helpText: "Discover devices on your local network via ARP/NDP. See IP, MAC, and vendor info.",
            detail: "ARP / NDP table"
        )
    }

    private var historyCard: some View {
        BentoCard(
            title: "Session History",
            icon: "clock.arrow.circlepath",
            color: .gray,
            action: { selection = .sessionHistory },
            helpText: "View past 90 days of tool usage: ping results, traceroutes, speed tests, and scan history."
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text("\(tools.sessionHistory.records.count) recorded sessions")
                    .font(.subheadline.bold())
                Text("Past 90 Days — Auto-saved")
                    .font(.caption2.monospaced()).foregroundColor(.secondary)
                if !tools.sessionHistory.records.isEmpty {
                    let recent = tools.sessionHistory.records.suffix(3)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(recent.enumerated()), id: \.offset) { _, record in
                            HStack(spacing: 6) {
                                Image(systemName: iconForTool(record.tool))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(record.tool.capitalized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func iconForTool(_ tool: String) -> String {
        switch tool.lowercased() {
        case "ping": return "antenna.radiowaves.left.and.right"
        case "traceroute": return "point.3.connected.trianglepath.dotted"
        case "multiping": return "dot.radiowaves.left.and.right"
        case "portscan": return "checklist"
        case "http_latency": return "stopwatch"
        case "pathmtu": return "ruler"
        case "subnet": return "number.square"
        case "dns": return "globe"
        case "ssl": return "lock.shield"
        case "whois": return "magnifyingglass.circle"
        case "bandwidth": return "chart.bar.xaxis"
        case "statistics": return "chart.line.uptrend.xyaxis"
        case "speedtest": return "speedometer"
        case "netquality": return "gauge.with.dots.needle.67percent"
        case "wol": return "power.circle"
        case "portlistener": return "ear"
        case "interfaces": return "network"
        case "wifi": return "wifi"
        case "routes": return "arrow.triangle.branch"
        case "neighbors": return "person.2.wave.2"
        case "connections": return "app.connected.to.app.below.fill"
        case "ipgeolocation": return "mappin.and.ellipse"
        case "dnsresolver": return "server.rack"
        case "sessionhistory": return "clock.arrow.circlepath"
        case "compare": return "arrow.left.arrow.right"
        case "doctor": return "stethoscope"
        case "subnetscan": return "network.badge.shield.half.filled"
        default: return "doc.text"
        }
    }
}