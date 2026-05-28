import SwiftUI

// MARK: - Root

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ThresholdsPane()
                .tabItem { Label("Thresholds", systemImage: "dial.medium") }
            ToolsPane()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            PrivacyPane()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @AppStorage("defaultPingCount")      private var pingCount      = 20
    @AppStorage("defaultPingInterval")   private var pingInterval   = 1.0
    @AppStorage("pingAutoStopLimit")     private var autoStopLimit  = 5
    @AppStorage("pingBeepOnLoss")        private var beepOnLoss     = false
    @AppStorage("defaultMaxHops")        private var maxHops        = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval  = 5.0
    @AppStorage("maxRawLines")           private var maxRawLines    = 500
    @AppStorage("menuBarDisplayMode")    private var menuBarMode    = "icon"
    @AppStorage("menuBarPingInterval")   private var menuBarInterval = 2.0

    var body: some View {
        Form {
            Section {
                LabeledContent("Default Count") {
                    Stepper("\(pingCount) pkts", value: $pingCount, in: 1...9999)
                        .frame(width: 130)
                }
                .help("Number of ICMP echo packets sent per session. Can be overridden directly in the Ping tool.")

                LabeledContent("Interval") {
                    CompactSlider(value: $pingInterval, range: 0.2...10, step: 0.1, format: "%.1f s")
                }
                .help("Wait time between consecutive ICMP echo requests. Lower values stress-test the network path more aggressively.")

                LabeledContent("Auto-Stop on Loss") {
                    Stepper(autoStopLimit == 0 ? "Disabled" : "\(autoStopLimit) timeouts",
                            value: $autoStopLimit, in: 0...50)
                        .frame(width: 155)
                }
                .help("Automatically stop the ping session after this many consecutive timeouts. Set to 0 to disable auto-stop.")

                LabeledContent("Beep on Loss") {
                    Toggle("", isOn: $beepOnLoss)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .help("Play a system sound each time a ping packet is lost. Useful for passive monitoring without watching the screen.")
            } header: {
                Text("Ping")
            }

            Section {
                LabeledContent("Max Hops") {
                    Stepper("\(maxHops) hops", value: $maxHops, in: 1...255)
                        .frame(width: 130)
                }
                .help("Maximum TTL value passed to traceroute via the -m flag. Controls how far the trace extends across the network.")

                LabeledContent("Re-trace Interval") {
                    CompactSlider(value: $traceInterval, range: 1...60, step: 1, format: "%.0f s")
                }
                .help("Seconds between automatic re-runs in continuous traceroute mode. Lower values keep path data more current.")
            } header: {
                Text("Traceroute")
            }

            Section {
                LabeledContent("Max Raw Output Lines") {
                    Stepper("\(maxRawLines)", value: $maxRawLines, in: 100...5000, step: 100)
                        .frame(width: 130)
                }
                .help("Maximum number of raw log lines kept in memory per tool. Older lines are dropped when this limit is reached to prevent high memory usage.")
            } header: {
                Text("Performance")
            }

            Section {
                LabeledContent("Shows") {
                    Picker("", selection: $menuBarMode) {
                        Label("Icon", systemImage: "waveform.path.ecg").tag("icon")
                        Text("16 ms").font(.system(size: 12, design: .monospaced)).tag("rtt")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .help("Icon shows the waveform symbol. RTT displays the live ping result in milliseconds, colored green/orange/red by your threshold settings.")

                LabeledContent("Ping Interval") {
                    CompactSlider(value: $menuBarInterval, range: 1...10, step: 1, format: "%.0f s")
                }
                .help("How often the background ping sends a packet. Minimum 1 second. Higher values reduce network activity.")
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Background ping runs automatically and updates the menu bar icon in real-time.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Thresholds

private struct ThresholdsPane: View {
    @AppStorage("rttWarnThreshold")   private var rttWarn   = 20.0
    @AppStorage("rttCritThreshold")   private var rttCrit   = 100.0
    @AppStorage("lossAlertThreshold") private var lossAlert = 10.0

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview").font(.caption).foregroundColor(.secondary)
                    RTTPreviewBar(warn: rttWarn, crit: rttCrit)
                    HStack {
                        legendItem(.green,  "Good — < \(Int(rttWarn)) ms")
                        Spacer()
                        legendItem(.orange, "Warn — \(Int(rttWarn))–\(Int(rttCrit)) ms")
                        Spacer()
                        legendItem(.red,    "Critical — > \(Int(rttCrit)) ms")
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)

                LabeledContent("Good → Warning") {
                    CompactSlider(value: $rttWarn, range: 5...500, step: 5, format: "%.0f ms", tint: .green)
                }
                .help("RTT values below this threshold are displayed in green across Ping, Traceroute, and Multi-Ping.")
                .onChange(of: rttWarn) { _, new in
                    if new >= rttCrit { rttWarn = rttCrit - 5 }
                }

                LabeledContent("Warning → Critical") {
                    CompactSlider(value: $rttCrit, range: 20...2000, step: 10, format: "%.0f ms", tint: .orange)
                }
                .help("RTT values above this threshold are displayed in red. Values between Warning and this boundary are displayed in orange.")
                .onChange(of: rttCrit) { _, new in
                    if new <= rttWarn { rttCrit = rttWarn + 10 }
                }
            } header: {
                Text("RTT Color Zones")
            }

            Section {
                LabeledContent("Alert Threshold") {
                    CompactSlider(value: $lossAlert, range: 1...100, step: 1, format: "%.0f%%", tint: .red)
                }
                .help("Packet loss percentage above this value turns the loss indicator red in all stats bars and the dashboard.")
            } header: {
                Text("Packet Loss")
            }

            Section {
                Button("Reset to Defaults") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        rttWarn   = 20
                        rttCrit   = 100
                        lossAlert = 10
                    }
                }
                .frame(maxWidth: .infinity)
                .help("Restore RTT and loss thresholds to their factory values: Good < 20 ms, Critical > 100 ms, Loss alert at 10%.")
            }
        }
        .formStyle(.grouped)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.8)).frame(width: 12, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
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
        Form {
            Section {
                LabeledContent("Connection Timeout") {
                    CompactSlider(value: $portScanTimeout, range: 0.5...10, step: 0.5, format: "%.1f s")
                }
                .help("Maximum time to wait for a TCP connection on each port before marking it closed or filtered. Lower values speed up scans but may produce false negatives on slow hosts.")

                LabeledContent("Concurrency") {
                    Stepper("\(portScanConc) threads", value: $portScanConc, in: 1...200)
                        .frame(width: 155)
                }
                .help("Number of simultaneous TCP probes. Higher values finish scans faster but are more aggressive and may trigger intrusion detection on the target.")
            } header: {
                Text("Port Scanner")
            }

            Section {
                LabeledContent("Request Timeout") {
                    CompactSlider(value: $httpTimeout, range: 5...60, step: 5, format: "%.0f s")
                }
                .help("Maximum time to wait for a complete HTTP or HTTPS response, including all redirect hops and body download.")
            } header: {
                Text("HTTP Latency")
            }

            Section {
                LabeledContent("Connect Timeout") {
                    CompactSlider(value: $sslTimeout, range: 5...30, step: 5, format: "%.0f s")
                }
                .help("Maximum time allowed for the TLS handshake to complete when inspecting a server certificate chain.")
            } header: {
                Text("SSL Inspector")
            }

            Section {
                LabeledContent("Refresh Interval") {
                    CompactSlider(value: $bwInterval, range: 0.5...5, step: 0.5, format: "%.1f s")
                }
                .help("How often kernel interface counters are sampled to compute current RX and TX throughput rates. Lower values give smoother graphs but use slightly more CPU.")
            } header: {
                Text("Bandwidth Monitor")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

private struct PrivacyPane: View {
    @AppStorage("geoEnabled") private var geoEnabled = true
    @StateObject private var history = HostHistory.shared

    var body: some View {
        Form {
            Section {
                Toggle("Look up IP locations in Traceroute", isOn: $geoEnabled)
                    .help("Sends each hop's IP address to ipinfo.io to retrieve country, city, ISP, and GPS coordinates for the map view. Disable for fully offline operation or strict privacy environments.")
            } header: {
                Text("Geolocation")
            } footer: {
                Text("Requests are sent to ipinfo.io. No account or API key is required.")
            }

            Section {
                LabeledContent("Saved Hosts") {
                    HStack(spacing: 8) {
                        Text("\(history.hosts.count) / 20")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button("Clear", role: .destructive) { history.clear() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(history.hosts.isEmpty)
                    }
                }
                .help("Hostnames and IP addresses entered in any tool are saved locally for quick recall via the history dropdown. Maximum 20 entries stored in UserDefaults.")
            } header: {
                Text("Host History")
            } footer: {
                Text("History is stored on this device only and is never transmitted.")
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No telemetry collected")
                            .font(.callout.weight(.medium))
                        Text("NetUtil does not collect analytics, crash reports, or usage data. All diagnostics remain on this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Data Collection")
            }
        }
        .formStyle(.grouped)
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

// MARK: - RTTPreviewBar

private struct RTTPreviewBar: View {
    let warn: Double
    let crit: Double

    var body: some View {
        GeometryReader { geo in
            let cap      = max(crit * 1.3, 200.0)
            let warnFrac = CGFloat(min(warn, cap) / cap)
            let critFrac = CGFloat((min(crit, cap) - min(warn, cap)) / cap)
            let redFrac  = max(0, 1 - warnFrac - critFrac)
            HStack(spacing: 0) {
                Rectangle().fill(Color.green.opacity(0.75)).frame(width: geo.size.width * warnFrac)
                Rectangle().fill(Color.orange.opacity(0.75)).frame(width: geo.size.width * critFrac)
                Rectangle().fill(Color.red.opacity(0.75)).frame(width: geo.size.width * redFrac)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: warn)
        .animation(.easeInOut(duration: 0.25), value: crit)
    }
}
