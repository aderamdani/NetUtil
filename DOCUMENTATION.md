# NetUtil — Comprehensive Documentation

Professional Network Diagnostics Toolkit for macOS.

## 1. Overview
NetUtil is a native macOS application built with SwiftUI and Swift 6, designed for system administrators, network engineers, and power users. It provides a comprehensive suite of tools for monitoring, analyzing, and debugging network connectivity with a clean, modern interface.

### Key Philosophy
- **Zero Third-Party Dependencies**: Built entirely using native macOS frameworks (SwiftUI, Network.framework, CoreWLAN, etc.).
- **Performance**: High-concurrency operations (like port scanning) are optimized for modern Apple Silicon.
- **Privacy**: No telemetry. All diagnostic data stays local to your machine.

---

## 2. System Architecture

NetUtil follows a strict **MVVM (Model-View-ViewModel)** architectural pattern.

### Core Layers
- **Views**: SwiftUI-based interface. Highly modular, with each tool having its own dedicated view.
- **ViewModels**: Manage state, process CLI output, and handle business logic. Isolated to `@MainActor`.
- **Models**: Simple data structures and singletons for cross-tool functionality (e.g., `HostHistory`, `Exporter`).

### Process Execution Engine
Most tools utilize a custom execution engine that wraps standard macOS CLI tools:
1. Spawns a `Process` (e.g., `/sbin/ping`).
2. Captures output via `Pipe`.
3. Streams output through `fileHandleForReading.readabilityHandler`.
4. Parses raw text into structured Models using `NSRegularExpression` on background threads.
5. Publishes updates to the UI via `@Published` properties on the Main Actor.

---

## 3. Detailed Toolset

### 🏠 Overview
- **Dashboard**: Home screen with live status cards for Ping, Multi-Ping, Port Scanner, Wi-Fi, Network Interfaces, Bandwidth, and DNS/SSL. Cards are interactive — clicking navigates to the tool. Pulsing green dot indicates active sessions.

### 🌐 Connectivity & Latency
- **Ping**: Live RTT chart with packet loss bars, jitter analysis, RTT distribution histograms, and configurable audio feedback ("Beep on Loss"). Supports custom packet sizes and auto-stop safety logic. Export via PDF or CSV.
- **Multi-Ping**: Monitor multiple hosts simultaneously with live sparklines, color-coded stability indicators, and custom host aliases. Consolidated PDF report for all hosts.
- **Traceroute**: Comprehensive hop-by-hop analysis with four view modes:
  - **Hops Table**: Per-hop columns — jitter, loss%, sparkline bar graph, geo location.
  - **Timeline View**: Canvas-drawn RTT bars per hop (last 60 samples). Tap a hop to expand a detail RTT area chart.
  - **Route Map**: MapKit-powered interactive map. Each geo-resolved hop is a numbered colored pin connected by polyline. Tap pin → opens IP Info Card.
  - **Raw**: Plain traceroute CLI output.
  - **Bottleneck Detection**: Auto-flags hops where RTT delta > 30 ms vs. previous hop (and avg RTT > 50 ms). Shown as red bolt badge in table, red pin on map, chip in path summary strip.
  - **IP Info Card**: Tap ⓘ per hop — shows Private/Public classification, full geolocation (flag, city, country, ISP, hostname, timezone, postal, coordinates), and RTT performance grid (Avg/Min/Max, Jitter, Loss%, Sent).
  - **Route Health Banner**: Automatic Critical / Degraded / Healthy path quality assessment.
- **HTTP Latency**: Phase-by-phase breakdown (DNS, TCP, TLS, TTFB, Download) using `URLSessionTaskMetrics`.

### 🔍 Discovery & Analysis
- **Port Scanner**: High-speed TCP port scanner with customizable ranges and concurrency controls. Presets: Common / Well-known / All / Custom. Mini-card grid layout for results.
- **SSL/TLS Inspector**: Full certificate chain analysis, expiry tracking, TLS version badge, and cipher suite verification.
- **DNS Lookup**: Comprehensive query tool (A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, ANY) using `dig`. Multiple server presets.
- **WHOIS**: Structured key/value display of domain registration and ownership records, with inline filter.

### 📊 System & Monitoring
- **Bandwidth Monitor**: Real-time RX/TX rate per interface with 60-second rolling area charts. State persists across navigation.
- **Network Interfaces**: All hardware interfaces via `getifaddrs()` — MAC, IPv4, IPv6, MTU, up/down status. State persists across navigation.
- **Wi-Fi Inspector**: Signal analysis via CoreWLAN — SSID, BSSID, RSSI, SNR, channel, band, security, tx rate, RSSI sparkline. State persists across navigation.
- **Route Table**: IPv4 and IPv6 routing rules via `netstat -rn`, with flag descriptions and live text filter.

### ⚙️ Settings
macOS System Settings–style sidebar navigation with four panes:
- **General**: Default ping count/interval, auto-stop on consecutive loss, traceroute max hops, re-trace interval, max raw output lines.
- **Thresholds**: RTT color-zone boundaries (good/warn/critical) with live animated preview bar. Packet loss alert threshold. Reset to Defaults button.
- **Tools**: Per-tool timeouts and concurrency — Port Scanner (connect timeout, thread count), HTTP Latency (request timeout), SSL Inspector (connect timeout), Bandwidth Monitor (refresh interval).
- **Privacy**: Geolocation toggle (ipinfo.io lookups in Traceroute), host history management, zero-telemetry disclosure.

---

## 4. Development & CI/CD

### Requirements
- **macOS**: 15.0 (Sequoia) or later.
- **Xcode**: 16.0 or later.
- **Tools**: `create-dmg` (for building installers).

### Build Instructions
```bash
# Clone the repository
git clone https://github.com/aderamdani/NetUtil.git
cd NetUtil

# Open in Xcode
open NetUtil.xcodeproj

# Build DMG (requires create-dmg)
bash scripts/build_dmg.sh
```

### Release Workflow
Releases are built locally and published via GitHub CLI:
1. Bump `MARKETING_VERSION` in `project.pbxproj` and add entry to `CHANGELOG.md`.
2. Build: `xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release`.
3. Package: `bash scripts/build_dmg.sh` → produces `dist/NetUtil-X.X.X.dmg`.
4. Commit, push, tag, create GitHub Release with the DMG attached.

---

## 5. User Interface Conventions

- **Tooltips**: Hover over any metric or button to see a detailed explanation of its purpose.
- **Exporting**: Ping and Multi-Ping support PDF report export. Ping and Port Scanner support CSV export.
- **Dark Mode**: Fully supports native macOS appearance settings.
- **Persistence**: Running sessions (Ping, Multi-Ping, Wi-Fi, Interfaces, Bandwidth) continue when navigating between sidebar tools.

---

## 6. Maintenance & Procedures

Refer to these internal documents for specific guidance:
- `CLAUDE.md`: Build commands, project structure, and release checklist.
- `CHANGELOG.md`: Historical record of all versions and changes.
- `ROADMAP.md`: Planned features and versioning roadmap.

---

*Documentation Version: 1.9.0 (May 2026)*
*Primary Developer: Ade Ramdani*
