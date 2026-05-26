# Changelog

All notable changes to NetUtil are documented here.

---

## [1.2.0] — 2026-05-26

### Added
- **Enhanced Ping Feature**: Complete overhaul of the Ping tool.
- **Data Tracking**: Auto IP resolution, RTT distribution analysis, and timeout sequence tracking.
- **Audio Feedback**: "Beep on Loss" toggle for audible alerts during packet loss.
- **Auto-Stop Logic**: Configurable safety mechanism to stop pinging after consecutive timeouts.
- **Packet Size Control**: New input field for custom ICMP payload size (`-s`).
- **Copy Summary**: Quick-share summary (Sent/Recv/Loss/RTT) via the Export menu.

### Changed
- **Modern UI**: Grid-based `StatCard` layout with icons and descriptive tooltips.
- **Advanced Visualization**: RTT chart now includes loss bars, gradient areas, and distribution bar.
- **User Guidance**: Added detailed "Help Popups" (tooltips) for all UI controls and metrics.
- **Clarity**: Renamed technical terms (e.g., `icmp_seq` → `Packet No.`, `Interval` → `Delay`) for easier understanding.

---

## [1.1.0] — 2026-05-26

### Added
- Custom DMG background with branded installer layout
- `build_dmg.sh` build script with auto-versioning from git tags
- `generate_background.swift` for programmatic DMG background generation
- Auto-scroll in Ping results table — always shows latest entry
- Return key auto-run on all host/URL input fields

### Changed
- HelpView, AboutView, and README updated with complete accurate content

### Fixed
- Sidebar navigation broken by `.badge()` + `.tag()` interaction
- Active-tool ViewModels now persist across sidebar navigation — running pings, traceroutes, etc. continue when switching tools

---

## [1.0.0] — 2026-05-26

### Added

**Active Probing**
- **Ping** — live RTT chart, min/avg/max/jitter/loss%, configurable count and interval, color-coded thresholds
- **Traceroute** — hop table, path summary strip (hop count, last host, last RTT, avg path loss), optional geolocation via ipinfo.io
- **Multi-Ping** — concurrent sessions to unlimited hosts, live sparklines, AppStorage RTT thresholds, sessions persist when navigating
- **Port Scanner** — Common / Well-known / All / Custom ranges, configurable concurrency + timeout, CSV export
- **HTTP Latency** — DNS / TCP / TLS / TTFB / Download phase breakdown, history table, Run Again button

**Lookup**
- **DNS Lookup** — A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, color-coded output, export
- **WHOIS** — parsed key/value display, comment dimming, export
- **SSL/TLS Inspector** — full certificate chain, TLS version + cipher suite badges, expiry countdown, SANs, SHA-256 fingerprint

**Network Info**
- **Network Interfaces** — all interfaces, IPv4/IPv6/MAC/MTU, auto-refresh every 3 s
- **Wi-Fi Inspector** — SSID/BSSID/channel/security, RSSI/SNR, RSSI history sparkline, SNR color coding (green/orange/red)
- **Route Table** — IPv4 + IPv6, flag descriptions, live text filter
- **Bandwidth Monitor** — per-interface RX/TX rate, 60 s rolling area chart with smooth interpolation

**Architecture**
- All ViewModels `@MainActor`-isolated
- `Process + Pipe` for live-streaming CLI output to UI
- Zero third-party dependencies
- Native SwiftUI throughout, macOS 15+ minimum target
