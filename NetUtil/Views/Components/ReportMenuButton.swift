import SwiftUI

struct ReportMenuButton: View {
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    
    var body: some View {
        Menu {
            Button("Export PDF", action: onExportPDF)
            Button("Export CSV", action: onExportCSV)
        } label: {
            Label("Report", systemImage: "doc.text")
        }
        .menuStyle(.borderlessButton)
    }
}
