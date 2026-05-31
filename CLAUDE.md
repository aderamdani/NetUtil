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
- **@Observable**: Preferred over `@ObservableObject` on macOS 15+. Use `@State` on the owning view, `@Bindable` for child views that need bindings.
- **MainActor Isolation**: All UI-facing logic and ViewModel updates strictly isolated to the main thread.
- **Asynchronous Parsing**: CLI output captured via readability handlers, parsed on background threads, and published to UI via `Task { @MainActor }`.
- **Directory Structure**: `Views/Components/` for shared reusable components (`ReportMenuButton`, control bars). `Views/Settings/` for settings panes.

---

## Tools Overview

| Tool | VM | CLI / API |
|------|----|-----------|
| Dashboard | — | — |
| Ping | PingViewModel | `/sbin/ping` |
| Traceroute | TracerouteViewModel | `/usr/bin/traceroute -a`, geolocation via `ipinfo.io` |
| Multi-Ping | MultiPingViewModel | `/sbin/ping` (concurrent sessions) |
| Port Scanner | PortScanViewModel | Swift `URLSessionStreamTask` (TCP connect) |
| HTTP Latency | HTTPLatencyViewModel | `URLSession` + `URLSessionTaskMetrics` |
| Subnet Scanner | SubnetScanViewModel | `ping` (concurrent), ARP, `host` |
| Subnet Calc | SubnetViewModel | `NetworkMath.swift` (native) |
| DNS Lookup | DNSViewModel | `/usr/bin/dig` |
| SSL/TLS | SSLInspectorViewModel | `SecTrust` / `Network.framework` |
| WHOIS | WhoisViewModel | `/usr/bin/whois` |
| Bandwidth | — | `getifaddrs()` via Darwin |
| Statistics | — | `UserDefaults` (90-day cap) |
| Speed Test | SpeedTestViewModel | Cloudflare Speed Test API |
| Top Processes | TopProcessesViewModel | `/usr/bin/top -l 0 -n 10` |
| Interfaces | NetworkInterfaceViewModel | `getifaddrs()` via Darwin |
| Wi-Fi | — | `CoreWLAN.CWWiFiClient` |
| Routes | — | `/usr/sbin/netstat -rn` |

---

## Feature Notes (per tool)

### Dashboard (v2.0.0, current: v4.3.0)
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

3. Verify AboutView toolList — must match this canonical list exactly (same order, same names, same SF symbols):
   ```swift
   ("square.grid.2x2",                       "Dashboard"),
   ("antenna.radiowaves.left.and.right",      "Ping"),
   ("point.3.connected.trianglepath.dotted",  "Traceroute"),
   ("dot.radiowaves.left.and.right",          "Multi-Ping"),
   ("checklist",                              "Port Scanner"),
   ("stopwatch",                              "HTTP Latency"),
   ("network.badge.shield.half.filled",       "Subnet Scanner"),
   ("number.square",                          "Subnet Calc"),
   ("globe",                                  "DNS Lookup"),
   ("lock.shield",                            "SSL/TLS"),
   ("magnifyingglass.circle",                 "WHOIS"),
   ("chart.bar.xaxis",                        "Bandwidth"),
   ("chart.line.uptrend.xyaxis",              "Statistics"),
   ("speedometer",                            "Speed Test"),
   ("list.bullet.rectangle",                  "Top Processes"),
   ("network",                                "Interfaces"),
   ("wifi",                                   "Wi-Fi"),
   ("arrow.triangle.branch",                  "Routes"),
   ```
   If a new tool is added to `ContentView.swift` Tool enum, add it here too (same SF symbol, same display name).

4. **HIG & Anti-Slop Audit** — for every new or modified view:
   - No font below 10pt. No hardcoded sizes where semantic styles apply.
   - No `Color(...).opacity(x)` backgrounds on cards/containers.
   - No forced ALL CAPS on labels or dynamic values.
   - No 40pt+ empty state icons.
   - Card `cornerRadius` is 8-12pt, never 20pt+.
   - Control bar titles have no colored background.
   - Learning guide button: `questionmark.circle` + `.borderless` only.

5. **Clean artifacts**: `rm -rf dist/NetUtil.xcarchive`

6. **Build**: `xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release -destination 'platform=macOS' ARCHS='arm64 x86_64'`

7. **Package**: `bash scripts/build_dmg.sh`

8. **Commit & Push**:
   - `git commit -m "docs: release vX.X.X - <summary>"`
   - `git push origin main`
   - `git tag vX.X.X`
   - `git push origin --tags`

9. **GitHub Release**:
   `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "vX.X.X — <short title>" --notes "..."`

---

## Apple Human Interface Guidelines (Mandatory)

Every new view, feature, or UI change MUST comply with Apple's macOS HIG. Non-compliance blocks release. Reference: https://developer.apple.com/design/human-interface-guidelines/

### Typography
- **Minimum font size: 10pt.** `.caption` / `.caption2` is the floor. Nothing smaller.
- **Use semantic text styles** over hardcoded sizes: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.caption2`.
- **Monospaced only for data**: IPs, RTTs, ports, binary masks — use `.system(.caption, design: .monospaced)` etc.
- **Never `.primary.opacity(x)`** as a proxy for `.secondary`. Use semantic colors directly.
- **No forced ALL CAPS** on labels or dynamic data. Title Case or Sentence Case only.

### Layout & Spacing
- **8pt grid**: spacing values must be multiples of 4 or 8 (4, 8, 12, 16, 20, 24, 32).
- **Content padding**: 20-24pt for main view content. 32pt is the maximum for spacious layouts.
- **Card corner radius**: 8-12pt for macOS panels/cards. 20pt+ is iOS/visionOS — never use on macOS.
- **Section spacing**: 16-24pt between sections. 32pt between major layout blocks.

### Materials & Backgrounds
- **Cards and containers**: always `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: N))`.
- **Never** `Color(.anything).opacity(x)` for card/container backgrounds (fake vibrancy).
- **Control bar titles**: plain `HStack` with icon + text. No colored opacity backgrounds behind them.
- **Status badges/chips** (VPN, errors, type labels): colored opacity is acceptable for these only.

### Components
- **Learning guide button**: always `Image(systemName: "questionmark.circle")` + `.buttonStyle(.borderless)`. No other icon or style.
- **Empty states**: silent secondary text only — `Text("No Target Selected").font(.headline).foregroundColor(.secondary)`. No large icons.
- **BentoCard/dashboard cards**: `cornerRadius: 10`, `.regularMaterial` background, shadow `opacity` max 0.06.

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

### 6. Unified Control Bar (Fixed Top)
- **Position**: Always locked at the top (`VStack` with 0 spacing, followed by `ScrollView`).
- **Layout**: `HStack` with 12pt spacing.
    - **Left**: Main Input (TextField) with trailing history overlay (clock icon `clock.arrow.circlepath`).
    - **Center**: Variable settings (Toggles, Pickers).
    - **Right**: Action Group: `[Report Menu]`, `[Start/Stop Button]`, `[Learning Guide (questionmark.circle)]`.

### 7. Unified Report Menu (Export)
- **Position**: Always in the control bar action group, before Start/Stop button.
- **Icon**: `Label("Report", systemImage: "doc.text")` with `.menuStyle(.borderlessButton)`.
- **Menu Items**: "Export PDF" and "Export CSV" — exact labels, no variation.
- **Filename Pattern**: `NetUtil-[ToolName]-[target]-[timestamp].format`
  - Timestamp format: `yyyyMMdd-HHmmss`
  - Example: `NetUtil-Ping-google.com-20260531-121500.pdf`
- **PDF Layout**: Header ("NetUtil — [Tool Name] Report"), target, timestamp, summary stats, data table, footer ("Generated by NetUtil vX.X.X").
- **Save Dialog**: Always use `NSSavePanel` with pre-filled filename.
- **Component**: Use shared `ReportMenuButton` from `Components/ReportMenuButton.swift`.
- **NEVER** use different icons, labels, positions, or menu styles across tools.

### 8. No Decorative Emojis (Professional Tone)
- **NEVER** use emojis in documentation files (`README.md`, `DOCUMENTATION.md`, `CHANGELOG.md`) or UI labels. Keep the tone clinical, enterprise-grade, and minimalist. Do not use generic AI-style excitement markers (🚀, 🌟).


---

## Coding Standards & Preferences
- **Architecture**: Stick to `@MainActor`-isolated ViewModels. Prefer `@Observable` macro on macOS 15+.
- **UI**: Prefer **Vanilla SwiftUI** and **Swift Charts**. Use system standard components (`Table`, `List`, `ScrollView`).
- **Icons**: Use **SF Symbols** exclusively.
- **Clean Code**: Keep regex nonisolated static, use surgical `replace` for edits, and always verify builds before release.

---

## Swift Engineering Rules

### Progressive Architecture
- Start with direct implementation. Only extract a protocol when a second implementation exists. Only generalize when a pattern emerges across 3+ cases.
- NO God objects: if a ViewModel exceeds 300 lines, decompose it.
- Inject all dependencies via init for testability.

### Error Handling
- Make impossible states unrepresentable using exhaustive enums with associated values.
- Every error case must have an actionable recovery path.
- NEVER force unwrap (`!`, `try!`) in production code. Use `guard let` or `if let`.
- NEVER use stringly-typed APIs. Use enums or constants.

### Access Control & Performance
- Default to `private` for all properties and methods. Widen only when needed.
- Mark all classes `final` unless explicitly designed for subclassing.
- Use value types (struct/enum) over reference types (class) when no identity is needed.
- Prefer `LazyVStack` / `LazyHStack` over `VStack` / `HStack` for large data sets (e.g., ping results, port scan grids).

### Quality Gates (verify before every commit)
- [ ] No force unwrapping (`!`, `try!`, `as!`)
- [ ] All errors have recovery paths
- [ ] Dependencies injected via init (not hardcoded singletons)
- [ ] No retained cycles in closures (use `[weak self]` where needed)
- [ ] Public APIs have parameter documentation

---

## SwiftUI Agent Rules

### View Composition
- If a view `body` exceeds 50 lines, extract subviews using computed properties or separate structs.
- NEVER use `AnyView` — it destroys SwiftUI's diffing. Use `@ViewBuilder` or `some View` returns.
- Prefer `Group {}` over `AnyView` for conditional views.
- Use `.task {}` instead of `.onAppear { Task {} }` for async work.

### State Management
- Use `@State` only for view-local transient state.
- Use `@Observable` (or `@ObservableObject`) for shared ViewModel state.
- NEVER store derived/computed data in `@State` — compute it in the view body or as a computed property.
- NEVER modify `@State` during view body evaluation — this causes infinite layout loops.

### Deprecated API (NEVER use these)
- `NavigationView` → use `NavigationSplitView` or `NavigationStack`
- `.navigationBarTitle()` → use `.navigationTitle()`
- `GeometryReader` for simple alignment → use `.frame()` or layout containers
- `.onAppear` for async → use `.task` modifier
- `List { ForEach }` with static content → use `List(items)` directly
- `@StateObject` → prefer `@State` with `@Observable` on macOS 15+

### Performance
- Avoid unnecessary `GeometryReader` — it forces parent layout passes.
- Use `.drawingGroup()` for complex overlapping views (charts, sparklines).
- Use `EquatableView` or manual `Equatable` conformance on heavy subviews to skip redundant diffs.
- Minimize use of `.onChange()` — prefer derived state.
- In `ForEach`, always use stable identifiers. Never use array index as id.

### Accessibility
- Every interactive element needs `.accessibilityLabel()`.
- Every `Image(systemName:)` used as a button needs `.accessibilityLabel()`.
- Use `.accessibilityValue()` for dynamic data (RTT values, percentages, status).
- Group related controls with `.accessibilityElement(children: .combine)`.

---

## Swift 6 Concurrency Rules

### MainActor Isolation (Critical for NetUtil)
- All ViewModels MUST be `@MainActor`.
- NEVER call `DispatchQueue.main.async` — use `await MainActor.run {}` or `@MainActor` isolation.
- Background work: use `Task.detached` or `nonisolated` methods, then hop back to MainActor for UI updates.

### Sendable Compliance
- All types passed across concurrency boundaries must conform to `Sendable`.
- Value types (struct, enum) with Sendable stored properties are implicitly Sendable.
- Use `@unchecked Sendable` only as a last resort, with documented justification.
- Mark closures crossing isolation boundaries as `@Sendable`.

### Task Management
- Store `Task` handles and cancel them in `deinit` or when navigation changes.
- Use `withTaskGroup` for parallel operations (e.g., Multi-Ping, Port Scanner).
- Prefer structured concurrency (`async let`, `TaskGroup`) over unstructured (`Task {}`).
- NEVER use `Task { @MainActor in }` when the enclosing context is already `@MainActor`.

### Actor Safety
- NEVER access actor-isolated state from `nonisolated` context without `await`.
- Use `nonisolated` for pure helper functions and static regex patterns.
- Prefer `actor` over `class` + lock for shared mutable state.

---

## Xcode Build Optimization

### Build Settings (apply to NetUtil.xcodeproj)
- Enable `SWIFT_COMPILATION_CACHING = YES` (Xcode 16+) for faster incremental builds.
- Set `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` to catch deprecated API early.
- Set `EAGER_LINKING = YES` for Debug to speed up link phase.
- Verify `SWIFT_COMPILATION_MODE = singlefile` for Debug (incremental) and `wholemodule` for Release.

### Code-Level Build Performance
- Avoid complex type inference in single expressions — break into typed intermediate `let` bindings.
- Avoid long chains of `+` string concatenation — use string interpolation.
- Minimize use of type-erasing wrappers (`AnyView`, `AnyPublisher`).
- Add explicit return types on complex computed properties.
- Use `final` on all classes — helps compiler devirtualize method calls.

### Script Phases
- All Run Script Phases must declare Input/Output files for incremental build support.
- Guard scripts with `if [ "$CONFIGURATION" = "Debug" ]; then exit 0; fi` when not needed for Debug.

---

## macOS Development Patterns

### Window Management
- Use `WindowGroup` for the main window. Use `Window` for auxiliary single-instance windows (Settings, About).
- Implement `.defaultSize()` and `.defaultPosition()` for predictable window placement.
- Support window restoration with `@SceneStorage`.

### Menu & Keyboard
- Use `.commands {}` modifier on `WindowGroup` for menu bar customization.
- Map all primary actions to keyboard shortcuts using `.keyboardShortcut()`.
- Follow macOS conventions: `⌘,` for Settings, `⌘W` for close, `⌘Q` for quit.

### Build & Distribution
- Always build Universal Binary: `ARCHS = 'arm64 x86_64'`.
- Use Hardened Runtime for notarization compatibility.
- Validate with `spctl --assess --verbose` after packaging.
- Agent MUST pipe build output through `xcbeautify` when available for clean, parseable logs.
