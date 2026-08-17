import SwiftUI

struct ReportMenuButton: View {
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    /// Optional — folds a "Copy Summary" action into this same menu instead
    /// of needing a separate button next to it. Omit for tools that don't
    /// have a clipboard summary to offer.
    var onCopySummary: (() -> Void)? = nil

    var body: some View {
        Menu {
            Button("Export PDF", action: onExportPDF)
            Button("Export CSV", action: onExportCSV)
            if let onCopySummary {
                Divider()
                Button("Copy Summary", action: onCopySummary)
            }
        } label: {
            Label("Report", systemImage: "doc.text")
        }
        .menuStyle(.borderlessButton)
    }
}
