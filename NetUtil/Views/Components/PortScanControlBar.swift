import SwiftUI

struct PortScanControlBar: View {
    @Binding var host: String
    var isRunning: Bool
    @Binding var portRangeType: PortPreset
    @Binding var customPorts: String
    let onStart: () -> Void
    let onShowGuide: () -> Void
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    let hasResults: Bool
    let history: HostHistory
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
    var body: some View {
        ToolControlBar(icon: "checklist", title: "Port Scanner",
                       host: $host, history: history, onSubmit: onStart) {
            HStack(spacing: 12) {
                Picker("", selection: $portRangeType) {
                    ForEach(PortPreset.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .accessibilityLabel("Port Range Type")

                if portRangeType == .custom {
                    TextField("e.g. 80,443,3000-4000", text: $customPorts)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .accessibilityLabel("Custom Port Range")
                }

                if hasResults {
                    ReportMenuButton(onExportPDF: onExportPDF, onExportCSV: onExportCSV)
                }

                Button(action: onStart) {
                    Label(isRunning ? "Stop" : "Scan", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.glassProminent)
                .tint(isRunning ? .red : .accentColor)
                .disabled(!isRunning && host.isEmpty)
                .accessibilityLabel(isRunning ? "Stop Scanning" : "Start Scanning")

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
                .accessibilityLabel("Show Help Guide")
            }
        }
    }
}

