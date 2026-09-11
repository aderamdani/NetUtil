import Foundation

/// One network destination a tool can contact. Every entry is audited
/// from the ViewModel/subprocess code — hosts are never invented.
///
/// Scope semantics:
/// - `.localOnly` — traffic stays on this Mac or the local network
///   (kernel counters, LAN ping/ARP, UDP broadcast). Never the internet.
/// - `.remote` — can reach, or accept connections from, hosts beyond the
///   local network (user targets, public APIs, measurement servers).
struct NetworkUsage: Sendable, Hashable {
    enum Scope: String, Sendable {
        case localOnly
        case remote
    }

    let host: String
    let purpose: String
    let scope: Scope
}

extension Tool {
    /// Audited network usage. Empty means the tool sends no packets at all
    /// (pure local computation or kernel-counter reads).
    var networkUsage: [NetworkUsage] {
        switch self {
        case .dashboard:
            return [NetworkUsage(host: "ipinfo.io",
                                 purpose: "Public IP address and geolocation for the header and cards",
                                 scope: .remote)]
        case .doctor:
            return [
                NetworkUsage(host: "default gateway (ICMP ping)",
                             purpose: "Router reachability check",
                             scope: .localOnly),
                NetworkUsage(host: "system DNS resolver",
                             purpose: "Resolves apple.com to test DNS",
                             scope: .remote),
                NetworkUsage(host: "captive.apple.com",
                             purpose: "Captive-portal check over plain http",
                             scope: .remote),
                NetworkUsage(host: "www.apple.com",
                             purpose: "TLS connectivity probe (https HEAD)",
                             scope: .remote),
            ]
        case .ping:
            return [NetworkUsage(host: "user-specified host",
                                 purpose: "ICMP echo requests (/sbin/ping)",
                                 scope: .remote)]
        case .traceroute:
            return [
                NetworkUsage(host: "user-specified host",
                             purpose: "Probe packets (/usr/sbin/traceroute)",
                             scope: .remote),
                NetworkUsage(host: "ipinfo.io",
                             purpose: "Per-hop geolocation — only when enabled in Settings",
                             scope: .remote),
            ]
        case .multiPing:
            return [NetworkUsage(host: "user-specified hosts",
                                 purpose: "Concurrent ICMP echo requests (/sbin/ping)",
                                 scope: .remote)]
        case .portScan:
            return [NetworkUsage(host: "user-specified host and ports",
                                 purpose: "TCP connection attempts",
                                 scope: .remote)]
        case .subnetScan:
            return [
                NetworkUsage(host: "user-entered subnet hosts",
                             purpose: "ICMP ping and ARP sweep of the local subnet",
                             scope: .localOnly),
                NetworkUsage(host: "system DNS resolver",
                             purpose: "Reverse-DNS lookup of discovered LAN addresses",
                             scope: .remote),
            ]
        case .httpLatency:
            return [NetworkUsage(host: "user-specified URL",
                                 purpose: "Timed HTTP/HTTPS request with phase metrics",
                                 scope: .remote)]
        case .pathMTU:
            return [NetworkUsage(host: "user-specified host",
                                 purpose: "Sized ICMP probes (/sbin/ping -D -s)",
                                 scope: .remote)]
        case .dns:
            return [NetworkUsage(host: "chosen DNS server (System, 8.8.8.8, 1.1.1.1, 9.9.9.9)",
                                 purpose: "dig query for the requested record type",
                                 scope: .remote)]
        case .ssl:
            return [NetworkUsage(host: "user-specified host and port",
                                 purpose: "TLS handshake and certificate-chain inspection",
                                 scope: .remote)]
        case .whois:
            return [NetworkUsage(host: "WHOIS server for the queried domain (port 43)",
                                 purpose: "Domain registration lookup via system whois",
                                 scope: .remote)]
        case .speedTest:
            return [
                NetworkUsage(host: "speed.cloudflare.com",
                             purpose: "Download and upload throughput transfers",
                             scope: .remote),
                NetworkUsage(host: "1.1.1.1",
                             purpose: "Gaming latency probes (cdn-cgi/trace)",
                             scope: .remote),
                NetworkUsage(host: "8 public sites (Google, Cloudflare, Wikipedia, GitHub, Apple, DuckDuckGo, Bing, Reddit)",
                             purpose: "Browsing-mode page-load timing",
                             scope: .remote),
            ]
        case .netQuality:
            return [NetworkUsage(host: "Apple measurement servers",
                                 purpose: "Throughput and responsiveness test (/usr/bin/networkQuality); exact endpoint shown per run",
                                 scope: .remote)]
        case .wakeOnLAN:
            return [NetworkUsage(host: "LAN broadcast address (default 255.255.255.255, UDP port 9)",
                                 purpose: "Wake-up magic packet — stays on the local network",
                                 scope: .localOnly)]
        case .portListener:
            return [NetworkUsage(host: "any host (inbound only)",
                                 purpose: "Accepts incoming test connections on the bound local port; initiates no outbound traffic",
                                 scope: .remote)]
        case .ipGeolocation:
            return [NetworkUsage(host: "ipinfo.io",
                                 purpose: "Geolocation for the queried IP address",
                                 scope: .remote)]
        case .dnsResolver:
            return [NetworkUsage(host: "configured DNS resolvers",
                                 purpose: "Latency probe (dig apple.com) against each system resolver",
                                 scope: .remote)]
        case .subnet, .bandwidth, .interfaces, .wifi, .routes, .neighbors,
             .connections, .statistics, .sessionHistory, .compare:
            return []
        }
    }

    /// No `.remote` entries — safe to list as a local-only tool.
    var isLocalOnly: Bool {
        !networkUsage.contains { $0.scope == .remote }
    }
}

/// One row of the Privacy table: a single remote destination of a tool.
struct PrivacyRow: Identifiable, Hashable {
    let tool: Tool
    let usage: NetworkUsage

    var id: String { "\(tool.persistenceKey)-\(usage.host)" }
}

extension PrivacyRow {
    /// Remote destinations of the given tools, in tool order. Pure and
    /// testable — the Privacy pane renders exactly this.
    static func remoteRows(for tools: [Tool]) -> [PrivacyRow] {
        tools.flatMap { tool in
            tool.networkUsage.filter { $0.scope == .remote }.map { PrivacyRow(tool: tool, usage: $0) }
        }
    }

    /// Tools with no remote contact, in tool order.
    static func localOnlyTools(from tools: [Tool]) -> [Tool] {
        tools.filter(\.isLocalOnly)
    }
}
