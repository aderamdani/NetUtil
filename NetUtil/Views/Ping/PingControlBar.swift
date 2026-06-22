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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Advanced Ping")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Advanced Ping Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                TextField("Hostname or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(onStartStop)
                    .accessibilityLabel("Host Input")
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { host = h; onStartStop() }
                                }
                                Divider()
                                Button("Clear History", role: .destructive) { history.clear() }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28)
                            .padding(.trailing, 4)
                            .accessibilityLabel("Host History")
                        }
                    }

                Spacer()

                GlassEffectContainer {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
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
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()
        }
    }
}
