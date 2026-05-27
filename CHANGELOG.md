# Changelog

All notable changes to NetUtil are documented here.

---

## [1.8.2] — 2026-05-27

### Changed
- **Global UI Standardization**: Completely refactored Ping, Multi-Ping, Traceroute, Port Scanner, and HTTP Latency to share an identical, symmetrical interface layout.
- **Fixed Headers**: Tool control bars are now locked at the top of the window, preventing layout shifts when analysis results populate.
- **Unified Reporting & History**: "Clear History" options and standardized PDF Report buttons are now consistently available across all major tools.
- **Modernized Port Scanner**: Replaced the legacy port table with a modern, responsive Mini-Card grid system for better readability.

---

## [1.8.1] — 2026-05-27

### Added
- **Multi-Ping Custom Aliases**: Added a new "Alias Name" column at the leftmost position, allowing users to provide meaningful labels (e.g., "Main Server") for each endpoint.
- **Alias Sorting**: Integrated Alias Name into the sorting engine, allowing for alphabetical organization of customized host lists.

### Improved
- **Smart Focus Management**: Implementing `@FocusState` in Multi-Ping to automatically release keyboard focus after renaming an alias, preventing persistent insertion pointers.
- **Table Reorganization**: Repositioned columns for better visual hierarchy, prioritizing Custom Aliases as the primary row identity.

---

## [1.8.0] — 2026-05-27

### Added
- **Enterprise Multi-Ping**: Major upgrades for infrastructure-scale monitoring.
    - **Drill-Down Detail Chart**: Expand any host row to view its full RTT history chart without leaving the screen.
    - **Consolidated PDF Report**: Generate a professional, unified report for all monitored hosts in one document.
- **Unified Learning System**: Standardized "Learning Guide" sheets across Ping, Multi-Ping, and Traceroute to help users understand network metrics.

### Improved
- **Premium Reporting Engine**: Standardized PDF designs across all tools with consistent headers, app branding, and timestamped filenames.
- **Ping UX Refinement**: 
    - Fixed auto-scroll to be 100% reliable using a robust ScrollViewReader engine.
    - Improved Stop button visibility and icon contrast.
    - Replaced timeout alert sound with a more modern and subtle "Tink" sound.
- **Global Typography**: Standardized all UI elements to pure San Francisco (SF) Pro.

---

## [1.7.2] — 2026-05-27

### Added
- **Premium PDF Diagnostics**: Branded PDF reports for Ping with app logo, detailed stats, and automatic timestamping.
- **Visual Intelligence**: 
    - **Health Strip**: GitHub-style 100-packet stability bar for instant quality assessment.
    - **Smart Interpretation**: Logic-driven connection quality summary (Excellent/Stable/Congested).

### Improved
- **Interactive Graphs**: Horizontal scrolling enabled for RTT charts to browse historical data.
- **Auto-Scroll Engine**: Definitively fixed real-time table scrolling using a robust `ScrollViewReader` implementation.
- **Global UI Overhaul**:
    - Standardized all typography to San Francisco (SF) Pro for a pure macOS aesthetic.
    - Enhanced visual depth with stronger, multi-layered card shadows.
    - Refined global whitespace and padding for a cleaner, "breathable" interface.
- **Traceroute Restoration**: Fully restored and enhanced premium components (`IPInfoCard`, `TimelineView`, `HopDetailChart`).

---

## [1.7.1] — 2026-05-27

### Added
- **Modernized Welcome Screen**: The `AboutView` is now the default screen when no tool is selected, providing a premium onboarding experience.

### Improved
- **Visual Depth**: Significantly strengthened card shadows across the Dashboard for better contrast and a modern "elevated" feel.
- **Typography Standardisation**: Standardized all Dashboard fonts to San Francisco (SF) Pro for a cleaner, unified macOS aesthetic.
- **Layout Refinement**: Increased whitespace and adjusted spacing to resolve previous overcrowding issues, ensuring a breathable UI.

---

## [1.7.0] — 2026-05-27

### Added
- **Real-time System Monitoring**: Integrated CPU load and RAM pressure tracking directly into the Dashboard header.
    - Uses Darwin kernel APIs for high-accuracy live measurement.
    - Color-coded badges for instant health assessment.
- **Educational Tooltips**: Comprehensive networking tooltips added across the Dashboard to help beginners understand technical terms (Latency, RSSI, IP Classes, etc.).

### Improved
- **UI Proportionality Overhaul**: Fixed oversized fonts and scaled down Dashboard elements for a more balanced and professional macOS feel.
- **Symmetry & Grid Layout**: Redesigned Dashboard cards with uniform heights and perfectly aligned grids.
- **Sparkline Refinement**: Adjusted mini-charts to be more concise and visually integrated within metric views.

---

## [1.6.0] — 2026-05-27

### Improved
- **Dashboard UI/UX Overhaul**: Major refactoring for better clarity and neatness.
    - **Hero Header**: Enhanced visual hierarchy with a bolder "Network Overview" and localized system hostname.
    - **Refined Identity Bar**: More distinct, color-coded badges for Local IP, Public IP, and VPN Status with improved spacing.
    - **Standardized Card Layout**: Unified padding and corner radius across all dashboard cards for a cleaner look.
    - **Informational Descriptions**: Added clear descriptions to each dashboard section to guide the user.
    - **Advanced Metric Visualization**: New `MetricView` component for consistent and readable data points (Latency, Loss, Signal).
    - **Enhanced Sparklines**: Thicker strokes and smoother gradients for real-time trend charts.
    - **Smooth Interactions**: Refined hover animations and pulse indicators for a more premium "native" feel.

---

## [1.5.0] — 2026-05-27

### Added
- **Ultra-Interactive Dashboard**: A new high-level "Mission Control" center for the entire app.
    - **Quick Action Buttons**: Start/Stop Ping, Multi-Ping, and Port Scans directly from the Dashboard.
    - **Live Sparklines**: Real-time RTT and Wi-Fi signal (RSSI) trend charts using high-performance Canvas.
    - **Network Identity Header**: Instant view of Hostname, Local IP, External IP, and VPN Status.
    - **IP Intelligence**: Integrated analysis for IP Class (A/B/C), Public/Private status, and Netmask detection.
    - **Interactive Navigation**: Click any dashboard card to jump directly to the detailed tool view.
    - **System Health Badges**: Live CPU load and Memory pressure indicators.
- **Enhanced Network Discovery**: Updated network interface logic to capture kernel-level netmask and prefix info.
- **Community Standards**: Added official `LICENSE` (MIT), `CONTRIBUTING.md`, and `SECURITY.md`.

### Improved
- **Modernized Help System**: Redesigned `HelpView` with categorized sections and documentation for all v1.4.0 features.
- **Visual Feedback**: Added animated pulse indicators, hover scaling, and glossy glassmorphism effects.
- **Architecture**: Centralized network state management in `ToolStore` for better synchronization.

---

## [1.3.0] — 2026-05-26

### Fixed
- **Force close on Interfaces and Wi-Fi tools**: Moving `WiFiInspectorViewModel` and `NetworkInterfaceViewModel` into `ToolStore` introduced an `@EnvironmentObject` pattern that SwiftUI couldn't resolve at runtime (only `ToolStore` itself was injected, not the child VM types). Reverted to `@ObservedObject` with VM passed as an init parameter — consistent with all other tools.

### Changed
- `AboutView` tool list now includes Dashboard and updated acknowledgements (MapKit, CoreLocation, Swift Charts).
- `HelpView` Traceroute section expanded with Route Map, Bottleneck Detection, and IP Info Card topics.
- README and DOCUMENTATION.md updated to reflect v1.4.x feature set.

---

## [1.5.0] — 2026-05-27

### Added
- **Dashboard**: New home screen with live overview cards for all active tools — Ping session stats, Multi-Ping host count/loss, Port Scan progress, Wi-Fi SSID/RSSI, Network Interfaces summary, Bandwidth, and quick-access to DNS/SSL.
- **Traceroute — Route Map**: New "Map" view mode with MapKit-powered pins per geo-tagged hop, `MapPolyline` connecting hops in order, and tap-to-inspect integration.
- **Traceroute — Smart Bottleneck Detection**: Automatically flags hops where RTT delta exceeds 30 ms vs. previous hop (and avg > 50 ms). "Bottleneck" badge shown in hop rows, map pins, summary strip, and IP Info Card.
- **Traceroute — IP Info Card**: ⓘ button per hop opens a detail sheet showing Private/Public IP badge, full geo (flag/city/country/ISP/hostname/timezone/postal/coordinates), performance grid (Avg/Min/Max RTT, Jitter, Loss, Sent), and bottleneck warning.
- **ROADMAP.md**: Comprehensive development roadmap documenting planned features across v1.3.1 → v1.6.0.

### Changed
- `WiFiInspectorViewModel` and `NetworkInterfaceViewModel` moved into `ToolStore` — these tools now persist state across sidebar navigation.
- `NetworkInterfaceView` and `WiFiInspectorView` use `@EnvironmentObject` instead of creating local `@StateObject` instances.
- `HelpView` updated with Dashboard section and revised Traceroute docs covering Timeline View, Route Health, Bottleneck detection, and IP Info Card.
- Traceroute mode picker widened to accommodate Map tab (320 pt).

---

## [1.3.0] — 2026-05-26

### Added
- **Traceroute Timeline View**: PingPlotter-style stacked hop rows with Canvas-drawn RTT bars; tap any hop to expand a detail chart.
- **Route Health Banner**: Automatic Critical/Degraded/Healthy assessment based on consecutive packet loss and worst hop RTT across the entire path.
- **Column Guide**: Help sheet explaining every table column and a "How to Read Traceroute Results" guide.
- **Jitter per Hop**: Standard deviation of RTT samples shown in a new Jitter column (color-coded green/orange/red).
- **Consecutive Loss Badge**: Warning icon appears on any hop with 3+ consecutive timeouts.
- **Copy per Hop**: Copy button in each hop row copies host, geolocation, avg RTT, loss, and jitter to clipboard.
- **Column Tooltips**: `.help()` text on all table column headers.

### Changed
- Traceroute view mode picker: Hops / Timeline / Raw (replaces single table view).
- `HopDetailChart` now includes dashed `RuleMark` threshold lines (warn / crit).

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
