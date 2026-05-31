import SwiftUI

struct GeneralPane: View {
    @AppStorage("defaultPingCount")      private var pingCount      = 20
    @AppStorage("defaultPingInterval")   private var pingInterval   = 1.0
    @AppStorage("pingAutoStopLimit")     private var autoStopLimit  = 5
    @AppStorage("pingBeepOnLoss")        private var beepOnLoss     = false
    @AppStorage("defaultMaxHops")        private var maxHops        = 30
    @AppStorage("defaultTraceInterval")  private var traceInterval  = 5.0
    @AppStorage("maxRawLines")           private var maxRawLines    = 500
    @AppStorage("menuBarDisplayMode")    private var menuBarMode    = "icon"
    @AppStorage("menuBarShowTraffic")    private var menuBarTraffic = false
    @AppStorage("menuBarPingInterval")   private var menuBarInterval = 2.0
    @AppStorage("backgroundOnClose")     private var backgroundOnClose = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Default Count") {
                    Stepper("\(pingCount) pkts", value: $pingCount, in: 1...9999)
                        .frame(width: 130)
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
                        .frame(width: 155)
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
                        .frame(width: 130)
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
                        .frame(width: 130)
                }
                .help("Maximum number of raw log lines kept in memory per tool. Older lines are dropped when this limit is reached to prevent high memory usage.")
                .accessibilityLabel("Max Raw Output Buffer Size")
            } header: {
                Text("Performance")
            }

            Section {
                LabeledContent("Shows") {
                    Picker("", selection: $menuBarMode) {
                        Label("Icon", systemImage: "waveform.path.ecg").tag("icon")
                        Text("16 ms").font(.system(size: 12, design: .monospaced)).tag("rtt")
                        Text("↓1M ↑200K").font(.system(size: 11, design: .monospaced)).tag("traffic")
                        Text("16ms ↓1M ↑200K").font(.system(size: 10, design: .monospaced)).tag("rtt_traffic")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                    .accessibilityLabel("Menu Bar Display Mode")
                }
                .help("Icon: waveform symbol only. Ping: live RTT in ms. Traffic: live download (↓) and upload (↑) rates. Ping + Traffic: both side by side, updated every second.")

                Toggle("Show traffic next to icon", isOn: $menuBarTraffic)
                    .disabled(menuBarMode == "traffic" || menuBarMode == "rtt_traffic" || menuBarMode == "rtt")
                    .help("Append live download (↓) and upload (↑) rates to the right of the icon. Disabled when the primary mode already shows traffic or uses the Ping + Traffic preset.")
                    .accessibilityLabel("Show Traffic in Menu Bar")

                Toggle("Keep running in menu bar when window closed", isOn: $backgroundOnClose)
                    .help("When enabled, closing the main window hides NetUtil from the Dock but keeps the menu bar item active. Click the menu bar icon and the window button to bring NetUtil back to the Dock. When disabled, closing the window quits the app.")
                    .accessibilityLabel("Keep Running in Background")

                LabeledContent("Ping Interval") {
                    CompactSlider(value: $menuBarInterval, range: 1...10, step: 1, format: "%.0f s")
                }
                .help("How often the background ping sends a packet. Minimum 1 second. Higher values reduce network activity.")
                .accessibilityLabel("Menu Bar Background Ping Interval")
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Background ping runs automatically and updates the menu bar icon in real-time.")
            }
        }
        .formStyle(.grouped)
    }
}
