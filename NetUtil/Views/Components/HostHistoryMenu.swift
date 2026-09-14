import SwiftUI

/// Recent-hosts dropdown shown next to a tool's host field.
struct HostHistoryMenu: View {
    let history: HostHistory
    let onSelect: (String) -> Void

    var body: some View {
        if !history.hosts.isEmpty {
            Menu {
                ForEach(history.hosts, id: \.self) { h in
                    Button(h) { onSelect(h) }
                }
                Divider()
                Button("Clear History", role: .destructive) { history.clear() }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20, alignment: .center)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24, height: 22)
            .contentShape(Rectangle())
            .accessibilityLabel("Host History")
        }
    }
}
