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

### 🌐 Connectivity & Latency
- **Ping**: Live RTT chart with packet loss bars, jitter analysis, RTT distribution histograms, and configurable audio feedback ("Beep on Loss"). Supports custom packet sizes and auto-stop safety logic.
- **Multi-Ping**: Monitor multiple hosts simultaneously with live sparklines and color-coded stability indicators.
- **Traceroute**: Comprehensive hop-by-hop analysis. Features a **Timeline View** with Canvas-drawn RTT bars, per-hop jitter analysis, automatic **Route Health** assessment, and geolocation integration.
- **HTTP Latency**: Phase-by-phase breakdown (DNS, TCP, TLS, TTFB) using `URLSessionTaskMetrics`.

### 🔍 Discovery & Analysis
- **Port Scanner**: High-speed TCP port scanner with customizable ranges and concurrency controls.
- **SSL/TLS Inspector**: Full certificate chain analysis, expiry tracking, and cipher suite verification.
- **DNS Lookup**: Comprehensive query tool (A, AAAA, MX, TXT, etc.) using `dig`.
- **WHOIS**: Structured display of domain registration and ownership records.

### 📊 System & Monitoring
- **Bandwidth Monitor**: Real-time traffic analysis per interface with rolling history charts.
- **Network Interfaces**: Detailed view of all hardware interfaces (MAC, IP, MTU, Status).
- **Wi-Fi Inspector**: Comprehensive signal analysis (RSSI, SNR, Channel, Band, Security).
- **Route Table**: Live view of IPv4 and IPv6 routing rules.

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
```

### CI/CD Workflow
The project uses GitHub Actions for automated testing and delivery:
1. **Swift CI**: Runs on every push/PR to ensure the code builds successfully.
2. **Release Automation**: Triggered by pushing a version tag (e.g., `v1.3.0`).
   - Automatically builds a release-ready app.
   - Generates a branded DMG installer using `scripts/build_dmg.sh`.
   - Creates a GitHub Release and attaches the DMG.

---

## 5. User Interface Conventions

- **Tooltips**: Hover over any metric or button to see a detailed explanation of its purpose.
- **Exporting**: All diagnostic results can be exported as CSV or JSON for external analysis.
- **Keyboard Shortcuts**: Common actions (like starting/stopping a scan) are mapped to standard macOS shortcuts.
- **Dark Mode**: Fully supports native macOS appearance settings.

---

## 6. Maintenance & Procedures

Refer to these internal documents for specific guidance:
- `CLAUDE.md`: Build commands, project structure, and release checklist.
- `GEMINI.md`: Specialized instructions for Ping feature, coding standards, and release automation.
- `CHANGELOG.md`: Historical record of all versions and changes.

---

*Documentation Version: 1.3.0 (May 2026)*
*Primary Developer: Ade Ramdani*
