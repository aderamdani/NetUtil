import SwiftUI

struct TracerouteControlBar: View {
    @Binding var host: String
    var isRunning: Bool
    @Binding var maxHops: Int
    @Binding var traceInterval: Double
    let round: Int
    let onStart: () -> Void
    let onShowGuide: () -> Void
    let history: HostHistory
    let hasHops: Bool
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").foregroundColor(.accentColor).imageScale(.large)
                    Text("Traceroute").font(.headline)
                }
                .accessibilityLabel("Traceroute Tool")
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Hostname or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(onStart)
                    .accessibilityLabel("Host Input")
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { host = h; onStart() }
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
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Hops").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                            TextField("", value: $maxHops, format: .number).textFieldStyle(.roundedBorder).frame(width: 45)
                        }
                        HStack(spacing: 4) {
                            Text("Interval").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                            TextField("", value: $traceInterval, format: .number).textFieldStyle(.roundedBorder).frame(width: 45)
                        }
                    }

                    if hasHops {
                        ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV)
                    }

                    Button(action: onStart) {
                        Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRunning ? .red : .accentColor)
                    
                    Button(action: onShowGuide) {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            Divider()
        }
    }
}
