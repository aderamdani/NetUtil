import SwiftUI

/// Shared empty/loading placeholders shown in a tool's content area before
/// a result exists or while one is being fetched.
enum ToolStateView {
    static func empty(title: String, subtitle: String, minHeight: CGFloat = 400) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
    }

    static func loading(message: String, minHeight: CGFloat = 400) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}
