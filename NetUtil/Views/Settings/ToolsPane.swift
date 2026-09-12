import SwiftUI

/// Layer 1 is which tools exist; the numerics that power them are tucked
/// behind a single "Advanced" disclosure because sensible defaults suit
/// almost every network.
struct ToolsPane: View {
    @Environment(ToolStore.self) private var tools
    @AppStorage("portScanTimeout")     private var portScanTimeout = 1.5
    @AppStorage("portScanConcurrency") private var portScanConc    = 50
    @AppStorage("httpTimeout")         private var httpTimeout     = 15.0
    @AppStorage("sslTimeout")          private var sslTimeout      = 10.0
    @AppStorage("bandwidthInterval")   private var bwInterval      = 1.0

    var body: some View {
        Form {
            ToolAvailabilitySection(catalog: tools.catalog)

            Section {
                DisclosureGroup("Advanced") {
                    LabeledContent("Port scan timeout") {
                        CompactSlider(value: $portScanTimeout, range: 0.5...10, step: 0.5, format: "%.1f s")
                    }
                    .accessibilityLabel("Port Scan Timeout")

                    LabeledContent("Port scan threads") {
                        Stepper("\(portScanConc)", value: $portScanConc, in: 1...200)
                            .frame(width: Metrics.settingsColumnWidth)
                    }
                    .accessibilityLabel("Port Scan Concurrency Threads")

                    LabeledContent("HTTP request timeout") {
                        CompactSlider(value: $httpTimeout, range: 5...60, step: 5, format: "%.0f s")
                    }
                    .accessibilityLabel("HTTP Request Timeout")

                    LabeledContent("SSL handshake timeout") {
                        CompactSlider(value: $sslTimeout, range: 5...30, step: 5, format: "%.0f s")
                    }
                    .accessibilityLabel("SSL Handshake Timeout")

                    LabeledContent("Speed refresh interval") {
                        CompactSlider(value: $bwInterval, range: 0.5...5, step: 0.5, format: "%.1f s")
                    }
                    .accessibilityLabel("Bandwidth Refresh Interval")
                }
            } header: {
                Text("Performance & Timeouts")
            } footer: {
                Text("Defaults work well for most networks. Adjust only if a scan is too slow or keeps timing out.")
            }
        }
        .formStyle(.grouped)
    }
}

/// Per-group tool availability toggles. Extracted to keep
/// `ToolsPane.body` small. Disabling a tool also stops its pollers.
private struct ToolAvailabilitySection: View {
    let catalog: ToolCatalog

    var body: some View {
        ForEach(ToolGroup.allCases, id: \.self) { group in
            Section {
                ForEach(group.tools) { tool in
                    Toggle(tool.displayName, isOn: binding(for: tool))
                        .disabled(!tool.canBeDisabled)
                        .help(tool.canBeDisabled
                              ? "Show \(tool.displayName) in the sidebar and menu bar."
                              : "\(tool.displayName) powers app-wide features and is always available.")
                }
            } header: {
                Text(group.title ?? "Core")
            } footer: {
                if group == .core {
                    Text("These power the dashboard, statistics, and history. They stay on.")
                }
            }
        }
    }

    private func binding(for tool: Tool) -> Binding<Bool> {
        Binding(
            get: { catalog.isAvailable(tool) },
            set: { catalog.setAvailable(tool, $0) }
        )
    }
}
