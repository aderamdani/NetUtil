import SwiftUI

struct ThresholdsPane: View {
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("RTT Color Zone Preview")

                LabeledContent("Good → Warning") {
                    CompactSlider(value: $rttWarn, range: 5...500, step: 5, format: "%.0f ms", tint: .green)
                }
                .help("RTT values below this threshold are displayed in green across Ping, Traceroute, and Multi-Ping.")
                .onChange(of: rttWarn) { _, new in
                    if new >= rttCrit { rttWarn = rttCrit - 5 }
                }
                .accessibilityLabel("Latency Warning Threshold")

                LabeledContent("Warning → Critical") {
                    CompactSlider(value: $rttCrit, range: 20...2000, step: 10, format: "%.0f ms", tint: .orange)
                }
                .help("RTT values above this threshold are displayed in red. Values between Warning and this boundary are displayed in orange.")
                .onChange(of: rttCrit) { _, new in
                    if new <= rttWarn { rttCrit = rttWarn + 10 }
                }
                .accessibilityLabel("Latency Critical Threshold")
            } header: {
                Text("RTT Color Zones")
            }

            Section {
                LabeledContent("Alert Threshold") {
                    CompactSlider(value: $lossAlert, range: 1...100, step: 1, format: "%.0f%%", tint: .red)
                }
                .help("Packet loss percentage above this value turns the loss indicator red in all stats bars and the dashboard.")
                .accessibilityLabel("Packet Loss Alert Threshold")
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
                .accessibilityLabel("Reset Thresholds to Defaults")
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
