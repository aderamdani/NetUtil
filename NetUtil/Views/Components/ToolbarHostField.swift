import SwiftUI

/// Host input for a tool's toolbar. Uses explicit inner padding so the text
/// never sits flush against the control's rounded edge (where the toolbar
/// bezel can make it look clipped).
struct ToolbarHostField: View {
    @Binding var host: String
    var placeholder: String = "Hostname or IP address"
    var width: CGFloat = 220
    var accessibilityLabel: String = "Host Input"
    var onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $host)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(.horizontal, Metrics.spacingSM)
            .padding(.vertical, Metrics.spacingXS)
            .frame(width: width)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM)
                    .stroke(Color(.separatorColor).opacity(0.15), lineWidth: 0.5)
            )
            .onSubmit(onSubmit)
            .accessibilityLabel(accessibilityLabel)
    }
}
