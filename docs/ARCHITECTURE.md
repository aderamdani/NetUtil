# NetUtil — Architecture Reference

> Definitive codebase reference for AI agents and new developers.
> Read this before touching any code. Keep it updated when structure changes.

---

## 1. Project at a Glance

| Property | Value |
|---|---|
| Type | Native macOS network diagnostics toolkit |
| UI Framework | SwiftUI (Swift 6, `@Observable`) |
| Target | macOS 26+, Apple Silicon only (`arm64`) |
| Architecture | MVVM with single environment hub (`ToolStore`) |
| Dependencies | Zero third-party. Apple frameworks + Darwin APIs + CLI wrappers |
| Version | 4.11.1 (build 51) |
| Bundle ID | `Vertex-Data.NetUtil` |
| Source Files | ~98 Swift source + 25 tests |

---

## 2. Directory Structure

```
NetUtil/
├── NetUtilApp.swift              # @main entry — 5 scenes
├── ContentView.swift             # Tool enum (28 cases) + NavigationSplitView
├── NetUtil.entitlements          # com.apple.security.network.client only
├── Assets.xcassets/              # App icon, accent color
│
├── Models/                       # 32 files — data types, persistence, subprocess wrappers
│   ├── ToolStore.swift           # Central hub — owns all VMs + global state
│   ├── SubprocessRunner.swift    # 3 subprocess abstractions (blocking, streaming, cancellable)
│   ├── PingResult.swift          # Ping output models + rolling stats
│   ├── TracerouteHop.swift       # Hop data with multi-round samples
│   ├── PortResult.swift          # Port scan results + presets
│   ├── DNSRecord.swift           # DNS lookup results + server presets
│   ├── CertInfo.swift            # TLS certificate chain info
│   ├── HTTPLatencyResult.swift   # HTTP phase timing breakdown
│   ├── SubnetScanResult.swift    # Subnet scan per-host results
│   ├── NetworkInterface.swift    # getifaddrs() interface enumeration
│   ├── NetworkMath.swift         # CIDR math, IP formatting, private detection
│   ├── ARPEntry.swift            # arp -an parser
│   ├── NetConnection.swift       # lsof -i parser
│   ├── RouteEntry.swift          # Routing table parser
│   ├── WiFiInfo.swift            # CoreWLAN Wi-Fi details
│   ├── BandwidthMonitor.swift    # Per-interface byte counter sampling
│   ├── SystemMonitor.swift       # CPU + RAM via host_processor_info
│   ├── TrafficStatistics.swift   # 90-day daily totals (UserDefaults)
│   ├── SpeedTestEngine.swift     # Cloudflare speed test (4 modes)
│   ├── SpeedTestModels.swift     # Speed test result types
│   ├── SessionRecord.swift       # Universal session log + snapshots
│   ├── FavoriteHost.swift        # Saved hosts with aliases
│   ├── HostHistory.swift         # MRU host list (20 entries)
│   ├── SSLWatchlist.swift        # SSL cert monitoring
│   ├── Notifier.swift            # macOS notification banners
│   ├── Exporter.swift            # CSV + PDF export for all tools
│   ├── Updater.swift             # GitHub Releases auto-updater
│   ├── WakeOnLan.swift           # Magic packet construction + UDP broadcast
│   ├── IPGeoResult.swift         # ipinfo.io response parser
│   ├── DNSResolverEntry.swift    # scutil --dns parser
│   ├── NetQualityResult.swift    # networkQuality -c JSON parser
│   └── GatewayParser.swift       # netstat -rn default gateway parser
│
├── ViewModels/                   # 22 files — one per tool (all @MainActor @Observable)
│   ├── PingViewModel.swift
│   ├── TracerouteViewModel.swift
│   ├── MultiPingViewModel.swift
│   ├── PortScanViewModel.swift
│   ├── DNSViewModel.swift
│   ├── HTTPLatencyViewModel.swift
│   ├── SSLInspectorViewModel.swift
│   ├── WhoisViewModel.swift
│   ├── NetworkDoctorViewModel.swift
│   ├── PathMTUViewModel.swift
│   ├── SubnetScanViewModel.swift
│   ├── SubnetViewModel.swift
│   ├── NetworkInterfaceViewModel.swift
│   ├── WiFiInspectorViewModel.swift
│   ├── NeighborsViewModel.swift
│   ├── ConnectionsViewModel.swift
│   ├── PortListenerViewModel.swift
│   ├── WakeOnLanViewModel.swift
│   ├── IPGeolocationViewModel.swift
│   ├── DNSResolverViewModel.swift
│   ├── SpeedTestViewModel.swift
│   └── NetQualityViewModel.swift
│
├── Views/                        # 33 root views + subdirectories
│   ├── DashboardView.swift       # Mission control — 4 section sub-views
│   ├── PingView.swift            # + PingControlBar, PingResultsTable, PingLatencyChartView
│   ├── TracerouteView.swift      # + TracerouteControlBar, HopsTable, TimelineView, MapView
│   ├── ...                       # One view per tool
│   ├── AboutView.swift           # Version, tool grid, acknowledgements
│   ├── HelpView.swift            # Learning guide (735+ lines, searchable)
│   ├── MenuBarView.swift         # Menu bar popover content
│   ├── SettingsView.swift        # Tab view: General, Thresholds, Tools, Privacy
│   ├── CompareView.swift         # Side-by-side session comparison
│   ├── SessionHistoryView.swift  # Filtered session log
│   │
│   ├── Components/               # 31 shared components
│   │   ├── ToolControlBar.swift  # Generic control bar scaffold
│   │   ├── ReportMenuButton.swift# Export PDF/CSV dropdown
│   │   ├── StatCard.swift        # Key-value metric card
│   │   ├── MoodBar.swift         # Status interpretation strip
│   │   ├── BentoCard.swift       # Dashboard card container
│   │   ├── DesignSystem.swift    # Metrics constants (fonts, chart windows)
│   │   ├── ToolStateView.swift   # Empty + loading placeholder states
│   │   ├── ErrorBanner.swift     # Error display
│   │   ├── HostHistoryMenu.swift # Recent host dropdown
│   │   ├── ImportHostsSheet.swift# Bulk host import
│   │   ├── PulsingIndicator.swift# Animated "running" dot
│   │   └── ...                   # Traceroute, PortScan, MultiPing sub-components
│   │
│   ├── Dashboard/                # 4 dashboard section views
│   │   ├── DiagnosticsCardsSection.swift
│   │   ├── TrafficCardsSection.swift
│   │   ├── LookupCardsSection.swift
│   │   └── SystemSecurityCardsSection.swift
│   │
│   ├── Ping/                     # 3 ping sub-views
│   │   ├── PingControlBar.swift
│   │   ├── PingResultsTable.swift
│   │   └── PingLatencyChartView.swift
│   │
│   └── Settings/                 # 4 settings panes
│       ├── GeneralPane.swift
│       ├── ThresholdsPane.swift
│       ├── ToolsPane.swift
│       └── PrivacyPane.swift
│
└── NetUtilTests/                 # 25 test files
    ├── PingTests.swift
    ├── TracerouteTests.swift
    ├── NetworkMathTests.swift
    ├── PortModelTests.swift
    ├── DNSTests.swift
    ├── SSLInspectorViewModelTests.swift
    ├── NetworkDoctorTests.swift
    ├── SubprocessRunnerTests.swift
    ├── ExporterTests.swift
    └── ...                       # 16 more test files
```

---

## 3. App Lifecycle

### Entry Point: `NetUtilApp.swift`

```
NetUtilApp (@main)
├── WindowGroup ──→ ContentView ──→ NavigationSplitView
│   ├── Sidebar: Tool enum list with 6 sections
│   └── Detail: toolView(_:) switches on Tool case
├── Window("about") ──→ AboutView
├── Window("help")  ──→ HelpView
├── Settings        ──→ SettingsView (4 tabs)
└── MenuBarExtra    ──→ MenuBarView + MenuBarLabel
```

- **`ToolStore`** is created as `@State` in `NetUtilApp` and injected via `.environment(tools)`.
- `MenuBarExtra` also receives `tools.interfaces` as a separate environment for the interface-aware menu bar label.
- `AppDelegate` handles `applicationShouldTerminateAfterLastWindowClosed` — when `backgroundOnClose` is enabled, closing the window switches to `.accessory` activation policy (Dock icon hidden, menu bar stays alive).
- `NSApplication.showMainWindow()` restores the window from menu bar mode.

### Window Behavior

| Window | Type | Size | Style |
|---|---|---|---|
| Main | `WindowGroup` | 1000×650 min | `.titleBar`, `.unified` toolbar |
| About | `Window(id: "about")` | Content-sized | `.titleBar` |
| Help | `Window(id: "help")` | Content-sized | `.titleBar`, `.unified` |
| Settings | `Settings` | 480×420 | Standard macOS settings |
| Menu Bar | `MenuBarExtra` | 280pt wide | `.window` style |

---

## 4. The Tool Enum

**File:** `ContentView.swift:4-108`

28 cases, each providing:
- `rawValue` — display name (e.g. `"Ping"`)
- `persistenceKey` — stable token (e.g. `"portScan"`), independent of the label; see `Models/ToolMetadata.swift`
- `group` — `ToolGroup` sidebar section (Core, Active Probing, IP Toolbox, Lookup & Security, Bandwidth, Network Status)
- `canBeDisabled` — false for core tools (Dashboard, Statistics, History)
- `icon` — SF Symbol name
- `shortcut` / `shortcutModifiers` — keyboard navigation (two banks: `Cmd+1-9`, `Opt+Cmd+1-9`)

Sidebar sections are generated data-driven from `ToolGroup.allCases` + `ToolCatalog.availableTools(in:)` (disabled tools hidden, empty sections skipped). A selection pointing at a newly-disabled tool falls back to `.dashboard` via `Tool.fallbackSelection`. Keyboard shortcuts register for available tools only.

**Tool availability** — `Models/ToolCatalog.swift` (`@MainActor @Observable`): persists disabled `persistenceKey`s in UserDefaults (`com.netutil.disabledTools`, default all available). Toggled per group in Settings > Tools. `ToolStore` owns the catalog and stops/starts the matching pollers (`BandwidthMonitor`, interface polling, `DNSResolverViewModel`) so a disabled tool costs zero CPU.

Sidebar sections (in order):
1. **Favorites** — dynamic, from `tools.favorites`
2. **General** — Dashboard, Doctor, History, Compare
3. **Active Probing** — Ping, Traceroute, Multi-Ping, Port Scanner, HTTP Latency, Path MTU
4. **IP Toolbox** — Subnet Scanner, Subnet Calc, Wake on LAN, Port Listener, IP Geolocation
5. **Lookup & Security** — DNS Lookup, DNS Resolver, SSL/TLS, WHOIS
6. **Bandwidth** — Bandwidth, Statistics, Speed Test, Net Quality
7. **Network Status** — Interfaces, Wi-Fi, Routes, Neighbors, Connections

Detail pane routing via `toolView(_ tool: Tool) -> some View` — a `@ViewBuilder` switch mapping each case to its concrete View, passing the ViewModel from `ToolStore`.

---

## 5. ToolStore — The Central Hub

**File:** `Models/ToolStore.swift` (244 lines)

```swift
@MainActor @Observable final class ToolStore
```

### Responsibilities

1. **Owns all ViewModels** — 22 `let` properties, one per tool
2. **Owns global state** — `externalIP`, `externalIPGeo`, `isVPNActive`, `primaryLocalIP`, `currentConnectionName`, `primaryInterface`
3. **Owns health status** — `healthIcon`, `healthColor`, `healthMessage` (derived from SSL watchlist, ping loss, Wi-Fi RSSI)
4. **Owns shared managers** — `statistics`, `sslWatchlist`, `favorites`, `sessionHistory`
5. **Wires session logging** — connects `onSessionComplete` closures from 12 ViewModels to `SessionHistory`
6. **Manages app-lifetime polling** — `BandwidthMonitor`, `SystemMonitor`, `TrafficStatistics`, `NetworkInterfaceViewModel`, `WiFiInspectorViewModel`
7. **Battery optimization** — `pauseMonitoring()` / `resumeMonitoring(reduced:)` drops to reduced polling when no window is visible or in accessory mode
8. **Global status refresh** — `refreshGlobalStatus()` fetches external IP via ipinfo.io, detects VPN, resolves connection name

### Initialization Flow

```
ToolStore.init()
├── bandwidth.onAggregateDelta = { statistics.record(rxDelta:txDelta:) }
├── bandwidth.start()
├── wireSessionLogging()          # Connect 12 VMs' onSessionComplete → sessionHistory
├── refreshGlobalStatus()         # External IP, VPN, connection name, health
├── dnsResolver.start()           # Background DNS resolver probing
├── observeActivationPolicy()     # NSNotification for accessory mode changes
└── observeOcclusion()            # NSNotification for window visibility changes
```

### How Views Access ViewModels

```swift
// In any View:
@Environment(ToolStore.self) private var tools

// Access a specific VM:
let pingVM = tools.ping
let sslVM = tools.ssl
```

---

## 6. ViewModel Layer

All ViewModels share these conventions (no shared protocol — enforced by convention):

```swift
@MainActor
@Observable
final class SomeViewModel {
    // Observable state (UI binds to these)
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var results: [Result] = []
    var onSessionComplete: ((SessionRecord) -> Void)?

    // Internal state (NOT observed by SwiftUI)
    @ObservationIgnored private var runID = 0
    @ObservationIgnored private var subprocess = StreamingSubprocess()
    @ObservationIgnored nonisolated(unsafe) private var task: Task<Void, Never>?

    // Pre-compiled regex (background-safe)
    private nonisolated static let pattern = try? NSRegularExpression(pattern: "...")

    func start(/* parameters */) { ... }
    func stop() { ... }
}
```

### Common Patterns

| Pattern | Purpose | Example |
|---|---|---|
| `runID` generation token | Prevent stale callbacks from corrupting new run | PingViewModel:46 |
| `@ObservationIgnored` | Exclude internal state from `@Observable` tracking | Subprocess handles, timers, buffers |
| `nonisolated(unsafe)` | Cross-isolation Task handles | `task: Task<Void, Never>?` |
| `nonisolated static func` | Pure parsing off MainActor | `PingViewModel.parseLine(_:)` |
| `onSessionComplete` closure | Log finished runs to SessionHistory | Wired in `ToolStore.wireSessionLogging()` |
| `start()` / `stop()` lifecycle | Match view appear/disappear | All VMs |

### 22 ViewModel Inventory

| ViewModel | File | Lines | Data Source | Category |
|---|---|---|---|---|
| `PingViewModel` | PingViewModel.swift | 319 | `/sbin/ping` via StreamingSubprocess | Streaming |
| `TracerouteViewModel` | TracerouteViewModel.swift | 261 | `/usr/sbin/traceroute` via StreamingSubprocess | Streaming |
| `MultiPingViewModel` | MultiPingViewModel.swift | 159 | `/sbin/ping` per slot via StreamingSubprocess | Streaming |
| `PathMTUViewModel` | PathMTUViewModel.swift | 132 | `/sbin/ping -D -s` via SubprocessRunner | Streaming |
| `PortScanViewModel` | PortScanViewModel.swift | 181 | `NWConnection` (TCP) via withTaskGroup | Network.framework |
| `PortListenerViewModel` | PortListenerViewModel.swift | 108 | `NWListener` (TCP/UDP) | Network.framework |
| `SSLInspectorViewModel` | SSLInspectorViewModel.swift | 186 | `URLSession` + `SecTrust` | URLSession |
| `HTTPLatencyViewModel` | HTTPLatencyViewModel.swift | 166 | `URLSessionTaskMetrics` | URLSession |
| `DNSViewModel` | DNSViewModel.swift | 125 | `/usr/bin/dig` via CancellableSubprocess | One-shot |
| `WhoisViewModel` | WhoisViewModel.swift | 64 | `/usr/bin/whois` via CancellableSubprocess | One-shot |
| `NetQualityViewModel` | NetQualityViewModel.swift | 75 | `/usr/bin/networkQuality -c` via CancellableSubprocess | One-shot |
| `SubnetScanViewModel` | SubnetScanViewModel.swift | 191 | ping + arp + host via SubprocessRunner + withTaskGroup | Subprocess |
| `SubnetViewModel` | SubnetViewModel.swift | 46 | `NetworkMath` (pure computation) | Pure |
| `DNSResolverViewModel` | DNSResolverViewModel.swift | 84 | `/usr/sbin/scutil --dns` + dig probe via SubprocessRunner | Subprocess |
| `NetworkDoctorViewModel` | NetworkDoctorViewModel.swift | 226 | ping + dig + URLSession (sequential steps) | Mixed |
| `NetworkInterfaceViewModel` | NetworkInterfaceViewModel.swift | 48 | `getifaddrs()` + GatewayParser | Darwin API |
| `WiFiInspectorViewModel` | WiFiInspectorViewModel.swift | 77 | `CoreWLAN.CWWiFiClient` | Darwin API |
| `NeighborsViewModel` | NeighborsViewModel.swift | 45 | `/usr/sbin/arp -an` via SubprocessRunner | Timer-polling |
| `ConnectionsViewModel` | ConnectionsViewModel.swift | 63 | `/usr/sbin/lsof -i -n -P` via SubprocessRunner | Timer-polling |
| `WakeOnLanViewModel` | WakeOnLanViewModel.swift | 25 | BSD socket (UDP broadcast) | Socket |
| `IPGeolocationViewModel` | IPGeolocationViewModel.swift | 74 | ipinfo.io REST API | URLSession |
| `SpeedTestViewModel` | SpeedTestViewModel.swift | 160 | Cloudflare API via SpeedTestEngine | URLSession |

---

## 7. Subprocess Patterns

**File:** `Models/SubprocessRunner.swift` (110 lines)

Three tiers for different use cases:

### 7a. `SubprocessRunner` — Blocking One-Shot

```swift
enum SubprocessRunner {
    nonisolated static func run(
        executable: String,
        arguments: [String],
        mergeStderr: Bool = false
    ) -> String
```

- Blocks until process completes
- **Drains pipe BEFORE `waitUntilExit()`** (avoids deadlock on large output)
- Used by: `SubnetScanViewModel`, `ConnectionsViewModel`, `NeighborsViewModel`, `DNSResolverViewModel`, `NetworkDoctorViewModel`, `GatewayParser`, `NetworkInterfaceFetcher`, `PathMTUViewModel`

### 7b. `StreamingSubprocess` — Continuous Stream

```swift
final class StreamingSubprocess {
    func run(
        executable: String,
        arguments: [String],
        onChunk: @escaping @Sendable (String) -> Void,
        onTerminate: @escaping @Sendable () -> Void
    ) throws
    func stop()
```

- Uses `readabilityHandler` on pipe's file handle for real-time chunks
- Both callbacks fire on pipe's **background readability queue** — callers must hop to `@MainActor`
- Used by: `PingViewModel`, `TracerouteViewModel`, `MultiPingViewModel` (via `PingSlot`)

### 7c. `CancellableSubprocess` — One-Shot + Cancel

```swift
final class CancellableSubprocess {
    func launch(executable: String, arguments: [String]) throws  // synchronous
    func collectOutput() async -> String                          // async drain
    func terminate()
```

- `launch()` throws synchronously so launch failures surface before any `await`
- `collectOutput()` drains on `Task.detached` off calling actor
- Used by: `DNSViewModel`, `WhoisViewModel`, `NetQualityViewModel`

### Deadlock Prevention Rule

**Always drain the pipe BEFORE calling `waitUntilExit()`.** If you wait first, the process blocks when the pipe buffer fills, and you block waiting for exit — deadlock. All three wrappers follow this rule.

---

## 8. Concurrency Patterns

### 8a. `@MainActor` Everything

All ViewModels and ToolStore are `@MainActor`. Background work via:
- `Task.detached` — for parallel operations (port scan, subnet scan, speed test)
- `nonisolated static func` — for pure parsing (regex, line parsing)
- `nonisolated(unsafe)` — for Task handles crossing isolation boundaries

### 8b. Generation Tokens (`runID`)

Every ViewModel that spawns a subprocess uses a `runID` counter:

```swift
@ObservationIgnored private var runID = 0

func start(...) {
    stop()              // increments runID
    runID += 1          // new token
    let id = runID      // capture for closure
    // ... spawn process
    // In callback:
    guard self.runID == id else { return }  // discard stale
}
```

Prevents terminated processes from polluting newer runs.

### 8c. `withTaskGroup` for Parallel Operations

Used in:
- `PortScanViewModel.runScan()` — sliding-window concurrent port scan
- `SubnetScanViewModel.start()` — batched ping sweep
- `SpeedTestEngine` — parallel download/upload measurement
- `DNSResolverViewModel.start()` — parallel nameserver latency probes

### 8d. Timer-Based Polling

| ViewModel | Interval | Pauses on occlusion? |
|---|---|---|
| `BandwidthMonitor` | 1-10s (dynamic) | Yes |
| `SystemMonitor` | 2-10s | Yes |
| `TrafficStatistics` | 30s (save only) | Yes |
| `NetworkInterfaceViewModel` | 3-15s | Yes |
| `WiFiInspectorViewModel` | 2s | Yes |
| `NeighborsViewModel` | 5s | No (tool-scoped) |
| `ConnectionsViewModel` | 5s | No (tool-scoped) |

### 8e. The One Actor: `ByteCounter`

Only one `actor` in the codebase: `ByteCounter` inside `SpeedTestEngine` — thread-safe atomic byte counter for parallel download/upload measurement.

---

## 9. Data Models

### CLI Output Parsers

Every parser is a `nonisolated static func` on the model struct — runs off MainActor:

| Model | Parses | Key Fields |
|---|---|---|
| `PingResult` / `PingStats` | `/sbin/ping` output | sequence, bytes, ttl, rtt, host, status; rolling stats (min/max/avg/jitter, distribution) |
| `TracerouteHop` / `GeoInfo` | `/usr/bin/traceroute` output | hop, ip, host, sent/recv/loss, min/avg/max/jitter, bottleneck flag, geo |
| `PortResult` | NWConnection result | port, status (open/closed/filtered), service name, latency |
| `DNSRecord` / `DNSResult` | `/usr/bin/dig` output | name, ttl, type, value; query time, server |
| `CertInfo` / `CertResult` | `SecTrust` chain | subject, issuer, SANs, serial, sha256, keyType, expiry, daysRemaining |
| `HTTPLatencyResult` | `URLSessionTaskMetrics` | phases (DNS/TCP/TLS/Request/TTFB/Download), totalMs, statusCode |
| `ARPEntry` | `/usr/sbin/arp -an` | ip, mac, interface, type (host/broadcast/multicast) |
| `NetConnection` | `/usr/sbin/lsof -i -n -P` | pid, process, protocol, state, local/remote address |
| `RouteEntry` | `/usr/sbin/netstat -rn` | destination, gateway, flags, interface |
| `SubnetScanResult` | ping + arp + host | ip, hostname, status, rtt, mac |
| `DNSResolverEntry` | `/usr/sbin/scutil --dns` | resolver nameservers, search domains, latency |
| `IPGeoResult` | `ipinfo.io/json` | ip, city, region, country, org, loc, asn |
| `NetQualityResult` | `networkQuality -c` JSON | download/upload, responsiveness, rpm, baseLatency |
| `WiFiInfo` | CoreWLAN | ssid, bssid, rssi, channel, band, security, txRate |

### Network Math

`NetworkMath.swift` — pure computation, no I/O:
- Subnet calculation (CIDR → network, broadcast, range, hosts)
- IP class detection, private IP check (RFC 1918 + APIPA 169.254/16)
- Byte/rate formatting (`formatBytes`, `formatRate`)
- IPv4 parsing and validation

### Persistence (UserDefaults)

| Manager | Key | Data | Max |
|---|---|---|---|
| `SessionHistory` | `sessionHistory` | `[SessionRecord]` (Codable) | 200 records, 20 with detail |
| `TrafficStatistics` | `trafficStats` | `[DayTotal]` (Codable) | 90 days |
| `FavoritesManager` | `favorites` | `[FavoriteHost]` (Codable) | 20 |
| `HostHistory` | `hostHistory` | `[String]` | 20 entries |
| `SSLWatchlist` | `sslWatchlist` | `[SSLWatchItem]` (Codable) | Unlimited |
| Settings | Various keys | Primitives via `@AppStorage` | — |

---

## 10. View Layer Patterns

### Standard Tool View Structure

Every tool view follows this pattern:

```swift
struct SomeToolView: View {
    @Bindable var vm: SomeToolViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            // 1. Control Bar — fixed top
            ToolControlBar(/* ... */) {
                ReportMenuButton(/* ... */)
            }

            // 2. MoodBar — status interpretation
            MoodBar(icon: vm.statusIcon, message: vm.statusMessage)

            // 3. Content — scrollable
            ScrollView {
                VStack(spacing: 24) {
                    ErrorBanner(message: vm.error)       // conditional
                    statsBarSection                       // HStack of StatCards
                    mainContent                           // Charts, Tables, etc.
                    ToolStateView.empty(...)              // when no data
                }
            }
        }
        .sheet(isPresented: $showLearningGuide) {
            HelpView(topic: "Tool Name")
        }
    }
}
```

### Shared Components Reference

| Component | File | Purpose |
|---|---|---|
| `ToolControlBar<Trailing>` | Components/ToolControlBar.swift | Generic scaffold: icon + title + TextField + trailing slot |
| `ReportMenuButton` | Components/ReportMenuButton.swift | "Export PDF" / "Export CSV" / "Copy Summary" |
| `StatCard` | Components/StatCard.swift | Key-value metric card (caption title, monospaced value) |
| `MoodBar<Accessory>` | Components/MoodBar.swift | Status strip under control bar |
| `BentoCard<Content>` | Components/BentoCard.swift | Dashboard card with title/icon header |
| `ToolStateView` | Components/ToolStateView.swift | `.empty(title:subtitle:)` and `.loading(message:)` |
| `ErrorBanner` | Components/ErrorBanner.swift | Red warning banner |
| `HostHistoryMenu` | Components/HostHistoryMenu.swift | Clock dropdown on text fields |
| `DesignSystem.Metrics` | Components/DesignSystem.swift | Global font/spacing constants |

### Dashboard Structure

```
DashboardView
├── Header Bar (hostname, connection name, IPs, VPN badge, uptime, CPU/RAM gauges)
├── MoodBar (global health status)
└── ScrollView
    ├── DashboardHeroSection      — Live RX/TX chart (SwiftUI Charts)
    ├── DiagnosticsCardsSection   — Ping, Multi-Ping, Port Scanner cards
    ├── TrafficCardsSection       — Bandwidth, Stats, Interfaces, Wi-Fi, etc.
    ├── LookupCardsSection        — WHOIS, Subnet Calc, IP Geo, DNS Resolver
    └── SystemSecurityCardsSection— Doctor, Net Quality, Port Listener, etc.
```

---

## 11. Export System

**File:** `Models/Exporter.swift` (744 lines)

### CSV Export

```swift
enum Exporter {
    static func csvField(_ value: String) -> String  // RFC 4180 escaping
    static func csvString(from results: [PingResult]) -> String
    static func csvString(from hops: [TracerouteHop]) -> String
    // ... 14 tool-specific CSV generators
}
```

### PDF Export

```swift
enum Exporter {
    static func savePingPDF(results:stats:host:, panel:NSSavePanel)
    static func saveTraceroutePDF(hops:stats:host:, panel:NSSavePanel)
    // ... 17 tool-specific PDF generators
}
```

PDFs are built with `CGContext` directly — no third-party PDF library.

### Filename Convention

```
NetUtil-[Tool]-[target]-yyyyMMdd-HHmmss.[csv|pdf]
```

### `ReportMenuButton` Component

Standardized dropdown in every tool's control bar:
- "Export PDF" → `NSSavePanel` → `Exporter.save*PDF`
- "Export CSV" → `NSSavePanel` → `Exporter.save*CSV`
- "Copy Summary" → `NSPasteboard` (on supported tools)

---

## 12. Darwin & System APIs

| API | File(s) | Purpose |
|---|---|---|
| `getifaddrs()` / `freeifaddrs()` | NetworkInterface.swift, BandwidthMonitor.swift | Interface enumeration, IPs, MACs, MTUs, byte counters |
| `getnameinfo()` | NetworkInterface.swift | sockaddr → IP string |
| `AF_LINK` / `if_data` | BandwidthMonitor.swift | Raw byte counts, interface type |
| `host_processor_info()` | SystemMonitor.swift | CPU usage per core |
| `host_statistics64()` | SystemMonitor.swift | Memory pressure, RAM usage |
| `sysctlbyname("hw.memsize")` | SystemMonitor.swift | Total RAM |
| `SCNetworkInterfaceCopyAll()` | ToolStore.swift | Localized interface names |
| `CWWiFiClient` | WiFiInspectorViewModel.swift, ToolStore.swift | Wi-Fi SSID, RSSI, channel, security, txRate |
| `SecTrust` / `SecCertificate` | SSLInspectorViewModel.swift | TLS certificate chain inspection |
| `SecCertificateCopyValues()` | SSLInspectorViewModel.swift | Cert expiry, issuer, SANs |
| `SecCertificateCopyKey()` | SSLInspectorViewModel.swift | Key type/size |
| `SHA256` (CryptoKit) | SSLInspectorViewModel.swift | Certificate fingerprinting |
| `NWConnection` | PortScanViewModel.swift | TCP port scanning |
| `NWListener` | PortListenerViewModel.swift | TCP/UDP port listening |
| BSD socket (`socket`, `sendto`) | WakeOnLan.swift | UDP broadcast for Wake-on-LAN |
| `URLSessionTaskMetrics` | HTTPLatencyViewModel.swift | HTTP phase-by-phase timing |
| `CGContext` | Exporter.swift | PDF report rendering |

### CLI Tools Used

| CLI | Path | Used By |
|---|---|---|
| `ping` | `/sbin/ping` | PingVM, MultiPingVM, PathMTUVM, SubnetScanVM, DoctorVM |
| `traceroute` | `/usr/sbin/traceroute` | TracerouteVM |
| `dig` | `/usr/bin/dig` | DNSVM, DoctorVM, DNSResolverVM |
| `whois` | `/usr/bin/whois` | WhoisVM |
| `arp` | `/usr/sbin/arp` | SubnetScanVM, NeighborsVM |
| `lsof` | `/usr/sbin/lsof` | ConnectionsVM |
| `netstat` | `/usr/sbin/netstat` | GatewayParser, RouteTableView |
| `host` | `/usr/bin/host` | SubnetScanVM |
| `scutil` | `/usr/sbin/scutil` | DNSResolverVM |
| `networkQuality` | `/usr/bin/networkQuality` | NetQualityVM |
| `ifconfig` | `/sbin/ifconfig` | NetworkInterfaceFetcher (VLAN details) |

---

## 13. Build Configuration

From `project.pbxproj`:

| Setting | Value |
|---|---|
| `SWIFT_VERSION` | 6.0 |
| `SWIFT_STRICT_CONCURRENCY` | `complete` |
| `SWIFT_COMPILATION_CACHING` | YES |
| `SWIFT_COMPILATION_MODE` | `singlefile` (Debug), `wholemodule` (Release) |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS` | YES |
| `MACOSX_DEPLOYMENT_TARGET` | 26.5 |
| `MARKETING_VERSION` | 4.11.1 |
| `CURRENT_PROJECT_VERSION` | 51 |
| `ARCHS` | arm64 (Apple Silicon only) |
| `CODE_SIGN_ENTITLEMENTS` | `NetUtil/NetUtil.entitlements` |

Entitlements: only `com.apple.security.network.client` (outbound connections).

---

## 14. Key Conventions for New Code

### Adding a New Tool

1. **Add case to `Tool` enum** in `ContentView.swift` — provide `icon`, `shortcut`, `shortcutModifiers`
2. **Create ViewModel** in `ViewModels/` — follow `@MainActor @Observable final class` pattern
3. **Create View** in `Views/` — follow standard tool view structure (Section 10)
4. **Add VM to `ToolStore`** — `let myTool = MyToolViewModel()` property
5. **Wire session logging** — set `myTool.onSessionComplete` in `ToolStore.wireSessionLogging()`
6. **Add routing** — add case to `toolView(_:)` switch in `ContentView.swift`
7. **Add to sidebar** — add to appropriate section in `ContentView.swift` sidebar List
8. **Add keyboard shortcut** — assign from available digit bank
9. **Add to `AboutView.toolList`** — icon + name tuple
10. **Add learning guide** — create `HelpView(topic: "My Tool")` content
11. **Add export** — implement CSV/PDF methods in `Exporter.swift`, wire `ReportMenuButton`
12. **Add to Dashboard** — optionally add a BentoCard in the appropriate section

### Adding a New ViewModel

```swift
@MainActor
@Observable
final class NewToolViewModel {
    // Observable state
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var results: [Result] = []
    var onSessionComplete: ((SessionRecord) -> Void)?

    // Internal (not observed)
    @ObservationIgnored private var runID = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    func start(/* params */) { ... }
    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        runID += 1
    }
}
```

### Error Handling

- Store errors as `private(set) var error: String?` — user-facing string
- Catch `CancellationError` explicitly and return silently
- Use `guard let` / `if let` — never force unwrap
- `WakeOnLanError` is the only typed error enum (for validation errors)

### SwiftUI Rules

- Extract subviews when `body` exceeds 50 lines
- Never `AnyView` — use `@ViewBuilder` or `some View`
- `.task {}` for async work (exception: Dashboard uptime ticker uses `.onAppear`)
- Never modify `@State` during body evaluation
- Never `DispatchQueue.main.async` — use `await MainActor.run {}`

---

## 15. Quick Reference: Which File to Edit

| Task | File(s) |
|---|---|
| Add a new tool | `ContentView.swift` (Tool enum + routing), `ViewModels/`, `Views/`, `ToolStore.swift`, `Exporter.swift`, `AboutView.swift` |
| Fix a tool's behavior | The tool's ViewModel in `ViewModels/` |
| Fix a tool's UI | The tool's View in `Views/` |
| Change dashboard cards | `Views/Dashboard/*Section.swift` |
| Modify export format | `Models/Exporter.swift` |
| Change subprocess behavior | `Models/SubprocessRunner.swift` |
| Modify global state | `Models/ToolStore.swift` |
| Change persistence | The model file + UserDefaults keys |
| Add shared UI component | `Views/Components/` |
| Modify settings | `Views/Settings/` panes |
| Change keyboard shortcuts | `ContentView.swift` Tool enum (`shortcut`, `shortcutModifiers`) |
| Update version | `project.pbxproj` (MARKETING_VERSION, CURRENT_PROJECT_VERSION), `AboutView.swift` |
| Add unit test | `NetUtilTests/` |

---

*Documentation Version: 4.11.1 (September 11, 2026)*
