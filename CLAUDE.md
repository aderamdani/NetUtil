# NetUtil — CLAUDE.md

Native macOS network diagnostics toolkit. SwiftUI, Swift 6, macOS 15+. Zero third-party dependencies.

---

## Build & Run

```bash
# Open in Xcode
open NetUtil.xcodeproj

# Build DMG (requires create-dmg installed)
bash scripts/build_dmg.sh
```

## Key Technologies
- **SwiftUI**: Modern declarative UI.
- **Swift Charts**: Data visualization for Ping, Multi-Ping, and Bandwidth.
- **Network.framework**: Modern TCP/UDP connectivity checks (Port Scanner).
- **CoreWLAN**: Apple native framework for Wi-Fi analytics.
- **Darwin APIs**: Low-level kernel interactions for interface stats (`getifaddrs`) and routing table.
- **Process + Pipe**: Wrapper for system CLI tools (`ping`, `traceroute`, `whois`, `dig`).
- **PDFKit + NSHostingView**: High-fidelity PDF report generation.

---

## Architecture Patterns
- **MVVM**: Separation of UI (`View`) and logic (`ViewModel`).
- **ToolStore**: Centralized EnvironmentObject managing all ViewModels and global network state (External IP, VPN, System Health).
- **MainActor Isolation**: All UI-facing logic and ViewModel updates strictly isolated to the main thread.
- **Asynchronous Parsing**: CLI output captured via readability handlers, parsed on background threads, and published to UI via `Task { @MainActor }`.

---

## Tools Overview

| Tool | VM | CLI / API |
|------|----|-----------|
| Ping | PingViewModel | `/sbin/ping` |
| Traceroute | TracerouteViewModel | `/usr/bin/traceroute -a`, geolocation via `ipinfo.io` |
| Multi-Ping | MultiPingViewModel | `/sbin/ping` (concurrent sessions) |
| Port Scanner | PortScanViewModel | Swift `URLSessionStreamTask` (TCP connect) |
| HTTP Latency | HTTPLatencyViewModel | `URLSession` + `URLSessionTaskMetrics` |
| DNS Lookup | DNSViewModel | `/usr/bin/dig` |
| WHOIS | WhoisViewModel | `/usr/bin/whois` |
| SSL/TLS Inspector | SSLInspectorViewModel | `SecTrust` / `Network.framework` |
| Network Interfaces | — | `getifaddrs()` via Darwin |
| Wi-Fi Inspector | — | `CoreWLAN.CWWiFiClient` |
| Route Table | — | `/usr/sbin/netstat -rn` |
| Bandwidth Monitor | — | `getifaddrs()` polled on timer |

---

## Feature Notes (per tool)

### Dashboard (v1.7.2)
- **Features**: Ultra-interactive hub with clickable cards, sparklines (RTT/RSSI), and system health badges (CPU/RAM).
- **Network Identity Header**: Displays Hostname, Local IP, Public IP (fetched from ipify.org), and VPN Status (utun detection).
- **IP Analysis**: Uses `IPAddressDetails` model for automated Class/Private/Netmask detection.
- **Visual Style**: Premium refactored UI with `MetricView` for clarity and standardized card layouts.
- **Quick Actions**: Circle play/stop buttons on cards; uses shared ViewModels from `ToolStore`.
- **Navigation**: Click cards to update `selection` binding and navigate sidebar.

### Build & Release Workflow
When requested to **"commit, build DMG, and release"** (or similar), follow this checklist **without exception**. Every file below must be updated every release.

0. **Sync**: Run `git pull` before making any changes.

1. **Update Version (SemVer Rules)**:
   - **Patch (+0.0.1)**: Perubahan minor banget, UI polish, atau bug fix.
   - **Minor (+0.1.0)**: Penambahan 1 fitur atau peningkatan alat yang signifikan.
   - **Major (+1.0.0)**: Full upgrade, perombakan sistem, atau perubahan core besar.
   - Files to update:
     - `project.pbxproj` → `MARKETING_VERSION` (both Debug + Release configs) and `CURRENT_PROJECT_VERSION` (+1)

2. **Sync ALL Documentation (no exceptions)**:
   - `CHANGELOG.md` → add new `[X.X.X] — YYYY-MM-DD` section at the top
   - `README.md` → reflect any new/changed features (EN + ID sections)
   - `DOCUMENTATION.md` → update footer version, update toolset section if tools changed
   - `AboutView.swift` → update version fallback string AND verify `toolList` matches canonical list below

3. **Verify AboutView toolList** — must match this canonical list exactly (same order, same names, same SF symbols):
   ```swift
   ("square.grid.2x2",                       "Mission Dashboard"),
   ("antenna.radiowaves.left.and.right",      "Advanced Ping"),
   ("point.3.connected.trianglepath.dotted",  "Traceroute"),
   ("dot.radiowaves.left.and.right",          "Multi-Ping"),
   ("checklist",                              "Port Scanner"),
   ("stopwatch",                              "HTTP Latency"),
   ("globe",                                  "DNS Lookup"),
   ("magnifyingglass.circle",                 "WHOIS"),
   ("lock.shield",                            "SSL/TLS Inspector"),
   ("network",                                "Network Interfaces"),
   ("wifi",                                   "Wi-Fi Inspector"),
   ("arrow.triangle.branch",                  "Route Table"),
   ("chart.bar.xaxis",                        "Bandwidth Monitor"),
   ```
   If a new tool is added to `ContentView.swift` Tool enum, add it here too (same SF symbol, same display name).

4. **Clean artifacts**: `rm -rf dist/NetUtil.xcarchive`

5. **Build**: `xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release -destination 'platform=macOS' ARCHS='arm64 x86_64'`

6. **Package**: `bash scripts/build_dmg.sh`

7. **Commit & Push**:
   - `git commit -m "docs: release vX.X.X - <summary>"`
   - `git push origin main`
   - `git tag vX.X.X`
   - `git push origin --tags`

8. **GitHub Release**:
   `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "vX.X.X — <short title>" --notes "..."`

### Ping (v1.7.2 Premium)
- **Features**: Smart Interpretation header (Excellent/Stable/Congested) with dynamic icons; Health Strip (GitHub-style 100-packet stability bar).
- **Chart**: Scrollable RTT history chart using `.chartScrollableAxes(.horizontal)`; supports packet selection for detail view; Avg RTT reference line.
- **Audio Feedback**: Subtle "Tink" sound on packet loss (toggled via beep icon).
- **Persistence**: No auto-stop on timeouts; manual control only for unlimited monitoring.
- **Table**: Custom `ScrollViewReader` based table with sticky header; guaranteed real-time auto-scroll to latest results; 6pt row padding for readability.
- **Reporting**:
  - **PDF**: Branded report with NetUtil logo, detailed summary, 100-packet table, and timestamped filename.
  - **CSV**: Standardized raw data export with timestamped filename.
- **Typography**: Strictly San Francisco (SF) Pro for all headers and labels; monospaced for data numbers only.

### Multi-Ping
- **Features**: Independent concurrent ping sessions to multiple hosts.
- **Sparklines**: Last 60 RTT samples as color-coded bars in each row.
- **Status Dots**: Quick visual indicator of host reachability.
- **Persistence**: Sessions continue running even when navigating away from the view.

### Traceroute
- **Features**: Hop-by-hop path discovery with modern Timeline View (stacked Canvas bars).
- **Route Health**: Automatic banner assessment (Healthy/Degraded/Critical).
- **Detail View**: Expand any hop to see full RTT area chart history.
- **Geolocation**: Integrated IP lookup for each hop (opt-in).

### Port Scanner
- **Features**: High-speed parallelized TCP scanner using `URLSessionStreamTask`.
- **Presets**: Quick selections for Common (15) and Well-known (1023) ports.
- **Progress**: Real-time progress bar and open port count.

### Bandwidth Monitor
- **Features**: Per-interface real-time traffic monitoring.
- **Visuals**: Area chart overlaying RX (download) and TX (upload) rates.
- **Auto-Scaling**: Dynamic Y-axis based on current peak throughput.

---

## Coding Standards & Preferences
- **Architecture**: Stick to `@MainActor`-isolated ViewModels.
- **UI**: Prefer **Vanilla SwiftUI** and **Swift Charts**. Use system standard components (`Table`, `List`, `ScrollView`).
- **Icons**: Use **SF Symbols** exclusively.
- **Clean Code**: Keep regex nonisolated static, use surgical `replace` for edits, and always verify builds before release.
