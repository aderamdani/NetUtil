import SwiftUI

/// Toolbar rendition of `ToolControlBar`: host input plus recent-history menu
/// in the leading group, tool-specific controls trailing. `icon`/`title` are
/// accepted for API parity but not rendered — the window title already names
/// the tool via `navigationTitle`.
struct ToolToolbar<Trailing: View>: ToolbarContent {
    let icon: String
    let title: String
    @Binding var host: String
    var placeholder: String = "Hostname or IP address"
    var textFieldWidth: CGFloat = 220
    var textFieldAccessibilityLabel: String = "Host Input"
    var accessibilityToolName: String? = nil
    let history: HostHistory
    let onSubmit: () -> Void
    var onSelectHistory: ((String) -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            TextField(placeholder, text: $host)
                .textFieldStyle(.roundedBorder)
                .frame(width: textFieldWidth)
                .onSubmit(onSubmit)
                .accessibilityLabel(textFieldAccessibilityLabel)

            HostHistoryMenu(history: history) { h in
                if let onSelectHistory {
                    onSelectHistory(h)
                } else {
                    host = h
                    onSubmit()
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            trailing()
        }
    }
}
