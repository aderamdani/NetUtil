# NetUtil — CLAUDE.md

Native macOS network diagnostics toolkit. SwiftUI, Swift 6, macOS 15+. Zero third-party dependencies.

---

## Build & Run

```bash
# Open in Xcode
open NetUtil.xcodeproj

# Build DMG (requires create-dmg homebrew tool)
bash scripts/build_dmg.sh
```

No `Package.swift` — Xcode project only. No test targets.

---

## Architecture

**MVVM**. All ViewModels are `@MainActor class : ObservableObject`.

```
NetUtil/
├── NetUtilApp.swift          # App entry, window/scene setup, MenuBarExtra
├── ContentView.swift         # NavigationSplitView + Tool enum (12 cases)
├── Models/
│   ├── ToolStore.swift       # Single @StateObject holding all VMs
│   ├── HostHistory.swift     # UserDefaults-backed singleton (20 hosts)
│   ├── Exporter.swift        # CSV/JSON export + NSSavePanel
│   ├── CertInfo.swift        # SSL certificate model
│   ├── DNSRecord.swift
│   ├── HTTPLatencyResult.swift
│   ├── NetworkInterface.swift
│   ├── PingResult.swift
│   ├── PortResult.swift
│   ├── RouteEntry.swift
│   └── TracerouteHop.swift
├── ViewModels/
│   ├── PingViewModel.swift
│   ├── TracerouteViewModel.swift
│   ├── MultiPingViewModel.swift
│   ├── PortScanViewModel.swift
│   ├── DNSViewModel.swift
│   ├── HTTPLatencyViewModel.swift
│   ├── SSLInspectorViewModel.swift
│   └── WhoisViewModel.swift   (no dedicated VM — uses WhoisViewModel)
└── Views/
    ├── PingView.swift
    ├── TracerouteView.swift
    ├── MultiPingView.swift
    ├── PortScanView.swift
    ├── DNSView.swift
    ├── HTTPLatencyView.swift
    ├── SSLInspectorView.swift
    ├── WhoisView.swift
    ├── NetworkInterfaceView.swift
    ├── WiFiInspectorView.swift
    ├── RouteTableView.swift
    ├── BandwidthView.swift
    ├── MenuBarView.swift
    ├── SettingsView.swift
    ├── HelpView.swift
    └── AboutView.swift
```

---

## Key Patterns

### Process + Pipe (live output)
All CLI-backed tools (`ping`, `traceroute`, `dig`, `whois`, `netstat`, `traceroute`) spawn `Process`, attach `Pipe`, and stream via `fileHandleForReading.readabilityHandler`. Parse happens on the background thread; UI updates go through `Task { @MainActor in ... }`.

```swift
pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
    let data = fh.availableData
    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
    // parse on background, then:
    Task { @MainActor [weak self] in
        self?.results.append(contentsOf: parsed)
    }
}
```

### ToolStore — VM persistence across navigation
`ToolStore` is a `@StateObject` on `NetUtilApp`, passed via `.environmentObject`. `ContentView` injects individual VMs (`tools.ping`, `tools.traceroute`, …) so they survive sidebar switches.

Views that don't need persistence (`NetworkInterfaceView`, `WiFiInspectorView`, `RouteTableView`, `BandwidthView`) own their own state internally.

### Sidebar navigation fix
`.tag()` on `Label` inside `List(selection:)` is required. `.badge()` must NOT be combined with `.tag()` on the same view — breaks selection binding.

### Return key auto-run
All host/URL fields use `.onSubmit { vm.start(...) }` for Return key support.

---

## AppStorage Keys

| Key | Type | Default | Used in |
|-----|------|---------|---------|
| `defaultPingCount` | Int | 20 | PingView |
| `defaultPingInterval` | Double | 1.0 | PingView |
| `defaultMaxHops` | Int | 30 | TracerouteView |
| `defaultTraceInterval` | Double | 5.0 | TracerouteView |
| `rttWarnThreshold` | Double | 20.0 | PingView, MultiPingView |
| `rttCritThreshold` | Double | 100.0 | PingView, MultiPingView |
| `lossAlertThreshold` | Double | 10.0 | MultiPingView |
| `maxRawLines` | Int | 500 | PingViewModel, TracerouteViewModel |
| `portScanTimeout` | Double | 1.5 | PortScanViewModel |
| `portScanConcurrency` | Int | 50 | PortScanViewModel |
| `sslTimeout` | Double | 10.0 | SSLInspectorViewModel |
| `httpTimeout` | Double | 15.0 | HTTPLatencyViewModel |
| `geoEnabled` | Bool | true | TracerouteViewModel |
| `bandwidthInterval` | Double | 1.0 | BandwidthView |

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

## Windows & Scenes

- **Main window** — `WindowGroup` → `ContentView` (NavigationSplitView, min 900×580)
- **About** — `Window(id: "about")` → `AboutView`, content-sized
- **Help** — `Window(id: "help")` → `HelpView`, content-sized
- **Settings** — `Settings` scene → `SettingsView` (460×340, 4 tabs)
- **Menu bar** — `MenuBarExtra` (window style, `"network"` SF symbol)

---

## Release Checklist

Every time commits are ready to ship, complete **all** steps below in order.

### 1 — Bump version in Xcode
Open `NetUtil.xcodeproj` → target **NetUtil** → General tab:
- **Version** (`CFBundleShortVersionString`) → new semver, e.g. `1.2.0`
- **Build** (`CFBundleVersion`) → increment integer, e.g. `3`

`AboutView` reads these from `Bundle.main.infoDictionary` at runtime — no hardcoded strings to update.

### 2 — Update CHANGELOG.md
Add a new section at the top of `CHANGELOG.md`:

```markdown
## [x.y.z] — YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

### 3 — Commit everything
```bash
git add NetUtil.xcodeproj CHANGELOG.md
git commit -m "Bump version to x.y.z"
git push origin main
```

### 4 — Tag and push tag
```bash
git tag vx.y.z
git push origin vx.y.z
```

### 5 — Build DMG
```bash
bash scripts/build_dmg.sh
# produces dist/NetUtil-x.y.z.dmg
# reads version from git describe --tags automatically
```
Requires `create-dmg` (`brew install create-dmg`). Skips Xcode build step if `dist/NetUtil.app` already exists.

### 6 — Create GitHub release
```bash
gh release create vx.y.z \
  --title "NetUtil vx.y.z" \
  --notes "$(cat <<'EOF'
## What's New

### Added
- ...

### Fixed
- ...

---

## Download

**NetUtil-x.y.z.dmg** — open, drag to Applications, run.
> First launch: right-click → Open to bypass Gatekeeper.

## Requirements
- macOS 15 Sequoia or later

See [CHANGELOG.md](https://github.com/aderamdani/NetUtil/blob/main/CHANGELOG.md) for full history.
EOF
)" \
  dist/NetUtil-x.y.z.dmg
```

### Summary of files touched per release
| File | Change |
|------|--------|
| `NetUtil.xcodeproj/project.pbxproj` | Version + Build bump |
| `CHANGELOG.md` | New version section at top |
| `dist/NetUtil-x.y.z.dmg` | Rebuilt DMG (not committed, uploaded to release) |

---

## Conventions

- No third-party Swift packages — keep it that way.
- ViewModels: `@MainActor class`, `ObservableObject`, owned by `ToolStore` or local to View.
- Parse regex/output on background thread, publish to `@Published` via `Task { @MainActor }`.
- Export uses `Exporter` enum (static methods) + `NSSavePanel`.
- `HostHistory.shared` records hosts from any input field; `SettingsView` privacy tab can clear it.
