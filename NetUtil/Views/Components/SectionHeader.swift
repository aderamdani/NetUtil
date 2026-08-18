import SwiftUI

/// Shared section header used throughout tool content areas: an accent
/// icon followed by a bold caption2 title, exposed as a header trait.
struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(.caption2, design: .default).weight(.bold))
            Text(title)
                .font(.system(.caption2, design: .default).weight(.bold))
                .foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }
}