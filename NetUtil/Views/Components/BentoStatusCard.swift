import SwiftUI

struct BentoStatusCard: View {
    let title: String
    let icon: String
    let color: Color
    let status: String
    let action: () -> Void
    let helpText: String?
    let statusColor: Color?
    let detail: String?

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        title: String,
        icon: String,
        color: Color,
        status: String,
        action: @escaping () -> Void,
        helpText: String? = nil,
        statusColor: Color? = nil,
        detail: String? = nil
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.status = status
        self.action = action
        self.helpText = helpText
        self.statusColor = statusColor
        self.detail = detail
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(status)
                            .font(.subheadline.bold())
                            .foregroundColor(statusColor ?? .primary)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                        
                        if let detail {
                            Text(detail)
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isHovered, let help = helpText {
                        Text(help)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
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
            .animation(.easeInOut(duration: 0.2), value: helpText)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) Status Card")
            .accessibilityValue(status)
            .accessibilityHint(helpText ?? "Tap to open \(title)")
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
        .help(helpText ?? "Open \(title) tool")
    }
}

// Note: pressEvents(_:onRelease:) is declared once in BentoCard.swift.