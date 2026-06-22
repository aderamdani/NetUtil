import SwiftUI

struct BentoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let content: Content

    @State private var isHovered = false

    init(title: String, icon: String, color: Color, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.icon    = icon
        self.color   = color
        self.action  = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.1)).frame(width: 24, height: 24)
                        Image(systemName: icon).font(.system(.caption, design: .default).weight(.bold)).foregroundColor(color)
                    }
                    Text(title).font(.system(.caption, design: .default).weight(.bold)).foregroundColor(.secondary)
                }
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassEffect(in: .rect(cornerRadius: 12))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) Diagnostic Card")
            .accessibilityHint("Tap to open \(title)")
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
