# NetUtil — Privacy

> Last updated: 2026-09-11
> App version: 4.13.1

---

## 1. Telemetry

NetUtil does **not** collect analytics, crash reports, or usage data. All diagnostics
run locally on this device. The only network traffic is the explicit queries you
initiate from the tools.

## 2. Sandbox Entitlement

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.network.client` | Outgoing TCP/UDP/ICMP connections required for diagnostics. No incoming listen entitlement is requested (Port Listener binds locally only). |

## 3. Per-Tool Network Usage

Every tool's network destinations are audited in `ToolNetworkUsage.swift`. The
Privacy pane (Settings > Privacy) renders this table directly from that model.

### Remote destinations

| Tool | Host / Destination | Purpose |
|------|-------------------|---------|
| Dashboard | ipinfo.io | Public IP + geolocation header/card |
| Doctor | system DNS resolver | Resolves `apple.com` for DNS test |
| Doctor | captive.apple.com | Captive-portal check (plain HTTP) |
| Doctor | www.apple.com | TLS connectivity probe (HTTPS HEAD) |
| Ping | user-specified host | ICMP echo (`/sbin/ping`) |
| Traceroute | user-specified host | Probe packets (`/usr/sbin/traceroute`) |
| Traceroute | ipinfo.io | Per-hop geolocation (only when enabled) |
| Multi-Ping | user-specified hosts | Concurrent ICMP echo |
| Port Scanner | user-specified host + ports | TCP connection attempts |
| Subnet Scanner | system DNS resolver | Reverse-DNS of discovered LAN addresses |
| HTTP Latency | user-specified URL | Timed HTTP/HTTPS request |
| Path MTU | user-specified host | Sized ICMP probes |
| DNS Lookup | chosen DNS server (System / 8.8.8.8 / 1.1.1.1 / 9.9.9.9) | `dig` query |
| SSL/TLS | user-specified host + port | TLS handshake + certificate inspection |
| WHOIS | WHOIS server (port 43) | Domain registration lookup |
| Speed Test | speed.cloudflare.com | Download / upload transfers |
| Speed Test | 1.1.1.1 | Gaming latency probes |
| Speed Test | 8 public sites | Browsing-mode page-load timing |
| Net Quality | Apple measurement servers | `/usr/bin/networkQuality` throughput + RPM |
| Wake on LAN | LAN broadcast (UDP 9) | Magic packet — stays on local network |
| Port Listener | any host (inbound only) | Accepts test connections; no outbound traffic |
| IP Geolocation | ipinfo.io | Geolocation for queried IP |
| DNS Resolver | configured DNS resolvers | Latency probe (`dig apple.com`) |

### Local-only tools

Dashboard (geolocation off), Subnet Scanner (LAN sweep only), Wake on LAN,
Bandwidth Monitor, Interfaces, Wi-Fi, Routes, Neighbors, Connections,
Statistics, Session History, Compare, and all pure-computation tools contact
no remote hosts.

## 4. Data Storage

| Data | Location | Retention |
|------|----------|-----------|
| Host history | `UserDefaults` | Up to 20 entries; cleared manually or on uninstall |
| Daily traffic totals | `UserDefaults` | 90-day rolling window |
| Session history | `UserDefaults` | Up to 200 records; max 20 with full detail |
| Favorites | `UserDefaults` | Up to 20 entries |
| Settings / tool availability | `UserDefaults` | Until cleared or app deleted |
| SSL watchlist | `UserDefaults` | Until cleared |

History and statistics are **excluded from Settings > Backup export by default**
and must be explicitly opted in.

## 5. Third-Party Services

| Service | Used by | Data sent |
|---------|---------|-----------|
| ipinfo.io | Dashboard, Traceroute, IP Geolocation | IP address (queried IP or your public IP) |
| Apple `networkQuality` | Net Quality | No account; measurement endpoint chosen by macOS |
| System `whois` (port 43) | WHOIS | Queried domain / IP |
| Cloudflare (`speed.cloudflare.com`) | Speed Test | No account; standard HTTP transfer |
| 8 public sites | Speed Test (Browsing mode) | Standard HTTPS page loads |

No API keys, cookies, or persistent identifiers are sent.

## 6. Update Checks

Update checks are **manual only** (Settings > General > Check for Updates).
No automatic phone-home.

## 7. User Controls

- **Geolocation toggle**: Settings > Privacy > "Look up IP locations in Traceroute"
  — disables all ipinfo.io traffic from Traceroute.
- **Host history clear**: Settings > Privacy > Clear (removes saved hostnames/IPs).
- **Settings backup**: export/import with explicit opt-in for history and statistics.
