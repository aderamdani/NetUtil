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


# NetUtil — GEMINI.md

Specialized instructions for codebase conventions, UI standards, and release procedures.

---

## Technical Context: Ping Feature

The Ping tool in NetUtil is a high-performance wrapper around `/sbin/ping`, utilizing `Process` and `Pipe` for real-time output capture and asynchronous regex parsing.

### Current Architecture & UI/UX (v2.0.0)
- **Model**: `PingResult` (sequence, bytes, host, ttl, rtt, status, timestamp).
- **ViewModel**: `@MainActor PingViewModel` (handles process lifecycle, unlimited timeout logic, and audio feedback via "Tink" system sound).
- **UI Style**: 
    - **Typography**: Pure San Francisco (SF) Pro standard (no rounded/monospaced variations for headers).
    - **Symmetry**: Grid-based layout with consistent card heights.
    - **Hierarchy**: Clear sectioning with bold headers and functional descriptions.
- **Interactive Visuals**:
    - **Health Strip**: GitHub-style bar representing the last 100 packets (Green/Orange/Red).
    - **Smart Interpretation**: Logic-driven status summary (Excellent, Congested, etc.) with dynamic icons.
    - **Scrollable Chart**: Interactive Swift Chart with horizontal scrolling, packet selection, and reference lines.
    - **Auto-Scroll Table**: Custom `ScrollViewReader` based table for guaranteed real-time scrolling to the latest results.
- **Reporting**:
    - **PDF Report**: Branded documents with app logo, detailed stats, and timestamped filenames.
    - **CSV Export**: Standardized timestamped file naming for systemic archiving.

---

## 🤖 Release Automation Prompt Procedure

When the user asks to **"commit, build DMG, and release"** (or similar), perform these steps automatically **without exception**. Every file in step 2 must be updated every release, no skipping.

0.  **Sync Local**: Run `git pull` to ensure you are working on the latest code.

1.  **Version Management (SemVer Rules)**:
    - **Major (X.0.0)**: Full upgrade, perombakan sistem, atau perubahan core besar.
    - **Minor (0.X.0)**: Penambahan 1 fitur atau peningkatan alat yang signifikan.
    - **Patch (0.0.X)**: Perubahan minor banget, UI polish, atau bug fix.
    - Update `MARKETING_VERSION` (both Debug + Release configs) and `CURRENT_PROJECT_VERSION` (+1) in `project.pbxproj`.

2.  **Documentation Sync (MANDATORY for every release)**:
    - `CHANGELOG.md` → **CRITICAL**: You MUST add a new `[X.X.X] — YYYY-MM-DD` section at the top describing all changes made during the session. If you skip this, the release is invalid.
    - `README.md` → reflect new/changed features in both **EN and ID** sections.
    - `DOCUMENTATION.md` → update version footer line, update toolset section if tools changed.
    - `AboutView.swift`:
      - Update version fallback string: `?? "X.X.X"`.
      - Verify `toolList` matches the **canonical list** exactly (see below).

3.  **Canonical `toolList` for `AboutView.swift`** — must always match `ContentView.swift` Tool enum:
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
    If a new tool is added to ContentView Tool enum, add it here too (same SF symbol, same display name).

4.  **HIG & Anti-Slop Audit** — for every new or modified view, verify:
    - No font below 10pt (labels, icons, chart axes, badges).
    - No `Color(...).opacity(x)` backgrounds on cards or containers.
    - No forced ALL CAPS on labels or dynamic values.
    - No 40pt+ icons in empty states.
    - Card `cornerRadius` is 8-12pt, never 20pt+.
    - Control bar titles have no colored background.
    - Learning guide button: `questionmark.circle` + `.borderless` only.

5.  **Clean Up**: `rm -rf dist/NetUtil.xcarchive`

6.  **Build & Package**:
    ```bash
    xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release \
      -destination 'platform=macOS' ARCHS='arm64 x86_64'
    bash scripts/build_dmg.sh
    ```

7.  **Version Control & GitHub**:
    ```bash
    git commit -m "docs: release vX.X.X - <key features>"
    git push origin main
    git tag vX.X.X
    git push origin --tags
    gh release create vX.X.X dist/NetUtil-X.X.X.dmg \
      --title "vX.X.X — <short title>" --notes "..."
    ```

---

## Apple Human Interface Guidelines (Mandatory)

Every new view, feature, or UI change MUST comply with Apple's macOS HIG. Non-compliance blocks release. Reference: https://developer.apple.com/design/human-interface-guidelines/

### Typography
- **Minimum font size: 10pt.** `.caption` / `.caption2` is the floor. Nothing smaller — not even for icons, chart axis labels, or chips.
- **Use semantic text styles** over hardcoded sizes: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.caption2`.
- **Monospaced only for technical data**: IPs, RTTs, ports, binary masks, timestamps. Use `.system(.caption, design: .monospaced)` pattern.
- **Never `.primary.opacity(x)`** as a proxy for `.secondary`. Use `.secondary` directly.
- **No forced ALL CAPS** on any label, StatCard title, or dynamic data value. Title Case or Sentence Case only.

### Layout & Spacing
- **8pt grid**: all spacing values must be multiples of 4 or 8 (4, 8, 12, 16, 20, 24, 32).
- **Main content padding**: 20-24pt. 32pt maximum for spacious views.
- **Card corner radius**: 8-12pt for macOS panels/cards. 20pt+ is iOS/visionOS — never on macOS.
- **Section spacing**: 16-24pt between sections. 32pt between major layout blocks.

### Materials & Backgrounds
- **Cards and containers**: always `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: N))`.
- **Never** `Color(.anything).opacity(x)` for card/container backgrounds.
- **Control bar title HStack**: plain icon + text, no colored opacity background behind it.
- **Status badges/chips only** (VPN active, error banner, DNS type labels): colored opacity acceptable.

### Components & Consistency
- **Learning guide button**: always `Image(systemName: "questionmark.circle")` + `.buttonStyle(.borderless)`.
- **Empty states**: silent text only — `Text("No Target Selected").font(.headline).foregroundColor(.secondary)`. No large icons.
- **BentoCard/dashboard cards**: `cornerRadius: 10`, `.regularMaterial` background, shadow opacity max 0.06.
- **Section headers**: `.headline` font, `.accentColor` icon, no `.foregroundColor(.primary.opacity(...))`.

### Pre-Release HIG Checklist (run for every new/modified view)
- [ ] No font below 10pt anywhere (labels, icons, chart axes, badges).
- [ ] No hardcoded sizes where semantic text styles apply.
- [ ] No `Color(...).opacity(x)` on card/container backgrounds.
- [ ] No forced ALL CAPS on labels or dynamic data.
- [ ] No 40pt+ icon in empty states.
- [ ] Card `cornerRadius` is 8-12pt, never 20pt+.
- [ ] Control bar title has no colored background.
- [ ] Learning guide button is `questionmark.circle` + `.borderless`.

---

## Native macOS Anti-Slop Guidelines (v2.3+)

To maintain a professional, "Apple Artisan" aesthetic, NEVER use AI-generated web-style layouts. All views MUST strictly adhere to these Native Mac principles:

### 1. The "Material" Rule (No Fake Opacity)
- **NEVER** use `.background(Color(...).opacity(...))` for cards or containers. This is considered "AI Slop".
- **ALWAYS** use SwiftUI's native materials: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))`. This ensures true vibrancy that reacts to the user's macOS wallpaper.

### 2. Flat Data Hierarchy (No Box-in-Box)
- **NEVER** wrap data tables, lists, or large charts in heavily shadowed, thick-bordered boxes.
- **ALWAYS** let data flow naturally. Separate rows using simple `Divider().opacity(0.5)` with generous horizontal padding (`12pt`-`16pt`). The outer container should only have a very subtle border: `.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))`.

### 3. Refined Typography (No Shouting)
- **NEVER** use forced ALL CAPS with heavy weights (e.g., `.font(.system(size: 10, weight: .black))`) for section titles.
- **ALWAYS** use standard system typographics: `.font(.headline)` for sections, `.font(.subheadline)` for descriptions, and `.font(.system(size: 11, design: .monospaced))` for technical data. Use Sentence Case or Title Case.

### 4. Silent Empty States & Data-Dense Headers
- **NEVER** use massive 40pt+ icons with chatty instructions (e.g., "Ready to analyze! Enter a URL...") for empty states. Use silent, `.secondary` text: `Text("No Target Selected")`.
- **NEVER** use conversational text in status headers (e.g., "All Systems Go! 2 out of 2 endpoints...").
- **ALWAYS** use data-dense, clinical terminology (e.g., "Active: 2", "Status: Secure").

### 5. Unified Control Bar (Fixed Top)
- **Position**: Always locked at the top (`VStack` with 0 spacing, followed by `ScrollView`).
- **Layout**: `HStack` with 12pt spacing.
    - **Left**: Main Input (TextField) with trailing history overlay (clock icon `clock.arrow.circlepath`).
    - **Center**: Variable settings (Toggles, Pickers).
    - **Right**: Action Group: `[Report Menu]`, `[Start/Stop Button]`, `[Learning Guide (questionmark.circle)]`.

### 6. No Decorative Emojis (Professional Tone)
- **NEVER** use emojis (e.g., 🚀, 🌟, 🛠️) in documentation files (`README.md`, `DOCUMENTATION.md`, `CHANGELOG.md`) or UI labels unless they serve a strict, technical functional purpose. The tone must remain clinical, enterprise-grade, and minimalist.

---

## Manual Validation Checklist

Since there are no automated tests, validate before every release:
- Test with valid hostnames (`google.com`).
- Test with invalid hostnames (`this.does.not.exist`).
- Test with unreachable IPs to verify timeout handling.
- Verify chart responsiveness during long-running infinite pings.
- Open Settings and confirm all 4 panes load without error.
- Verify AboutView tool grid shows all 13 tools.
