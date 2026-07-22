import SwiftUI

/// Shared status strip shown under a tool's control bar — icon, message,
/// and an optional trailing accessory (e.g. a progress bar).
struct MoodBar<Accessory: View>: View {
    let icon: String
    let color: Color
    let message: String
    /// Message stays `.secondary` in the standard bar; Dashboard's health bar
    /// tints it red/orange to escalate degraded states.
    var messageColor: Color = .secondary
    @ViewBuilder var accessory: () -> Accessory

    init(icon: String, color: Color, message: String, messageColor: Color = .secondary,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.icon = icon
        self.color = color
        self.message = message
        self.messageColor = messageColor
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(message).font(.callout).foregroundColor(messageColor)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}
