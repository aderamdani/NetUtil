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
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
    var body: some View {
        ToolControlBar(icon: "point.3.connected.trianglepath.dotted", title: "Traceroute",
                       host: $host, history: history, onSubmit: onStart) {
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
                .buttonStyle(.glassProminent)
                .tint(isRunning ? .red : .accentColor)

                if !host.isEmpty, let onToggle = onToggleFavorite {
                    Button(action: onToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }

                Button(action: onShowGuide) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
