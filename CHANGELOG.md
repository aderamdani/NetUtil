# Changelog

All notable changes to NetUtil are documented here.

---

## [2.2.0] — 2026-05-27

### Added
- **Global Search (⌘F)**: Integrated a fast history search in the sidebar. Instantly find and reuse previous target hosts or domains across the entire toolkit.
- **Keyboard Navigation Shortcuts**: Added `Cmd+1` through `Cmd+9` support for instant switching between primary diagnostic tools.
- **Sidebar Activity Indicators**: Introduced pulsing green dots in the sidebar for tools actively running background tasks (Ping, Traceroute, etc.).
- **Total Tool Standardization**: Completed the symmetrical UI overhaul for the remaining tools: Wi-Fi Inspector, Network Interfaces, Bandwidth Monitor, Routing Table, and WHOIS.

### Improved
- **Passive Tool Headers**: Added visual anchors and locked control bars to informational tools to maintain zero layout-shift during navigation.
- **Enhanced WHOIS & Wi-Fi Views**: Redesigned output formatting and stats bars for better technical clarity and professional aesthetics.

---

## [2.1.0] — 2026-05-27

### Added
- **Global UI Symmetry**: Completely standardized the layout of Ping, Multi-Ping, Traceroute, Port Scanner, and HTTP Latency. Every tool now shares an identical header and information hierarchy.
- **Interpretation Mood Header**: Added an automated status interpretation bar (icon + description) for all diagnostic tools to help users understand results instantly.
- **Port Mini-Card System**: Replaced the legacy Port Scanner table with a modern grid of interactive status cards.

### Improved
- **Locked Control Bars**: All tool headers are now fixed at the top, ensuring stability while results scroll underneath.
- **Universal History Management**: Added persistent host/URL history and "Clear History" options to every input form in the application.

---

## [2.0.1] — 2026-05-27

### Fixed
- **In-App Updater**: Replaced unreliable bash script installer (broken `hdiutil mount`, missing permissions) with a clean `NSWorkspace.shared.open()` approach — downloads the DMG, clears quarantine flag, opens it in Finder, and guides the user to drag-install.

---

## [2.0.0] — 2026-05-27

### Added
- **PingPlotter-Style Live Graph**: New default Traceroute view mode — heatmap grid where each row = one hop, each column = one round. Cell color encodes RTT (green/orange/red intensity), solid dark red = packet loss. Select any row to expand RTT area chart inline.
- **5 Traceroute View Modes**: Live Graph · Hops Table · Timeline · Route Map · Raw Console.
- **Sortable Hops Table**: Click any column header (# / Host / Location / Sent / Loss% / Min / Avg / Max / StdDev) to sort ascending/descending.
- **Complete Hop Stats**: Added Min, Max, StdDev columns. Renamed Jitter → StdDev for accuracy.
- **Copy Hop**: Per-row copy button copies hop stats to clipboard.
- **PDF Export for Traceroute**: Branded PDF report with hop-by-hop analysis table, summary stats, and timestamps.
- **Improved IP Info Card**: Full geo section (flag, city, country, ISP, hostname, timezone, postal, coordinates), 7-cell performance grid (Sent/Recv/Loss/Min/Avg/Max/StdDev), Public/Private badge.
- **Path Summary Stats**: Path Avg RTT, Path Loss%, Bottleneck count, Round counter as StatCards.
- **Inline Detail Chart**: Click any hop in Hops Table, Live Graph, or Timeline to expand RTT history chart with threshold rule lines (Warn/Crit markers).
- **Loading State**: Shows progress indicator while initial trace is running.

### Improved
- **Route Map**: Numbered pin labels (1–N) instead of "Hop N" annotations; shadow glow color matches hop health.
- **Timeline**: Shows Avg RTT + Loss% per hop in trailing column; inline chart expansion on row tap.
- **Route Health Banner**: Added description subtitle explaining the status.
- **Settings (v1.9.0)**: Already released — sidebar navigation, live RTT preview bar, complete coverage.

---

## [1.9.0] — 2026-05-27

### Improved
- **Redesigned Settings**: Complete overhaul from tab-based layout to a macOS System Settings–style sidebar navigation (General, Thresholds, Tools, Privacy panes).
- **Live RTT Preview Bar**: Animated color-zone bar in Thresholds pane shows green/orange/red zones as sliders move in real time.
- **Complete Settings Coverage**: Added missing controls — Auto-Stop on Consecutive Loss, Bandwidth refresh interval, all tool timeouts, and concurrency settings.
- **Privacy Pane**: New dedicated section with geolocation toggle, host history count/clear, and zero-telemetry notice.
- **Settings UX Fixes**: Sidebar rows fully clickable (entire row, not just text); removed blue focus ring from sidebar buttons.
