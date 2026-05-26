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

## Feature Notes (per tool)

### Dashboard (v1.5.0)
- **Features**: Ultra-interactive hub with clickable cards, sparklines (RTT/RSSI), and system health badges (CPU/RAM).
- **Network Identity Header**: Displays Hostname, Local IP, Public IP (fetched from ipify.org), and VPN Status (utun detection).
- **IP Analysis**: Uses `IPAddressDetails` model for automated Class/Private/Netmask detection.
- **Quick Actions**: Circle play/stop buttons on cards; uses shared ViewModels from `ToolStore`.
- **Navigation**: Click cards to update `selection` binding and navigate sidebar.

### Build & Release Workflow
When requested to **"commit, build DMG, and release"**, follow this checklist:
0. **Sync**: Run `git pull` before making any changes.
1. **Update Version (SemVer Rules)**:
   - **Patch (+0.0.1)**: Perubahan minor banget, UI polish, atau bug fix.
   - **Minor (+0.1.0)**: Penambahan 1 fitur atau peningkatan alat yang signifikan.
   - **Major (+1.0.0)**: Full upgrade, perombakan sistem, atau perubahan core besar.
   - Update `MARKETING_VERSION` in `project.pbxproj` and `CHANGELOG.md`.
2. **Sync Documentation**: Update `README.md`, `DOCUMENTATION.md`, and `AboutView.swift`.
3. **Clean artifacts**: `rm -rf dist/NetUtil.xcarchive` (Hapus xcarchive lama di dist).
4. **Build**: `xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release -destination 'platform=macOS' ARCHS='arm64 x86_64'`.
5. **Package**: Run `bash scripts/build_dmg.sh`.
6. **Commit & Push**: 
   - `git commit -m "docs: release vX.X.X - <summary>"`
   - `git push origin main`
   - `git tag vX.X.X`
   - `git push origin --tags`
7. **Manual Fallback**: Jika CI GitHub Actions gagal (billing issue), gunakan GitHub CLI:
   `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "vX.X.X" --notes "Release notes summary"`

### Ping
- Input: hostname or IP, optional count (default from `defaultPingCount`), interval (default `defaultPingInterval`), infinite toggle (`∞`)
- Stats bar: Sent · Recv · Loss% · Min · Avg · Max · **Jitter** — all color-coded against RTT thresholds
- Live RTT chart: last 60 results, `LineMark + AreaMark + PointMark` via Swift Charts; points colored green/orange/red
- Output toggle: Table view (auto-scrolls to latest row via `scrollPosition`) ↔ Raw monospaced output (also auto-scrolls)
- Export: CSV and JSON via `Exporter`, triggered from toolbar menu
- Host history: dropdown with clock icon, 20-entry MRU via `HostHistory.shared`, clearable
- Regex parsing: two pre-compiled `NSRegularExpression` patterns (IPv4 `icmp_seq` + IPv6 `icmp6_seq`), parsed on background thread
- Stats model (`PingStats`): tracks transmitted, received, min/avg/max RTT, jitter (mean absolute deviation of consecutive RTTs)

### Traceroute
- Input: hostname/IP, max hops (default 30), re-trace interval (default 5 s)
- Reruns automatically every `interval` seconds while running — `round` counter shown in toolbar
- **View Modes**: Hops (Table) / Timeline (Stacked Canvas bars) / Raw
- Hops table columns: #, Host/IP, Location, Snt, Loss%, **Jitter**, Last, Avg, Best, Wrst, Updated, **sparkline bar graph** (last 60 samples, Canvas-drawn)
- **Route Health Banner**: Automatic Critical/Degraded/Healthy assessment based on path loss/RTT
- Row background: red tint at ≥50% loss, orange at >0% loss
- **Path summary strip**: Hops count · Last Seen host · Last RTT · Avg Loss — chips above table
- Detail panel (split view): click any hop to see per-hop RTT area chart over time with timeout markers (red ×)
- Geolocation: queries `ipinfo.io` per unique IP (opt-in, cached per session, disabled in Settings → Privacy)
- Geo display: flag + city/country + ISP in Location column; full org in `.help()` tooltip
- Export: CSV and JSON
- Raw output tab available

### Multi-Ping
- Add unlimited hosts; each runs independent `/sbin/ping` process (infinite mode)
- Table: Host · Snt · Loss% · Last (ms) · Avg (ms) · **sparkline** (last 60 samples)
- Status dot per row: green = 0% loss, orange = some loss, red = ≥50% loss
- Start All / Stop All buttons
- Remove individual sessions with ×
- Sessions persist across sidebar navigation (owned by `ToolStore`)

### Port Scanner
- Presets: **Common** (well-known services ~20 ports) · **Well-known** (1–1023) · **All** (1–65535) · **Custom** (free-form: `80,443,8000-9000`)
- Concurrency stepper: 1–200 threads (default from `portScanConcurrency`)
- Timeout: configurable per connection (default from `portScanTimeout`)
- Progress bar with scanned/total count and live **ETA** estimate
- Stats bar: Scanned · Open · Closed/Filtered
- Filter toggle: "Open only" hides closed/filtered rows
- Status badges: `open` (green capsule) · `closed` (red) · `filtered` (orange)
- Service name lookup: maps port → service name string
- Export: All ports CSV · Open ports CSV
- Elapsed timer shown during scan

### HTTP Latency
- Methods: GET · HEAD · POST · PUT · OPTIONS
- Follow Redirects toggle
- Waterfall chart: **DNS · TCP · TLS · Request · TTFB · Download** phases from `URLSessionTaskMetrics`
- Summary bar: HTTP status (color-coded) · Total ms · Body bytes
- History table: keeps all runs from the session, selectable to re-display waterfall
- "Run Again" button re-runs same URL/method

### DNS Lookup
- Record types: A, AAAA, MX, TXT, NS, CNAME, SOA, PTR
- Uses `/usr/bin/dig`; output displayed with syntax highlighting
- Export raw output

### WHOIS
- Uses `/usr/bin/whois`; key/value parsed display, comments dimmed
- Export raw output

### SSL/TLS Inspector
- Input: hostname or URL (strips `https://` prefix), configurable port (default 443)
- Full certificate chain display — click tab per cert in chain
- Per-cert: Subject, Issuer, SANs, Not Before/After, Serial, Key Type (RSA/EC + bit size), SHA-256 fingerprint
- Expiry countdown badge: days remaining, colored green/orange/red
- TLS version badge + cipher suite badge (from `URLAuthenticationChallenge`)
- Certificate parsing via `SecCertificateCopyValues` with pre-cast CFString keys

### Network Interfaces
- Lists all `getifaddrs()` interfaces (excludes loopback option)
- Per interface: IPv4, IPv6, MAC, MTU, Up/Down status
- Auto-refreshes every 3 s

### Wi-Fi Inspector
- Data source: `CoreWLAN.CWWiFiClient`
- Displays: SSID, BSSID (selectable text), channel, band, security type, country code
- RSSI in dBm + color-coded signal quality (green/orange/red)
- SNR display with color coding
- Transmit rate (Mbps)
- RSSI history sparkline (last N samples)
- Manual refresh button
- Auto-refreshes on timer

### Route Table
- Runs `/usr/sbin/netstat -rn`, shows IPv4 and IPv6 routes
- Columns: Destination · Gateway · Flags · Interface
- Flag descriptions shown as tooltips
- Live text filter field

### Bandwidth Monitor
- Polls `getifaddrs()` on configurable interval (default 1 s, from `bandwidthInterval`)
- Per-interface card: RX rate + TX rate in auto-scaled units (B/s → KB/s → MB/s)
- 60-second rolling area chart per interface (smooth interpolation)
- "Active only" toggle hides interfaces with no traffic
- Grid layout, 2 columns, excludes loopback

---

## Windows & Scenes

- **Main window** — `WindowGroup` → `ContentView` (NavigationSplitView, min 900×580)
- **About** — `Window(id: "about")` → `AboutView`, content-sized
- **Help** — `Window(id: "help")` → `HelpView`, content-sized
- **Settings** — `Settings` scene → `SettingsView` (460×340, 4 tabs)
- **Menu bar** — `MenuBarExtra` (window style, `"network"` SF symbol)

---

## Finalize Release Workflow (Automated)

When a release is ready, execute:
1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode project.
2. Update `CHANGELOG.md` with new version and changes.
3. Commit and push to main.
4. Push a tag: `git tag v1.x.y && git push origin v1.x.y`.

**GitHub Actions (`release.yml`)** will automatically build the DMG and create the GitHub Release.

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
