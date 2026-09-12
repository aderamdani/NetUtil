import SwiftUI

/// Leads with a plain-language reassurance, then lets curious users expand
/// the full remote/local breakdown instead of showing a wall of hosts.
struct PrivacyPane: View {
    @Environment(ToolStore.self) private var tools
    @AppStorage("geoEnabled") private var geoEnabled = true
    @State private var history = HostHistory.shared

    private var remoteRows: [PrivacyRow] {
        PrivacyRow.remoteRows(for: tools.catalog.availableTools)
    }

    private var localTools: [Tool] {
        PrivacyRow.localOnlyTools(from: tools.catalog.availableTools)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Metrics.spacingMD) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Everything stays on this Mac")
                            .font(.callout.weight(.medium))
                        Text("No telemetry, no analytics, no account. NetUtil only reaches the network for the diagnostic you are running.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Metrics.spacingXS)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No telemetry collected")
            } header: {
                Text("Privacy at a Glance")
            }

            Section {
                Toggle("Look up hop locations in Traceroute", isOn: $geoEnabled)
                    .accessibilityLabel("Enable Geolocation Lookup")

                LabeledContent("Saved hosts") {
                    HStack(spacing: Metrics.spacingSM) {
                        Text("\(history.hosts.count) of 20")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button("Clear", role: .destructive) { history.clear() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(history.hosts.isEmpty)
                            .accessibilityLabel("Clear Host History")
                    }
                }
            } header: {
                Text("Your Data")
            } footer: {
                Text("Location lookup sends hop addresses to ipinfo.io. Saved hosts stay on this device and are never transmitted.")
            }

            Section {
                DisclosureGroup("See what NetUtil connects to") {
                    connectionDetails
                }
            } footer: {
                Text("Only tools currently enabled in the Tools tab are listed. Update checks are manual and contact api.github.com.")
            }
        }
        .formStyle(.grouped)
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                Text("Remote connections")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                if remoteRows.isEmpty {
                    Text("No enabled tool contacts remote hosts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(remoteRows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingMD) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.tool.displayName)
                                    .font(.callout.weight(.medium))
                                Text(row.usage.purpose)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Text(row.usage.host)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                Text("Local-only tools")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(localTools) { tool in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.displayName)
                            .font(.callout.weight(.medium))
                        Text(localNote(for: tool))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text("Sandbox entitlement")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("com.apple.security.network.client")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, Metrics.spacingXS)
    }

    private func localNote(for tool: Tool) -> String {
        tool.networkUsage.first { $0.scope == .localOnly }?.purpose
            ?? "No network traffic — computed locally on this Mac."
    }
}
