import SwiftUI
import AppKit

struct ImportHostsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var hostText: String = ""
    var onImport: ([String]) -> Void
    
    var detectedHosts: [String] {
        hostText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .unique()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Import Multiple Hosts")
                .font(.headline)
                .padding(.top, Metrics.spacingLG)
                .padding(.bottom, Metrics.spacingSM)
            
            TextEditor(text: $hostText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM).stroke(Color(.separatorColor), lineWidth: 0.5))
                .padding(.horizontal, Metrics.spacingLG)
                .padding(.vertical, Metrics.spacingSM)
                .accessibilityLabel("Hosts to import, one per line")
            
            HStack {
                Button(action: pasteFromClipboard) {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("\(detectedHosts.count) hosts detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, Metrics.spacingLG)
            .padding(.bottom, Metrics.spacingLG)
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Import") {
                    onImport(detectedHosts)
                    dismiss()
                }
                    .buttonStyle(.glassProminent)
                .disabled(detectedHosts.isEmpty)
            }
            .padding(Metrics.spacingLG)
            .background(.regularMaterial)
        }
        .frame(width: 400, height: 400)
    }
    
    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            hostText = string
        }
    }
}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
