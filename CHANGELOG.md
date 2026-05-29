# Changelog

All notable changes to NetUtil are documented here.

---

## [2.9.0] — 2026-05-29

### Added
- **Bandwidth Monitor Overhaul**: 
  - New aggregate throughput chart showing 10-minute history with hover interactivity.
  - Session Peak tracking (Max Download/Upload).
  - Enhanced interface cards with IP addresses and status badges.
  - Pause/Resume and Peak Reset capabilities.
- **Traffic Statistics Overhaul**:
  - Time-range filtering for daily totals (7D, 14D, 30D, All).
  - Interactive bar charts with floating tooltips for exact daily values.
  - New "Detailed History" table with activity ratio bars.
  - Professional CSV Export for historical traffic data.
- **Help System**: Support for deep linking directly to specific tool documentation.

### Changed
- Unified UI/UX for all monitoring tools following professional macOS standards: materials, monospaced technical data, and data-dense headers.
- Consolidated rate and byte formatting logic into `NetworkMath`.

---

## [2.8.1] — 2026-05-29

### Fixed
- **Updater**: Resolved an issue where the app would not prompt to install or open the DMG after completing an update download.

---

## [2.8.0] — 2026-05-29

### Added
- **Speed Test History**: Results are now persisted across app restarts (up to 50 entries).
- **Speed Test Verdicts**: New color-coded metric verdicts for Speed, Browsing, Gaming, and Streaming results.
- **Speed Test Auto-Labels**: Automatically uses Wi-Fi SSID or localized network interface names (e.g., "USB 10/100/1000 LAN") for test connections.
- **Speed Test Renaming**: History entries can be renamed inline via right-click and deleted.

### Changed
- Refined Speed Test UI strictly following HIG: replaced generic emojis with proper SF Symbols, improved typographic separators (· instead of /), and removed forced ALL CAPS.
- `ToolStore` now exposes `currentConnectionName` to safely report network connection names.

---

## [2.7.0] — 2026-05-28

### Added

- **Speed Test** (`Speed Test` sidebar tool) — four test kinds matching nperf-style coverage:
  - **Speed**: sustained download (4 parallel connections, 10 s) + upload + median ping + jitter via Cloudflare endpoints.
  - **Browsing**: sequential GET to 8 popular sites (Google, Cloudflare, Wikipedia, GitHub, Apple, DuckDuckGo, Bing, Reddit). Reports average load time, median TTFB, Fast/OK/Slow verdict.
  - **Gaming**: 50 HEAD probes to 1.1.1.1 at 50 ms cadence. Reports median, P99, jitter, packet loss. Color-coded latency verdict.
  - **Streaming**: 15 s sustained download with 1 s window sampling. Reports min/avg throughput and sustainable streaming tier (240p — 8K UHD).
- **Top Processes** (`Top Processes` sidebar tool) — per-application real-time download and upload rates via `/usr/bin/nettop`. Activity bars normalised across processes. Hooks into existing `/usr/bin/script` PTY wrapper.
- **Traffic Statistics** (`Statistics` sidebar tool) — daily download and upload totals persisted in UserDefaults for 90 days. Live 10-minute aggregate throughput chart. 30-day daily bar chart with download/upload split.
- **`BandwidthMonitor` lifted to `ToolStore`** — shared, always-running aggregate sampler. `totalHistory` for 10 minutes of throughput, `onAggregateDelta` callback feeds the new `TrafficStatistics` daily accumulator.

### Menu Bar

- **Traffic display mode** — new `Shows` option in Settings: `↓1M ↑200K` live aggregate rates updated every second from all non-loopback adapters.
- **Ping + Traffic combined mode** — fourth picker preset `16ms ↓1M ↑200K` shows both side by side as a single status item.
- **Show traffic next to icon** toggle — appends live rates to the right of the waveform icon. Auto-disabled when primary mode already includes traffic.
- **Background mode** — new `Keep running in menu bar when window closed` toggle. When enabled, closing the main window switches NSApp activation policy to `.accessory` (Dock icon disappears) and prevents quit. Reopening from the menu bar restores `.regular` policy.

### Changed

- Sidebar restructured into a `Bandwidth` group containing Bandwidth Monitor, Statistics, Speed Test, and Top Processes.
- `BandwidthSample` and the old private `BandwidthViewModel` consolidated into `BandwidthMonitor` (`Models/`).
- `AboutView` tool list expanded with Statistics, Speed Test, Top Processes.

### Fixed

- Speed test download previously reported ~0 Mbps because the original implementation iterated `URLSession.AsyncBytes` one byte at a time across a 100 MB stream — pure await overhead, no real measurement. Replaced with sequential `URLSession.data(for:)` chunk loop for single-connection mode and parallel chunk downloads with a `ByteCounter` actor for the saturated test.
- `MenuBarLabel` `Ping + Traffic` mode now uses single `Text` concatenation. `HStack` of two Text children was being clipped to the first child inside the `NSStatusItem` rasterisation context.

---

## [2.6.0] — 2026-05-28

### Added

- **Network Guide in Help**: Four new reference sections added to the Help window (⌘?) covering the core networking concepts every network engineer needs:
  - **OSI Model** — 7-layer table with real protocols and corresponding NetUtil tools per layer, deep-dive on Layer 3 IP header and Layer 4 TCP vs UDP.
  - **TCP/IP Stack** — IPv4 private ranges, IPv6 notation, TCP 3-way handshake diagram, TCP flags, ICMP types table.
  - **Subnetting & CIDR** — Prefix reference table (/8–/32), step-by-step subnet calculation example, VLSM allocation walkthrough.
  - **DNS, TLS & Routing** — DNS resolution chain diagram, all 8 record types, TLS 1.3 handshake flow, routing table with longest-prefix-match explanation.
- Each guide section includes monospaced code blocks for diagrams/tables and lightbulb tips pointing to the relevant NetUtil tool.
- **`HelpTopic` enhanced** with optional `codeBlock` field — renders monospaced code/diagram panels with a `.regularMaterial` background, available for future help content.

---

## [2.5.2] — 2026-05-28

### Fixed

- **VPN false positive**: `isVPNActive` no longer triggers on iCloud Private Relay and Apple's internal `utun` interfaces. Detection now requires the `utun`/`ipsec` interface to have an IPv4 address assigned, which is only true for real user VPN connections.
- **Wrong local IP**: Dashboard and menu bar no longer show the IP of AirDrop (`awdl0`), Low Latency WLAN (`llw0`), hotspot bridge (`bridge100`), or tunnel interfaces as the primary local IP. Selection now prefers physical Ethernet/Wi-Fi interfaces only.
- **Window title**: Title bar now shows `NetUtil — Tool Name` when a tool is selected (e.g., `NetUtil — Ping`). Dashboard shows just `NetUtil`.
- **DMG build script**: `build_dmg.sh` now always rebuilds from a fresh archive. Previously, a cached `dist/NetUtil.app` could be repackaged under a new version number without updating its contents.

---

## [2.5.1] — 2026-05-28

### Fixed

- **Updater silent failure**: `checkForUpdates` now shows an explicit error dialog on network failure instead of silently doing nothing.
- **Progress panel invisible**: Added `NSApp.activate()` before showing the download progress panel and all update dialogs — fixes the panel not appearing when triggered from the menu bar popup.
- **`isChecking` stuck**: Added 15-second request timeout; all error paths now reset `isChecking` to prevent the update button from doing nothing on subsequent taps.
- **Main thread block**: `xattr` quarantine removal moved to `Task.detached` — no longer blocks the main thread during installation.
- **Ghost progress panel**: Panel is now set to `nil` after closing, so a second update attempt creates a fresh panel instead of resurfacing a closed one.
- **Missing `!isDownloading` guard**: Prevented overlap between an active download and a new check.
- **Version fallback**: Updated hardcoded fallback from `"2.4.1"` to `"2.5.1"`.

---

## [2.5.0] — 2026-05-28

### Changed

- **Apple HIG Compliance Audit**: Conducted a full project-wide audit against Apple's Human Interface Guidelines. Every view now uses semantic text styles (`.headline`, `.body`, `.caption`), a minimum 10pt font floor, and an 8pt spacing grid.
- **Material Rule Enforcement**: Eliminated all remaining fake-opacity backgrounds (`Color(...).opacity(x)`) from cards and containers across every view. All surfaces now use `.regularMaterial` for native vibrancy.
- **Typography Overhaul**: Removed hardcoded font sizes in favour of SwiftUI semantic styles throughout. Eliminated `.weight(.black)` at small sizes, forced ALL CAPS on dynamic data, and `.primary.opacity(x)` proxies.
- **BentoCard Redesign**: Corner radius reduced from 20pt (iOS/visionOS) to 10pt (macOS standard). Background migrated to `.regularMaterial`. Shadow softened to max 0.06 opacity.
- **Dashboard Layout**: Padding reduced from 48pt to 24pt. Section spacing normalised to 8pt grid.
- **Empty States**: All 40pt+ decorative icons in empty states replaced with silent `.secondary` text per HIG guidelines.
- **Section Headers**: Unified to `.headline` font with `.accentColor` icon across all views. Removed `.foregroundColor(.primary.opacity(0.8))` pattern.

### Added

- **Settings Redesign**: Replaced custom sidebar with standard macOS `TabView` + `Form { Section { LabeledContent } }` pattern using `.formStyle(.grouped)`. Every control now has a `.help()` tooltip explaining its function.
- **Menu Bar RTT Display**: New configurable menu bar icon mode. Choose between the waveform icon or a live ping RTT readout (`16 ms`) coloured by threshold. Configurable in Settings > General > Menu Bar.
- **Menu Bar Auto-Start Ping**: Background ping now starts automatically at app launch rather than requiring the popup to be opened first.
- **Menu Bar Ping Interval**: Configurable background ping interval (1–10s) added to Settings > General > Menu Bar.
- **Menu Bar Status Header**: Menu bar popup now shows External IP, Local IP, connection type, and VPN status.
- **Ping Sparkline in Menu Bar**: Real-time RTT sparkline visible in the menu bar popup.
- **Beep on Loss in Settings**: The ping beep-on-loss toggle is now accessible in Settings > General > Ping.
- **Threshold Clamping**: Good/Warning/Critical RTT sliders in Settings now clamp automatically to prevent invalid configurations (warn >= crit).

### Fixed

- `NSApp.activate(ignoringOtherApps:)` replaced with `NSApp.activate()` to fix deprecation on macOS 14+.
- Menu bar ping colour now respects user-configured RTT thresholds instead of hardcoded 20/100ms values.
- External IP no longer re-fetched on every menu bar popup open; fetches only when stale.
- Sub-10pt font sizes eliminated from chart axis labels, chevron icons, and status badges.
- "ms" unit no longer clipped in menu bar RTT display (unified to single `Text` view).

---

## [2.4.2] — 2026-05-28

### Improved
- **Transparent Updater UX**: Introduced a floating progress panel that appears automatically when downloading an update.
- **Automated Installation Flow**: The update DMG is now automatically opened upon download completion, followed by an instruction dialog to guide the installation.
- **Visual Feedback**: Real-time download percentage and progress bar added to both the floating panel and the About view.

---

## [2.4.1] — 2026-05-28

### Changed
- **Extreme Anti-Slop Audit**: Conducted a project-wide sweep to eliminate all remaining "AI Slop" elements.
- **Refined Typography**: Removed all excessive `.black` weights and forced `.uppercased()` section headers. Every tool now uses elegant, system-standard `.headline` and `.bold` typography with natural Sentence Case.
- **Vibrancy & Material Unification**: Replaced remaining fake-transparency backgrounds with native macOS `.regularMaterial`, ensuring a truly cohesive and reactive interface.
- **Data-Dense Minimalist Aesthetics**: Unified all data containers and lists into a flat hierarchy with ultra-fine `0.5pt` dividers, matching the clinical precision of native system utilities.
- **Clean Documentation**: Fully purged decorative emojis and generic AI-style formatting from `README.md`, `DOCUMENTATION.md`, and `CHANGELOG.md`.

---

## [2.4.0] — 2026-05-28

### Changed
- **Help Documentation Redesign**: Completely overhauled the `HelpView` window to follow the Native Mac Anti-Slop guidelines. The sidebar now uses `.regularMaterial` for true macOS vibrancy, and the topic content flows naturally without heavy box-in-box shadows.
- **Improved Sidebar UX**: Enlarged the clickable hitboxes (`contentShape`) across all navigation sidebars so users can click anywhere on a row, matching standard macOS behavior.

### Fixed
- **Updater UX**: Moved the "Check for Updates" functionality out of the About window and integrated it natively into the macOS Menu Bar (`NetUtil > Check for Updates...`) and the Status Bar dropdown menu. It now utilizes native `NSAlert` dialogs instead of inline web-style UI.

---

## [2.3.0] — 2026-05-28

### Changed
- **The Native Mac Polish**: Completely overhauled the entire application to eliminate web-centric "AI Slop" and embrace authentic macOS design patterns.
- **Bento Box Dashboard**: Replaced the generic dashboard grid with a curated, dynamic Bento Box layout featuring live sparklines and pulsing activity indicators.
- **Vibrant Materials**: Removed fake transparency colors and implemented native `.regularMaterial` across all containers to support dynamic wallpaper vibrancy.
- **Flat Data Hierarchy**: Eliminated excessive box-in-box wrapping on data tables. Results now flow naturally with refined 0.5pt system dividers, matching native macOS utilities like Activity Monitor.
- **Silent States & Data-Dense Typography**: Removed shouting ALL-CAPS headers and noisy empty states. Implemented a calmer typographic scale (`.headline`, `.subheadline`) and clinical, data-dense status indicators.
- **Permanent Design Guidelines**: Enshrined the new "Native macOS Anti-Slop" rules into the project's AI context documentation to ensure all future updates automatically inherit this premium artisan aesthetic.

---

## [2.2.1] — 2026-05-27

### Added
- **VLAN Audit Support**: Automatically detects virtual interfaces (`vlan`) and extracts VLAN ID (802.1Q tag) and Parent Interface details.
- **VLAN Learning Guide**: Added a dedicated section in the Interface guide explaining VLAN concepts and step-by-step instructions for creating them on macOS.

### Improved
- **Final Symmetry Refinement**: Polished the headers and interpretation bars across all 13 tools for absolute consistency in information positioning.
- **VLAN Visualization**: Introduced a unique purple theme and `tag.fill` icon for virtual interfaces to distinguish them from physical adapters.

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
