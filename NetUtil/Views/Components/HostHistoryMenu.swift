import SwiftUI

/// Recent-hosts dropdown shown as a trailing overlay on a tool's host field.
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
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .padding(.trailing, 4)
            .accessibilityLabel("Host History")
        }
    }
}
