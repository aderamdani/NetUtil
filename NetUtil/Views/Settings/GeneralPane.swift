import SwiftUI

struct GeneralPane: View {
    @AppStorage("defaultPingCount")      private var pingCount      = 20
    @AppStorage("defaultPingInterval")   private var pingInterval   = 1.0
    @AppStorage("pingAutoStopLimit")     private var autoStopLimit  = 5
    @AppStorage("pingBeepOnLoss")        private var beepOnLoss     = false
    @AppStorage("defaultMaxHops")        private var maxHops        = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval  = 5.0
    @AppStorage("maxRawLines")           private var maxRawLines    = 500
    @AppStorage("backgroundOnClose")     private var backgroundOnClose = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Default Count") {
                    Stepper("\(pingCount) pkts", value: $pingCount, in: 1...9999)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .help("Number of ICMP echo packets sent per session. Can be overridden directly in the Ping tool.")
                .accessibilityLabel("Default Ping Count")

                LabeledContent("Interval") {
                    CompactSlider(value: $pingInterval, range: 0.2...10, step: 0.1, format: "%.1f s")
                }
                .help("Wait time between consecutive ICMP echo requests. Lower values stress-test the network path more aggressively.")
                .accessibilityLabel("Default Ping Interval")

                LabeledContent("Auto-Stop on Loss") {
                    Stepper(autoStopLimit == 0 ? "Disabled" : "\(autoStopLimit) timeouts",
                            value: $autoStopLimit, in: 0...50)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .help("Automatically stop the ping session after this many consecutive timeouts. Set to 0 to disable auto-stop.")
                .accessibilityLabel("Auto-Stop on Loss Threshold")

                LabeledContent("Beep on Loss") {
                    Toggle("", isOn: $beepOnLoss)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .help("Play a system sound each time a ping packet is lost. Useful for passive monitoring without watching the screen.")
                .accessibilityLabel("Enable Beep on Packet Loss")
            } header: {
                Text("Ping")
            }

            Section {
                LabeledContent("Max Hops") {
                    Stepper("\(maxHops) hops", value: $maxHops, in: 1...255)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .help("Maximum TTL value passed to traceroute via the -m flag. Controls how far the trace extends across the network.")
                .accessibilityLabel("Traceroute Max Hops")

                LabeledContent("Re-trace Interval") {
                    CompactSlider(value: $traceInterval, range: 1...60, step: 1, format: "%.0f s")
                }
                .help("Seconds between automatic re-runs in continuous traceroute mode. Lower values keep path data more current.")
                .accessibilityLabel("Continuous Traceroute Interval")
            } header: {
                Text("Traceroute")
            }

            Section {
                LabeledContent("Max Raw Output Lines") {
                    Stepper("\(maxRawLines)", value: $maxRawLines, in: 100...5000, step: 100)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .help("Maximum number of raw log lines kept in memory per tool. Older lines are dropped when this limit is reached to prevent high memory usage.")
                .accessibilityLabel("Max Raw Output Buffer Size")
            } header: {
                Text("Performance")
            }

            Section {
                Toggle("Keep running in menu bar when window closed", isOn: $backgroundOnClose)
                    .help("When enabled, closing the main window hides NetUtil from the Dock but keeps the menu bar item active. Click the menu bar icon and the window button to bring NetUtil back to the Dock. When disabled, closing the window quits the app.")
                    .accessibilityLabel("Keep Running in Background")
            } header: {
                Text("Menu Bar")
            }
        }
        .formStyle(.grouped)
    }
}
