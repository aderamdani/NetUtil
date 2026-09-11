import SwiftUI

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
                Toggle("Look up IP locations in Traceroute", isOn: $geoEnabled)
                    .help("Sends each hop's IP address to ipinfo.io to retrieve country, city, ISP, and GPS coordinates for the map view. Disable for fully offline operation or strict privacy environments.")
                    .accessibilityLabel("Enable Geolocation Lookup")
            } header: {
                Text("Geolocation")
            } footer: {
                Text("Requests are sent to ipinfo.io. No account or API key is required.")
            }

            Section {
                LabeledContent("Saved Hosts") {
                    HStack(spacing: 8) {
                        Text("\(history.hosts.count) / 20")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button("Clear", role: .destructive) { history.clear() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(history.hosts.isEmpty)
                            .accessibilityLabel("Clear Host History")
                    }
                }
                .help("Hostnames and IP addresses entered in any tool are saved locally for quick recall via the history dropdown. Maximum 20 entries stored in UserDefaults.")
            } header: {
                Text("Host History")
            } footer: {
                Text("History is stored on this device only and is never transmitted.")
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No telemetry collected")
                            .font(.callout.weight(.medium))
                        Text("NetUtil does not collect analytics, crash reports, or usage data. All diagnostics remain on this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Privacy Shield: No Telemetry Collected")
            } header: {
                Text("Data Collection")
            }

            Section {
                Text("NetUtil contacts the network only to perform the diagnostics you run. The only sandbox entitlement is outgoing connections — no analytics, no telemetry, no crash reporting.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Entitlement") {
                    Text("com.apple.security.network.client")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                LabeledContent("Update checks") {
                    Text("Manual only")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Network Transparency")
            } footer: {
                Text("Choosing Check for Updates contacts api.github.com for the latest release. It never checks automatically.")
            }

            PrivacyRemoteSection(rows: remoteRows)

            PrivacyLocalSection(tools: localTools)
        }
        .formStyle(.grouped)
    }
}

/// Remote destinations of currently enabled tools, derived from the
/// audited `Tool.networkUsage` model. Extracted to keep `PrivacyPane`
/// small. Hostnames use monospaced type per the data-typography rule.
private struct PrivacyRemoteSection: View {
    let rows: [PrivacyRow]

    var body: some View {
        Section {
            if rows.isEmpty {
                Text("No enabled tool contacts remote hosts.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
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
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.tool.displayName): \(row.usage.purpose). Host \(row.usage.host)")
                }
            }
        } header: {
            Text("Remote Connections")
        } footer: {
            Text("Only tools currently enabled in Settings > Tools are listed.")
        }
    }
}

/// Tools with no remote contact. Extracted to keep `PrivacyPane` small.
private struct PrivacyLocalSection: View {
    let tools: [Tool]

    var body: some View {
        Section {
            ForEach(tools) { tool in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.callout.weight(.medium))
                    Text(localNote(for: tool))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Local-Only Tools")
        } footer: {
            Text("These tools never contact remote servers. Local-network traffic stays inside your network.")
        }
    }

    private func localNote(for tool: Tool) -> String {
        tool.networkUsage.first { $0.scope == .localOnly }?.purpose
            ?? "No network traffic — computed locally on this Mac."
    }
}
