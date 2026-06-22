import SwiftUI

struct ToolsPane: View {
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
                .accessibilityLabel("Port Scan Timeout")

                LabeledContent("Concurrency") {
                    Stepper("\(portScanConc) threads", value: $portScanConc, in: 1...200)
                        .frame(width: Metrics.settingsColumnWidth)
                }
                .help("Number of simultaneous TCP probes. Higher values finish scans faster but are more aggressive and may trigger intrusion detection on the target.")
                .accessibilityLabel("Port Scan Concurrency Threads")
            } header: {
                Text("Port Scanner")
            }

            Section {
                LabeledContent("Request Timeout") {
                    CompactSlider(value: $httpTimeout, range: 5...60, step: 5, format: "%.0f s")
                }
                .help("Maximum time to wait for a complete HTTP or HTTPS response, including all redirect hops and body download.")
                .accessibilityLabel("HTTP Request Timeout")
            } header: {
                Text("HTTP Latency")
            }

            Section {
                LabeledContent("Connect Timeout") {
                    CompactSlider(value: $sslTimeout, range: 5...30, step: 5, format: "%.0f s")
                }
                .help("Maximum time allowed for the TLS handshake to complete when inspecting a server certificate chain.")
                .accessibilityLabel("SSL Handshake Timeout")
            } header: {
                Text("SSL Inspector")
            }

            Section {
                LabeledContent("Refresh Interval") {
                    CompactSlider(value: $bwInterval, range: 0.5...5, step: 0.5, format: "%.1f s")
                }
                .help("How often kernel interface counters are sampled to compute current RX and TX throughput rates. Lower values give smoother graphs but use slightly more CPU.")
                .accessibilityLabel("Bandwidth Refresh Interval")
            } header: {
                Text("Bandwidth Monitor")
            }
        }
        .formStyle(.grouped)
    }
}
