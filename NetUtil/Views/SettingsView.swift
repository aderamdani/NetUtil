import SwiftUI

// MARK: - Section enum

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general    = "General"
    case thresholds = "Thresholds"
    case tools      = "Tools"
    case privacy    = "Privacy"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general:    "gearshape"
        case .thresholds: "dial.medium"
        case .tools:      "wrench.and.screwdriver"
        case .privacy:    "hand.raised"
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 600, height: 440)
        .background(Color(.windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { s in
                SidebarRow(label: s.rawValue, icon: s.icon, isSelected: section == s) {
                    section = s
                }
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 8)
        .frame(width: 168)
        .background(Color(.windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general:    GeneralPane()
        case .thresholds: ThresholdsPane()
        case .tools:      ToolsPane()
        case .privacy:    PrivacyPane()
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 16)
                Text(label)
                    .font(.system(.callout, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

// MARK: - Pane header

private struct PaneHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Settings row helpers

private struct SettingRow<Control: View>: View {
    let label: String
    let hint: String?
    let control: Control

    init(_ label: String, hint: String? = nil, @ViewBuilder control: () -> Control) {
        self.label = label
        self.hint = hint
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.callout)
                if let hint {
                    Text(hint).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            control
        }
        .padding(.vertical, 4)
    }
}

private struct SettingSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(0.8)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @AppStorage("defaultPingCount")      private var pingCount       = 20
    @AppStorage("defaultPingInterval")   private var pingInterval    = 1.0
    @AppStorage("pingAutoStopLimit")     private var autoStopLimit   = 5
    @AppStorage("defaultMaxHops")        private var maxHops         = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval   = 5.0
    @AppStorage("maxRawLines")           private var maxRawLines     = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(icon: "gearshape", title: "General",
                           subtitle: "Default values used when starting tools")

                SettingSection("Ping") {
                    SettingRow("Default Count",
                               hint: "Packets sent per session unless overridden") {
                        Stepper("\(pingCount) pkts", value: $pingCount, in: 1...9999)
                            .frame(width: 130)
                    }
                    Divider().opacity(0.5)
                    SettingRow("Interval",
                               hint: "Wait between each ICMP request") {
                        CompactSlider(value: $pingInterval, range: 0.2...10, step: 0.1,
                                      format: "%.1f s")
                    }
                    Divider().opacity(0.5)
                    SettingRow("Auto-Stop on Consecutive Loss",
                               hint: "Stop after N timeouts in a row (0 = disabled)") {
                        Stepper(autoStopLimit == 0 ? "Off" : "\(autoStopLimit) pkts",
                                value: $autoStopLimit, in: 0...50)
                            .frame(width: 130)
                    }
                }

                SettingSection("Traceroute") {
                    SettingRow("Max Hops",
                               hint: "Maximum TTL value (-m flag)") {
                        Stepper("\(maxHops) hops", value: $maxHops, in: 1...255)
                            .frame(width: 130)
                    }
                    Divider().opacity(0.5)
                    SettingRow("Re-trace Interval",
                               hint: "Seconds between automatic re-runs") {
                        CompactSlider(value: $traceInterval, range: 1...60, step: 1,
                                      format: "%.0f s")
                    }
                }

                SettingSection("Performance") {
                    SettingRow("Max Raw Output Lines",
                               hint: "Older lines are trimmed when this limit is reached") {
                        Stepper("\(maxRawLines)", value: $maxRawLines,
                                in: 100...5000, step: 100)
                            .frame(width: 130)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Thresholds

private struct ThresholdsPane: View {
    @AppStorage("rttWarnThreshold")   private var rttWarn   = 20.0
    @AppStorage("rttCritThreshold")   private var rttCrit   = 100.0
    @AppStorage("lossAlertThreshold") private var lossAlert = 10.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(icon: "dial.medium", title: "Thresholds",
                           subtitle: "Color-coding boundaries used across all tools")

                SettingSection("RTT Color Zones") {
                    // Live preview bar
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview").font(.caption).foregroundColor(.secondary)
                        RTTPreviewBar(warn: rttWarn, crit: rttCrit)
                        HStack {
                            legendItem(.green, "Good — < \(Int(rttWarn)) ms")
                            Spacer()
                            legendItem(.orange, "Warn — \(Int(rttWarn))–\(Int(rttCrit)) ms")
                            Spacer()
                            legendItem(.red, "Critical — > \(Int(rttCrit)) ms")
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)

                    Divider().opacity(0.5)

                    SettingRow("Good → Warning boundary") {
                        CompactSlider(value: $rttWarn, range: 5...500, step: 5,
                                      format: "%.0f ms", tint: .green)
                    }
                    Divider().opacity(0.5)
                    SettingRow("Warning → Critical boundary") {
                        CompactSlider(value: $rttCrit, range: 20...2000, step: 10,
                                      format: "%.0f ms", tint: .orange)
                    }
                }

                SettingSection("Packet Loss") {
                    SettingRow("Alert Threshold",
                               hint: "Loss% above this value turns red in stats bars") {
                        CompactSlider(value: $lossAlert, range: 1...100, step: 1,
                                      format: "%.0f%%", tint: .red)
                    }
                }

                // Reset
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rttWarn   = 20
                            rttCrit   = 100
                            lossAlert = 10
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.8))
                .frame(width: 12, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// RTT preview bar
private struct RTTPreviewBar: View {
    let warn: Double
    let crit: Double

    var body: some View {
        GeometryReader { geo in
            let cap = max(crit * 1.3, 200.0)
            let warnFrac = CGFloat(min(warn, cap) / cap)
            let critFrac = CGFloat((min(crit, cap) - min(warn, cap)) / cap)
            let redFrac  = max(0, 1 - warnFrac - critFrac)

            HStack(spacing: 0) {
                Rectangle().fill(Color.green.opacity(0.75))
                    .frame(width: geo.size.width * warnFrac)
                Rectangle().fill(Color.orange.opacity(0.75))
                    .frame(width: geo.size.width * critFrac)
                Rectangle().fill(Color.red.opacity(0.75))
                    .frame(width: geo.size.width * redFrac)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: warn)
        .animation(.easeInOut(duration: 0.25), value: crit)
    }
}

// MARK: - Tools

private struct ToolsPane: View {
    @AppStorage("portScanTimeout")     private var portScanTimeout = 1.5
    @AppStorage("portScanConcurrency") private var portScanConc    = 50
    @AppStorage("httpTimeout")         private var httpTimeout     = 15.0
    @AppStorage("sslTimeout")          private var sslTimeout      = 10.0
    @AppStorage("bandwidthInterval")   private var bwInterval      = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(icon: "wrench.and.screwdriver", title: "Tools",
                           subtitle: "Per-tool timeouts and concurrency defaults")

                SettingSection("Port Scanner") {
                    SettingRow("Connection Timeout",
                               hint: "Per-port TCP connect wait before marking closed/filtered") {
                        CompactSlider(value: $portScanTimeout, range: 0.5...10, step: 0.5,
                                      format: "%.1f s")
                    }
                    Divider().opacity(0.5)
                    SettingRow("Concurrency",
                               hint: "Simultaneous probes — higher is faster but more aggressive") {
                        Stepper("\(portScanConc) threads",
                                value: $portScanConc, in: 1...200)
                            .frame(width: 155)
                    }
                }

                SettingSection("HTTP Latency") {
                    SettingRow("Request Timeout",
                               hint: "Maximum wait for the full response to complete") {
                        CompactSlider(value: $httpTimeout, range: 5...60, step: 5,
                                      format: "%.0f s")
                    }
                }

                SettingSection("SSL Inspector") {
                    SettingRow("Connect Timeout",
                               hint: "Maximum wait for TLS handshake to complete") {
                        CompactSlider(value: $sslTimeout, range: 5...30, step: 5,
                                      format: "%.0f s")
                    }
                }

                SettingSection("Bandwidth Monitor") {
                    SettingRow("Refresh Interval",
                               hint: "How often kernel counters are polled for RX/TX rates") {
                        CompactSlider(value: $bwInterval, range: 0.5...5, step: 0.5,
                                      format: "%.1f s")
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Privacy

private struct PrivacyPane: View {
    @AppStorage("geoEnabled") private var geoEnabled = true
    @StateObject private var history = HostHistory.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaneHeader(icon: "hand.raised", title: "Privacy",
                           subtitle: "Control data lookups and locally stored history")

                SettingSection("Geolocation") {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Look up IP locations in Traceroute")
                                .font(.callout)
                            Text("Sends hop IPs to ipinfo.io to retrieve country, city, ISP, and coordinates. Disable for fully offline operation or strict privacy requirements.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Toggle("", isOn: $geoEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }

                SettingSection("Host History") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved hosts")
                                .font(.callout)
                            Text("\(history.hosts.count) of 20 entries stored locally in UserDefaults")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Clear All", role: .destructive) {
                            history.clear()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(history.hosts.isEmpty)
                    }
                    .padding(.vertical, 4)
                }

                SettingSection("Data") {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No telemetry collected")
                                .font(.callout.bold())
                            Text("NetUtil does not collect analytics, crash reports, or usage data. All diagnostics stay on this machine.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - CompactSlider

private struct CompactSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $value, in: range, step: step)
                .tint(tint)
                .frame(width: 120)
            Text(String(format: format, value))
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 58, alignment: .trailing)
        }
    }
}
