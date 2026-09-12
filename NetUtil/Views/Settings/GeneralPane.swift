import SwiftUI

/// Everyday preferences first; technical tuning lives behind an "Advanced"
/// disclosure so non-technical users are never confronted with ICMP counts
/// or buffer sizes unless they go looking.
struct GeneralPane: View {
    @AppStorage("backgroundOnClose")     private var backgroundOnClose = false
    @AppStorage("menuBarShowTraffic")    private var menuBarTraffic   = false
    @AppStorage("pingAlerts")            private var alertsEnabled  = false
    @AppStorage("pingBeepOnLoss")        private var beepOnLoss     = false

    @AppStorage("defaultPingCount")      private var pingCount      = 20
    @AppStorage("defaultPingInterval")   private var pingInterval   = 1.0
    @AppStorage("pingAutoStopLimit")     private var autoStopLimit  = 5
    @AppStorage("defaultMaxHops")        private var maxHops        = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval  = 5.0
    @AppStorage("maxRawLines")           private var maxRawLines    = 500

    @AppStorage("rttWarnThreshold")      private var rttWarn   = 20.0
    @AppStorage("rttCritThreshold")      private var rttCrit   = 100.0
    @AppStorage("lossAlertThreshold")    private var lossAlert = 10.0

    var body: some View {
        Form {
            Section {
                Toggle("Keep NetUtil available after closing the window", isOn: $backgroundOnClose)
                    .accessibilityLabel("Keep Running in Background")
                Toggle("Show live speed in the menu bar icon", isOn: $menuBarTraffic)
                    .accessibilityLabel("Show Traffic in Menu Bar Icon")
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("When kept available, NetUtil stays in the menu bar so it can keep monitoring. Turn off to quit NetUtil when the window closes.")
            }

            Section {
                Toggle("Notify me about connection problems", isOn: $alertsEnabled)
                    .accessibilityLabel("Enable Ping Notifications")
                Toggle("Play a sound when a ping is lost", isOn: $beepOnLoss)
                    .accessibilityLabel("Enable Beep on Packet Loss")
            } header: {
                Text("Alerts")
            } footer: {
                Text("Notifications appear when a run finishes and when loss or latency crosses the limits below.")
            }

            Section {
                LabeledContent("Pings per run") {
                    Stepper("\(pingCount)", value: $pingCount, in: 1...9999)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .accessibilityLabel("Default Ping Count")

                LabeledContent("Time between pings") {
                    CompactSlider(value: $pingInterval, range: 0.2...10, step: 0.1, format: "%.1f s")
                }
                .accessibilityLabel("Default Ping Interval")

                DisclosureGroup("Advanced") {
                    LabeledContent("Stop after repeated timeouts") {
                        Stepper(autoStopLimit == 0 ? "Never" : "\(autoStopLimit) timeouts",
                                value: $autoStopLimit, in: 0...50)
                            .frame(width: Metrics.settingsColumnWidth)
                    }
                    .accessibilityLabel("Auto-Stop on Loss Threshold")

                    LabeledContent("Traceroute max hops") {
                        Stepper("\(maxHops)", value: $maxHops, in: 1...255)
                            .frame(width: Metrics.settingsColumnWidth)
                    }
                    .accessibilityLabel("Traceroute Max Hops")

                    LabeledContent("Traceroute re-trace interval") {
                        CompactSlider(value: $traceInterval, range: 1...60, step: 1, format: "%.0f s")
                    }
                    .accessibilityLabel("Continuous Traceroute Interval")

                    LabeledContent("Log lines kept per tool") {
                        Stepper("\(maxRawLines)", value: $maxRawLines, in: 100...5000, step: 100)
                            .frame(width: Metrics.settingsColumnWidth)
                    }
                    .accessibilityLabel("Max Raw Output Buffer Size")
                }
            } header: {
                Text("Ping & Traceroute")
            } footer: {
                Text("Starting values for new sessions. You can still change them inside each tool.")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    RTTPreviewBar(warn: rttWarn, crit: rttCrit)
                    HStack {
                        legendItem(.green,  "Good < \(Int(rttWarn)) ms")
                        Spacer()
                        legendItem(.orange, "\(Int(rttWarn))–\(Int(rttCrit)) ms")
                        Spacer()
                        legendItem(.red,    "> \(Int(rttCrit)) ms")
                    }
                }
                .padding(.vertical, Metrics.spacingXS)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Latency Color Preview")

                LabeledContent("Good → Warning") {
                    CompactSlider(value: $rttWarn, range: 5...500, step: 5, format: "%.0f ms", tint: .green)
                }
                .onChange(of: rttWarn) { _, new in
                    if new >= rttCrit { rttWarn = rttCrit - 5 }
                }
                .accessibilityLabel("Latency Warning Threshold")

                LabeledContent("Warning → Critical") {
                    CompactSlider(value: $rttCrit, range: 20...2000, step: 10, format: "%.0f ms", tint: .orange)
                }
                .onChange(of: rttCrit) { _, new in
                    if new <= rttWarn { rttCrit = rttWarn + 10 }
                }
                .accessibilityLabel("Latency Critical Threshold")

                DisclosureGroup("Advanced") {
                    LabeledContent("Packet loss alert") {
                        CompactSlider(value: $lossAlert, range: 1...100, step: 1, format: "%.0f%%", tint: .red)
                    }
                    .accessibilityLabel("Packet Loss Alert Threshold")

                    Button("Reset Color Limits") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rttWarn   = 20
                            rttCrit   = 100
                            lossAlert = 10
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Reset Thresholds to Defaults")
                }
            } header: {
                Text("Latency Colors")
            } footer: {
                Text("Latency is shown in green, orange, or red across Ping, Traceroute, and Multi-Ping based on these limits.")
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
