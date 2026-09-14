import SwiftUI

/// One toolbar button that reveals a tool's secondary controls in a popover,
/// keeping the toolbar itself to essentials (host, run, report, help).
struct ToolbarOptionsButton<Content: View>: View {
    var label: String = "Options"
    @State private var show = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button { show.toggle() } label: {
            Image(systemName: "slider.horizontal.3")
                .imageScale(.medium)
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
        .popover(isPresented: $show, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: Metrics.spacingMD) {
                content()
            }
            .padding(Metrics.spacingLG)
            .frame(width: 300)
        }
    }
}
