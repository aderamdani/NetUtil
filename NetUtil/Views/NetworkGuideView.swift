import SwiftUI

// MARK: - Root

struct NetworkGuideView: View {
    @State private var selectedChapter: NGChapter.ID? = NGChapter.all.first?.id

    private var selected: NGChapter? {
        NGChapter.all.first { $0.id == selectedChapter }
    }

    var body: some View {
        HSplitView {
            chapterList
            if let chapter = selected {
                chapterDetail(chapter)
            } else {
                Text("Select a topic").font(.headline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(NGChapter.all) { chapter in
                    chapterRow(chapter)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
        .background(.regularMaterial)
    }

    private func chapterRow(_ chapter: NGChapter) -> some View {
        let selected = selectedChapter == chapter.id
        return Button { selectedChapter = chapter.id } label: {
            HStack(spacing: 10) {
                Image(systemName: chapter.icon)
                    .font(.body.weight(.medium))
                    .foregroundColor(selected ? .white : .accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(chapter.title)
                        .font(.system(.callout, weight: selected ? .semibold : .regular))
                        .foregroundColor(selected ? .white : .primary)
                    Text(chapter.subtitle)
                        .font(.caption2)
                        .foregroundColor(selected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chapter Detail

    private func chapterDetail(_ chapter: NGChapter) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: chapter.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 56, height: 56)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title).font(.title2.bold())
                        Text(chapter.subtitle).font(.subheadline).foregroundColor(.secondary)
                    }
                }

                // Sections
                ForEach(chapter.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title).font(.headline)
                        ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                            blockView(block)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 800, alignment: .topLeading)
        }
    }

    // MARK: - Block Renderer

    @ViewBuilder
    private func blockView(_ block: NGBlock) -> some View {
        switch block {
        case .text(let s):
            Text(s)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

        case .code(let s):
            Text(s)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5))

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .tip(let s):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                    .padding(.top, 1)
                Text(s)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        case .toolCallout(let toolName, let icon, let caption):
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try it: \(toolName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(headers.indices, id: \.self) { i in
                    Text(headers[i])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .background(Color(.separatorColor).opacity(0.1))
            Divider()
            // Data rows
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        Text(rows[r][c])
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                }
                if r < rows.count - 1 { Divider().opacity(0.5) }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data Model

enum NGBlock {
    case text(String)
    case code(String)
    case table(headers: [String], rows: [[String]])
    case tip(String)
    case toolCallout(String, String, String) // name, sf symbol, caption
}

struct NGSection: Identifiable {
    let id = UUID()
    let title: String
    let blocks: [NGBlock]
}

struct NGChapter: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let sections: [NGSection]
}

// MARK: - Content

extension NGChapter {
    static let all: [NGChapter] = [osiModel, tcpip, subnetting, dnsAndTls]

    // MARK: OSI Model
    static let osiModel = NGChapter(
        icon: "square.stack.3d.up",
        title: "OSI Model",
        subtitle: "7 layers explained with real protocols",
        sections: [
            NGSection(title: "Overview", blocks: [
                .text("The OSI (Open Systems Interconnection) model is a conceptual framework that standardises how network systems communicate. Every packet traverses these seven layers — each adds or removes a header as data moves between application and physical medium."),
                .table(
                    headers: ["#", "Layer", "Unit", "Protocols", "NetUtil Tool"],
                    rows: [
                        ["7", "Application",  "Data",    "HTTP, DNS, FTP, SSH, SMTP",   "DNS, SSL, HTTP Latency, WHOIS"],
                        ["6", "Presentation", "Data",    "TLS, SSL, JPEG, GZIP",         "SSL/TLS Inspector"],
                        ["5", "Session",      "Data",    "NetBIOS, RPC, PPTP",            "HTTP Latency"],
                        ["4", "Transport",    "Segment", "TCP, UDP, QUIC",                "Port Scanner"],
                        ["3", "Network",      "Packet",  "IP, ICMP, OSPF, BGP",          "Ping, Traceroute, Routes"],
                        ["2", "Data Link",    "Frame",   "Ethernet, Wi-Fi 802.11, ARP",  "Interfaces"],
                        ["1", "Physical",     "Bit",     "Copper, Fiber, Radio",          "Wi-Fi Inspector"],
                    ]
                ),
            ]),
            NGSection(title: "Layer 3 — Network", blocks: [
                .text("The Network layer routes packets between different IP networks using logical addressing. The IP header contains source/destination addresses, TTL, and protocol type. Every router decrements TTL by 1; when TTL reaches 0, an ICMP Time Exceeded message is sent back — the mechanism traceroute exploits."),
                .code("IP Header (simplified):\n  Version (4 bits) | IHL | DSCP | Total Length\n  Identification   | Flags | Fragment Offset\n  TTL (8 bits)     | Protocol | Header Checksum\n  Source IP Address (32 bits)\n  Destination IP Address (32 bits)"),
                .toolCallout("Traceroute", "point.3.connected.trianglepath.dotted", "Each hop in Traceroute represents one Layer 3 router decrementing the TTL. The displayed RTT is the round-trip time at that network layer hop."),
            ]),
            NGSection(title: "Layer 4 — Transport", blocks: [
                .text("Transport layer provides end-to-end communication between processes using port numbers. TCP offers reliable, ordered delivery with congestion control. UDP is connectionless and faster — preferred for real-time applications like DNS, video streaming, and VoIP."),
                .table(
                    headers: ["Feature", "TCP", "UDP"],
                    rows: [
                        ["Connection",   "Connection-oriented (handshake)",  "Connectionless"],
                        ["Reliability",  "Guaranteed delivery, retransmit",  "Best-effort, no retransmit"],
                        ["Order",        "Ordered sequence numbers",          "Unordered"],
                        ["Speed",        "Slower (overhead)",                 "Faster (minimal header)"],
                        ["Header size",  "20–60 bytes",                       "8 bytes"],
                        ["Use case",     "HTTP, SSH, FTP, SMTP",              "DNS, VoIP, video, QUIC"],
                    ]
                ),
                .toolCallout("Port Scanner", "checklist", "Port Scanner performs TCP connect probes at Layer 4. An open port returns SYN-ACK; a closed port returns RST; filtered ports produce no response."),
            ]),
            NGSection(title: "Layer 7 — Application", blocks: [
                .text("Application layer protocols define the rules for communication between software applications. HTTP, DNS, TLS, and SMTP operate here — they are what users and services interact with directly."),
                .tip("Layers 5 and 6 are largely theoretical in modern TCP/IP stacks — TLS handles both presentation-layer encryption and session management within the application layer."),
                .toolCallout("HTTP Latency", "stopwatch", "HTTP Latency measures phases across layers: DNS resolution (L7), TCP connect (L4), TLS handshake (L6/L7), and server response (L7 TTFB)."),
            ]),
        ]
    )

    // MARK: TCP/IP Stack
    static let tcpip = NGChapter(
        icon: "arrow.left.arrow.right",
        title: "TCP/IP Stack",
        subtitle: "Addressing, handshakes, flags, and ICMP",
        sections: [
            NGSection(title: "IPv4 Addressing", blocks: [
                .text("IPv4 uses 32-bit addresses written in dotted-decimal notation. Addresses are divided into network and host portions by the subnet mask. Three private ranges are defined in RFC 1918 — routers do not forward these on the public internet."),
                .table(
                    headers: ["Class", "Range", "Default Mask", "Use"],
                    rows: [
                        ["A (Private)", "10.0.0.0 – 10.255.255.255",    "/8",  "Large enterprise"],
                        ["B (Private)", "172.16.0.0 – 172.31.255.255",  "/12", "Medium networks"],
                        ["C (Private)", "192.168.0.0 – 192.168.255.255","/16", "Home / small office"],
                        ["Loopback",    "127.0.0.0 – 127.255.255.255",  "/8",  "Local host only"],
                        ["Link-local",  "169.254.0.0 – 169.254.255.255","/16", "APIPA / no DHCP"],
                    ]
                ),
            ]),
            NGSection(title: "IPv6 Basics", blocks: [
                .text("IPv6 uses 128-bit addresses written as eight groups of four hex digits separated by colons. Consecutive all-zero groups can be collapsed to '::' once per address. IPv6 eliminates NAT — every device gets a globally routable address."),
                .code("Full:        2001:0db8:0000:0000:0000:0000:0000:0001\nCompressed:  2001:db8::1\n\nLink-local:  fe80::1 (always on every interface)\nLoopback:    ::1"),
                .tip("A Mac will always have a link-local address starting with fe80:: on each interface. Check Interfaces to see all IPv6 assignments."),
                .toolCallout("Interfaces", "network", "Interfaces view shows both IPv4 and IPv6 addresses assigned to each adapter, including link-local and global unicast addresses."),
            ]),
            NGSection(title: "TCP 3-Way Handshake", blocks: [
                .text("Before any data is exchanged, TCP establishes a connection via a 3-way handshake. This synchronises sequence numbers on both sides and ensures both parties are ready to communicate."),
                .code("Client                          Server\n  │──── SYN (Seq=X) ──────────→│\n  │←─── SYN-ACK (Seq=Y,Ack=X+1)─│\n  │──── ACK (Ack=Y+1) ────────→│\n  │═══════ DATA TRANSFER ════════│\n  │──── FIN ───────────────────→│\n  │←─── FIN-ACK ────────────────│"),
                .table(
                    headers: ["TCP Flag", "Meaning", "Use"],
                    rows: [
                        ["SYN", "Synchronise",     "Initiate connection"],
                        ["ACK", "Acknowledge",      "Confirm receipt"],
                        ["FIN", "Finish",           "Graceful close"],
                        ["RST", "Reset",            "Immediate close / port closed"],
                        ["PSH", "Push",             "Send data immediately"],
                        ["URG", "Urgent",           "Priority data"],
                    ]
                ),
                .toolCallout("Port Scanner", "checklist", "When Port Scanner sends a SYN and receives SYN-ACK, the port is Open. RST means Closed. No response means Filtered (firewall dropping)."),
            ]),
            NGSection(title: "ICMP — Ping & Traceroute Protocol", blocks: [
                .text("ICMP operates at Layer 3. It carries control messages between network devices. Ping uses ICMP Echo Request (type 8) and Echo Reply (type 0). Traceroute sends packets with incrementing TTL values, triggering ICMP Time Exceeded (type 11) responses from each router."),
                .table(
                    headers: ["Type", "Code", "Message", "Tool Use"],
                    rows: [
                        ["0",  "0", "Echo Reply",         "Ping: received response"],
                        ["3",  "0", "Net Unreachable",    "Destination not reachable"],
                        ["3",  "3", "Port Unreachable",   "UDP port closed"],
                        ["8",  "0", "Echo Request",       "Ping: sent packet"],
                        ["11", "0", "Time Exceeded",      "Traceroute: TTL expired"],
                    ]
                ),
                .toolCallout("Ping", "antenna.radiowaves.left.and.right", "Ping measures RTT using ICMP Echo. Packet loss occurs when no Echo Reply is received within the timeout. Jitter is the variation in successive RTT values."),
            ]),
        ]
    )

    // MARK: Subnetting & CIDR
    static let subnetting = NGChapter(
        icon: "number.square",
        title: "Subnetting & CIDR",
        subtitle: "Mask calculation, CIDR notation, host ranges",
        sections: [
            NGSection(title: "CIDR Notation", blocks: [
                .text("CIDR (Classless Inter-Domain Routing) replaced the old class-based system. A prefix like 192.168.1.0/24 means the first 24 bits are the network portion and the remaining 8 bits identify hosts. The '/' notation is the subnet mask expressed as bit count."),
                .table(
                    headers: ["CIDR", "Subnet Mask",      "Hosts", "Typical Use"],
                    rows: [
                        ["/8",  "255.0.0.0",       "16,777,214", "Large enterprise / ISP block"],
                        ["/16", "255.255.0.0",     "65,534",     "Campus / large office"],
                        ["/24", "255.255.255.0",   "254",        "Standard LAN segment"],
                        ["/25", "255.255.255.128", "126",        "Split /24 in two"],
                        ["/28", "255.255.255.240", "14",         "Small VLAN"],
                        ["/30", "255.255.255.252", "2",          "Point-to-point link"],
                        ["/32", "255.255.255.255", "1",          "Host route / loopback"],
                    ]
                ),
            ]),
            NGSection(title: "Calculating a Subnet", blocks: [
                .text("Given an IP and prefix, you can calculate four values: network address (all host bits = 0), broadcast address (all host bits = 1), first host (network + 1), and last host (broadcast − 1)."),
                .code("IP:        192.168.10.45 / 26\nMask:      255.255.255.192  (11000000)\n\nNetwork:   192.168.10.0    (host bits zeroed)\nBroadcast: 192.168.10.63   (host bits all 1s)\nFirst:     192.168.10.1\nLast:      192.168.10.62\nHosts:     62  (2^6 − 2)"),
                .tip("Formula: usable hosts = 2^(32−prefix) − 2. Subtract 2 for network address and broadcast address."),
                .toolCallout("Subnet Calculator", "number.square", "Enter any IP and prefix. The tool computes network address, broadcast, host range, total hosts, and binary mask representation in real-time."),
            ]),
            NGSection(title: "VLSM — Variable Length Subnet Masking", blocks: [
                .text("VLSM allows different subnets to use different prefix lengths within the same address space. This prevents wasting addresses by right-sizing each subnet to its actual host requirement."),
                .code("Requirement: allocate from 10.0.0.0/24\n\n  Dept A: 50 hosts → /26 (62 hosts)\n    10.0.0.0/26   (10.0.0.1 – 10.0.0.62)\n\n  Dept B: 20 hosts → /27 (30 hosts)\n    10.0.0.64/27  (10.0.0.65 – 10.0.0.94)\n\n  Link:   2 hosts  → /30 (2 hosts)\n    10.0.0.96/30  (10.0.0.97 – 10.0.0.98)\n\n  Remaining: 10.0.0.100/26, 10.0.0.128/25"),
            ]),
            NGSection(title: "Supernetting & Route Aggregation", blocks: [
                .text("Supernetting combines contiguous networks into a single summary route, reducing routing table size. ISPs aggregate customer prefixes before announcing to upstream providers. This is why traceroutes often show BGP-level aggregates at the internet backbone."),
                .code("Aggregate these four /24s into one summary:\n  192.168.0.0/24\n  192.168.1.0/24\n  192.168.2.0/24\n  192.168.3.0/24\n  ─────────────────\n  Summary: 192.168.0.0/22  (2048 addresses)"),
                .toolCallout("Routes", "arrow.triangle.branch", "The routing table shows exactly which prefix each packet matches against. Longer prefixes (more specific) always win — /32 beats /24 beats /0."),
            ]),
        ]
    )

    // MARK: DNS, TLS & Routing
    static let dnsAndTls = NGChapter(
        icon: "lock.shield",
        title: "DNS, TLS & Routing",
        subtitle: "Resolution chain, handshake, routing table",
        sections: [
            NGSection(title: "DNS Resolution Chain", blocks: [
                .text("When you type a hostname, your OS contacts a stub resolver which queries a recursive resolver (usually your ISP or 1.1.1.1/8.8.8.8). The recursive resolver walks the DNS hierarchy from root to TLD to authoritative nameserver, then caches the result for the TTL duration."),
                .code("Browser → Stub Resolver (OS cache)\n             ↓ cache miss\n         Recursive Resolver (1.1.1.1)\n             ↓ cache miss\n         Root Nameserver (.)\n             ↓ delegation\n         TLD Nameserver (.com)\n             ↓ delegation\n         Authoritative NS (example.com)\n             ↓ A record\n         93.184.216.34  ← cached for TTL seconds"),
                .table(
                    headers: ["Record", "Purpose", "Example"],
                    rows: [
                        ["A",     "IPv4 address",              "example.com → 93.184.216.34"],
                        ["AAAA",  "IPv6 address",              "example.com → 2606:2800::1"],
                        ["CNAME", "Alias to another name",     "www → example.com"],
                        ["MX",    "Mail server",               "mail.example.com pri 10"],
                        ["NS",    "Authoritative nameservers", "ns1.example.com"],
                        ["TXT",   "Arbitrary text / SPF/DKIM", "v=spf1 include:..."],
                        ["PTR",   "Reverse DNS (IP → name)",   "34.216.184.93 → example.com"],
                        ["SOA",   "Zone authority record",     "Primary NS + refresh timers"],
                    ]
                ),
                .toolCallout("DNS Lookup", "globe", "DNS Lookup queries all record types against any resolver — compare results between your ISP's resolver and 1.1.1.1 or 8.8.8.8 to diagnose propagation or poisoning issues."),
            ]),
            NGSection(title: "TLS 1.3 Handshake", blocks: [
                .text("TLS 1.3 reduced the handshake to 1 round-trip (vs TLS 1.2's 2 RTT). The client sends its key share immediately in ClientHello; the server responds with its key share and certificate in a single flight. Symmetric keys are derived using Diffie-Hellman — the private key never crosses the wire."),
                .code("Client                          Server\n  │──── ClientHello ───────────→│\n  │     (cipher suites,          │\n  │      key_share, SNI)         │\n  │                              │\n  │←─── ServerHello ────────────│\n  │     (selected cipher,        │\n  │      key_share)              │\n  │←─── {Certificate} ──────────│\n  │←─── {CertificateVerify} ────│\n  │←─── {Finished} ─────────────│\n  │──── {Finished} ────────────→│\n  │                              │\n  │═══ [Application Data] ══════│\n  (braces = encrypted, 1 RTT total)"),
                .table(
                    headers: ["Certificate Field", "Purpose"],
                    rows: [
                        ["Subject",          "Domain / entity the cert belongs to"],
                        ["Issuer",           "Certificate Authority that signed it"],
                        ["Not Before/After", "Validity period"],
                        ["SAN",              "Subject Alternative Names (additional domains)"],
                        ["Key Type",         "RSA 2048/4096 or EC P-256/P-384"],
                        ["SHA-256 Fingerprint", "Unique digest — use to verify cert identity"],
                    ]
                ),
                .tip("A certificate chain typically has 3 tiers: Leaf (your domain) → Intermediate CA → Root CA. Browsers trust root CAs stored in the OS keychain. Intermediates must be sent by the server."),
                .toolCallout("SSL/TLS Inspector", "lock.shield", "SSL Inspector shows the full certificate chain, expiry, SAN entries, key type, TLS version negotiated, and the SHA-256 fingerprint for pinning verification."),
            ]),
            NGSection(title: "Routing Table & Longest Prefix Match", blocks: [
                .text("Every router (and your Mac) maintains a routing table — a list of network prefixes mapped to next-hop addresses or exit interfaces. When forwarding a packet, the router applies longest prefix match: the most specific matching route wins."),
                .code("Destination      Gateway         Flags  Interface\n0.0.0.0/0        192.168.1.1     UG     en0      ← default route\n192.168.1.0/24   link#4          U      en0      ← local subnet\n10.0.0.0/8       10.8.0.1        UG     utun0    ← VPN tunnel\n127.0.0.0/8      127.0.0.1       U      lo0      ← loopback\n\nFlags: U=Up  G=Gateway  H=Host  S=Static"),
                .text("The default route (0.0.0.0/0) matches everything with the shortest prefix — it is the gateway of last resort. A VPN route like 0.0.0.0/1 + 128.0.0.0/1 uses two more-specific routes to override the default without replacing it, routing all traffic through the tunnel."),
                .toolCallout("Routes", "arrow.triangle.branch", "The Routes tool displays the live kernel routing table for IPv4 and IPv6. Look for unexpected default routes or VPN tunnel routes that explain why traffic takes an unexpected path."),
            ]),
        ]
    )
}
