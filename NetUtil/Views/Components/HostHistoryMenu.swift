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
                ZStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Recent hosts")
            .accessibilityLabel("Host History")
        }
    }
}
