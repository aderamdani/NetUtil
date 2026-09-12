# NetUtil — Improvement Backlog

> Last updated: 2026-09-12
> Current version: 4.14.0

---

## P0 — Critical (blocking or high-impact)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P0-1 | **Automated HIG regression tests** | CI / TESTING | Human audit is not enough — codify font-size, corner-radius, material, and padding checks into XCTest so PRs cannot regress Anti-Slop rules. |
| P0-2 | **Smoke-test harness for all 28 tools** | CI | A single `xcodebuild test` target that drives every tool through its empty/loading/error state with mock data, catching runtime crashes before release. |
| P0-3 | **Accessibility audit pass** | All views | Verify VoiceOver labels/values on every interactive element; fix missing `accessibilityLabel` on custom buttons and chart marks. |

---

## P1 — Important (polish, consistency, performance)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P1-2 | **Unified error-surface component** | All tools | Replace ad-hoc `alert` / `Text("...").foregroundColor(.red)` with a shared `ClinicalErrorBanner` that supports retry, copy, and dismiss. |
| P1-3 | **Live-filter on all result tables** | Ping, Traceroute, Port Scan, DNS, WHOIS | Add per-tool search/filter bar to narrow large result sets without re-running the scan. |
| P1-4 | **PDF table header repeat on every page** | Exporter | Long reports (Multi-Ping, Traceroute) lose column headers after page 1; implement `CGContext` page-header drawing. |
| P1-5 | **Settings search** | SettingsView | Add a filter field to jump directly to a setting pane (Thresholds, Backup, Privacy, Tools). |
| P1-6 | **Batch export (PDF + CSV)** | All export-capable tools | Allow selecting multiple sessions/tools and exporting one combined PDF or ZIP of CSVs. |
| P1-7 | **Unit-test coverage for Exporter** | Exporter.swift | Add snapshot-style tests for PDF page count, CSV column order, and filename pattern `NetUtil-[Tool]-[target]-yyyyMMdd-HHmmss`. |

---

## P2 — Nice-to-have (features, experimentation)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P2-1 | **Plug-in host-resolver cache** | All tools | Cache DNS / Geo / RDAP lookups for the session lifetime to reduce repeated ipinfo.io calls and speed up Traceroute / WHOIS. |
| P2-2 | **Timeline scrubber for historical data** | Statistics, Bandwidth | Replace static daily bar chart with a draggable time window (day / week / month / 90-day). |
| P2-3 | **Custom alert presets** | Ping, Multi-Ping, Net Quality | Let users save named threshold sets (e.g., "Gaming", "Work") and switch between them without opening Settings. |
| P2-4 | **LAN device fingerprinting** | Neighbors | Enrich ARP entries with OUI vendor name and guessed device type (router, printer, phone). |
| P2-5 | **CLI companion tool** | New binary | `netutil ping <host>` / `netutil speed` for scripts and Terminal usage; share the same subprocess runners as the app. |
| P2-6 | **Menu-bar only mode** | MenuBarExtra | Hide the main window and run a lightweight status-bar popover with ping / bandwidth / VPN state. |

---

## Forward Roadmap

### v4.14.0 — HIG Hardening & Accessibility (Q4 2026)
- P0-1 automated HIG tests + CI gate.
- P1-2 unified error banner.
- P1-3 live-filter on Ping / Traceroute result tables.

### v4.15.0 — Export & Settings Polish (Q4 2026)
- P1-4 PDF header repeat.
- P1-5 Settings search.
- P1-6 batch export.
- P1-7 Exporter unit tests.

### v5.0.0 — Platform Expansion (2027)
- P2-5 CLI companion tool.
- P2-6 menu-bar only mode.
- Refactor `Exporter` + subprocess runners into a reusable `NetUtilCore` framework consumable by the CLI and potential future iOS/iPadOS front-ends.
- Evaluate Swift Package Manager distribution for the core framework.

---

## Completed

### First-run onboarding — SELESAI
- Onboarding shown once via `@AppStorage("hasCompletedOnboarding")` in `ContentView`; privacy-forward summary (no telemetry; points to Settings > Privacy for per-tool host breakdown).

### SystemMonitor lifecycle (zero-idle) — SELESAI
- `ToolStore` is now the sole owner of `SystemMonitor` lifecycle (`SystemMonitor.init` no longer auto-starts); cadence uses named constants `SystemMonitor.normalInterval` (2s) / `backgroundInterval` (10s).

### Chart accessibility parity — SELESAI
- Done (AXChartDescriptor + test): Ping, Bandwidth aggregate, Wi-Fi RSSI, Multi-Ping slot.
- Sudah ada sejak awal: Statistics (live throughput + daily totals).
- N/A (tidak punya Swift Chart / sudah berlabel VoiceOver): Traceroute (tabel + timeline custom), Speed Test (kartu + tabel), HTTP Latency (waterfall custom).
- Dekoratif, sengaja dilewati: sparkline dashboard hero & interface bandwidth card.
