import SwiftUI

struct PrivacyPane: View {
    @AppStorage("geoEnabled") private var geoEnabled = true
    @State private var history = HostHistory.shared

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
        }
        .formStyle(.grouped)
    }
}
