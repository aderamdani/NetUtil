import SwiftUI

struct HelpView: View {
    @State private var search = ""
    @State private var selectedTitle: String?

    init(topic: String? = "Dashboard") {
        _selectedTitle = State(initialValue: topic)
    }

    var body: some View {
        HSplitView {
            sidebar
            detail
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search Bar Area
            VStack(alignment: .leading, spacing: 12) {
                Text("Documentation")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11, weight: .bold))
                    TextField("Search help...", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
            
            Divider().opacity(0.5)

            // Navigation List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredSections) { section in
                        sectionRow(section)
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
        .background(.regularMaterial)
    }

    private var detail: some View {
        ScrollView {
            if let section = selectedSection {
                VStack(alignment: .leading, spacing: 32) {
                    // Section Header
                    HStack(spacing: 16) {
                        Image(systemName: section.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.title.bold())
                            Text(section.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 8)

                    // Topics
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(section.topics) { topic in
                            topicBlock(topic)
                            if topic.id != section.topics.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
                .padding(40)
                .frame(maxWidth: 800, alignment: .topLeading)
            } else {
                emptyState
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var selectedSection: HelpSection? {
        filteredSections.first { $0.title == selectedTitle } ?? filteredSections.first
    }

    private var filteredSections: [HelpSection] {
        guard !search.isEmpty else { return allSections }
        let q = search.lowercased()
        return allSections.compactMap { section in
            let matchTitle = section.title.lowercased().contains(q)
            let matchTopics = section.topics.filter { $0.heading.lowercased().contains(q) || $0.body.lowercased().contains(q) }
            if matchTitle { return section }
            if !matchTopics.isEmpty {
                return HelpSection(title: section.title, icon: section.icon, subtitle: section.subtitle, topics: matchTopics)
            }
            return nil
        }
    }

    @ViewBuilder
    private func sectionRow(_ section: HelpSection) -> some View {
        let isSelected = selectedTitle == section.title
        Button {
            selectedTitle = section.title
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func topicBlock(_ topic: HelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(topic.heading)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(topic.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            if let code = topic.codeBlock {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5))
            }

            if let tips = topic.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 10))
                                .padding(.top, 3)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 4)
            }
        }
    }
    
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No results for \"\(search)\"")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

// MARK: - Data model

private struct HelpTopic: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
    var codeBlock: String? = nil
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
        title: "Dashboard",
        icon: "square.grid.2x2",
        subtitle: "Real-time network overview",
        topics: [
            HelpTopic(heading: "What it does", body: "The Dashboard provides a centralized, high-level summary of your network environment and the status of active diagnostic tools.", tips: nil),
            HelpTopic(heading: "Interactive Cards", body: "Each card on the dashboard acts as a quick-access button. Clicking a card will navigate you directly to the corresponding tool for deeper analysis.", tips: [
                "Cards with a green pulse indicate an active diagnostic session.",
                "Hover over cards to see a subtle scale effect and highlighted borders.",
                "Tooltips provide a brief description of each tool's primary purpose."
            ]),
            HelpTopic(heading: "System Health", body: "The header displays real-time badges for CPU load and memory pressure, helping you correlate network performance with local system resources.", tips: nil)
        ]
    ),
    HelpSection(
        title: "Ping",
        icon: "antenna.radiowaves.left.and.right",
        subtitle: "ICMP echo request latency",
        topics: [
            HelpTopic(heading: "What it does", body: "Sends ICMP echo requests to a host using /sbin/ping and measures round-trip time (RTT). Results update live as each ping arrives.", tips: nil),
            HelpTopic(heading: "How to use", body: "Enter a hostname or IP, then press Return or click Start. Adjust count and interval directly in the toolbar.", tips: [
                "Press Return in the host field to start immediately.",
                "The action button turns red (Cancel) while a run is in progress.",
                "RTT colors: green below warn threshold, orange below critical, red at or above critical. Configure thresholds in Settings."
            ]),
            HelpTopic(heading: "Stats explained", body: "Min / Avg / Max show the best, mean, and worst RTT for the run. Jitter is the standard deviation of RTT — a measure of consistency. Loss% counts unanswered pings as a fraction of packets sent.", tips: [
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
            HelpTopic(heading: "What it does", body: "Uses /usr/sbin/traceroute to discover each network hop between your machine and the destination. Features a modern Timeline View for visual path analysis.", tips: nil),
            HelpTopic(heading: "Timeline View", body: "Switch to the Timeline tab to see a stacked bar chart of RTTs for every hop. This provides a clear visual comparison of latency across the entire network path.", tips: [
                "Canvas-drawn bars show the last 60 RTT samples per hop.",
                "Tap any hop row to expand a detailed RTT area chart for that specific hop."
            ]),
            HelpTopic(heading: "Route Health", body: "The Route Health banner automatically assesses the path quality. It monitors for significant packet loss or excessive latency at any hop.", tips: [
                "Critical: Significant loss (≥50%) or severe latency detected.",
                "Degraded: Moderate loss (>0%) or high jitter observed.",
                "Healthy: Low latency and zero packet loss throughout the path."
            ]),
            HelpTopic(heading: "Route Map", body: "The Map tab renders a live geographic map of your packet's journey. Each geo-resolved hop appears as a numbered pin connected by a polyline. Tap any pin to open the IP Info Card for that hop.", tips: [
                "Pins use geo data from ipinfo.io — enable Geolocation in Settings.",
                "Bottleneck hops appear as red pins with a bolt icon.",
                "Private/unresolved IPs are skipped on the map."
            ]),
            HelpTopic(heading: "Bottleneck Detection", body: "NetUtil automatically flags hops where latency spikes sharply compared to the previous hop. A hop is marked as a bottleneck if the RTT delta exceeds 30 ms and the hop's average RTT exceeds 50 ms.", tips: [
                "Bottleneck badge appears in the Hops table, on the Route Map pin, and in the path summary strip.",
                "A bottleneck at hop N means congestion is at or between hop N-1 and N.",
                "A single bottleneck hop is usually normal inter-ISP peering — multiple in a row indicates a real problem."
            ]),
            HelpTopic(heading: "IP Info Card", body: "Tap the ⓘ button on any hop row (or tap a map pin) to open the IP Info Card. It shows the Private/Public classification, full geolocation (country, city, ISP, hostname, timezone, coordinates), and a performance grid with Avg/Min/Max RTT, Jitter, Loss%, and packets sent.", tips: nil),
            HelpTopic(heading: "Reading results", body: "* * * means all three probes for that hop timed out. This is common for routers that drop ICMP TTL-exceeded packets but still forward traffic — the path isn't broken.", tips: [
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
            HelpTopic(heading: "What it does", body: "Runs independent concurrent ping sessions to any number of hosts. Each host gets its own row with a live sparkline, loss%, and last/average RTT.", tips: nil),
            HelpTopic(heading: "How to use", body: "Type a hostname and press Add (or Return). Use Start All / Stop All to control all sessions at once. Remove individual hosts with the × button.", tips: [
                "History clock shows recently used hosts.",
                "Sparkline shows the last 60 RTT samples as color-coded bars.",
                "Red bars in the sparkline = timed-out packets.",
                "Sessions keep running when you navigate to another tool."
            ]),
            HelpTopic(heading: "Row color coding", body: "Row background and status dot reflect loss: green = 0%, orange = 1–49%, red = 50%+. RTT values use the same warn/critical thresholds as Ping.", tips: nil)
        ]
    ),
    HelpSection(
        title: "Port Scanner",
        icon: "checklist",
        subtitle: "TCP port reachability",
        topics: [
            HelpTopic(heading: "What it does", body: "Attempts TCP connections to a range of ports on a target host using Network.framework. Reports each port as Open, Closed, or Filtered based on connection outcome.", tips: nil),
            HelpTopic(heading: "Port range presets", body: "Common: the 15 most common service ports (SSH, HTTP, HTTPS, MySQL, etc.). Well-known: ports 1–1023. All: full range 1–65535 (slow). Custom: enter your own start–end range.", tips: [
                "Full scan (65535 ports) at concurrency 50 takes several minutes.",
                "Use Common preset for a quick reachability check."
            ]),
            HelpTopic(heading: "Performance", body: "Concurrency controls simultaneous TCP probes. Higher values are faster but may trigger firewall rate-limiting. Timeout controls how long to wait per port before marking it closed/filtered.", tips: [
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
            HelpTopic(heading: "What it does", body: "Makes an HTTP/HTTPS request and breaks down total latency into phases: DNS resolution, TCP connect, TLS handshake, request send, time to first byte (TTFB), and download. Uses URLSessionTaskMetrics — no custom instrumentation.", tips: nil),
            HelpTopic(heading: "Reading the phases", body: "DNS: hostname lookup time. TCP: connection establishment. TLS: handshake (HTTPS only). Request: time to send headers + body. TTFB: server think time. Download: response body transfer.", tips: [
                "DNS = 0 ms usually means the hostname was already cached.",
                "TTFB is the most important metric for server responsiveness.",
                "Long TLS on first request is normal; subsequent requests reuse the session.",
                "Press Return in the URL field to run immediately."
            ]),
            HelpTopic(heading: "History table", body: "The last 20 requests are stored in the history table. Click any row to restore that URL and method. Use 'Run Again' in the summary bar to re-run the current result.", tips: nil)
        ]
    ),
    HelpSection(
        title: "Subnet Calculator",
        icon: "number.square",
        subtitle: "CIDR and IP Class calculations",
        topics: [
            HelpTopic(heading: "What it does", body: "Calculates subnet masks, network addresses, broadcast addresses, and host ranges based on an IP address and a CIDR prefix.", tips: nil),
            HelpTopic(heading: "How to use", body: "Enter an IP address and adjust the prefix slider (0 to 32). The network parameters update instantly.", tips: [
                "Use the 'Copy Info' button to copy the calculation to your clipboard."
            ]),
            HelpTopic(heading: "Binary Representation", body: "Displays the 32-bit binary version of the subnet mask, illustrating the exact division between network bits (ones) and host bits (zeros).", tips: nil)
        ]
    ),
    HelpSection(
        title: "DNS Lookup",
        icon: "globe",
        subtitle: "Resolve hostnames and query DNS records",
        topics: [
            HelpTopic(heading: "What it does", body: "Uses /usr/bin/dig to query DNS records for a hostname. Supports A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, and ANY record types. Raw dig output is shown with color-coded fields.", tips: nil),
            HelpTopic(heading: "Record types", body: "A / AAAA: IPv4 and IPv6 addresses. MX: mail exchange servers with priority. TXT: SPF, DKIM, DMARC, verification tokens. NS: authoritative nameservers. SOA: zone serial and timing. PTR: reverse DNS (enter an IP address).", tips: [
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
            HelpTopic(heading: "What it does", body: "Queries the WHOIS database for a domain name or IP address using /usr/bin/whois. Returns registrar, registrant, nameservers, and important dates.", tips: nil),
            HelpTopic(heading: "Output format", body: "Fields with a key: value structure are parsed and displayed in two columns — label (bold, accent color) and value (selectable). Comment lines starting with % or # are shown dimmed.", tips: [
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
            HelpTopic(heading: "What it does", body: "Connects to a host and performs a TLS handshake using Apple's SecTrust API. Inspects the full certificate chain — leaf and intermediate certificates.", tips: nil),
            HelpTopic(heading: "Connection info", body: "After inspection, the header shows the TLS version (e.g. TLS 1.3) as a green badge and the negotiated cipher suite. This confirms the security level of the connection.", tips: [
                "Default port is 443. Change it for non-standard HTTPS services (8443, etc.).",
                "Click through the chain picker (Leaf / Chain [1] / …) to inspect intermediate CA certificates."
            ]),
            HelpTopic(heading: "Expiry banner", body: "Color-coded banner shows days remaining until the leaf certificate expires. Green = more than 30 days, orange = 7–30 days, red = expired or less than 7 days.", tips: nil),
            HelpTopic(heading: "Subject Alternative Names", body: "SANs list all hostnames and IPs the certificate is valid for. Useful for confirming wildcard coverage and identifying the scope of a shared certificate.", tips: [
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
            HelpTopic(heading: "What it does", body: "Lists all network interfaces using getifaddrs(), grouped by name, with IPv4/IPv6 addresses, MAC address, MTU, and up/down status. Auto-refreshes every 3 seconds.", tips: nil),
            HelpTopic(heading: "Virtual Interfaces", body: "Automatically detects VLAN interfaces (802.1Q) and displays the VLAN ID tag alongside its physical parent interface. VPN tunnels (utun) are also clearly identified.", tips: nil),
            HelpTopic(heading: "Common interfaces", body: "en0: primary Ethernet or Wi-Fi. lo0: loopback (127.0.0.1). utun0–utunN: VPN tunnels. awdl0: AirDrop/AirPlay peer-to-peer. bridge0: VM bridging.", tips: [
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
            HelpTopic(heading: "What it does", body: "Uses CoreWLAN to display details about the currently connected Wi-Fi network: SSID, BSSID, channel, band, security type, RSSI, noise floor, SNR, and transmit rate. Updates every 2 seconds.", tips: nil),
            HelpTopic(heading: "Signal quality", body: "RSSI is in dBm (negative; closer to 0 is stronger). SNR = RSSI − noise floor in dB. SNR is more meaningful than RSSI alone: green ≥ 25 dB (good), orange 15–24 dB (marginal), red < 15 dB (poor).", tips: [
                "SNR < 15 dB typically causes visible performance degradation and retransmissions.",
                "BSSID shows which AP you're connected to — useful for mesh networks.",
                "Transmit rate well below theoretical maximum indicates distance, interference, or capability mismatch."
            ]),
            HelpTopic(heading: "RSSI history sparkline", body: "A rolling chart of the last 30 RSSI samples (2-second interval = 60-second window) shows signal stability. A flat line at a good level means solid coverage; downward spikes indicate interference or AP handoff events.", tips: nil)
        ]
    ),
    HelpSection(
        title: "Route Table",
        icon: "arrow.triangle.branch",
        subtitle: "System IP routing table",
        topics: [
            HelpTopic(heading: "What it does", body: "Runs netstat -rn and parses the routing table for IPv4 and IPv6. Shows destination, gateway, flags, and interface for each route.", tips: nil),
            HelpTopic(heading: "Route flags", body: "U = Up, G = Gateway (not directly connected), H = Host route, S = Static, C = Clone, L = Link (interface address), B = Blackhole (drop silently), I = Reject (ICMP unreachable).", tips: [
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
            HelpTopic(heading: "What it does", body: "Polls if_data kernel counters every second and calculates per-second receive (RX) and transmit (TX) byte rates for each active network interface. No elevated privileges required.", tips: nil),
            HelpTopic(heading: "Chart", body: "60-second rolling area chart with RX and TX overlaid using smooth interpolation. Y-axis auto-scales to the peak rate in the current window. Rates display as B/s, KB/s, or MB/s depending on magnitude.", tips: [
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
            HelpTopic(heading: "Ping & Multi-Ping", body: "Set default ping count (packets per run) and interval (seconds between pings). These apply to both Ping and Multi-Ping. The count field accepts up to 9999.", tips: nil),
            HelpTopic(heading: "RTT thresholds", body: "Warn and critical thresholds control the green/orange/red coloring used across Ping, Traceroute, Multi-Ping sparklines, and the menu bar indicator. Changes take effect immediately.", tips: [
                "Default: warn at 20 ms, critical at 100 ms.",
                "Loss alert threshold: loss% above this turns red in the Ping stats bar."
            ]),
            HelpTopic(heading: "Privacy", body: "Host input history is stored in UserDefaults and shown in the history dropdown across all tools. Clear it here if needed. Geolocation setting is also here.", tips: nil)
        ]
    ),

    // MARK: - Network Guide

    HelpSection(
        title: "OSI Model",
        icon: "square.stack.3d.up",
        subtitle: "7 layers with real protocols",
        topics: [
            HelpTopic(
                heading: "Layer Overview",
                body: "The OSI model standardises how systems communicate across seven layers. Each layer adds or removes a header as data moves between application and physical medium.",
                codeBlock:
                    "Layer  Name           Unit     Protocols               NetUtil Tool\n" +
                    "───────────────────────────────────────────────────────────────────\n" +
                    "  7    Application   Data     HTTP, DNS, SMTP, SSH    DNS, SSL, HTTP Lat.\n" +
                    "  6    Presentation  Data     TLS, SSL, JPEG, GZIP    SSL/TLS Inspector\n" +
                    "  5    Session       Data     NetBIOS, RPC, PPTP      HTTP Latency\n" +
                    "  4    Transport     Segment  TCP, UDP, QUIC          Port Scanner\n" +
                    "  3    Network       Packet   IP, ICMP, OSPF, BGP     Ping, Traceroute\n" +
                    "  2    Data Link     Frame    Ethernet, 802.11, ARP   Interfaces\n" +
                    "  1    Physical      Bit      Copper, Fiber, Radio    Wi-Fi Inspector"
            ),
            HelpTopic(
                heading: "Layer 3 — Network (IP & ICMP)",
                body: "Routers operate at Layer 3, forwarding packets based on IP addresses. Each router decrements the TTL field by 1. When TTL reaches 0, an ICMP Time Exceeded is returned — the mechanism that Traceroute exploits to discover hops.",
                codeBlock:
                    "IP Header (key fields):\n" +
                    "  Version | IHL | DSCP | Total Length\n" +
                    "  TTL (8 bits) | Protocol | Checksum\n" +
                    "  Source IP (32 bits)\n" +
                    "  Destination IP (32 bits)\n\n" +
                    "Protocol field values:\n" +
                    "  1 = ICMP   6 = TCP   17 = UDP   89 = OSPF"
            ),
            HelpTopic(
                heading: "Layer 4 — Transport (TCP vs UDP)",
                body: "TCP is connection-oriented with guaranteed delivery, ordering, and retransmission. UDP is connectionless — no handshake, no retransmit, minimal header overhead.",
                codeBlock:
                    "Feature        TCP                       UDP\n" +
                    "─────────────────────────────────────────────\n" +
                    "Connection     Handshake required        None\n" +
                    "Reliability    Guaranteed, retransmit    Best-effort\n" +
                    "Header size    20–60 bytes               8 bytes\n" +
                    "Use case       HTTP, SSH, FTP, SMTP      DNS, VoIP, video",
                tips: ["Port Scanner probes Layer 4: SYN → SYN-ACK = Open. SYN → RST = Closed. No reply = Filtered."]
            ),
        ]
    ),

    HelpSection(
        title: "TCP/IP Stack",
        icon: "arrow.left.arrow.right",
        subtitle: "Addressing, handshake, flags, ICMP",
        topics: [
            HelpTopic(
                heading: "IPv4 Private Ranges",
                body: "Three RFC 1918 address blocks are reserved for private networks. Routers do not forward these on the public internet. NAT translates them to a public address at the network edge.",
                codeBlock:
                    "Range                          Mask   Typical use\n" +
                    "────────────────────────────────────────────────────\n" +
                    "10.0.0.0 – 10.255.255.255       /8     Large enterprise\n" +
                    "172.16.0.0 – 172.31.255.255     /12    Medium networks\n" +
                    "192.168.0.0 – 192.168.255.255   /16    Home / small office\n" +
                    "169.254.0.0 – 169.254.255.255   /16    Link-local (APIPA)"
            ),
            HelpTopic(
                heading: "TCP 3-Way Handshake",
                body: "Before data is exchanged, TCP synchronises sequence numbers on both ends via a 3-step process. Understanding this is key to reading Port Scanner results and diagnosing connection failures.",
                codeBlock:
                    "Client                      Server\n" +
                    "  │─── SYN (Seq=X) ────────→│\n" +
                    "  │←── SYN-ACK (Seq=Y,Ack=X+1)─│\n" +
                    "  │─── ACK (Ack=Y+1) ──────→│\n" +
                    "  │══════ DATA TRANSFER ═════│\n" +
                    "  │─── FIN ────────────────→│  (graceful close)\n\n" +
                    "TCP Flags:  SYN=sync  ACK=ack  FIN=finish\n" +
                    "            RST=reset  PSH=push  URG=urgent"
            ),
            HelpTopic(
                heading: "ICMP — Ping & Traceroute",
                body: "ICMP carries control messages at Layer 3. Ping uses Echo Request (type 8) / Echo Reply (type 0). Traceroute sends packets with incrementing TTL, triggering Time Exceeded (type 11) from each router.",
                codeBlock:
                    "Type  Code  Message            Tool use\n" +
                    "────────────────────────────────────────────────\n" +
                    "   0     0  Echo Reply         Ping: response received\n" +
                    "   3     0  Net Unreachable    Destination not reachable\n" +
                    "   3     3  Port Unreachable   UDP port closed\n" +
                    "   8     0  Echo Request       Ping: packet sent\n" +
                    "  11     0  Time Exceeded      Traceroute: TTL expired"
            ),
            HelpTopic(
                heading: "IPv6 Basics",
                body: "IPv6 uses 128-bit addresses in eight colon-separated hex groups. Consecutive zero groups collapse to '::'. Link-local addresses (fe80::) are always present on active interfaces.",
                codeBlock:
                    "Full:       2001:0db8:0000:0000:0000:0000:0000:0001\n" +
                    "Compressed: 2001:db8::1\n\n" +
                    "Link-local: fe80::1   (every active interface)\n" +
                    "Loopback:   ::1       (equivalent to 127.0.0.1)",
                tips: ["Check the Interfaces tool to see all IPv6 addresses assigned to each adapter, including link-local and any global unicast addresses."]
            ),
        ]
    ),

    HelpSection(
        title: "Subnetting & CIDR",
        icon: "number.square",
        subtitle: "Mask calculation, host ranges, VLSM",
        topics: [
            HelpTopic(
                heading: "CIDR Prefix Reference",
                body: "CIDR (Classless Inter-Domain Routing) expresses the subnet mask as a bit count after the slash. The remaining bits identify hosts. Usable hosts = 2^(32-prefix) − 2 (subtract network and broadcast addresses).",
                codeBlock:
                    "CIDR  Subnet Mask         Hosts    Typical use\n" +
                    "────────────────────────────────────────────────────\n" +
                    "/8    255.0.0.0           16,777,214  ISP block\n" +
                    "/16   255.255.0.0         65,534      Campus LAN\n" +
                    "/24   255.255.255.0       254         Standard LAN\n" +
                    "/25   255.255.255.128     126         Split /24\n" +
                    "/28   255.255.255.240     14          Small VLAN\n" +
                    "/30   255.255.255.252     2           Point-to-point\n" +
                    "/32   255.255.255.255     1           Host route"
            ),
            HelpTopic(
                heading: "Calculating a Subnet",
                body: "Given an IP and prefix, zero the host bits to get the network address. Set all host bits to 1 for the broadcast. First host = network + 1. Last host = broadcast − 1.",
                codeBlock:
                    "IP:        192.168.10.45 / 26\n" +
                    "Mask:      255.255.255.192  (11000000 in last octet)\n\n" +
                    "Network:   192.168.10.0    (host bits zeroed)\n" +
                    "Broadcast: 192.168.10.63   (host bits all 1s)\n" +
                    "First:     192.168.10.1\n" +
                    "Last:      192.168.10.62\n" +
                    "Hosts:     62  (2^6 − 2)",
                tips: ["Use the Subnet Calculator tool to compute all values instantly. It also shows the binary representation of the mask."]
            ),
            HelpTopic(
                heading: "VLSM — Variable Length Subnet Masking",
                body: "VLSM assigns different prefix lengths to different subnets within the same address space. Right-size each segment to avoid wasting addresses.",
                codeBlock:
                    "Allocate from 10.0.0.0/24:\n\n" +
                    "  50 hosts → /26 (62 hosts)  10.0.0.0/26\n" +
                    "  20 hosts → /27 (30 hosts)  10.0.0.64/27\n" +
                    "   2 hosts → /30  (2 hosts)  10.0.0.96/30\n" +
                    "  Remainder:                 10.0.0.100 onward"
            ),
        ]
    ),

    HelpSection(
        title: "DNS, TLS & Routing",
        icon: "lock.shield",
        subtitle: "Resolution chain, handshake, routing table",
        topics: [
            HelpTopic(
                heading: "DNS Resolution Chain",
                body: "When you enter a hostname, your OS queries a recursive resolver which walks the DNS hierarchy from root to TLD to authoritative nameserver. Results are cached for the TTL duration.",
                codeBlock:
                    "Browser → Stub Resolver (OS cache)\n" +
                    "              ↓ miss\n" +
                    "          Recursive Resolver (1.1.1.1 / 8.8.8.8)\n" +
                    "              ↓ miss\n" +
                    "          Root Nameserver  (.)\n" +
                    "              ↓ delegation\n" +
                    "          TLD Nameserver   (.com)\n" +
                    "              ↓ delegation\n" +
                    "          Authoritative NS (example.com)\n" +
                    "              ↓\n" +
                    "          A record → 93.184.216.34  (cached for TTL s)",
                tips: ["DNS Lookup lets you compare results between your ISP resolver and 1.1.1.1 or 8.8.8.8 to detect propagation delays or resolver differences."]
            ),
            HelpTopic(
                heading: "DNS Record Types",
                body: "Each record type serves a specific purpose. Understanding them is essential when diagnosing mail delivery, CDN routing, and certificate validation failures.",
                codeBlock:
                    "Record  Purpose                      Example\n" +
                    "────────────────────────────────────────────────────────\n" +
                    "A       IPv4 address                 93.184.216.34\n" +
                    "AAAA    IPv6 address                 2606:2800::1\n" +
                    "CNAME   Alias to another hostname    www → example.com\n" +
                    "MX      Mail server + priority       mail.example.com 10\n" +
                    "NS      Authoritative nameservers    ns1.example.com\n" +
                    "TXT     Arbitrary text / SPF / DKIM  v=spf1 include:...\n" +
                    "PTR     Reverse lookup (IP → name)   93.184.216.34 → ...\n" +
                    "SOA     Zone authority + timers      primary NS + serial"
            ),
            HelpTopic(
                heading: "TLS 1.3 Handshake",
                body: "TLS 1.3 completes the handshake in 1 round-trip. The client sends its key share in ClientHello; the server replies with its key share and certificate in a single flight. Private keys never cross the wire.",
                codeBlock:
                    "Client                        Server\n" +
                    "  │─── ClientHello ──────────→│  (cipher suites, key_share)\n" +
                    "  │←── ServerHello ───────────│  (selected cipher, key_share)\n" +
                    "  │←── {Certificate} ─────────│\n" +
                    "  │←── {CertificateVerify} ───│\n" +
                    "  │←── {Finished} ────────────│\n" +
                    "  │─── {Finished} ────────────→│\n" +
                    "  │════ [Application Data] ════│\n" +
                    "  { } = encrypted   total: 1 RTT",
                tips: [
                    "SSL/TLS Inspector shows the full certificate chain, expiry date, SANs, key type, and SHA-256 fingerprint.",
                    "A certificate chain is: Leaf → Intermediate CA → Root CA. The server must send the intermediate — browsers trust root CAs from the OS keychain."
                ]
            ),
            HelpTopic(
                heading: "Routing Table & Longest Prefix Match",
                body: "Every router and your Mac maintain a routing table. When forwarding a packet, the longest (most specific) matching prefix wins. The default route 0.0.0.0/0 matches everything as a last resort.",
                codeBlock:
                    "Destination        Gateway        Flags  Interface\n" +
                    "────────────────────────────────────────────────────\n" +
                    "0.0.0.0/0          192.168.1.1    UG     en0      ← default\n" +
                    "192.168.1.0/24     link#4         U      en0      ← local\n" +
                    "10.0.0.0/8         10.8.0.1       UG     utun0    ← VPN\n" +
                    "127.0.0.0/8        127.0.0.1      U      lo0      ← loopback\n\n" +
                    "Flags: U=Up  G=Gateway  H=Host  S=Static",
                tips: ["A VPN often injects 0.0.0.0/1 + 128.0.0.0/1 — two /1 routes more specific than the default /0 — to route all traffic through the tunnel without replacing the default route."]
            ),
        ]
    ),
]
