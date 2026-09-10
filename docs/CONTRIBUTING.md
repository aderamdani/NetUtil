# Contributing to NetUtil

Thank you for considering contributing to NetUtil.

## Getting Started

1. **Read `docs/ARCHITECTURE.md`** — maps the entire codebase, patterns, and conventions.
2. **Read `AGENTS.md`** — coding standards, HIG rules, SwiftUI rules, concurrency rules.
3. Fork the repo and create a feature branch (`git checkout -b feature/name`).

## Requirements

- macOS 26+ (Apple Silicon only)
- Xcode 16+ with Swift 6
- Zero third-party dependencies — do not add any SPM packages

## Project Structure

```
NetUtil/
├── NetUtilApp.swift          # App entry (5 scenes)
├── ContentView.swift         # Tool enum + NavigationSplitView
├── Models/                   # Data types, ToolStore, subprocess wrappers, exporters
├── ViewModels/               # One per tool (@MainActor @Observable)
└── Views/
    ├── Components/           # Shared UI components
    ├── Dashboard/            # Dashboard section views
    ├── Ping/                 # Ping sub-views
    └── Settings/             # Settings panes
```

See `docs/ARCHITECTURE.md` for the full map.

## Code Style

### Swift
- `@MainActor @Observable final class` for all ViewModels
- `private` by default; widen only when needed
- Never force unwrap (`!`, `try!`) — use `guard let` / `if let`
- Never `DispatchQueue.main.async` — use `await MainActor.run {}`
- Never `AnyView` — use `@ViewBuilder` or `some View`
- Extract subviews when `body` exceeds 50 lines
- `nonisolated` for pure helpers and static regex
- `@ObservationIgnored` for internal VM state not exposed to SwiftUI
- Generation tokens (`runID`) for any subprocess-spawning ViewModel

### SwiftUI
- `.task {}` for async work (not `.onAppear { Task {} }`)
- `.regularMaterial` for card backgrounds — never `Color(...).opacity()`
- Minimum 10pt font. Monospaced for data (IPs, RTTs, ports)
- 8pt grid: spacing multiples of 4 or 8. Card corner radius 8–12pt
- `.accessibilityLabel()` on every interactive element
- Never `@StateObject` — use `@State` + `@Observable`

### Concurrency
- All ViewModels are `@MainActor`
- Background work via `Task.detached` or `nonisolated` functions
- `Sendable` for all types crossing concurrency boundaries
- `withTaskGroup` for parallel operations
- Store `Task` handles, cancel in `deinit`

## Adding a New Tool

1. Add case to `Tool` enum in `ContentView.swift`
2. Create ViewModel in `ViewModels/` (follow existing patterns)
3. Create View in `Views/` (follow standard tool view structure)
4. Add VM property to `ToolStore`
5. Wire `onSessionComplete` in `ToolStore.wireSessionLogging()`
6. Add routing in `toolView(_:)` switch
7. Add to sidebar section
8. Add keyboard shortcut (if digit bank available)
9. Add to `AboutView.toolList`
10. Add learning guide content in `HelpView`
11. Add CSV/PDF export in `Exporter.swift`
12. Optionally add Dashboard card

## Pull Request Checklist

- [ ] Code compiles without warnings (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`)
- [ ] No force unwrapping
- [ ] All errors have recovery paths
- [ ] Dependencies injected via init
- [ ] No retained cycles (`[weak self]` in closures)
- [ ] ViewModels under 300 lines
- [ ] Subviews extracted when body exceeds 50 lines
- [ ] HIG compliant (fonts, materials, spacing)
- [ ] Anti-Slop compliant (no fake opacity, no ALL CAPS, no 40pt+ empty icons)
- [ ] Accessibility labels on interactive elements
- [ ] Learning guide updated (if tool changed)
- [ ] Export works (if applicable)
- [ ] Unit tests added for new parsing logic

## Testing

```bash
xcodebuild test -project NetUtil.xcodeproj -scheme NetUtil -destination 'platform=macOS'
```

Or `Cmd+U` in Xcode. See `docs/TESTING.md` for manual test scenarios.

## Reporting Bugs

- Use the GitHub issue tracker with detailed reproduction steps
- Include your macOS version and NetUtil version
- Include console output if applicable

## Reporting Security Vulnerabilities

Do not open a public issue. See `docs/SECURITY.md` for responsible disclosure instructions.
