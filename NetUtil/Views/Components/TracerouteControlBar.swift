import SwiftUI

struct TracerouteControlBar: ToolbarContent {
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
    var onCopySummary: (() -> Void)? = nil
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
    var body: some ToolbarContent {
        ToolToolbar(icon: "point.3.connected.trianglepath.dotted", title: "Traceroute",
                       host: $host, history: history, onSubmit: onStart) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    HStack(spacing: Metrics.spacingXS) {
                        Text("Hops").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                        TextField("", value: $maxHops, format: .number).textFieldStyle(.roundedBorder).frame(width: 48)
                            .accessibilityLabel("Maximum hops")
                    }
                    HStack(spacing: Metrics.spacingXS) {
                        Text("Interval").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                        TextField("", value: $traceInterval, format: .number).textFieldStyle(.roundedBorder).frame(width: 48)
                            .accessibilityLabel("Re-trace interval in seconds")
                    }
                }

                if hasHops {
                    ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV, onCopySummary: onCopySummary)
                }

                Button(action: onStart) {
                    Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.glassProminent)
                .tint(isRunning ? .red : .accentColor)
                .accessibilityLabel(isRunning ? "Stop Traceroute" : "Start Traceroute")

                if !host.isEmpty, let onToggle = onToggleFavorite {
                    Button(action: onToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }

                Button(action: onShowGuide) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
        }
    }
}
