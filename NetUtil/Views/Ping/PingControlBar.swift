import SwiftUI

struct PingControlBar: View {
    @Binding var host: String
    @Binding var countText: String
    @Binding var intervalText: String
    @Binding var packetSizeText: String
    @Binding var infinite: Bool
    @Binding var alertsEnabled: Bool
    let vm: PingViewModel
    let history: HostHistory
    let onStartStop: () -> Void
    let onHelp: () -> Void
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    @Environment(ToolStore.self) private var tools

    var body: some View {
        ToolControlBar(icon: "antenna.radiowaves.left.and.right", title: "Advanced Ping",
                       host: $host, textFieldWidth: 160, history: history, onSubmit: onStartStop) {
            Toggle(isOn: $infinite) {
                Image(systemName: "infinity")
                    .font(.caption.weight(.bold))
            }
            .toggleStyle(.button)
            .help("Infinite Ping — runs until stopped, ignoring Count")
            .accessibilityLabel("Infinite Ping Mode")

            Toggle(isOn: $alertsEnabled) {
                Image(systemName: alertsEnabled ? "bell.fill" : "bell.slash")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .help("Notify when this ping finishes, or when recent loss or latency crosses the Settings > Thresholds alert level")
            .accessibilityLabel("Notify on Completion or High Loss")

            if !infinite {
                TextField("Count", text: $countText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .help("Packet count")
                    .accessibilityLabel("Packet Count")
            }

            TextField("Sec", text: $intervalText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .help("Wait interval, in seconds")
                .accessibilityLabel("Ping Interval")

            TextField("Bytes", text: $packetSizeText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 46)
                .help("Payload size, in bytes")
                .accessibilityLabel("Payload Size")

            if !vm.results.isEmpty {
                ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV, onCopySummary: copySummary)
            }

            Button(action: onStartStop) {
                Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                    .frame(minWidth: 60)
            }
            .buttonStyle(.glassProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .accessibilityLabel(vm.isRunning ? "Stop Ping" : "Start Ping")

            let favHost = vm.isRunning ? vm.currentHost : host
            if !favHost.isEmpty {
                let isFav = tools.favorites.isFavorite(favHost)
                Button { tools.favorites.toggle(host: favHost) } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundColor(isFav ? .orange : .secondary)
                }
                .buttonStyle(.borderless)
                .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(isFav ? "Remove from Favorites" : "Add to Favorites")
            }

            Button(action: onHelp) {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Show Help Guide")
        }
    }

    private func copySummary() {
        let s = vm.stats
        let summary = "Host: \(vm.currentHost)\nTransmitted: \(s.transmitted)\nReceived: \(s.received)\nLoss: \(String(format: "%.1f%%", s.loss))\nAvg RTT: \(String(format: "%.1f ms", s.avgRtt))\nMin/Max RTT: \(String(format: "%.1f", s.minRtt))/\(String(format: "%.1f", s.maxRtt)) ms\nJitter: \(String(format: "%.1f ms", s.jitter))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}
