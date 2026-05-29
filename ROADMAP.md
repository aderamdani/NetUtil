# NetUtil — Roadmap & Development Plan

> Last updated: 2026-05-29  
> Current version: 2.9.0  
> Based on full codebase audit and recent monitoring upgrades.

---

## Current Feature Inventory

| Tool | Core Capability | Status |
|------|----------------|--------|
| Mission Dashboard | Live aggregate "Mission Control" overview | ✅ Overhauled (v2.9.0) |
| Advanced Ping | RTT chart, stats, jitter, export | ✅ Shipped |
| Traceroute | Hops / Timeline / Map / Geo / bottleneck | ✅ Shipped |
| Multi-Ping | Concurrent ping sessions with sparklines | ✅ Shipped |
| Port Scanner | Preset/custom ranges, concurrency, ETA | ✅ Shipped |
| HTTP Latency | Waterfall chart (DNS/TCP/TLS/TTFB) | ✅ Shipped |
| DNS Lookup | dig-based, 8 record types, 4 server presets | ✅ Shipped |
| WHOIS | Parsed key/value display with filter | ✅ Shipped |
| SSL/TLS Inspector | Full chain, expiry countdown, TLS version | ✅ Shipped |
| Network Interfaces | getifaddrs, IPv4/IPv6/MAC/MTU/status | ✅ Shipped |
| Wi-Fi Inspector | RSSI/SNR/channel/band/security, sparkline | ✅ Shipped |
| Route Table | netstat -rn, flag tooltips, live filter | ✅ Shipped |
| Bandwidth Monitor | Aggregate 10min history, peak rates, card grid | ✅ Overhauled (v2.9.0) |
| Traffic Statistics | 30d history, interactive tooltips, CSV export | ✅ Overhauled (v2.9.0) |
| Speed Test | Nperf-style 4-tier test, history, verdicts | ✅ Shipped (v2.8.0) |
| Top Processes | Real-time per-process traffic (nettop) | ✅ Shipped |

---

## Recent Milestone: Monitoring & Visual Excellence (v2.9.0)
- **Interactive Dashboard**: High-fidelity aggregate traffic chart, system health gauges, and data-dense status cards.
- **Bandwidth Pro**: Session peak tracking, pause/resume, and clinical interface cards with IP details.
- **Statistics Pro**: Time-range filtering (7D/14D/30D), interactive tooltips, and detailed history activity bars.
- **Release Automation**: Standardized DMG building, version bumping, and automated documentation sync.

---

## Tier 1 — Feature Enhancements (v2.10.0)

| # | Task | Tool | Description |
|---|------|------|-------------|
| T1-1 | DNS Server Comparison | DNS | Parallel query across System/Google/Cloudflare/Quad9. |
| T1-2 | SSL Expiry Notifications | SSL | Background check for saved certs + local notifications. |
| T1-3 | Traceroute Code Split | Traceroute | Refactor 1200-line view into modular components (Map, Timeline, Table). |
| T1-4 | Bulk Host Import | Multi-Ping | Paste list of IPs/Hostnames into an import sheet. |
| T1-5 | Default Gateway Actions | Interfaces | Quick "Ping Gateway" or "Traceroute Gateway" buttons. |

---

## Tier 2 — New Tools & Advanced Logic (v3.0.0)

### Subnet Scanner
**Tool ID:** `subnetScan`  
- Input: CIDR notation (`192.168.1.0/24`)
- Concurrent ping sweep (64+ threads)
- Results: IP · Hostname · Status · RTT
- Quick actions to Ping/Port Scan alive hosts.

### mDNS / Bonjour Browser
**Tool ID:** `mdns`  
- Browse `_http`, `_ssh`, `_airplay`, etc.
- Resolve host/IP/Port on demand.
- Filter by service type.

---

## UX Consistency & "Anti-Slop" Mandates
- **No Font < 10pt**: Strictly enforced across all charts and badges.
- **Regular Material Only**: No fake opacity `Color.opacity()` for containers.
- **Monospaced Technical Data**: All IPs, ports, rates, and timestamps must use mono design.
- **Symmetry**: 12pt corner radius, 24pt main padding, 8pt grid system.

---

## Versioning History

| Version | Milestone |
|---------|-----------|
| **v2.9.0** | Monitoring & Visual Overhaul (Bandwidth, Statistics, Dashboard) |
| **v2.8.0** | Speed Test Persistence, Verdicts & History |
| **v2.7.0** | Speed Test initial release |
| **v2.0.0** | Swift 6 Migration & Native Charts Integration |
| **v1.x.x** | Foundation tools (Ping, Traceroute, Port Scan) |
