import SwiftUI

struct PingControlBar: View {
    @Binding var host: String
    @Binding var countText: String
    @Binding var intervalText: String
    @Binding var packetSizeText: String
    @Binding var infinite: Bool
    @Binding var beepOnLoss: Bool
    let vm: PingViewModel
    let history: HostHistory
    let onStartStop: () -> Void
    let onHelp: () -> Void
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    @Environment(ToolStore.self) private var tools

    var body: some View {
        ToolControlBar(icon: "antenna.radiowaves.left.and.right", title: "Advanced Ping",
                       host: $host, history: history, onSubmit: onStartStop) {
            GlassEffectContainer {
                HStack(spacing: 12) {
                    Toggle(isOn: $infinite) {
                        Image(systemName: "infinity")
                            .font(.caption.weight(.bold))
                    }
                    .toggleStyle(.button)
                    .help("Infinite Ping")
                    .accessibilityLabel("Infinite Ping Mode")

                    Toggle(isOn: $beepOnLoss) {
                        Image(systemName: beepOnLoss ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .help("Audio Feedback on Loss")
                    .accessibilityLabel("Audio feedback on packet loss")

                    if !infinite {
                        TextField("Count", text: $countText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .help("Packet Count")
                            .accessibilityLabel("Packet Count")
                    }

                    TextField("Interval", text: $intervalText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .help("Wait Interval (s)")
                        .accessibilityLabel("Ping Interval")

                    TextField("Size", text: $packetSizeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .help("Payload Size (Bytes)")
                        .accessibilityLabel("Payload Size")
                }

                if !vm.results.isEmpty {
                    ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV)
                }

                Button(action: onStartStop) {
                    Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 70)
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
    }
}
