import SwiftUI

/// Shared status strip shown under a tool's control bar — icon, message,
/// and an optional trailing accessory (e.g. a progress bar).
struct MoodBar<Accessory: View>: View {
    let icon: String
    let color: Color
    let message: String
    @ViewBuilder var accessory: () -> Accessory

    init(icon: String, color: Color, message: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.icon = icon
        self.color = color
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(message).font(.callout).foregroundColor(.secondary)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
}
