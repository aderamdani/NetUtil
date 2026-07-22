# Changelog

All notable changes to NetUtil are documented here.

---

## [4.10.0] — 2026-07-22

### Added
- **Connectivity Doctor**: diagnoses "why doesn't the internet work?" for non-experts by checking four layers in order — router reachability, DNS resolution, plain web egress (with captive-portal detection), and TLS — then states the first broken layer with a concrete fix suggestion.
- **Multi-Ping latency alerts**: a bell toggle posts a macOS notification when a monitored host's packet loss or average RTT crosses the thresholds set in Settings > Thresholds (rate-limited to one alert per host every 5 minutes).
- **Path MTU**: binary-searches with don't-fragment pings to find the exact path MTU to a host — diagnoses the classic "large transfers stall on VPN" problem, grading results against known values (1500 Ethernet, 1492 PPPoE, 1420-1460 VPN tunnels).
- **Neighbors**: ARP table viewer listing every device this Mac has exchanged packets with (IP, MAC, interface), auto-refreshing every 5 seconds.
- **Connections**: lists every open TCP/UDP socket via `lsof -i -n -P` — which process is talking to which host, filterable by process/address and connection state.
- **Port Listener**: opens a TCP or UDP port via `NWListener` and logs every inbound connection — the mirror image of Port Scanner, for verifying firewall rules and port forwards from the receiving side.

All six new tools follow the existing house patterns (MoodBar, ToolStateView, Session History logging, learning guide, standard export where applicable) and ship with unit tests for their core logic (verdict resolution, MAC/ARP/lsof parsing, MTU binary search, end-to-end loopback connection logging).

### Changed
- Tool count is now 26 (25 diagnostics + Dashboard), up from 19.

---

## [4.9.0] — 2026-07-22

### Added
- **Net Quality**: new tool wrapping Apple's built-in `networkQuality` — measures responsiveness under working load in RPM (the bufferbloat signal a plain speed test misses), plus throughput and base RTT, with High/Medium/Low grading. Results log to Session History and are comparable in Compare.
- **Wake on LAN**: new tool that wakes sleeping machines with a UDP magic-packet broadcast (BSD socket). Accepts colon/dash/bare-hex MAC formats; broadcast address and port configurable.
- **Learning guide completed**: five tools had no help section at all (Subnet Scanner, Speed Test, Traffic Statistics, Session History, Compare) and their ?-buttons silently opened the Dashboard page; two more (Ping, SSL/TLS) opened the wrong page via stale titles. All 21 tools now have plain-language documentation that opens correctly.

### Changed
- **Swift 6 for real**: the project claimed Swift 6 but compiled as Swift 5 with minimal concurrency checking. Now `SWIFT_VERSION = 6.0` with `SWIFT_STRICT_CONCURRENCY = complete` — Sendable and actor isolation are compiler-enforced across app and tests.
- **Component adoption completed**: the 8 remaining hand-rolled mood bars (Bandwidth, Multi-Ping, Compare, Session History, Statistics, Subnet Scanner, Speed Test, Dashboard) now use the shared `MoodBar`; remaining plain empty/loading states use `ToolStateView`.
- **Subprocess consolidation completed**: DNS and WHOIS moved to a new cancellable one-shot runner, Traceroute and Multi-Ping to the shared streaming runner — no ViewModel hand-rolls Process/Pipe code anymore.
- **Zero-warning build**: App Category set, AppIntents metadata extraction skipped.

### Tests
- 32 new tests (118 total): SubprocessRunner one-shot/cancellable/streaming (including a 220 KB drain-before-wait deadlock regression), primary-interface predicate, direct `isPrivateIP` boundaries, Wake-on-LAN MAC parsing and magic-packet layout, networkQuality JSON parsing and RPM grade bands.

---

## [4.8.2] — 2026-07-22

### Fixed
- **Deadlock**: `RouteTableView`'s `netstat -rn` spawn waited on process exit before draining its output pipe — could hang forever on a large routing table. Reordered to drain-then-wait (matches the fix already applied elsewhere in 4.7.5).
- **Route flags**: lowercase route flags (`c`, `m`, `r`, …) were shown raw instead of expanded — flag matching is now case-insensitive.
- **Race condition**: Subnet Scanner lacked the run-generation-token guard every other Process-spawning ViewModel has; stopping and immediately restarting a scan could let the old run keep writing into the freshly-reset results.
- **Battery**: Wi-Fi polling was excluded from window-occlusion pause/resume — it kept polling CoreWLAN every 2s while the window was minimized or hidden. Now pauses/resumes with everything else.
- **Consistency**: the menu bar and main app computed "primary interface" via two independently-maintained predicates that had already diverged (one was missing the `tun`/`tap` exclusion) — unified into one shared helper.
- Removed 2 force-unwraps, added `final` to the one ViewModel missing it, fixed 3 `Task` handles never cancelled in `deinit`, fixed 3 `ForEach` views keying off array index instead of a stable id, consolidated duplicated `isPrivateIP` and byte-formatting logic into single sources of truth.

### Changed
- **ViewModel standardization**: all 13 tool ViewModels now share one shape — `isRunning`/`error` as `private(set) var`, `start()`/`stop()`, `runID` generation tokens for anything spawning a `Process`. Previously a mix of `isScanning`/`isTesting`/`errorMessage`, `startScan`/`lookup`/`run`, and inconsistent access control across tools.
- **Shared components**: extracted `MoodBar`, `ToolStateView` (empty/loading states), `ToolControlBar` + `HostHistoryMenu`, and a `SubprocessRunner` utility — removing roughly 700 lines of near-identical code that had been copy-pasted across 7-19 tools.
- **Build**: release builds now target Apple Silicon only (`ARCHS=arm64`); the x86_64 slice has been dropped.

### Docs
- `docs/TESTING.md`'s stale open-items table (O1-O5, generated against v4.3.0) re-audited against current code and corrected — 4 of 5 were already resolved by earlier passes, the 5th (route flag case-sensitivity) is fixed in this release.

---

## [4.8.1] — 2026-07-18

### Changed
- **App Icon**: Redesigned to a minimalist liquid-glass style — a single hub-and-spoke network glyph (accent `#6DCCFF`) over a soft navy gradient with a translucent glass plate and specular sheen, replacing the previous busy concentric-ring + node-dot design. Regenerated all 7 app-icon sizes via `generate_icon.swift`.

---

## [4.8.0] — 2026-07-18

### Added
- **Session History everywhere**: DNS, WHOIS, SSL/TLS, HTTP Latency, and Speed Test now log completed runs to Session History (previously only Ping, Traceroute, and Port Scan did). History rows show the correct icon and label for every tool.
- **Compare for all logged tools**: the Compare tool now supports DNS, WHOIS, SSL/TLS, HTTP Latency, and Speed Test sessions via a generic session-overview comparison (status, duration, summary, timestamp) alongside the existing detailed Ping/Port Scan/Traceroute comparisons.
- **Compare export**: Report menu (Export PDF / Export CSV) added to the Compare tool.
- **Mood bars**: Ping, Traceroute, Port Scanner, SSL/TLS, and WHOIS gained the standard status mood bar — every diagnostic tool now has one.
- **Keyboard shortcuts**: the remaining 10 tools are now reachable via ⌥⌘1–⌥⌘9 and ⌥⌘0 (Subnet Scanner through Compare); the first 9 keep ⌘1–⌘9.

## [4.7.5] — 2026-07-18

### Fixed
- **Crash**: `NetworkMath.calculateSubnet` trapped on boundary IPs (`255.255.255.255/32`, `0.0.0.0/32`) — first/last host now use wrapping arithmetic; out-of-range prefixes return `nil`.
- **Crash**: Subnet Scanner crashed on `/31`–`/32` CIDR input (`1...0` range in `generateIPs`); prefix is now validated (`/16`–`/30`) with a visible error banner.
- **Concurrency**: restarting Ping/Traceroute mid-run spawned orphan processes and let stale handlers tear down the new run — all subprocess ViewModels (Ping, Traceroute, DNS, WHOIS, Port Scan, SSL) now use run-generation tokens.
- **Session History**: sessions were logged twice on restart and never logged when a finite run or scan completed naturally; sessions now log exactly once.
- **Deadlock**: Subnet Scanner helpers called `waitUntilExit()` before draining the pipe (hang risk on large `arp -an` output); WHOIS never drained stderr and read stdout only after exit. All subprocess reads now happen before waiting.
- **UI**: Stop buttons in DNS, WHOIS, and SSL/TLS were no-ops — they now actually cancel the running operation.

### Changed
- **Performance**: `netstat` default-gateway lookup moved off the main thread (was a synchronous spawn on the main actor every 3s); monitoring now also drops to reduced cadence when all windows are minimized or fully occluded; dead `sysctl` call removed from `SystemMonitor`.
- **Export**: 6 dead "Export PDF" menu items implemented (Wi-Fi, Interfaces, Bandwidth, Routes, Statistics, Session History); CSV filenames unified to `NetUtil-[Tool]-[target]-yyyyMMdd-HHmmss`; CSV fields now RFC 4180-escaped; Statistics uses the shared `Exporter.save`.
- **UI consistency**: Subnet Scanner aligned to the standard tool layout (shared ToolStore VM, standard mood bar with progress, standard empty/loading states, 24pt padding, sidebar activity indicator); stroke opacity normalized in Compare and Session History.

### Tests
- New regression tests: `/32` boundary IPs, out-of-range prefixes, hostless/too-wide/malformed CIDR rejection, CSV field escaping.

## [4.7.4] — 2026-07-18

### Fixed
- **Performance**: Idle CPU reduced (~101% → ~0–3%) by moving the Dashboard uptime ticker out of `.task` (which SwiftUI re-ran on every `body` recompute driven by live bandwidth rates) into a single `onAppear` `Task` cancelled on `onDisappear`.
- **Performance**: Speed Test streaming phase CPU spin (~119%) eliminated by throttling the sequential request loop in `SpeedTestEngine.runStreaming()` with a 50ms `Task.sleep` per iteration.

### Changed
- Consolidated duplicate `.onAppear` modifiers in `TracerouteView` and `PortScanView` into single modifiers.
- Normalized `Tool` enum indentation (`icon`, `shortcut`, `toolView` switch) in `ContentView` for consistency.

---

## [4.7.3] — 2026-06-23

### Fixed
- **Performance**: Ping-infinite CPU reduced (~138% → target <40%) by throttling chart data to 5fps, using verbatim Text for axis labels, replacing glassEffect with regularMaterial on the hover tooltip, and deduplicating geometry-triggered chartWidth updates.

---

## [4.7.2] — 2026-06-23

### Added
- **Battery Optimization**: Window visibility monitoring — pause/resume all polling (Wi-Fi, interfaces, bandwidth, system health) when the main window is hidden or occluded (`6b92c53`).

### Fixed
- **Tests**: Aligned `formatBytes` test expectations with `%.2f` implementation in `NetworkMathTests` (`bfb8c24`).

---

## [4.7.1] — 2026-06-22

### Added
- **Subnet Calculator**: PDF/CSV export via unified ReportMenuButton (was missing).
- **WhoisViewModel**: Extracted to dedicated file (`ViewModels/WhoisViewModel.swift`).

### Fixed
- **Battery**: DashboardView now stops Wi-Fi polling (`tools.wifi.stop()`) on `.onDisappear` — was running 2s timer while user browsed other tools.
- **Dead Code**: Removed 4 orphaned files (`GuideComponents`, `SSLWatchlistView`, `IPAddressDetails` + its test), 20 stale `import Combine` statements, unused `menuBarCurrentRTT` property, empty `SSLWatchlist.checkAll()` stub.
- **UI Polish**: MultiPing control bar now wraps settings in `GlassEffectContainer` with `.borderless` secondary buttons. Subnet Calculator control bar follows same pattern.
- **Liquid Glass**: Final 3 `.borderedProminent` buttons (ImportHostsSheet, TracerouteView Done, AboutView) migrated to `.glassProminent`.

---

## [4.7.0] — 2026-06-22

### Added
- **Liquid Glass**: Adopted Apple's Liquid Glass design system (macOS 26+ Tahoe).
  - Migrated custom container backgrounds to `.glassEffect(in: .rect(cornerRadius: N))` on all BentoCards, StatCards, healthGauge, PingResultsTable, rawOutput, and chart tooltips.
  - Wrapped adjacent glass views in `GlassEffectContainer` for unified blur/refraction blending across dashboard card grids and Ping control bar.
  - Upgraded primary Start/Stop buttons to `.glassProminent` style across all tool views.
- **Typography**: Extracted remaining `.font(.system(size:))` literals into named `Metrics` constants.

### Fixed
- **Exporter**: Replaced force-unwrap on `NSAppearance(named: .aqua)` with safe `guard let` fallback (AGENTS.md compliance).
  - Eliminated high-frequency `UserDefaults` writes (2-3 writes/sec).
  - Cached expensive system API calls (`SCNetworkInterfaceCopyAll`, `CWWiFiClient.ssid`) in `ToolStore`.
  - Optimized `DashboardHeroSection` chart and disabled automatic Menu Bar ping on launch.

---

## [4.6.3] — 2026-06-01

### Fixed
- **Performance**: Resolved persistent high CPU usage (114%+ at idle).
  - Eliminated high-frequency `UserDefaults` writes in `BandwidthMonitor` and `MenuBarViewModel` (was 2-3 writes/sec).
  - Cached expensive system queries (`SCNetworkInterfaceCopyAll`, `CWWiFiClient.ssid`) in `ToolStore` to avoid hammering system APIs every second.
  - Optimized `DashboardHeroSection` chart by limiting data points to 100 and removing expensive Catmull-Rom interpolation.
  - Disabled automatic background ping on launch; Menu Bar ping now only runs when a host is explicitly provided.
  - Refactored `DashboardView` to use pre-calculated and cached health status properties from `ToolStore`.

---

## [4.6.2] — 2026-06-01

### Fixed
- **Performance**: Resolved persistent high CPU usage (125% at idle).
  - Fixed major timer leak in `WiFiInspectorViewModel` where background timers accumulated on every navigation to Dashboard.
  - Eliminated "Observation Storm" by marking internal state properties in `BandwidthMonitor`, `SystemMonitor`, `PingViewModel`, and `MenuBarViewModel` with `@ObservationIgnored`.
  - Optimized `TopProcessesViewModel` buffer management to avoid O(N^2) work on the main actor.
  - Cached `Host.current().localizedName` in `DashboardView` to avoid expensive system calls during re-renders.
  - Throttled `SubnetScanViewModel` updates to reduce UI pressure during large scans.
- **Safety**: Added guards to `start()` methods in monitoring view models to prevent redundant background work.

---

## [4.6.1] — 2026-06-01

### Fixed
- **Performance**: Resolved critical high CPU usage (117% at idle).
  - Implemented VLAN details caching in `NetworkInterfaceFetcher` to eliminate redundant process spawning of `/sbin/ifconfig`.
  - Reduced `BandwidthMonitor` polling frequency for full interface details (1s -> 10s).
  - Optimized `TrafficStatistics` persistence by batching `UserDefaults` writes (30s interval).
  - Fixed `NetworkInterfaceView` spawning `/usr/sbin/netstat` in the view body.
- **Safety**: Added null checks for `ifa_addr` in `BandwidthMonitor` to prevent potential crashes in raw byte fetching.

---

## [4.6.0] — 2026-05-31

### Added
- **Favorites**: Pin frequently-used hosts to sidebar with quick-launch to any tool. Star button across all input tools. Drag-to-reorder, max 20 favorites. `FavoritesManager` persisted to UserDefaults.
- **Session History**: Automatic logging of all scan/test sessions (max 200 records, max 20 with full detail). Filter by tool/date, search by hostname, CSV export. Click any record to revisit with pre-filled target and auto-start.
- **Compare Mode**: Side-by-side diff of two sessions — Ping stats comparison (RTT, loss, jitter with green/red delta), Port Scan port diff (new/closed/unchanged ports), Traceroute hop-by-hop RTT comparison.

### Changed
- Sidebar reorganized: Favorites section at top, then Dashboard/History/Compare, then diagnostic tools.
- Star button added to all 9 input tools (Ping, Traceroute, Port Scanner, Multi-Ping, HTTP Latency, Subnet Scanner, DNS, SSL/TLS, WHOIS).
- SessionHistoryView and CompareView use flat `ScrollView + LazyVStack + Divider` layout consistent with existing tools.
- CompareView session pickers moved into control bar for faster workflow.

### Internal
- `FavoritesManager` and `SessionHistory` added to `ToolStore` (shared singletons, UserDefaults-persisted).
- `PingViewModel`, `TracerouteViewModel`, `PortScanViewModel` gain `onSessionComplete` logging closure and `quickLaunchHost` for favorites auto-start.
- `SessionRecord` with optional detail snapshots (`PingStatsSnapshot`, `PortResultSnapshot`, `HopSnapshot`) for Compare feature.

---

## [4.5.0] — 2026-05-31

### Changed
- **Full UX Consistency Audit**: 153-check audit across all 17 tools × 9 criteria. 14 fixes applied, zero remaining violations.
- **Mood Bars (6 tools)**: Added real-time interpretation bars to Multi-Ping (active/loss summary), HTTP Latency (TTFB health), DNS (records resolved/query time), Bandwidth (throughput status), Statistics (today's total), and Speed Test (last result type + values).
- **Report Menu (4 tools)**: Added `ReportMenuButton` with CSV export to Top Processes, Network Interfaces, Wi-Fi Inspector, and Route Table. Added corresponding `csvString(from:)` methods to `Exporter`.
- **Chart Fixes (StatisticsView)**: Realtime chart now uses explicit `chartYScale` with 15% headroom and `drawingGroup()`. Daily bar chart adds `drawingGroup()`.
- **Multi-Ping Sparkline**: Expanded chart now uses index-based X-axis (sequence numbers #N) instead of timestamps, enabling sequence labels and proper domain clamping.

---

## [4.4.1] — 2026-05-31

### Fixed
- **Build System**: Resolved "Cannot find 'Exporter' in scope" error by refactoring `Exporter.swift` to break up complex array literals that caused Swift compiler timeouts.
- **Unit Tests**: Fixed `@MainActor` isolation errors in `SubnetScanTests.swift`.
- **Unit Tests**: Synchronized `ExporterTests` CSV header expectation with the latest model changes.
- **PDF Reports**: Bumped PDF font sizes to 10pt (footer/table content) to strictly comply with Apple HIG and project accessibility standards.

---

## [4.4.0] — 2026-05-31

### Changed
- **Dashboard Live Data Cards**: Traceroute, SSL/TLS, HTTP Latency, DNS, and WHOIS cards now display last session results instead of static placeholder labels. Added Speed Test card (↓/↑ Mbps + download sparkline) and Subnet Scanner card (CIDR + alive host count).
- **Network Health Summary Bar**: New full-width status bar below the dashboard header showing real-time system health — SSL certificate critical/warning state, Ping packet loss alerts, and Wi-Fi signal weakness. Displays most critical issue with color-coded icon.
- **System Gauges — RAM**: Gauge now shows actual used/total GB subtitle (e.g. "8.4 / 16 GB") and `.help()` tooltip with percentage. Total RAM read via `hw.memsize` sysctl; used RAM computed from `vm_statistics64`.
- **System Gauges — CPU**: Added `.help()` tooltip showing usage percentage and logical core count.
- **App Uptime Counter**: Live "Xh Ym" / "Xm" uptime display in dashboard header, updated every 60 seconds via async `.task`.
- **Ping Chart**: Hover tooltip rendered outside chart bounds (ZStack sibling) — no longer clipped at left/right/top edges. Chart now uses tight `chartXScale` domain for full-width rendering. X-axis shows sequence number labels (#10, #20…) with dynamic stride (10/25/50 based on packet count).
- **PDF Export (all tools)**: Fixed blank exports in dark mode. All 10 PDF export functions now force `.aqua` NSAppearance during rendering and use explicit fixed colors (`NSColor.black`, white: 0.35/0.55/0.78) instead of semantic `NSColor.labelColor` / `separatorColor` that resolve to white in dark mode.

### Internal
- `SSLWatchlist` moved to `ToolStore` (shared singleton); `SSLInspectorView` migrated from `@State` instance to `@Environment(ToolStore.self)`.
- `DNSViewModel` and `WhoisViewModel` now track `lastQuery` for dashboard display.
- `SystemMonitor` exposes `ramUsedGB` / `ramTotalGB` (constant, computed at init).

---

## [4.3.0] — 2026-05-31

### Added
- **Traceroute host history**: Clock icon dropdown in Traceroute control bar — identical to Ping, DNS, and HTTP Latency. Selecting a recent host auto-starts the trace.
- **Bandwidth Monitor full UI**: Replaced placeholder with live implementation — aggregate stat cards (Download, Upload, Peak RX/TX with reset), 60-second mirrored throughput chart (RX above / TX below axis), per-interface table with type icon, IP, live rates, and 30-sample sparkline per interface. Pause/Resume, Active Only filter, and CSV export all functional.

### Fixed
- **Chart Y-axis label clipping**: Applied `.chartPlotStyle` top/bottom padding and `.chartYScale(domain:)` with explicit headroom across all charts that had visible Y-axis labels (BandwidthView, StatisticsView line + bar, WiFiInspectorView RSSI, MultiPingSlotRow expanded RTT). Matches PingView's existing pattern.
- **Port Scanner PDF export**: `onExportPDF` wired to `Exporter.savePortScanPDF`.
- **WHOIS PDF export**: `onExportPDF` wired to `Exporter.saveWhoisPDF`.
- **Swift 6 concurrency warnings** (all now clean in Release build):
  - `SystemMonitor`: Timer closure captures `[weak self]` directly in inner `Task` to avoid "captured var in concurrently-executing code" warning.
  - `PingViewModel`, `DNSViewModel`, `TracerouteViewModel`, `MultiPingViewModel`: Added `@ObservationIgnored` to `process: Process?` property — excludes it from `@Observable` macro synthesis so `nonisolated(unsafe)` applies to the raw stored property as intended.

---

## [4.2.0] — 2026-05-31

### Added
- **Subnet Scanner context menu quick actions**: Right-click any alive host to instantly launch Ping (20 packets), Port Scan (25 common ports), or Traceroute (30 hops). Navigates directly to the target tool with the scan already running.

---

## [4.1.0] — 2026-05-31

### Added
- **Speed Test full UI**: Complete implementation replacing the placeholder view.
  - Kind selector (Speed / Browsing / Gaming / Streaming) as segmented control in control bar.
  - Live metric cards per kind: Speed shows Download/Upload/Ping/Jitter; Browsing shows Sites/Avg Load/Median TTFB; Gaming shows Median Ping/P99/Jitter/Loss; Streaming shows Avg Mbps/Min Mbps/Tier.
  - Linear progress bar with phase label and percentage during active test.
  - Interactive empty state with kind selection cards showing each test's description.
  - History table with editable result labels (click to rename), kind icon, primary/secondary metrics, per-row delete, and clear all.
  - Color-coded metrics: speed tiers, ping quality, streaming tier.
  - Full PDF and CSV export connected to Exporter.

---

## [4.0.1] — 2026-05-31

### Fixed
- Implemented all PDF export methods (Ping, Multi-Ping, HTTP Latency, Traceroute, DNS, SSL, Subnet Scanner, Speed Test) that were previously empty stubs.
- Implemented all CSV export functions (Traceroute, Multi-Ping, HTTP Latency, Subnet Scan, Speed Test) that were returning empty strings.
- SSLInspectorView: `watchlist` was not wrapped in `@State`, preventing view from observing changes. Fixed.
- SubnetScanView: Force unwrap `result.rtt!` replaced with safe optional mapping.
- SpeedTestView: Start/Stop button had an empty action closure. Now correctly calls `vm.start()` / `vm.cancel()`.

### Changed
- SSLInspectorView: Control bar action group reordered to `[Report]` `[Watch]` `[Inspect]` `[Guide]` per HIG layout spec.
- SubnetScanView: Added learning guide button and `HelpView` sheet (was the only tool missing it).
- SubnetScanView `statusMoodBar`: Background changed from `Color.secondary.opacity(0.1)` to `.regularMaterial` (Anti-Slop compliance).
- TracerouteView `StatCardMini`: Background changed from `Color.secondary.opacity(0.1)` to `.regularMaterial`.
- TracerouteViewModel: `rawLines` type changed from `[String]` to `[PingLogLine]` for stable `ForEach` identifiers.
- DNSView: `ForEach(records, id: \.value)` replaced with `ForEach(records)` using model's native `Identifiable` conformance.
- SpeedTestView: Added `speedometer` SF symbol to control bar title for consistency with all other tools.
- Removed inline code-explaining comments from `PingView` and `MultiPingView`.

---

## [4.0.0] — 2026-05-31

### Added
- **Subnet Scanner (Tier 2)**: Concurrent ping sweep across entire subnets with host discovery, ARP enrichment, hostname resolution, MAC address detection, and CSV/PDF export. Context menu quick actions to Ping/Port Scan/Traceroute discovered hosts. Common subnet presets including auto-detect current network.
- **DNS Server Comparison (T1-1)**: Parallel query across System, Google (8.8.8.8), Cloudflare (1.1.1.1), and Quad9 (9.9.9.9) with side-by-side response time ranking.
- **SSL Expiry Watchlist (T1-2)**: Background certificate monitoring with local macOS notifications for expiring certificates. Dashboard integration with status badges.
- **Bulk Host Import (T1-4)**: Paste or import host lists into Multi-Ping with duplicate detection and clipboard integration.
- **Default Gateway Actions (T1-5)**: Quick Ping/Traceroute buttons in Network Interfaces with automatic gateway detection from route table.

### Changed
- Expanded test coverage with 8+ new test files covering models, ViewModels, and new features.
- Migrated test suite from standalone SPM package to native Xcode test target.

### Fixed
- Y-axis label clipping ("0 ms") on Ping RTT chart.

---

## [3.5.1] — 2026-05-31

### Changed
- **Documentation & Wiki Sync**: Comprehensive update of README, Technical Documentation, and GitHub Wiki to reflect the new modular architecture and native test infrastructure.
- **QA & Testing**: Refined QA clinical test cases and ensured full synchronization between documentation and the native Xcode test suite.

---

## [3.5.0] — 2026-05-31

### Changed
- **Comprehensive Code Audit & Refactoring**: Conducted a project-wide audit for performance, accessibility, and infrastructure.
- **UI Architecture Overhaul**: Decomposed large View bodies into modular components in `Views/Components/` and fragmented `SettingsView` into dedicated panes for better maintainability.
- **Performance Optimization**: Added `.drawingGroup()` to all real-time Swift Charts, migrating rendering load to GPU. Optimized `TopProcessesView` with native `List` virtualization.
- **Accessibility (VoiceOver)**: Implemented `.accessibilityLabel()`, `.accessibilityValue()`, and `.accessibilityElement(children: .combine)` across all views, ensuring full inclusivity.
- **Native Test Infrastructure**: Migrated entire unit test suite from external `tests-spm` to a native Xcode test target (`NetUtilTests`), enabling seamless development and CI integration.
- **Build Infrastructure**: Optimized Xcode build settings for compilation caching, strict concurrency (Swift 6), and faster linking.
- **Task Lifecycle Management**: Secured background task execution with explicit cancellation and proper cleanup in all ViewModels.

---

## [3.4.0] — 2026-05-31

### Changed
- **Observation Framework Migration**: Major architectural refactoring to migrate all ViewModels and applicable Models from `ObservableObject` to the modern Swift `@Observable` framework.
- **State Management & Concurrency Optimization**: Deconstructed monolithic ViewModels (like `SpeedTestViewModel`) into discrete models and engines for cleaner state handling. Enhanced thread-safety and optimized background task execution using `private(set)` on internally-mutated properties and rigorous `@MainActor` isolation.
- **Bug Fixes**: Removed legacy force unwraps to guarantee stable execution.

---

## [3.3.0] — 2026-05-30

### Changed
- **Comprehensive UI/UX Refinement**: Sweeping updates across all views to enforce strict adherence to Apple's Human Interface Guidelines (HIG) and "Native Mac Anti-Slop" principles. Eliminated all remaining `Color.opacity` instances in favor of native `.regularMaterial` for true vibrancy.
- **Network Models & Logic**: Adjusted `NetworkMath` and `HTTPLatencyViewModel` to improve reliability and correctness (e.g., proper handling of HTTP redirects).
- **Testing Infrastructure**: Added initial Swift Package Manager (SPM) testing suite (`tests-spm`) and clinical QA documentation (`QA-CLINICAL-TEST.md`) to establish a foundation for automated verification.

---

## [3.2.0] — 2026-05-29

### Performance Overhaul: High-Frequency Monitoring
- **Ping Batching Engine**: Implemented a double-buffered batching system in the Ping tool. Results are now collected in the background and flushed to the UI every 100ms, eliminating UI lag during fast monitoring (up to 5 packets/sec).
- **Virtualized Data Tables**: Transitioned Ping Analysis and Console Log to native macOS `List` views, providing superior cell recycling and responsiveness for datasets up to 1,000 entries.
- **Optimized Auto-Scroll**: Refactored auto-scroll logic to use direct scroll position bindings, significantly reducing MainActor workload and layout thrashing.

### UX & "Anti-Slop" Finalization
- **Fixed Tool Headers (Complete)**: Finalized the migration to the "Anti-Slop" header pattern across all 16 tools. Headers are now locked at the top, ensuring controls are always accessible.
- **Fixed Dashboard Navigation**: Moved connection metadata and system health gauges to a fixed top bar on the Dashboard.
- **Intelligent Chart Scaling**: Added a minimum 50ms Y-axis scale to the Ping chart to ensure visual stability when monitoring ultra-fast hosts like `1.1.1.1`.
- **Synchronized Console Log**: The raw Console Log now features the same high-performance auto-scrolling as the structured Analysis table.

---

## [3.1.0] — 2026-05-29

### Added
- **Fixed Headers (Project-Wide)**: Implemented standardized, locked top-level headers across all 16 tools for better accessibility and "Anti-Slop" compliance.
- **Advanced Ping - Packet Size**: Added payload size control to the Ping tool for MTU and fragmentation testing.

### Optimized
- **Ping Performance**: Implemented a 1,000-entry result cap and optimized auto-scrolling to ensure smooth operation during high-frequency monitoring.
- **Sticky Table Headers**: Refactored data tables (Ping, DNS, HTTP, WHOIS) to keep headers permanently visible while scrolling content.
- **Traceroute Engine**: Improved regex parsing for complex multi-IP hops and resolved Swift 6 concurrency warnings.
- **Standardized Visuals**: Synchronized RTT quality colors (Normal = Green) across all tools and legends.

---

## [3.0.0] — 2026-05-29

### Overhaul: Project-Wide UI/UX (Apple Artisan)
- **Unified Standard**: Applied a professional, handcrafted macOS aesthetic across all 17 integrated tools.
- **Vibrant Materials**: Transitioned all containers and cards to native SwiftUI `.regularMaterial` for true wallpaper-reactive translucency.
- **Clinical Typography**: Enforced a 10pt minimum font floor and monospaced technical data (IPs, Ports, Timestamps, Rates) for maximum precision.
- **Unified Control Bars**: Standardized headers across all tools with fixed action groups, integrated history access, and data-dense statuses.

### Tool-Specific Enhancements
- **Traceroute Refactor**: Decoupled the 1200-line monolithic view into modular components: `TracerouteHopsTable`, `TracerouteMapView`, and `TracerouteTimelineView`. Added path polyline support to the map.
- **Advanced Ping**: New RTT distribution bar, interactive charts with vibrancy gradients, and clinical status badges.
- **Multi-Ping**: Professional row-based monitoring with expandable RTT charts and inline renaming.
- **Port Scanner**: Redesigned grid with high-fidelity service cards and thread concurrency control.
- **HTTP Latency**: Precision waterfall chart with millisecond-accurate phase timing and payload analysis.
- **DNS Lookup**: Structured record table with type-specific badges (A/MX/TXT/etc.) and resolver presets.
- **WHOIS**: Structured summary header with registrar/expiration tracking and filterable Registry datasets.
- **Network & Wi-Fi**: Vibrant signal strength gauges, RSSI stability charts, and detailed interface topology cards including VLAN detection.
- **Subnet Calculator**: Interactive CIDR topology with bitwise representation visualization.
- **Top Processes**: Real-time per-app network intensity monitor with normalized activity bars.

---

## [2.9.1] — 2026-05-29

### Added
- **Mission Dashboard Overhaul**:
  - New "Network Activity" hero section with real-time aggregate throughput charts.
  - Redesigned system health gauges for CPU and Memory with integrated progress bars.
  - Comprehensive 16-tool Bento grid with pulsing activity indicators.
  - Improved connection labeling (SSID/localized name) and IP visibility.

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
