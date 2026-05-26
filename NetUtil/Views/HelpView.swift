import SwiftUI

struct HelpView: View {
    @State private var search = ""
    @State private var expanded: Set<String> = ["Ping"]

    var body: some View {
        HSplitView {
            sidebar
            detail
        }
        .frame(minWidth: 680, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField("Search…", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSections) { section in
                        sectionRow(section)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)
        .background(Color(.windowBackgroundColor))
    }

    private var detail: some View {
        ScrollView {
            if let section = selectedSection {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.title)
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.title2.bold())
                            Text(section.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(section.topics) { topic in
                        topicBlock(topic)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a topic from the sidebar")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.textBackgroundColor))
    }

    @State private var selectedTitle: String? = "Ping"

    private var selectedSection: HelpSection? {
        filteredSections.first { $0.title == selectedTitle }
            ?? filteredSections.first
    }

    private var filteredSections: [HelpSection] {
        guard !search.isEmpty else { return allSections }
        let q = search.lowercased()
        return allSections.compactMap { section in
            let matchTitle = section.title.lowercased().contains(q)
            let matchTopics = section.topics.filter {
                $0.heading.lowercased().contains(q) ||
                $0.body.lowercased().contains(q)
            }
            if matchTitle { return section }
            if !matchTopics.isEmpty {
                return HelpSection(title: section.title,
                                   icon: section.icon,
                                   subtitle: section.subtitle,
                                   topics: matchTopics)
            }
            return nil
        }
    }

    @ViewBuilder
    private func sectionRow(_ section: HelpSection) -> some View {
        Button {
            selectedTitle = section.title
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.callout)
                    .foregroundColor(selectedTitle == section.title ? .white : .accentColor)
                    .frame(width: 18)
                Text(section.title)
                    .font(.callout)
                    .foregroundColor(selectedTitle == section.title ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedTitle == section.title ? Color.accentColor : Color.clear)
            .cornerRadius(6)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func topicBlock(_ topic: HelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(topic.heading)
                .font(.headline)
            Text(topic.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let tips = topic.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.accentColor)
                                .font(.caption.bold())
                            Text(tip)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Data model

private struct HelpTopic: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
    var tips: [String]? = nil
}

private struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let subtitle: String
    let topics: [HelpTopic]
}

private let allSections: [HelpSection] = [
    HelpSection(
        title: "Ping",
        icon: "antenna.radiowaves.left.and.right",
        subtitle: "ICMP echo request latency",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Sends ICMP echo requests to a host using the system /sbin/ping command and measures round-trip time (RTT). Results update live as pings arrive.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Enter a hostname or IP address and press Return or click Start. Adjust count and interval in Settings → General.",
                      tips: [
                        "Press ⌘R or click Stop/Start to restart a run.",
                        "Export results as CSV via the toolbar.",
                        "Colors: green < warn threshold, orange < crit, red ≥ crit (configure in Settings → Thresholds)."
                      ]),
            HelpTopic(heading: "Stats explained",
                      body: "Min/Avg/Max show the best, mean, and worst RTT for the current run. Loss % counts unanswered pings as a percentage of sent packets.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Traceroute",
        icon: "point.3.connected.trianglepath.dotted",
        subtitle: "Hop-by-hop path discovery",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses /usr/sbin/traceroute to discover each network hop between your machine and the destination. Three probes are sent per hop. RTT is measured for each probe.",
                      tips: nil),
            HelpTopic(heading: "Geo column",
                      body: "When Geolocation is enabled (Settings → Privacy), each public IP is resolved to country + city via ipinfo.io. Private IPs (RFC 1918) are skipped.",
                      tips: [
                        "Flag emoji + city name appears in the Location column.",
                        "Disable geolocation if you prefer offline-only operation."
                      ]),
            HelpTopic(heading: "Reading results",
                      body: "A * for an RTT means that probe timed out. Some hops are firewalled and will show all * — this is normal and doesn't mean the path is broken.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Multi-Ping",
        icon: "dot.radiowaves.left.and.right",
        subtitle: "Ping multiple hosts simultaneously",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Runs concurrent ping sessions to multiple hosts. Each host gets a live sparkline chart, loss %, and last/average RTT.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Type a hostname and press Add (or Return). Remove individual hosts with the × button. History clock shows recently used hosts.",
                      tips: [
                        "Useful for comparing latency across multiple endpoints at once.",
                        "Sparkline shows the last 60 RTT samples."
                      ])
        ]
    ),
    HelpSection(
        title: "Port Scanner",
        icon: "checklist",
        subtitle: "TCP port reachability",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Attempts TCP connections to a range of ports on a target host. Reports each port as Open, Closed, or Filtered based on connection outcome.",
                      tips: nil),
            HelpTopic(heading: "Port presets",
                      body: "Common: the most frequently used service ports. Top 1000: the 1000 ports most often found open in network surveys. Full: all 65535 ports (slow). Custom: enter your own range like '80, 443, 8080-8090'.",
                      tips: nil),
            HelpTopic(heading: "Performance",
                      body: "Concurrency controls how many simultaneous TCP probes run. Higher values are faster but may trigger firewall rate limiting. Default 50 is a safe balance.",
                      tips: [
                        "Timeout per port configurable in Settings → Tools.",
                        "Export Open Ports only for a clean report."
                      ])
        ]
    ),
    HelpSection(
        title: "HTTP Latency",
        icon: "stopwatch",
        subtitle: "HTTP/HTTPS request phase timing",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Makes an HTTP/HTTPS request and breaks down total latency into phases: DNS resolution, TCP connect, TLS handshake, request send, time to first byte (TTFB), and download.",
                      tips: nil),
            HelpTopic(heading: "Reading the waterfall",
                      body: "Each bar shows when a phase started (relative to request start) and how long it lasted. Bars are scaled to the longest phase. Hover over a bar to see exact milliseconds.",
                      tips: [
                        "TTFB is usually the most important metric for server responsiveness.",
                        "A long DNS bar suggests slow DNS resolution — try a different DNS resolver.",
                        "TLS only appears for HTTPS requests."
                      ]),
            HelpTopic(heading: "History",
                      body: "The last 20 requests are stored in the history table. Click any row to restore that URL. Results are not persisted between app launches.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "DNS Lookup",
        icon: "globe",
        subtitle: "Resolve hostnames and query DNS records",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses /usr/bin/dig to query DNS records for a hostname. Supports A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, and ALL record types.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Enter a hostname or IP (for PTR lookups) and select the record type. The raw dig output is shown with syntax highlighting for record types.",
                      tips: [
                        "For reverse DNS lookups, enter an IP address and select PTR.",
                        "Copy the full output with the copy button."
                      ])
        ]
    ),
    HelpSection(
        title: "WHOIS",
        icon: "magnifyingglass.circle",
        subtitle: "Domain and IP registration info",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Queries the WHOIS database for a domain name or IP address using /usr/bin/whois. Returns registrar, registrant, nameservers, and important dates.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Enter a domain (example.com) or IP address and press Lookup. Results are color-coded: keys in one color, values in another, comments dimmed.",
                      tips: [
                        "Export results as a plain text file.",
                        "Some TLDs have restricted WHOIS data due to GDPR."
                      ])
        ]
    ),
    HelpSection(
        title: "SSL/TLS",
        icon: "lock.shield",
        subtitle: "Certificate chain inspection",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Connects to a host on a given port, performs a TLS handshake, and inspects the full certificate chain. Shows subject, issuer, validity dates, SANs, key type, and SHA-256 fingerprint.",
                      tips: nil),
            HelpTopic(heading: "Expiry banner",
                      body: "A color-coded banner shows days remaining until the leaf certificate expires. Green = plenty of time, yellow = expiring soon (< 30 days), red = expired.",
                      tips: [
                        "Default port is 443. Use 8443 or custom ports for non-standard HTTPS.",
                        "Click through the chain picker to inspect intermediate and root certificates."
                      ]),
            HelpTopic(heading: "SANs",
                      body: "Subject Alternative Names list all hostnames and IPs the certificate is valid for. Useful for checking wildcard coverage.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Network Interfaces",
        icon: "network",
        subtitle: "Local network interface details",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Lists all network interfaces on the machine with their IPv4/IPv6 addresses, MAC address, MTU, and up/down status. Refreshes automatically every 3 seconds.",
                      tips: nil),
            HelpTopic(heading: "Show all interfaces",
                      body: "By default, only active (up) interfaces are shown. Toggle 'Show all' to see loopback, tunnel, and inactive interfaces.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Wi-Fi Inspector",
        icon: "wifi",
        subtitle: "Connected Wi-Fi network details",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses CoreWLAN to display details about the currently connected Wi-Fi network: SSID, BSSID, channel, security type, signal strength (RSSI), signal-to-noise ratio (SNR), and transmit rate.",
                      tips: nil),
            HelpTopic(heading: "Signal quality",
                      body: "RSSI is in dBm (negative values, closer to 0 is stronger). SNR is the difference between signal and noise floor — higher is better. A SNR above 25 dB is generally good.",
                      tips: [
                        "Refreshes every 4 seconds.",
                        "If no Wi-Fi is connected, the view shows a prompt to connect first."
                      ])
        ]
    ),
    HelpSection(
        title: "Route Table",
        icon: "arrow.triangle.branch",
        subtitle: "System IP routing table",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Runs netstat -rn and parses the system routing table for both IPv4 and IPv6. Shows destination, gateway, flags, and interface for each route.",
                      tips: nil),
            HelpTopic(heading: "Flags",
                      body: "Common flags: U = Up, G = Gateway, H = Host route, S = Static, C = Cloning. The default route (0.0.0.0/0 or ::/0) is highlighted.",
                      tips: [
                        "Switch between IPv4 and IPv6 using the segmented picker.",
                        "Filter by destination or interface using the search field."
                      ])
        ]
    ),
    HelpSection(
        title: "Bandwidth Monitor",
        icon: "chart.bar.xaxis",
        subtitle: "Per-interface traffic rate",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Polls getifaddrs() every second and calculates the per-second receive (RX) and transmit (TX) byte rate for each active network interface.",
                      tips: nil),
            HelpTopic(heading: "Chart",
                      body: "Each interface card shows a 60-second rolling chart with two series: download (blue) and upload (orange). The Y axis auto-scales to the peak rate in the window.",
                      tips: [
                        "Inactive interfaces (zero traffic for the window) are shown but grayed out.",
                        "Rates are shown in bytes/s, KB/s, or MB/s depending on magnitude."
                      ])
        ]
    ),
    HelpSection(
        title: "Settings",
        icon: "gearshape",
        subtitle: "Configure NetUtil behavior",
        topics: [
            HelpTopic(heading: "General",
                      body: "Set default ping count and interval. Set traceroute max hops and probe interval. Set max raw output lines retained in memory.",
                      tips: nil),
            HelpTopic(heading: "Thresholds",
                      body: "RTT warn and critical thresholds control the green/orange/red coloring used across Ping, Traceroute, Multi-Ping, and the menu bar indicator. Loss alert threshold triggers a warning in the Ping stats bar.",
                      tips: [
                        "Default: warn at 20 ms, critical at 100 ms.",
                        "Changes take effect immediately — no restart needed."
                      ]),
            HelpTopic(heading: "Tools",
                      body: "Configure port scanner timeout and concurrency, HTTP request timeout, SSL inspector timeout, and bandwidth poll interval.",
                      tips: nil),
            HelpTopic(heading: "Privacy",
                      body: "Geolocation uses ipinfo.io to resolve public IPs in Traceroute. Disable this if you want fully offline operation. Host history can be cleared here.",
                      tips: nil)
        ]
    ),
]
