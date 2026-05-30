# NetUtil — Technical Documentation

Professional Network Diagnostics Toolkit for macOS.

## 1. Overview
NetUtil is a native macOS application built with SwiftUI and Swift 6, designed for system administrators, network engineers, and power users. It provides a comprehensive suite of tools for monitoring, analyzing, and debugging network connectivity with a clean, symmetrical, and modern interface.

### Key Philosophy
- **Apple Artisan Design**: Adheres strictly to the "Native macOS Anti-Slop Guidelines" — utilizing flat data hierarchies, true material vibrancy (`.regularMaterial`), and data-dense silent states to avoid generic web-style layouts.
- **Zero Third-Party Dependencies**: Built entirely using native macOS frameworks (SwiftUI, Network.framework, CoreWLAN, etc.).
- **Performance**: High-concurrency operations (like port scanning) are optimized for modern Apple Silicon.
- **Privacy**: No telemetry. All diagnostic data stays local to your machine.

---

## 2. System Architecture

NetUtil follows a strict **MVVM (Model-View-ViewModel)** architectural pattern.

### Core Layers
- **Views**: SwiftUI-based interface. Highly modular, with each tool having its own dedicated view following a symmetrical layout (Fixed Top Header + Interpretation Bar + Stat Bar + Flat Results).
- **ViewModels**: Manage state, process CLI output, and handle business logic. Isolated to `@MainActor`.
- **Models**: Simple data structures and singletons for cross-tool functionality (e.g., `HostHistory`, `Exporter`, `NetworkMath`).

### Process Execution Engine
Most tools utilize a custom execution engine that wraps standard macOS CLI tools:
1. Spawns a `Process` (e.g., `/sbin/ping`).
2. Captures output via `Pipe`.
3. Streams output through `fileHandleForReading.readabilityHandler`.
4. Parses raw text into structured Models using `NSRegularExpression` on background threads.
5. Publishes updates to the UI via `@Published` properties on the Main Actor.

---

## 3. Detailed Toolset

### Overview
- **Bento Dashboard**: Home screen featuring a curated "Bento Box" layout. Displays live status cards for active tools (Ping, Port Scan, etc.), real-time CPU/RAM gauges, and pulsing green activity indicators.

### Connectivity & Latency
- **Advanced Ping**: Live RTT chart with packet loss bars, jitter analysis, RTT distribution histograms, and configurable audio feedback ("Beep on Loss"). Export via PDF or CSV.
- **Multi-Ping**: Monitor multiple hosts simultaneously with live sparklines, color-coded stability indicators, and custom host aliases. Consolidated PDF report for all hosts.
- **Traceroute**: Comprehensive hop-by-hop path analysis with five view modes:
  - **Live Graph** (default): PingPlotter-style heatmap with inline RTT area charts.
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
macOS System Settings–style sidebar navigation with four panes:
- **General**: Default limits and operational parameters.
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

## 5. Development & CI/CD

### Requirements
- **macOS**: 15.0 (Sequoia) or later.
- **Xcode**: 16.0 or later.
- **Tools**: `create-dmg` (for building installers).

### Release Workflow
Releases are built locally and published via GitHub CLI. **It is mandatory to update `CHANGELOG.md` before executing a release.**
1. Bump `MARKETING_VERSION` in `project.pbxproj` and add detailed notes to `CHANGELOG.md`.
2. Build: `xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release`.
3. Package: `bash scripts/build_dmg.sh` → produces `dist/NetUtil-X.X.X.dmg`.
4. Commit, push, tag, create GitHub Release with the DMG attached.

---

## 6. Maintenance & Procedures

Refer to these internal documents for specific guidance:
- `CLAUDE.md`: Internal agent instructions, strict UI/UX guidelines, and release checklists.
- `CHANGELOG.md`: Historical record of all versions and changes.
- `ROADMAP.md`: Planned features and versioning roadmap.

---

*Documentation Version: 3.3.0 (May 2026)*
*Primary Developer: Ade Ramdani*
