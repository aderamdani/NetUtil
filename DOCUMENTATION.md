# NetUtil — Technical Documentation

Professional Network Diagnostics Toolkit for macOS.

## 1. Overview
NetUtil is a native macOS application built with SwiftUI and Swift 6, designed for system administrators, network engineers, and power users. It provides a comprehensive suite of tools for monitoring, analyzing, and debugging network connectivity with a clean, symmetrical, and modern interface.

### Key Philosophy
- **Apple Artisan Design**: Adheres strictly to the "Native macOS Anti-Slop Guidelines" — utilizing flat data hierarchies, true material vibrancy (`.regularMaterial`), and data-dense silent states.
- **Accessibility Centric**: Fully audited for VoiceOver support, including descriptive labels and consolidated information elements for an inclusive experience.
- **GPU-Accelerated Performance**: Real-time charts and sparklines leverage `.drawingGroup()` to ensure smooth UI performance under high-frequency data updates.
- **Zero Third-Party Dependencies**: Built entirely using native macOS frameworks (SwiftUI, Network.framework, CoreWLAN, etc.).

---

## 2. System Architecture

NetUtil follows a strict **MVVM (Model-View-ViewModel)** architectural pattern.

### Core Layers
- **Views**: SwiftUI-based interface. Large views are decomposed into modular components in `Views/Components/` to maintain high readability and focus.
- **ViewModels**: Manage state and business logic, isolated to `@MainActor` with strict concurrency enforcement.
- **Models**: Efficient value types and data-management singletons (e.g., `HostHistory`, `Exporter`, `NetworkMath`).

### Concurrency & Performance
- **Structured Concurrency**: Utilizes `TaskGroup` and `async let` for parallel operations like port scanning.
- **Lifecycle Safety**: ViewModels explicitly manage background task handles to ensure proper cancellation and zero resource leaks on deinit.
- **GPU Rendering**: Complex Swift Charts are offloaded to the GPU using the `.drawingGroup()` modifier to prevent Main Thread contention.

---

## 3. Detailed Toolset

### Overview
- **Bento Dashboard**: Home screen featuring a curated "Bento Box" layout. Displays live status cards for active tools (Ping, Port Scan, etc.), real-time CPU/RAM gauges, and pulsing green activity indicators.

### Connectivity & Latency
- **Advanced Ping**: Live RTT chart with packet loss bars, jitter analysis, RTT distribution histograms, and configurable audio feedback ("Beep on Loss"). Export via PDF or CSV.
- **Multi-Ping**: Monitor multiple hosts simultaneously with live sparklines, color-coded stability indicators, and custom host aliases. Consolidated PDF report for all hosts.
- **Traceroute**: Comprehensive hop-by-hop path analysis with four view modes:
  - **Table**: Sortable columns with sparklines and detailed metrics (Min/Avg/Max/StdDev).
  - **Timeline**: Stacked per-hop bar charts.
  - **Map**: MapKit-powered interactive map with geo-resolved colored pins.
  - **Console**: Plain traceroute CLI output.
- **HTTP Latency**: Phase-by-phase breakdown (DNS, TCP, TLS, TTFB, Download) using `URLSessionTaskMetrics`. Includes a latency waterfall chart and history tracking.

### IP Toolbox
- **Subnet Calculator**: Network math utility supporting CIDR prefixes, wildcard masking, IP class detection, and 32-bit binary representation.

### Discovery & Analysis
- **Port Scanner**: High-speed TCP port scanner with customizable ranges and concurrency controls. Results are displayed in a modern, scannable mini-card grid layout.
- **SSL/TLS Inspector**: Full certificate chain analysis, expiry tracking, TLS version badge, and cipher suite verification.
- **DNS Lookup**: Comprehensive query tool (A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, ANY) using `dig`. Multiple server presets.
- **WHOIS**: Structured key/value display of domain registration and ownership records, with inline filtering.

### System & Monitoring
- **Bandwidth Monitor**: Real-time RX/TX rate per interface with 60-second rolling area charts. State persists across navigation.
- **Network Interfaces**: Hardware interfaces via `getifaddrs()` — MAC, IPv4, IPv6, MTU. Includes automatic detection and labeling of Virtual LANs (802.1Q).
- **Wi-Fi Inspector**: Signal analysis via CoreWLAN — SSID, BSSID, RSSI, SNR, channel, security. Includes an RSSI stability sparkline.
- **Route Table**: IPv4 and IPv6 routing rules via `netstat -rn`, with flag descriptions and live text filter.

### Settings
macOS System Settings–style TabView with four fragmented panes:
- **General**: Default limits, operational parameters, and Menu Bar settings.
- **Thresholds**: RTT color-zone boundaries (good/warn/critical) with a live animated preview bar.
- **Tools**: Per-tool timeouts and concurrency settings.
- **Privacy**: Geolocation toggle, host history management, and zero-telemetry disclosure.

---

## 4. User Interface Conventions (Anti-Slop)

NetUtil enforces a strict "Native macOS Polish" across all views:
- **Symmetrical Layouts**: Every tool uses the exact same header structure — Input (Left), Settings (Center), Actions (Right).
- **Fixed Headers**: Tool control bars are locked at the top, preventing layout shifts when analysis results populate.
- **Global Search**: `Cmd+F` opens a universal search bar in the sidebar to recall host history instantly.
- **Keyboard Navigation**: `Cmd+1` through `Cmd+9` allows rapid switching between primary tools.
- **Vibrant Materials**: Utilization of `.regularMaterial` ensures UI elements react dynamically to the macOS desktop background.
- **Silent States**: Empty states use quiet `.secondary` text instead of massive, shouting icons.

---

## 5. Development & Testing

### Requirements
- **macOS**: 15.0 (Sequoia) or later.
- **Xcode**: 16.0 or later.
- **Tools**: `create-dmg` (for building installers).

### Testing Infrastructure
NetUtil uses a native Xcode test target (**NetUtilTests**) for automated verification.
- **Logic Coverage**: Unit tests cover core parsers (Ping, Traceroute, DNS), network math, and status models.
- **Execution**: Run tests directly in Xcode (`Cmd+U`) or via CLI:
  ```bash
  xcodebuild test -project NetUtil.xcodeproj -scheme NetUtil -destination 'platform=macOS'
  ```

### Release Workflow
Releases are built locally and published via GitHub CLI.
1. Bump version in `project.pbxproj` and add detailed notes to `CHANGELOG.md`.
2. Build & Package: `bash scripts/build_dmg.sh` → produces `dist/NetUtil-X.X.X.dmg`.
3. Publish: `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "vX.X.X" --notes "..."`.

---

## 6. Maintenance & Procedures

Refer to these internal documents for specific guidance:
- `CLAUDE.md`: Internal agent instructions, strict UI/UX guidelines, and release checklists.
- `CHANGELOG.md`: Historical record of all versions and changes.
- `ROADMAP.md`: Planned features and versioning roadmap.
- `QA-CLINICAL-TEST.md`: Functional test scenarios and clinical HIG audit logs.

---

*Documentation Version: 4.0.0 (May 31, 2026)*
*Primary Developer: Ade Ramdani*
