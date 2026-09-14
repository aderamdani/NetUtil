import SwiftUI

/// Multi-Ping control bar: host input plus primary actions only (report,
/// add, favorite, help). Secondary controls (sort, import, alerts) live in
/// the slots options row near the table header — same split as
/// PingControlBar/TracerouteControlBar.
struct MultiPingControlBar: View {
    @Binding var host: String
    let history: HostHistory
    let vm: MultiPingViewModel
    let onAddHost: () -> Void
    let onShowGuide: () -> Void
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    @Environment(ToolStore.self) private var tools

    var body: some View {
        ToolControlBar(icon: "dot.radiowaves.left.and.right", title: "Multi-Ping",
                       host: $host, textFieldWidth: 180, history: history, onSubmit: onAddHost) {
            if !vm.slots.isEmpty {
                ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV)
            }

            ThresholdPresetMenu()

            Button(action: onAddHost) {
                Label("Add Host", systemImage: "plus")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Add Host to Monitor")

            let trimmed = host.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let isFav = tools.favorites.isFavorite(trimmed)
                Button { tools.favorites.toggle(host: trimmed) } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundColor(isFav ? .orange : .secondary)
                }
                .buttonStyle(.borderless)
                .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(isFav ? "Remove from Favorites" : "Add to Favorites")
            }

            Button(action: onShowGuide) {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Show Help Guide")
        }
    }
}
