import SwiftUI

struct HelpView: View {
    @State private var search = ""
    @State private var selectedTitle: String? = "Ping"

    var body: some View {
        HSplitView {
            sidebar
            detail
        }
        .frame(minWidth: 700, minHeight: 540)
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
                      body: "Sends ICMP echo requests to a host using /sbin/ping and measures round-trip time (RTT). Results update live as each ping arrives.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Enter a hostname or IP, then press Return or click Start. Adjust count and interval directly in the toolbar.",
                      tips: [
                        "Press Return in the host field to start immediately.",
                        "The action button turns red (Cancel) while a run is in progress.",
                        "RTT colors: green below warn threshold, orange below critical, red at or above critical. Configure thresholds in Settings."
                      ]),
            HelpTopic(heading: "Stats explained",
                      body: "Min / Avg / Max show the best, mean, and worst RTT for the run. Jitter is the standard deviation of RTT — a measure of consistency. Loss% counts unanswered pings as a fraction of packets sent.",
                      tips: [
                        "Jitter > 5 ms on a wired connection usually signals switch or ISP issues.",
                        "Loss% turns red when it exceeds the alert threshold (default 5%)."
                      ])
        ]
    ),
    HelpSection(
        title: "Traceroute",
        icon: "point.3.connected.trianglepath.dotted",
        subtitle: "Hop-by-hop path discovery",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses /usr/sbin/traceroute to discover each network hop between your machine and the destination. Three probes are sent per hop; RTT is measured for each.",
                      tips: nil),
            HelpTopic(heading: "Path summary",
                      body: "A strip below the toolbar shows a quick summary: total responding hops, the last responding host, its RTT (color-coded), and average path loss (hops returning * * *).",
                      tips: nil),
            HelpTopic(heading: "Geolocation column",
                      body: "When Geolocation is enabled, each public IP is resolved to country + city via ipinfo.io. Private IPs (RFC 1918) are skipped. Disable in Settings if you prefer offline operation.",
                      tips: [
                        "Flag emoji + city name appears in the Location column.",
                        "Disable geolocation to skip API calls and speed up traces."
                      ]),
            HelpTopic(heading: "Reading results",
                      body: "* * * means all three probes for that hop timed out. This is common for routers that drop ICMP TTL-exceeded packets but still forward traffic — the path isn't broken.",
                      tips: [
                        "High RTT appearing suddenly at one hop and staying high: bottleneck is at or before that hop.",
                        "RTT drops after a high hop: router is rate-limiting ICMP, not a real bottleneck."
                      ])
        ]
    ),
    HelpSection(
        title: "Multi-Ping",
        icon: "dot.radiowaves.left.and.right",
        subtitle: "Ping multiple hosts simultaneously",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Runs independent concurrent ping sessions to any number of hosts. Each host gets its own row with a live sparkline, loss%, and last/average RTT.",
                      tips: nil),
            HelpTopic(heading: "How to use",
                      body: "Type a hostname and press Add (or Return). Use Start All / Stop All to control all sessions at once. Remove individual hosts with the × button.",
                      tips: [
                        "History clock shows recently used hosts.",
                        "Sparkline shows the last 60 RTT samples as color-coded bars.",
                        "Red bars in the sparkline = timed-out packets.",
                        "Sessions keep running when you navigate to another tool."
                      ]),
            HelpTopic(heading: "Row color coding",
                      body: "Row background and status dot reflect loss: green = 0%, orange = 1–49%, red = 50%+. RTT values use the same warn/critical thresholds as Ping.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Port Scanner",
        icon: "checklist",
        subtitle: "TCP port reachability",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Attempts TCP connections to a range of ports on a target host using Network.framework. Reports each port as Open, Closed, or Filtered based on connection outcome.",
                      tips: nil),
            HelpTopic(heading: "Port range presets",
                      body: "Common: the 15 most common service ports (SSH, HTTP, HTTPS, MySQL, etc.). Well-known: ports 1–1023. All: full range 1–65535 (slow). Custom: enter your own start–end range.",
                      tips: [
                        "Full scan (65535 ports) at concurrency 50 takes several minutes.",
                        "Use Common preset for a quick reachability check."
                      ]),
            HelpTopic(heading: "Performance",
                      body: "Concurrency controls simultaneous TCP probes. Higher values are faster but may trigger firewall rate-limiting. Timeout controls how long to wait per port before marking it closed/filtered.",
                      tips: [
                        "Default 50 concurrency is a safe balance for most targets.",
                        "Export results as CSV for firewall audit documentation."
                      ])
        ]
    ),
    HelpSection(
        title: "HTTP Latency",
        icon: "stopwatch",
        subtitle: "HTTP/HTTPS request phase timing",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Makes an HTTP/HTTPS request and breaks down total latency into phases: DNS resolution, TCP connect, TLS handshake, request send, time to first byte (TTFB), and download. Uses URLSessionTaskMetrics — no custom instrumentation.",
                      tips: nil),
            HelpTopic(heading: "Reading the phases",
                      body: "DNS: hostname lookup time. TCP: connection establishment. TLS: handshake (HTTPS only). Request: time to send headers + body. TTFB: server think time. Download: response body transfer.",
                      tips: [
                        "DNS = 0 ms usually means the hostname was already cached.",
                        "TTFB is the most important metric for server responsiveness.",
                        "Long TLS on first request is normal; subsequent requests reuse the session.",
                        "Press Return in the URL field to run immediately."
                      ]),
            HelpTopic(heading: "History table",
                      body: "The last 20 requests are stored in the history table. Click any row to restore that URL and method. Use 'Run Again' in the summary bar to re-run the current result.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "DNS Lookup",
        icon: "globe",
        subtitle: "Resolve hostnames and query DNS records",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses /usr/bin/dig to query DNS records for a hostname. Supports A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, and ANY record types. Raw dig output is shown with color-coded fields.",
                      tips: nil),
            HelpTopic(heading: "Record types",
                      body: "A / AAAA: IPv4 and IPv6 addresses. MX: mail exchange servers with priority. TXT: SPF, DKIM, DMARC, verification tokens. NS: authoritative nameservers. SOA: zone serial and timing. PTR: reverse DNS (enter an IP address).",
                      tips: [
                        "For reverse DNS, enter an IP address and select PTR.",
                        "TXT records reveal email security configuration (SPF/DKIM/DMARC).",
                        "SOA serial lets you verify zone change propagation.",
                        "Export raw output for documentation."
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
            HelpTopic(heading: "Output format",
                      body: "Fields with a key: value structure are parsed and displayed in two columns — label (bold, accent color) and value (selectable). Comment lines starting with % or # are shown dimmed.",
                      tips: [
                        "Export results as .txt for reporting.",
                        "Many domains show 'Redacted for Privacy' for registrant fields under GDPR.",
                        "IP address WHOIS returns ASN, organization, and abuse contact."
                      ])
        ]
    ),
    HelpSection(
        title: "SSL/TLS",
        icon: "lock.shield",
        subtitle: "Certificate chain inspection",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Connects to a host and performs a TLS handshake using Apple's SecTrust API. Inspects the full certificate chain — leaf and intermediate certificates.",
                      tips: nil),
            HelpTopic(heading: "Connection info",
                      body: "After inspection, the header shows the TLS version (e.g. TLS 1.3) as a green badge and the negotiated cipher suite. This confirms the security level of the connection.",
                      tips: [
                        "Default port is 443. Change it for non-standard HTTPS services (8443, etc.).",
                        "Click through the chain picker (Leaf / Chain [1] / …) to inspect intermediate CA certificates."
                      ]),
            HelpTopic(heading: "Expiry banner",
                      body: "Color-coded banner shows days remaining until the leaf certificate expires. Green = more than 30 days, orange = 7–30 days, red = expired or less than 7 days.",
                      tips: nil),
            HelpTopic(heading: "Subject Alternative Names",
                      body: "SANs list all hostnames and IPs the certificate is valid for. Useful for confirming wildcard coverage and identifying the scope of a shared certificate.",
                      tips: [
                        "Compare SHA-256 fingerprint against the CA's published fingerprint to detect substitution.",
                        "Certificate serial number is useful for cross-referencing with CA transparency logs."
                      ])
        ]
    ),
    HelpSection(
        title: "Network Interfaces",
        icon: "network",
        subtitle: "Local network interface details",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Lists all network interfaces using getifaddrs(), grouped by name, with IPv4/IPv6 addresses, MAC address, MTU, and up/down status. Auto-refreshes every 3 seconds.",
                      tips: nil),
            HelpTopic(heading: "Common interfaces",
                      body: "en0: primary Ethernet or Wi-Fi. lo0: loopback (127.0.0.1). utun0–utunN: VPN tunnels. awdl0: AirDrop/AirPlay peer-to-peer. bridge0: VM bridging.",
                      tips: [
                        "awdl0 and llw0 are Apple internal interfaces — safe to ignore.",
                        "MTU below 1500 may indicate VPN overhead.",
                        "Multiple IPv6 addresses per interface is normal (link-local + global)."
                      ])
        ]
    ),
    HelpSection(
        title: "Wi-Fi Inspector",
        icon: "wifi",
        subtitle: "Connected Wi-Fi network details",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Uses CoreWLAN to display details about the currently connected Wi-Fi network: SSID, BSSID, channel, band, security type, RSSI, noise floor, SNR, and transmit rate. Updates every 2 seconds.",
                      tips: nil),
            HelpTopic(heading: "Signal quality",
                      body: "RSSI is in dBm (negative; closer to 0 is stronger). SNR = RSSI − noise floor in dB. SNR is more meaningful than RSSI alone: green ≥ 25 dB (good), orange 15–24 dB (marginal), red < 15 dB (poor).",
                      tips: [
                        "SNR < 15 dB typically causes visible performance degradation and retransmissions.",
                        "BSSID shows which AP you're connected to — useful for mesh networks.",
                        "Transmit rate well below theoretical maximum indicates distance, interference, or capability mismatch."
                      ]),
            HelpTopic(heading: "RSSI history sparkline",
                      body: "A rolling chart of the last 30 RSSI samples (2-second interval = 60-second window) shows signal stability. A flat line at a good level means solid coverage; downward spikes indicate interference or AP handoff events.",
                      tips: nil)
        ]
    ),
    HelpSection(
        title: "Route Table",
        icon: "arrow.triangle.branch",
        subtitle: "System IP routing table",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Runs netstat -rn and parses the routing table for IPv4 and IPv6. Shows destination, gateway, flags, and interface for each route.",
                      tips: nil),
            HelpTopic(heading: "Route flags",
                      body: "U = Up, G = Gateway (not directly connected), H = Host route, S = Static, C = Clone, L = Link (interface address), B = Blackhole (drop silently), I = Reject (ICMP unreachable).",
                      tips: [
                        "Switch between IPv4 and IPv6 with the segmented picker.",
                        "Filter by destination or interface with the search field.",
                        "Missing default route means no internet gateway — check DHCP.",
                        "VPN connections typically add a new default route with lower metric."
                      ])
        ]
    ),
    HelpSection(
        title: "Bandwidth Monitor",
        icon: "chart.bar.xaxis",
        subtitle: "Per-interface traffic rate",
        topics: [
            HelpTopic(heading: "What it does",
                      body: "Polls if_data kernel counters every second and calculates per-second receive (RX) and transmit (TX) byte rates for each active network interface. No elevated privileges required.",
                      tips: nil),
            HelpTopic(heading: "Chart",
                      body: "60-second rolling area chart with RX and TX overlaid using smooth interpolation. Y-axis auto-scales to the peak rate in the current window. Rates display as B/s, KB/s, or MB/s depending on magnitude.",
                      tips: [
                        "Switch interface tabs to monitor individual adapters.",
                        "Peak rate is session-only — resets when you navigate away or relaunch.",
                        "lo0 traffic is local inter-process communication, not internet usage.",
                        "Use alongside Wi-Fi Inspector to correlate signal quality with throughput."
                      ])
        ]
    ),
    HelpSection(
        title: "Settings",
        icon: "gearshape",
        subtitle: "Configure NetUtil behavior",
        topics: [
            HelpTopic(heading: "Ping & Multi-Ping",
                      body: "Set default ping count (packets per run) and interval (seconds between pings). These apply to both Ping and Multi-Ping. The count field accepts up to 9999.",
                      tips: nil),
            HelpTopic(heading: "RTT thresholds",
                      body: "Warn and critical thresholds control the green/orange/red coloring used across Ping, Traceroute, Multi-Ping sparklines, and the menu bar indicator. Changes take effect immediately.",
                      tips: [
                        "Default: warn at 20 ms, critical at 100 ms.",
                        "Loss alert threshold: loss% above this turns red in the Ping stats bar."
                      ]),
            HelpTopic(heading: "Traceroute",
                      body: "Max hops sets the -m flag for traceroute. Geolocation toggle controls whether ipinfo.io is called per hop. Disable for fully offline operation.",
                      tips: nil),
            HelpTopic(heading: "Port Scanner",
                      body: "Concurrency: simultaneous TCP probes (default 50, max 200). Timeout: per-port connection timeout in seconds. Higher concurrency = faster scans but more aggressive on the target.",
                      tips: nil),
            HelpTopic(heading: "Privacy",
                      body: "Host input history is stored in UserDefaults and shown in the history dropdown across all tools. Clear it here if needed. Geolocation setting is also here.",
                      tips: nil)
        ]
    ),
]
