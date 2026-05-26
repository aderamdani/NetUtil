import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                VStack(spacing: 4) {
                    Text("NetUtil")
                        .font(.system(size: 22, weight: .bold))
                    Text("Version \(version) (\(build))")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 14) {
                Text("A professional network diagnostics toolkit for macOS. Monitor, analyze, and debug network connectivity with ease.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Divider()

                // Tool list
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(toolList, id: \.0) { icon, name in
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .frame(width: 14)
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Divider()

                // Links and credits
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Developed by **Ade Ramdani**")
                            .font(.caption)
                        Text("Built with SwiftUI · macOS 15+ · Zero dependencies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Button("GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/aderamdani/NetUtil")!)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        Button("Acknowledgements") {
                            showAck()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 360)
        .fixedSize()
    }

    private let toolList: [(String, String)] = [
        ("antenna.radiowaves.left.and.right", "Ping"),
        ("point.3.connected.trianglepath.dotted", "Traceroute"),
        ("dot.radiowaves.left.and.right", "Multi-Ping"),
        ("checklist", "Port Scanner"),
        ("stopwatch", "HTTP Latency"),
        ("globe", "DNS Lookup"),
        ("magnifyingglass.circle", "WHOIS"),
        ("lock.shield", "SSL/TLS Inspector"),
        ("network", "Network Interfaces"),
        ("wifi", "Wi-Fi Inspector"),
        ("arrow.triangle.branch", "Route Table"),
        ("chart.bar.xaxis", "Bandwidth Monitor"),
    ]

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = """
        System tools & frameworks used by NetUtil:

        • /sbin/ping — ICMP echo requests
        • /usr/sbin/traceroute — Hop-by-hop path discovery
        • /usr/bin/whois — WHOIS queries
        • /usr/bin/dig — DNS record lookups
        • /usr/sbin/netstat — Routing table

        Apple Frameworks:
        • Network.framework — TCP port scanning
        • CoreWLAN.framework — Wi-Fi inspection
        • CryptoKit — SHA-256 certificate fingerprinting

        Geolocation data provided by ipinfo.io
        (opt-in, can be disabled in Settings)
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
