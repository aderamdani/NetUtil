import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultPingCount")      private var pingCount       = 20
    @AppStorage("defaultPingInterval")   private var pingInterval    = 1.0
    @AppStorage("defaultMaxHops")        private var maxHops         = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval   = 5.0
    @AppStorage("rttWarnThreshold")      private var rttWarn         = 20.0
    @AppStorage("rttCritThreshold")      private var rttCrit         = 100.0
    @AppStorage("lossAlertThreshold")    private var lossAlert       = 10.0
    @AppStorage("maxRawLines")           private var maxRawLines     = 500
    @AppStorage("portScanTimeout")       private var portScanTimeout = 1.5
    @AppStorage("portScanConcurrency")   private var portScanConc    = 50
    @AppStorage("sslTimeout")           private var sslTimeout      = 10.0
    @AppStorage("httpTimeout")          private var httpTimeout     = 15.0
    @AppStorage("geoEnabled")           private var geoEnabled      = true
    @AppStorage("bandwidthInterval")    private var bwInterval      = 1.0

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            thresholdsTab.tabItem { Label("Thresholds", systemImage: "chart.bar") }
            toolsTab.tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            privacyTab.tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 460, height: 340)
    }

    private var generalTab: some View {
        Form {
            Section("Ping") {
                LabeledContent("Default Count") {
                    Stepper("\(pingCount)", value: $pingCount, in: 1...9999)
                        .frame(width: 120)
                }
                sliderRow("Interval", value: $pingInterval, range: 0.2...10, step: 0.1, unit: "s", format: "%.1f")
            }
            Section("Traceroute") {
                LabeledContent("Max Hops") {
                    Stepper("\(maxHops)", value: $maxHops, in: 1...255)
                        .frame(width: 120)
                }
                sliderRow("Re-trace Interval", value: $traceInterval, range: 1...60, step: 1, unit: "s", format: "%.0f")
            }
            Section("Performance") {
                LabeledContent("Max Raw Lines") {
                    Stepper("\(maxRawLines)", value: $maxRawLines, in: 100...5000, step: 100)
                        .frame(width: 140)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var thresholdsTab: some View {
        Form {
            Section("RTT Colors") {
                LabeledContent("Good → Warning") {
                    HStack {
                        Circle().fill(Color.green).frame(width: 9, height: 9)
                        Slider(value: $rttWarn, in: 5...500, step: 5)
                            .frame(width: 140)
                        Circle().fill(Color.orange).frame(width: 9, height: 9)
                        Text("\(Int(rttWarn)) ms")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
                LabeledContent("Warning → Critical") {
                    HStack {
                        Circle().fill(Color.orange).frame(width: 9, height: 9)
                        Slider(value: $rttCrit, in: 20...2000, step: 10)
                            .frame(width: 140)
                        Circle().fill(Color.red).frame(width: 9, height: 9)
                        Text("\(Int(rttCrit)) ms")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
                HStack(spacing: 12) {
                    Spacer()
                    legendDot(.green,  "< \(Int(rttWarn)) ms = Good")
                    legendDot(.orange, "\(Int(rttWarn))–\(Int(rttCrit)) ms = Warn")
                    legendDot(.red,    "> \(Int(rttCrit)) ms = Critical")
                }
            }
            Section("Packet Loss") {
                sliderRow("Alert Threshold", value: $lossAlert, range: 1...100, step: 1, unit: "%", format: "%.0f")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var toolsTab: some View {
        Form {
            Section("Port Scanner") {
                sliderRow("Timeout", value: $portScanTimeout, range: 0.5...10, step: 0.5, unit: "s", format: "%.1f")
                LabeledContent("Default Concurrency") {
                    Stepper("\(portScanConc)", value: $portScanConc, in: 1...200)
                        .frame(width: 120)
                }
            }
            Section("HTTP Latency") {
                sliderRow("Request Timeout", value: $httpTimeout, range: 5...60, step: 5, unit: "s", format: "%.0f")
            }
            Section("SSL Inspector") {
                sliderRow("Connect Timeout", value: $sslTimeout, range: 5...30, step: 5, unit: "s", format: "%.0f")
            }
            Section("Bandwidth") {
                sliderRow("Refresh Interval", value: $bwInterval, range: 0.5...5, step: 0.5, unit: "s", format: "%.1f")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var privacyTab: some View {
        Form {
            Section("Geolocation") {
                Toggle("Look up IP locations in Traceroute", isOn: $geoEnabled)
                Text("Queries ipinfo.io for country, city, and ISP data on each hop IP.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("Host History") {
                LabeledContent("Saved Hosts") {
                    Button("Clear All", role: .destructive) {
                        HostHistory.shared.clear()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String, format: String) -> some View {
        LabeledContent(label) {
            HStack {
                Slider(value: value, in: range, step: step)
                    .frame(width: 140)
                Text(String(format: format + " \(unit)", value.wrappedValue))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 62, alignment: .trailing)
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
