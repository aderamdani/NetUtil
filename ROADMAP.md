# NetUtil — Roadmap & Development Plan

> Last updated: 2026-05-31
> Current version: 4.5.0

---

## Current Feature Inventory

| Tool | Core Capability | Status |
|------|----------------|--------|
| Dashboard | Live mission control: sparklines, CPU/RAM, VPN, gateway, health bar, uptime | Optimized (v4.4.0) |
| Ping | RTT chart, jitter, distribution, health strip, audio feedback | Optimized (v4.3.0) |
| Traceroute | Hops / Timeline / Map / Raw, geo, bottleneck, host history | Optimized (v4.3.0) |
| Multi-Ping | Concurrent sessions, sparklines, bulk import, PDF report | Optimized (v4.3.0) |
| Port Scanner | Preset/custom ranges, concurrency, ETA, PDF/CSV export | Optimized (v4.3.0) |
| HTTP Latency | Waterfall chart (DNS/TCP/TLS/TTFB), history, PDF/CSV export | Optimized (v4.3.0) |
| Subnet Scanner | CIDR sweep, ARP enrichment, hostname, MAC, context menu actions | Optimized (v4.3.0) |
| Subnet Calc | CIDR math, wildcard, class, binary mask | Optimized (v4.3.0) |
| DNS Lookup | dig-based, 8 record types, 4 resolver presets, PDF/CSV export | Optimized (v4.3.0) |
| SSL/TLS Inspector | Full chain, expiry watchlist, notifications, PDF export | Optimized (v4.3.0) |
| WHOIS | Parsed key/value, filter, PDF/CSV export | Optimized (v4.3.0) |
| Bandwidth Monitor | Live RX/TX chart, per-interface sparklines, pause/resume | Optimized (v4.3.0) |
| Traffic Statistics | 90-day history, daily totals bar chart, CSV export | Optimized (v4.3.0) |
| Speed Test | 4-tier (Speed/Browsing/Gaming/Streaming), history, PDF/CSV | Optimized (v4.3.0) |
| Top Processes | Real-time per-app network intensity via nettop | Optimized (v4.3.0) |
| Interfaces | getifaddrs, IPv4/IPv6/MAC/VLAN detection, gateway actions | Optimized (v4.3.0) |
| Wi-Fi | RSSI stability chart, SNR, channel, CoreWLAN | Optimized (v4.3.0) |
| Routes | netstat -rn, protocol matrix, flag legend | Optimized (v4.3.0) |

**Total: 17 tools (16 diagnostics + Dashboard)**

---

## Recent Milestones

### Version 4.5.0 — Polish & Consistency (2026-05-31)
- 153-check UX audit: 17 tools × 9 criteria, 14 fixes, zero remaining violations
- Mood bars added to 6 missing tools (Multi-Ping, HTTP Latency, DNS, Bandwidth, Statistics, Speed Test)
- Report menus (CSV export) added to 4 missing tools (Top Processes, Interfaces, Wi-Fi, Routes)
- StatisticsView charts: `drawingGroup()` + explicit `chartYScale` headroom
- Multi-Ping expanded sparkline: index-based X-axis with #N sequence labels

### Version 4.4.0 — Dashboard Enhancement & Quality Fixes (2026-05-31)
- Dashboard: live data in Traceroute, SSL, HTTP Latency, DNS, WHOIS cards
- Dashboard: Speed Test + Subnet Scanner cards added (with sparklines)
- Dashboard: Network Health Summary Bar (SSL/Ping/Wi-Fi status)
- Dashboard: RAM GB subtitle + CPU/RAM `.help()` tooltips + app uptime counter
- Ping chart: external tooltip (no clipping), tight X scale, sequence X-axis labels
- PDF export: fixed blank output in dark mode (explicit colors + forced aqua appearance)
- `SSLWatchlist` centralized in ToolStore; DNS/WHOIS VMs track `lastQuery`

### Version 4.3.0 — Bug Fixes & Bandwidth Monitor (2026-05-31)
- Bandwidth Monitor: full live UI replacing placeholder (60s chart, per-interface sparklines, pause/resume)
- Traceroute: host history dropdown added (matches Ping/DNS/HTTP Latency pattern)
- Chart Y-axis label clipping: fixed across all charts via explicit `chartYScale(domain:)` headroom
- Port Scanner + WHOIS PDF exports implemented
- Release build: zero warnings, zero errors (Swift 6 concurrency fixes)

### Version 4.2.0 — Subnet Scanner Quick Actions (2026-05-31)
- Subnet Scanner context menu: right-click Alive host → Ping, Port Scan, or Traceroute
- Navigates to target tool with scan already running

### Version 4.1.0 — Speed Test Full UI (2026-05-31)
- Speed Test: complete implementation replacing the placeholder view
- 4-kind segmented selector, live metric cards, progress, history table, PDF/CSV export

### Version 4.0.1 — Export Implementation & HIG Fixes (2026-05-31)
- All PDF/CSV export stubs implemented (7 PDF methods, 4 CSV functions)
- SSLInspectorView watchlist @State bug fixed
- SubnetScanView force unwrap fixed
- Anti-Slop: regularMaterial applied to remaining fake-opacity containers

### Version 4.0.0 — Tier 1 Feature Drop (2026-05-31)
- Subnet Scanner (Tier 2): concurrent CIDR sweep, ARP, hostname, MAC, CSV/PDF
- DNS Server Comparison (T1-1): parallel 4-resolver comparison
- SSL Expiry Watchlist (T1-2): background monitoring + macOS notifications
- Bulk Host Import (T1-4): paste/import lists into Multi-Ping
- Default Gateway Actions (T1-5): Ping/Traceroute from Interfaces view

### Version 3.5.1 (2026-05-31)
- Documentation & Wiki sync; QA clinical test cases refinement

### Version 3.5.0 — Performance & Accessibility (2026-05-31)
- @Observable migration, view decomposition, GPU chart rendering
- VoiceOver audit, native Xcode test target, Swift 6 strict concurrency

---

## Tier 1 — Feature Enhancements

| # | Task | Tool | Status |
|---|------|------|--------|
| T1-1 | DNS Server Comparison | DNS | Done (v4.0.0) |
| T1-2 | SSL Expiry Notifications | SSL | Done (v4.0.0) |
| T1-3 | Traceroute Code Split | Traceroute | Done (v3.0.0) |
| T1-4 | Bulk Host Import | Multi-Ping | Done (v4.0.0) |
| T1-5 | Default Gateway Actions | Interfaces | Done (v4.0.0) |

---

## Tier 2 — New Tools & Advanced Logic

### Subnet Scanner
**Status:** Done (v4.0.0)
- CIDR notation input, concurrent ping sweep
- ARP enrichment, hostname resolution, MAC address detection
- CSV/PDF export, context menu quick actions (v4.2.0)

### mDNS / Bonjour Browser
**Tool ID:** `mdns` | **Status:** Removed — out of scope for core diagnostics

---

## UX Consistency & "Anti-Slop" Mandates

- **No Font < 10pt**: Strictly enforced across all charts, badges, and axis labels.
- **Regular Material Only**: No fake opacity `Color.opacity()` for card/container backgrounds.
- **Monospaced Technical Data**: All IPs, ports, rates, timestamps use monospaced design.
- **8pt Grid**: All spacing multiples of 4 or 8. Card corner radius 8–12pt only.
- **Chart Headroom**: All charts with visible Y-axis labels use explicit `chartYScale(domain:)` with 1.2–1.25× headroom to prevent label clipping with `drawingGroup()`.

---

## Versioning History

| Version | Milestone |
|---------|-----------|
| **v4.5.0** | Full 153-check UX audit: mood bars (6 tools), report menus (4 tools), chart fixes, Multi-Ping sparkline index labels |
| **v4.4.0** | Dashboard live data cards, health summary bar, gauge enhancements, uptime counter, Ping chart fixes, PDF dark mode fix |
| **v4.3.0** | Bandwidth Monitor full UI, Traceroute history, chart fixes, Swift 6 clean |
| **v4.2.0** | Subnet Scanner context menu quick actions |
| **v4.1.0** | Speed Test full UI implementation |
| **v4.0.1** | Export implementation, HIG/Anti-Slop fixes |
| **v4.0.0** | Subnet Scanner, DNS Comparison, SSL Watchlist, Bulk Import, Gateway Actions |
| **v3.5.1** | Documentation sync |
| **v3.5.0** | Performance, Accessibility & Build Optimization |
| **v3.4.0** | Observation Framework Migration |
| **v3.3.0** | Comprehensive UI/UX Refinement & Testing Infrastructure |
| **v3.2.0** | High-Performance Ping Engine |
| **v3.1.0** | Fixed Headers & Packet Size Control |
| **v2.9.0** | Monitoring & Visual Overhaul (Bandwidth, Statistics, Dashboard) |
| **v2.8.0** | Speed Test Persistence, Verdicts & History |
| **v2.7.0** | Speed Test, Top Processes, Traffic Statistics initial release |
| **v2.0.0** | Swift 6 Migration & Native Charts Integration |
| **v1.x.x** | Foundation tools (Ping, Traceroute, Port Scan) |
