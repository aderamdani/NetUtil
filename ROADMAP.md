# NetUtil — Roadmap & Development Plan

> Last updated: 2026-05-29  
> Current version: 3.0.0  
> Based on full project-wide "Apple Artisan" overhaul.

---

## Current Feature Inventory

| Tool | Core Capability | Status |
|------|----------------|--------|
| Mission Dashboard | Live aggregate "Mission Control" overview | ✅ Overhauled (v3.0.0) |
| Advanced Ping | RTT chart, stats, jitter, distribution | ✅ Overhauled (v3.0.0) |
| Traceroute | Hops / Timeline / Map / Geo / bottleneck | ✅ Refactored (v3.0.0) |
| Multi-Ping | Concurrent ping sessions with sparklines | ✅ Overhauled (v3.0.0) |
| Port Scanner | Preset/custom ranges, concurrency, ETA | ✅ Overhauled (v3.0.0) |
| HTTP Latency | Waterfall chart (DNS/TCP/TLS/TTFB) | ✅ Overhauled (v3.0.0) |
| DNS Lookup | dig-based, 8 record types, resolver presets | ✅ Overhauled (v3.0.0) |
| WHOIS | Parsed key/value display with filters | ✅ Overhauled (v3.0.0) |
| SSL/TLS Inspector | Full chain, expiry tracking, security audit | ✅ Overhauled (v3.0.0) |
| Network Interfaces | getifaddrs, IPv4/IPv6/MAC/VLAN detection | ✅ Overhauled (v3.0.0) |
| Wi-Fi Inspector | RSSI stability chart, SNR, radio band | ✅ Overhauled (v3.0.0) |
| Route Table | netstat -rn, protocol matrix, tooltips | ✅ Overhauled (v3.0.0) |
| Bandwidth Monitor | Aggregate 10min history, peak rates | ✅ Overhauled (v3.0.0) |
| Traffic Statistics | 30d history, interactive tooltips, CSV export | ✅ Overhauled (v3.0.0) |
| Speed Test | Nperf-style 4-tier test, history, verdicts | ✅ Overhauled (v3.0.0) |
| Top Processes | Real-time intensity bars (nettop) | ✅ Overhauled (v3.0.0) |

---

## Recent Milestone: Version 3.0.0 "Artisan"
- **Project-Wide Consistency**: Standardized UI across all tools using native materials and semantic typography.
- **Data-Dense Engineering**: Integrated clinical, monospaced data visualization everywhere.
- **Architectural Cleanup**: Traceroute refactored into modular components.
- **Professional Reports**: Synchronized CSV/PDF reporting capabilities.

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
