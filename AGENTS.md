# NetUtil — Agent Instructions

Native macOS network diagnostics toolkit. SwiftUI, Swift 6, macOS 26+. Zero third-party dependencies.

## Build & Run

```bash
open NetUtil.xcodeproj                          # Open in Xcode
bash scripts/build_dmg.sh                        # Build DMG (requires create-dmg)
xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release \
  -destination 'platform=macOS' ARCHS='arm64 x86_64'  # Release build
```

## Architecture

- **MVVM**: Views → ViewModels → Models. `@MainActor`-isolated ViewModels with `@Observable`.
- **ToolStore**: Central `EnvironmentObject` managing all ViewModels, global network state (External IP, VPN, System Health).
- **CLI Wrappers**: `Process` + `Pipe` for `ping`, `traceroute`, `whois`, `dig`. Parsed asynchronously, published via `Task { @MainActor }`.
- **Darwin APIs**: `getifaddrs()` for interface stats and bandwidth. `CoreWLAN` for Wi-Fi.
- **Persistence**: `UserDefaults` for daily traffic, scan history, favorite hosts.
- **Directory**: `Views/Components/` for shared components (`ReportMenuButton`). `Views/Settings/` for settings panes.

## Technologies

SwiftUI, Swift Charts, Network.framework (TCP/UDP), CoreWLAN (Wi-Fi), Darwin APIs (interfaces, routes), Process + Pipe (CLI tools), PDFKit (reports).

## Tools

| Tool | VM | Source |
|------|----|--------|
| Dashboard | — | — |
| Ping | PingViewModel | `/sbin/ping` |
| Traceroute | TracerouteViewModel | `/usr/bin/traceroute -a`, ipinfo.io |
| Multi-Ping | MultiPingViewModel | `/sbin/ping` (concurrent) |
| Port Scanner | PortScanViewModel | `URLSessionStreamTask` (TCP) |
| HTTP Latency | HTTPLatencyViewModel | `URLSessionTaskMetrics` |
| Subnet Scanner | SubnetScanViewModel | ping, ARP, `host` |
| Subnet Calc | SubnetViewModel | `NetworkMath.swift` |
| DNS Lookup | DNSViewModel | `/usr/bin/dig` |
| SSL/TLS | SSLInspectorViewModel | `SecTrust` / Network.framework |
| WHOIS | WhoisViewModel | `/usr/bin/whois` |
| Bandwidth | — | `getifaddrs()` |
| Statistics | — | `UserDefaults` (90-day) |
| Speed Test | SpeedTestViewModel | Cloudflare API |
| Interfaces | NetworkInterfaceViewModel | `getifaddrs()` |
| Wi-Fi | — | `CoreWLAN.CWWiFiClient` |
| Routes | — | `/usr/sbin/netstat -rn` |
| History | — | `UserDefaults` |
| Compare | — | Multi-resolver DNS |

## Release Workflow

When asked to **"commit, build DMG, and release"**, follow this checklist without exception:

0. `git pull`
1. **Version** (SemVer): Patch (+0.0.1) = bug fix/UI polish. Minor (+0.1.0) = new feature. Major (+1.0.0) = core overhaul. Update `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `project.pbxproj`.
2. **Docs**: Add `[X.X.X] — YYYY-MM-DD` section to `CHANGELOG.md`. Update `README.md`, `AGENTS.md` footer. Update `AboutView.swift` version string + verify `toolList`.
3. **Audit**: HIG + Anti-Slop check (no font <10pt, no fake opacity, no ALL CAPS, no 40pt+ empty icons, card radius 8-12pt, `questionmark.circle` + `.borderless` for learning guide).
4. `rm -rf dist/NetUtil.xcarchive`
5. `xcodebuild` (Release, arm64 + x86_64)
6. `bash scripts/build_dmg.sh`
7. `git commit`, `git push`, `git tag vX.X.X`, `git push --tags`
8. `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "..." --notes "..."`

### Canonical toolList (AboutView.swift)

Must match `ContentView.swift` Tool enum exactly:

```swift
("square.grid.2x2",                       "Dashboard"),
("antenna.radiowaves.left.and.right",      "Ping"),
("point.3.connected.trianglepath.dotted",  "Traceroute"),
("dot.radiowaves.left.and.right",          "Multi-Ping"),
("checklist",                              "Port Scanner"),
("network.badge.shield.half.filled",       "Subnet Scanner"),
("stopwatch",                              "HTTP Latency"),
("number.square",                          "Subnet Calc"),
("globe",                                  "DNS Lookup"),
("lock.shield",                            "SSL/TLS"),
("magnifyingglass.circle",                 "WHOIS"),
("chart.bar.xaxis",                        "Bandwidth"),
("network",                                "Interfaces"),
("wifi",                                   "Wi-Fi"),
("arrow.triangle.branch",                  "Routes"),
("chart.line.uptrend.xyaxis",              "Statistics"),
("speedometer",                            "Speed Test"),
("clock.arrow.circlepath",                 "History"),
("arrow.left.arrow.right",                 "Compare"),
```

## Apple HIG (Mandatory)

### Typography
- Minimum **10pt**. `.caption`/`.caption2` is the floor.
- Semantic styles only: `.largeTitle` → `.caption2`. No hardcoded sizes.
- Monospaced only for data: IPs, RTTs, ports, masks.
- No `.primary.opacity(x)` as `.secondary` proxy. Use `.secondary` directly.
- No forced ALL CAPS. Title Case or Sentence Case only.

### Layout
- **8pt grid**: 4, 8, 12, 16, 20, 24, 32.
- Content padding: 20-24pt. Max 32pt.
- Card corner radius: **8-12pt**. Never 20pt+.
- Section spacing: 16-24pt. Major blocks: 32pt.

### Materials
- Cards/containers: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: N))`.
- **Never** `Color(...).opacity(x)` for card/container backgrounds.
- Control bar titles: plain `HStack`, icon + text. No colored background.
- Status badges/chips: colored opacity acceptable.

### Components
- Learning guide: `Image(systemName: "questionmark.circle")` + `.buttonStyle(.borderless)` only.
- Empty states: `Text("...").font(.headline).foregroundColor(.secondary)`. No large icons.
- Dashboard cards: `cornerRadius: 10`, `.regularMaterial`, shadow opacity max 0.06.

## Anti-Slop Guidelines

1. **Material Rule**: Never `Color(...).opacity(...)` for cards. Always `.regularMaterial`.
2. **Flat Data Hierarchy**: No box-in-box. Use `Divider().opacity(0.5)` + 12-16pt padding.
3. **Refined Typography**: No ALL CAPS + heavy weights. Use `.headline`, `.subheadline`, monospaced 11pt for data.
4. **Silent Empty States**: No 40pt+ icons, no chatty text. Clinical terminology only.
5. **Unified Control Bar**: Fixed top. `HStack` 12pt: `[Input] [Settings] [Report] [Start/Stop] [Guide]`.
6. **Unified Report Menu**: `Label("Report", systemImage: "doc.text")`, `.menuStyle(.borderlessButton)`. Items: "Export PDF", "Export CSV". Filename: `NetUtil-[Tool]-[target]-yyyyMMdd-HHmmss.format`. Use `NSSavePanel`. Use `ReportMenuButton` component.
7. **No Emojis**: Clinical, enterprise-grade tone in docs and UI.

## Swift Engineering

### Progressive Architecture
- Extract protocol at 2nd implementation. Generalize at 3+ cases.
- Decompose ViewModels exceeding 300 lines.
- Inject dependencies via init.

### Error Handling
- Exhaustive enums with associated values. Actionable recovery for every error.
- **Never** force unwrap (`!`, `try!`). Use `guard let` / `if let`.
- **Never** stringly-typed APIs. Use enums/constants.

### Access Control & Performance
- Default `private`. Widen only when needed.
- `final` on all classes unless designed for subclassing.
- Value types over reference types when no identity needed.
- `LazyVStack`/`LazyHStack` for large data sets.

### Quality Gates
- [ ] No force unwrapping
- [ ] All errors have recovery paths
- [ ] Dependencies injected via init
- [ ] No retained cycles (`[weak self]`)
- [ ] Public APIs documented

## SwiftUI Rules

### View Composition
- Extract subviews when `body` exceeds 50 lines.
- **Never** `AnyView`. Use `@ViewBuilder` or `some View`.
- `.task {}` instead of `.onAppear { Task {} }`.

### State Management
- `@State` for view-local transient state only.
- `@Observable` for shared ViewModel state.
- **Never** store derived data in `@State`.
- **Never** modify `@State` during body evaluation.

### Deprecated API (Never Use)
`NavigationView`, `.navigationBarTitle()`, `GeometryReader` for alignment, `.onAppear` for async, `@StateObject` → use `NavigationSplitView`, `.navigationTitle()`, `.frame()`, `.task`, `@State` + `@Observable`.

### Performance
- Avoid unnecessary `GeometryReader`.
- `.drawingGroup()` for complex overlapping views.
- Stable identifiers in `ForEach`. Never array index as id.
- Minimize `.onChange()` — prefer derived state.

### Accessibility
- `.accessibilityLabel()` on every interactive element.
- `.accessibilityValue()` for dynamic data.
- `.accessibilityElement(children: .combine)` for grouped controls.

## Swift 6 Concurrency

- All ViewModels: `@MainActor`.
- **Never** `DispatchQueue.main.async` — use `await MainActor.run {}`.
- Background work: `Task.detached` or `nonisolated`, hop back to MainActor for UI.
- `Sendable` for all types crossing concurrency boundaries.
- Store `Task` handles, cancel in `deinit`.
- `withTaskGroup` for parallel operations. Prefer structured concurrency.
- `nonisolated` for pure helpers and static regex.

## Xcode Optimization

- `SWIFT_COMPILATION_CACHING = YES`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`.
- `SWIFT_COMPILATION_MODE`: `singlefile` (Debug), `wholemodule` (Release).
- Break complex type inference into typed `let` bindings.
- `final` on all classes for devirtualization.
- Script phases: declare Input/Output files. Guard Debug-only scripts.

## macOS Patterns

- `WindowGroup` for main window. `Window` for auxiliary (Settings, About).
- `.defaultSize()`, `.defaultPosition()`, `@SceneStorage` for restoration.
- `.commands {}` for menu bar. `.keyboardShortcut()` for primary actions.
- `⌘,` Settings, `⌘W` close, `⌘Q` quit.
- Universal Binary: `ARCHS = 'arm64 x86_64'`. Hardened Runtime. `spctl --assess --verbose`.
- Pipe build output through `xcbeautify` when available.

---

*See also: `CHANGELOG.md` (history), `ROADMAP.md` (planned features), `QA-CLINICAL-TEST.md` (test scenarios).*
*Documentation Version: 4.7.1 (June 22, 2026)*
