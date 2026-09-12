# NetUtil — Roadmap & Development Plan

> Last updated: 2026-09-12
> Current version: 4.14.0

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
| Interfaces | getifaddrs, IPv4/IPv6/MAC/VLAN detection, gateway actions | Optimized (v4.3.0) |
| Wi-Fi | RSSI stability chart, SNR, channel, CoreWLAN | Optimized (v4.3.0) |
| Routes | netstat -rn, protocol matrix, flag legend | Optimized (v4.3.0) |
| Session History | Auto-logged sessions (ping/traceroute/port scan), filters, PDF/CSV | Active |
| Compare | Side-by-side comparison of logged sessions per tool | Active |
| Net Quality | Apple networkQuality wrapper: RPM responsiveness/bufferbloat under load | New (v4.9.0) |
| Wake on LAN | UDP magic-packet sender (BSD socket, broadcast) | New (v4.9.0) |
| Doctor | Layered fault isolation: router → DNS → internet → TLS, captive-portal detection | New |
| Path MTU | Don't-fragment ping binary search for effective MTU | New |
| Neighbors | ARP table viewer (devices on the local network) | New |
| Connections | Open TCP/UDP sockets per process (lsof) | New |
| Port Listener | Inbound reachability test via NWListener | New |
| IP Geolocation | Country/city/ISP/ASN lookup for any IP, with map | New |
| DNS Resolver | Live `scutil --dns` resolver list with per-server latency | New |

**Total: 28 tools (27 diagnostics + Dashboard)**

Multi-Ping additionally gained threshold-based latency alert notifications.

---

## Recent Milestones

### Version 4.14.0 — Onboarding, Chart Accessibility & Token Sweep (2026-09-12)

- First-run onboarding sheet (`hasCompletedOnboarding` in `ContentView`), privacy-forward, pointing to Settings > Privacy.
- VoiceOver chart descriptors (`AXChartDescriptor`) on Ping, Bandwidth aggregate, Wi-Fi RSSI, and Multi-Ping slot charts, each backed by a pure summary function under test.
- SystemMonitor lifecycle owned solely by `ToolStore` (no self-start); cadence via `normalInterval` (2s) / `backgroundInterval` (10s).
- UI token sweep: corner radii and stack spacing moved to `Metrics.*`, unified control-bar header padding, off-grid padding curated — locked in by `hig-lint.sh` (H2/H5/H6/H7), run manually before each commit.
- Distribution: manual DMG release, Homebrew tap (`aderamdani/tap`), and a README Screenshots section.

### Version 4.13.1 — Control Bar + String Polish (2026-09-11)
- Multi-Ping control bar standardized to the Ping/Traceroute pattern: new `MultiPingControlBar` (host input + Add Host + favorite + report + help), with sort/import/alert controls in a secondary row.
- String-fusion sweep across all tool views: fixed glued units in dashboard jitter card and SSL copy summary; audited interpolations for VoiceOver-safe spacing.
- VoiceOver/MoodBar strings for Multi-Ping, Traceroute, Ping, and SSL extracted to testable pure functions.

### Version 4.13.0 — Zero-Idle Monitoring + Tool Catalog + Privacy + Backup (2026-09-11)
- Zero-idle monitoring tier: an occluded app with no live consumer stops all app-lifetime pollers; resume lump-captures raw byte deltas so daily totals stay exact.
- Modular tool catalog: stable `persistenceKey` per tool, `ToolGroup` sections, `ToolCatalog` availability in Settings > Tools with dashboard fallback; legacy session key migrated on load.
- Permission transparency: audited `Tool.networkUsage` per tool; Settings > Privacy shows remote-connections table and local-only list.
- Export/Import Settings: versioned JSON backup of preference whitelist plus tool availability, favorites, and SSL watchlist.

### Version 4.12.0 — Verdict Cards + HIG Standardization (2026-09-11)
- Verdict/rating cards across Ping (Connection Quality), Traceroute (Path Verdict), Speed Test, Net Quality, and HTTP Latency with plain-language suitability advice.
- Layperson explanations for Wi-Fi (signal rating + channel advice), DNS Resolver, and Interfaces.
- Apple HIG standardization pass over Dashboard, Doctor, Ping, Traceroute, and Session History: semantic typography, 8pt-grid spacing, consistent corner radii and badges.
- PDF report tables rebuilt with dynamic column widths and proper header rows.

### Version 4.11.2 — Docs & Architecture (2026-09-11)
- `docs/ARCHITECTURE.md`: comprehensive codebase reference (directory structure, ToolStore, 28 tools, subprocess patterns, concurrency, persistence, export).
- `docs/CONTRIBUTING.md`: expanded with architecture context, code style rules, PR checklist, testing requirements.
- `AGENTS.md` updated with ARCHITECTURE.md reference.

### Version 4.11.1 — Dashboard System Cards + Settings Resurrection (2026-08-18)
- Dashboard "System & Security" section: Connectivity Doctor, Net Quality, Port Listener, Connections, Neighbors, Session History cards.
- Menu-bar traffic label toggle (`↓`/`↑` live rate).
- Previously dead preferences now read: `pingAutoStopLimit`, `maxRawLines`, HTTP/SSL timeouts, `bandwidthInterval`.
- Ping RTT-high alerts use rolling 20-ping window.

### Version 4.11.0 — IP Geolocation + DNS Resolver (2026-07-23)
- IP Geolocation: country/city/ISP/ASN/map position for any IP, Dashboard live card.
- DNS Resolver: live `scutil --dns` resolver list with per-server latency.
- Tool count: 28 (27 diagnostics + Dashboard).

### Version 4.10.0 — Six New Tools (2026-07-22)
- Connectivity Doctor, Path MTU, Neighbors, Connections, Port Listener, Wake on LAN.
- Multi-Ping latency alerts (macOS notifications, rate-limited).
- 32 new tests (118 total at this release).

### Version 4.9.0 — Net Quality + Wake on LAN + Swift 6 Real (2026-07-22)
- Net Quality: `networkQuality` wrapper for RPM/bufferbloat grading.
- Wake on LAN: UDP magic-packet broadcast.
- Learning guide completed for all 21 tools.
- Swift 6 strict concurrency enforced (`SWIFT_STRICT_CONCURRENCY = complete`).
- Component adoption: shared `MoodBar`, `ToolStateView`, `ToolControlBar`, `SubprocessRunner`.

---

## Forward Roadmap (from docs/IMPROVEMENTS.md)

### Shipped in v4.14.0 — HIG Hardening & Accessibility

- Automated HIG regression lint (run manually) — P0-1 (font, corner-radius, spacing, grid-padding checks).
- Chart accessibility descriptors for VoiceOver — P1-1 (Ping, Bandwidth, Wi-Fi RSSI, Multi-Ping).
- Also shipped: first-run onboarding, zero-idle SystemMonitor ownership, and a full UI token sweep.

### Next — carried over from v4.14.0 scope

- Unified `ClinicalErrorBanner` component (P1-2).
- Live-filter on Ping / Traceroute result tables (P1-3).

### v4.15.0 — Export & Settings Polish (Q4 2026)
- PDF table header repeat on every page (P1-4).
- Settings search (P1-5).
- Batch export (PDF + CSV) (P1-6).
- Exporter unit tests (P1-7).

### v5.0.0 — Platform Expansion (2027)
- CLI companion tool (`netutil ping <host>`, `netutil speed`) (P2-5).
- Menu-bar only mode via `MenuBarExtra` (P2-6).
- Refactor `Exporter` + subprocess runners into reusable `NetUtilCore` framework.
- Evaluate SPM distribution for the core framework.

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
| **v4.14.0** | Onboarding, VoiceOver chart descriptors, zero-idle SystemMonitor ownership, UI token sweep + HIG lint, Homebrew tap |
| **v4.13.1** | Multi-Ping control bar, string-fusion sweep, VoiceOver pure functions |
| **v4.13.0** | Zero-idle monitoring, modular tool catalog, privacy pane, settings backup |
| **v4.12.0** | Verdict cards (Ping/Traceroute/Speed/HTTP/NetQuality), layperson explanations, HIG standardization, PDF table rebuild |
| **v4.11.2** | Architecture docs, contributing guide, agent instructions update |
| **v4.11.1** | Dashboard system cards, menu-bar traffic label, settings resurrection, rolling RTT alerts |
| **v4.11.0** | IP Geolocation, DNS Resolver |
| **v4.10.0** | Connectivity Doctor, Path MTU, Neighbors, Connections, Port Listener, Wake on LAN |
| **v4.9.0** | Net Quality, Wake on LAN, learning guide completed, Swift 6 strict concurrency, component adoption |
| **v4.8.2** | Deadlock fix, route flag case, race fix, battery fix, ViewModel standardization, shared components |
| **v4.8.1** | App icon redesign |
| **v4.8.0** | Session History everywhere, Compare for all tools, mood bars everywhere, keyboard shortcuts |
| **v4.7.5** | Stability, CPU, consistency audit: subprocess hygiene, export stubs, CSV unification |
| **v4.7.4** | Idle CPU fixes (Dashboard ticker, Speed Test streaming) |
| **v4.7.3** | Ping-infinite CPU fix |
| **v4.7.2** | Battery optimization: window-occlusion pause/resume |
| **v4.7.1** | Dead code removal, Liquid Glass final migration |
| **v4.7.0** | Liquid Glass design system adoption, Metrics extraction |
| **v4.6.x** | Performance sweeps (CPU, memory, timers) |
| **v4.5.0** | Full 153-check UX audit: mood bars, report menus, chart fixes |
| **v4.4.0** | Dashboard live data cards, health summary bar, gauge enhancements |
| **v4.3.0** | Bandwidth Monitor full UI, Traceroute history, chart fixes |
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
