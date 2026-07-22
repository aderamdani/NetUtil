import SwiftUI

/// Shared control-bar scaffold: icon+title header, host/target input with a
/// recent-history menu, then tool-specific trailing controls (start/stop,
/// report menu, favorite, help — supplied by the caller exactly as before,
/// since their layout/order/styling genuinely differs per tool).
struct ToolControlBar<Trailing: View>: View {
    let icon: String
    let title: String
    @Binding var host: String
    var placeholder: String = "Hostname or IP address"
    var textFieldWidth: CGFloat = 250
    var textFieldAccessibilityLabel: String = "Host Input"
    var accessibilityToolName: String? = nil
    let history: HostHistory
    let onSubmit: () -> Void
    var onSelectHistory: ((String) -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text(title)
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityToolName ?? "\(title) Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                TextField(placeholder, text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: textFieldWidth)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(textFieldAccessibilityLabel)
                    .overlay(alignment: .trailing) {
                        HostHistoryMenu(history: history) { h in
                            if let onSelectHistory {
                                onSelectHistory(h)
                            } else {
                                host = h
                                onSubmit()
                            }
                        }
                    }

                Spacer()

                trailing()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()
        }
    }
}
