import SwiftUI

/// Shared section header used throughout tool content areas: an accent
/// icon followed by a bold caption2 title, exposed as a header trait.
struct SectionHeader: View {
    let title: String
    let icon: String
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    headerContent
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .help("Jump to \(title)")
            } else {
                headerContent
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var headerContent: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isHovered ? .accentColor : .accentColor)
                .font(.caption.weight(.bold))
                .symbolEffect(.bounce, value: isHovered)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(isHovered ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}