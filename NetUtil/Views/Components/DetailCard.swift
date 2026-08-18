import SwiftUI

/// Shared key/value detail tile used in grid layouts (subnet parameters,
/// Wi-Fi infrastructure, geolocation): accent icon, bold caption2 label,
/// monospaced value on a regularMaterial card.
struct DetailCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}