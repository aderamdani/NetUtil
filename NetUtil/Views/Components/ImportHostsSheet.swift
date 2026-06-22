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
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            TextEditor(text: $hostText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor), lineWidth: 0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
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
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
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
            .padding(16)
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
