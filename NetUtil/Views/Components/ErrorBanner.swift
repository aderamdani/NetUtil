import SwiftUI

/// Shared error banner shown in a tool's content area when a run fails:
/// red warning icon, message in subheadline, tinted background with a thin
/// red border. Consistent corner radius and typography across all tools.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Metrics.spacingMD) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(Metrics.spacingMD)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        .accessibilityLabel("Error: \(message)")
    }
}