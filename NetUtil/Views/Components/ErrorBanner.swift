import SwiftUI
import AppKit

/// Shared error banner shown in a tool's content area when a run fails.
/// Neutral material surface with a red warning glyph and the message; a
/// built-in copy action for bug reports, plus optional retry and dismiss.
/// Consistent corner radius and typography across all tools.
struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Metrics.spacingMD) {
            HStack(spacing: Metrics.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: \(message)")

            Spacer(minLength: Metrics.spacingSM)

            if let onRetry {
                bannerButton("arrow.clockwise", label: "Retry", action: onRetry)
            }
            bannerButton("doc.on.doc", label: "Copy error message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
            if let onDismiss {
                bannerButton("xmark", label: "Dismiss", action: onDismiss)
            }
        }
        .padding(Metrics.spacingMD)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM)
                .stroke(Color.red.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func bannerButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}
