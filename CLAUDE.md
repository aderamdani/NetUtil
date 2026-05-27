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

### Dashboard (v2.0.0)
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

2. **Sync Documentation (MANDATORY for every release)**:
   - `CHANGELOG.md` → **CRITICAL**: You MUST add a new `[X.X.X] — YYYY-MM-DD` section at the top describing all changes made during the session. If you skip this, the release is invalid.
   - `README.md` → reflect any new/changed features (EN + ID sections)
   - `DOCUMENTATION.md` → update footer version, update toolset section if tools changed
   - `AboutView.swift` → update version fallback string AND verify `toolList` matches canonical list below

3. **Verify AboutView toolList** — must match this canonical list exactly (same order, same names, same SF symbols):
   ```swift
   ("square.grid.2x2",                       "Dashboard"),
   ("antenna.radiowaves.left.and.right",      "Ping"),
   ("point.3.connected.trianglepath.dotted",  "Traceroute"),
   ("dot.radiowaves.left.and.right",          "Multi-Ping"),
   ("checklist",                              "Port Scanner"),
   ("stopwatch",                              "HTTP Latency"),
   ("number.square",                          "Subnet Calc"),
   ("globe",                                  "DNS Lookup"),
   ("lock.shield",                            "SSL/TLS"),
   ("magnifyingglass.circle",                 "WHOIS"),
   ("chart.bar.xaxis",                        "Bandwidth"),
   ("network",                                "Interfaces"),
   ("wifi",                                   "Wi-Fi"),
   ("arrow.triangle.branch",                  "Routes"),
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

---

## Native macOS Anti-Slop Guidelines (v2.3+)

To maintain a professional, "Apple Artisan" aesthetic, NEVER use AI-generated web-style layouts. All views MUST strictly adhere to these Native Mac principles:

### 1. The "Material" Rule (No Fake Opacity)
- **NEVER** use `.background(Color(...).opacity(...))` for cards or containers.
- **ALWAYS** use SwiftUI's native materials: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))`.

### 2. Flat Data Hierarchy (No Box-in-Box)
- **NEVER** wrap data tables, lists, or large charts in heavily shadowed, thick-bordered boxes.
- **ALWAYS** let data flow naturally. Separate rows using simple `Divider().opacity(0.5)` with generous horizontal padding (`12pt`-`16pt`).

### 3. Refined Typography (No Shouting)
- **NEVER** use forced ALL CAPS with heavy weights (e.g., `.font(.system(size: 10, weight: .black))`) for section titles.
- **ALWAYS** use standard system typographics: `.font(.headline)`, `.font(.subheadline)`, and `.font(.system(size: 11, design: .monospaced))` for technical data.

### 4. Silent Empty States & Data-Dense Headers
- **NEVER** use massive 40pt+ icons with chatty instructions for empty states. Use silent, `.secondary` text: `Text("No Target Selected")`.
- **NEVER** use conversational text in status headers.
- **ALWAYS** use data-dense, clinical terminology (e.g., "Active: 2", "Status: Secure").

### 5. Unified Control Bar (Fixed Top)
- **Position**: Always locked at the top (`VStack` with 0 spacing, followed by `ScrollView`).
- **Layout**: `HStack` with 12pt spacing.
    - **Left**: Main Input (TextField) with trailing history overlay (clock icon `clock.arrow.circlepath`).
    - **Center**: Variable settings (Toggles, Pickers).
    - **Right**: Action Group: `[Report Menu]`, `[Start/Stop Button]`, `[Learning Guide (questionmark.circle)]`.

### 6. No Decorative Emojis (Professional Tone)
- **NEVER** use emojis in documentation files (`README.md`, `DOCUMENTATION.md`, `CHANGELOG.md`) or UI labels. Keep the tone clinical, enterprise-grade, and minimalist. Do not use generic AI-style excitement markers (🚀, 🌟).

---

## Coding Standards & Preferences
- **Architecture**: Stick to `@MainActor`-isolated ViewModels.
- **UI**: Prefer **Vanilla SwiftUI** and **Swift Charts**. Use system standard components (`Table`, `List`, `ScrollView`).
- **Icons**: Use **SF Symbols** exclusively.
- **Clean Code**: Keep regex nonisolated static, use surgical `replace` for edits, and always verify builds before release.
