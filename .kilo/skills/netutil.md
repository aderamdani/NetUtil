# NetUtil — Kilo Skill

Native macOS network diagnostics toolkit. SwiftUI, Swift 6, macOS 15+. Zero third-party dependencies.

## Project Identity

- **Name**: NetUtil
- **Platform**: macOS 15+ (Sequoia)
- **Language**: Swift 6
- **UI**: SwiftUI + Swift Charts
- **Architecture**: MVVM with `@Observable` ViewModels
- **Bundle**: `com.aderamdani.NetUtil`

## Quick Commands

```bash
open NetUtil.xcodeproj                                    # Open project
bash scripts/build_dmg.sh                                  # Build DMG
xcodebuild -project NetUtil.xcodeproj -scheme NetUtil \
  -configuration Release -destination 'platform=macOS' \
  ARCHS='arm64 x86_64'                                     # Release build
```

## File Structure

```
NetUtil/
├── Views/                   # SwiftUI views (one per tool)
│   ├── Components/          # Shared: ReportMenuButton, control bars
│   └── Settings/            # Settings panes (General, Thresholds, Tools, Privacy)
├── ViewModels/              # @MainActor @Observable classes
├── Models/                  # Data models, parsers, NetworkMath
├── Services/                # ToolStore, Exporter, SystemMonitor
├── Assets.xcassets/         # App icon, colors
└── scripts/
    └── build_dmg.sh         # DMG packaging script
```

## Tools (20 total)

Dashboard, Ping, Traceroute, Multi-Ping, Port Scanner, HTTP Latency, Subnet Scanner, Subnet Calc, DNS Lookup, SSL/TLS, WHOIS, Bandwidth, Statistics, Speed Test, Top Processes, Interfaces, Wi-Fi, Routes, History, Compare.

## Canonical toolList (AboutView.swift)

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
("clock.arrow.circlepath",                 "History"),
("arrow.left.arrow.right",                 "Compare"),
```

## HIG Quick Reference

- Min font: 10pt. Semantic styles only.
- 8pt grid spacing. Card radius: 8-12pt.
- `.regularMaterial` for cards — never `Color(...).opacity(x)`.
- No ALL CAPS. No emojis. Clinical tone.
- Learning guide: `questionmark.circle` + `.borderless`.
- Empty states: `.headline` + `.secondary` text only.

## Release Checklist

1. `git pull`
2. Bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `project.pbxproj`
3. Add `[X.X.X] — YYYY-MM-DD` to `CHANGELOG.md`
4. Update `AboutView.swift` version + verify `toolList`
5. HIG audit (no <10pt, no fake opacity, no ALL CAPS, no 40pt+ icons)
6. `rm -rf dist/NetUtil.xcarchive`
7. `xcodebuild` (Release, arm64 + x86_64)
8. `bash scripts/build_dmg.sh`
9. `git commit`, `git push`, `git tag`, `gh release create`

## Key Rules

- `@MainActor` on all ViewModels. `@Observable` (not `@ObservableObject`).
- No force unwrap. No `AnyView`. No `NavigationView`.
- No third-party dependencies.
- `final` on all classes. `private` by default.
- Structured concurrency. Cancel tasks in `deinit`.
