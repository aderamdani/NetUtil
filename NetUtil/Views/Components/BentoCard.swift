import SwiftUI

struct BentoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let content: Content
    let helpText: String?
    let quickActions: [QuickAction]?

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void,
        helpText: String? = nil,
        quickActions: [QuickAction]? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.helpText = helpText
        self.quickActions = quickActions
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM)
                            .fill(color.opacity(isHovered ? 0.15 : 0.1))
                            .frame(width: 24, height: 24)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                        Image(systemName: icon)
                            .font(.caption.weight(.bold))
                            .foregroundColor(color)
                            .symbolEffect(.bounce, value: isHovered)
                    }
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG)
                            .stroke(
                                isHovered ? color.opacity(0.3) : Color(.separatorColor).opacity(0.1),
                                lineWidth: isHovered ? 1.5 : 0.5
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.01 : 1.0))
            .shadow(
                color: isHovered ? color.opacity(0.15) : .clear,
                radius: isHovered ? 12 : 0,
                x: 0, y: isHovered ? 4 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) Diagnostic Card")
            .accessibilityHint(helpText ?? "Tap to open \(title)")
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
        .help(helpText ?? "Open \(title) tool")
        .contextMenu {
            if let quickActions {
                ForEach(quickActions) { action in
                    Button(action.label, systemImage: action.symbol, action: action.handler)
                }
            }
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let label: String
    let symbol: String
    let handler: () -> Void
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}