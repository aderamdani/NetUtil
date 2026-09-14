# NetUtil — Improvement Backlog

> Last updated: 2026-09-13
> Current version: 4.16.0

---

## P0 — Critical (blocking or high-impact)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P0-1 | **Automated HIG regression tests** (shipped v4.14.0) | CI / TESTING | Human audit is not enough — codify font-size, corner-radius, material, and padding checks into XCTest so PRs cannot regress Anti-Slop rules. |
| P0-2 | **Smoke-test harness for all 28 tools** | CI | A single `xcodebuild test` target that drives every tool through its empty/loading/error state with mock data, catching runtime crashes before release. |
| P0-3 | **Accessibility audit pass** | All views | Verify VoiceOver labels/values on every interactive element; fix missing `accessibilityLabel` on custom buttons and chart marks. |

---

## P1 — Important (polish, consistency, performance)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P1-2 | **Unified error-surface component** (done, unreleased) | All tools | Replace ad-hoc `alert` / `Text("...").foregroundColor(.red)` with a shared `ClinicalErrorBanner` that supports retry, copy, and dismiss. |
| P1-3 | **Live-filter on all result tables** (done, unreleased) | Ping, Traceroute, Port Scan, DNS, WHOIS | Add per-tool search/filter bar to narrow large result sets without re-running the scan. |
| P1-4 | **PDF table header repeat on every page** (shipped v4.16.0) | Exporter | Long reports (Multi-Ping, Traceroute) lose column headers after page 1; implement `CGContext` page-header drawing. |
| P1-5 | **Settings search** (done, unreleased) | SettingsView | Add a filter field to jump directly to a setting pane (Thresholds, Backup, Privacy, Tools). |
| P1-6 | **Batch export (PDF + CSV)** (shipped v4.16.0) | All export-capable tools | Allow selecting multiple sessions/tools and exporting one combined PDF or ZIP of CSVs. |
| P1-7 | **Unit-test coverage for Exporter** (shipped v4.16.0) | Exporter.swift | Add snapshot-style tests for PDF page count, CSV column order, and filename pattern `NetUtil-[Tool]-[target]-yyyyMMdd-HHmmss`. |
| P1-8 | **Dashboard redesign** (done, unreleased) | Dashboard | Layout masih terasa belum pas; tata ulang hierarki informasi, kartu ringkasan/hero, dan spacing agar status at-a-glance terbaca jelas dan konsisten dengan token `Metrics.*`. |
| P1-9 | **Beginner-friendly + standardization sweep** (done, unreleased) | All tools | Buat tiap tool bisa dipahami pemula: label bahasa awam, hint inline "ini apa / harus apa", state empty/loading/error yang konsisten, dan satu tata bahasa visual yang seragam di 28 tool. |

---

## P2 — Nice-to-have (features, experimentation)

| # | Task | Tool / Area | Rationale |
|---|------|-------------|-----------|
| P2-1 | **Plug-in host-resolver cache** (done, unreleased) | All tools | Cache DNS / Geo / RDAP lookups for the session lifetime to reduce repeated ipinfo.io calls and speed up Traceroute / WHOIS. |
| P2-2 | **Timeline scrubber for historical data** (done, unreleased) | Statistics, Bandwidth | Replace static daily bar chart with a draggable time window (day / week / month / 90-day). |
| P2-3 | **Custom alert presets** | Ping, Multi-Ping, Net Quality | Let users save named threshold sets (e.g., "Gaming", "Work") and switch between them without opening Settings. |
| P2-4 | **LAN device fingerprinting** | Neighbors | Enrich ARP entries with OUI vendor name and guessed device type (router, printer, phone). |
| P2-5 | **CLI companion tool** | New binary | `netutil ping <host>` / `netutil speed` for scripts and Terminal usage; share the same subprocess runners as the app. |
| P2-6 | **Menu-bar only mode** | MenuBarExtra | Hide the main window and run a lightweight status-bar popover with ping / bandwidth / VPN state. |
| P2-7 | **Guided troubleshooting workflow** (done via Doctor, unreleased) | New (Assistant) | Alur diagnosa step-by-step yang memandu user lewat urutan troubleshooting umum (link -> IP/DHCP -> gateway -> DNS -> internet reachability), menjalankan tool yang relevan di tiap langkah dan menjelaskan hasilnya dalam bahasa awam. |

---

## Forward Roadmap

### Shipped in v4.14.0 — HIG Hardening & Accessibility

- P0-1 automated HIG lint (run manually) — done.
- P1-1 chart accessibility descriptors (Ping, Bandwidth, Wi-Fi RSSI, Multi-Ping) — done.

### Shipped in v4.15.0 (2026-09-13)


- P1-2 — `ErrorBanner` evolved (material, copy/retry/dismiss) across all tools.
- P1-3 — live-filter on all result tables (Ping, Traceroute, Port Scan, DNS, WHOIS).

### Shipped in v4.16.0 (2026-09-13)
- P1-4 — PDF table header repeat on every page.
- P1-6 — batch export (Session History; per-tool sections, filter-aware).
- P1-7 — Exporter unit tests (CSV header + column-order coverage).
- P1-5 Settings search — deferred; Settings sudah disederhanakan jadi 4 tab bahasa awam, search belum diperlukan.

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

### UI token sweep + HIG lint — SELESAI

- Corner radii and stack spacing across all views moved to `Metrics.*`; off-grid padding curated. Locked in by `scripts/hig-lint.sh` (H2 font, H5 radius, H6 spacing, H7 grid padding) run manually before each commit.

### Distribution: Homebrew + screenshots — SELESAI

- Homebrew tap `aderamdani/tap` with a `netutil` cask (ad-hoc signed; Gatekeeper caveat documented in the cask and README).
- README Screenshots section (4 tool captures) + an Installation Homebrew option.


### Error banner evolution (P1-2) — SELESAI


- `ErrorBanner` moved to a `.regularMaterial` surface (was fake red opacity), gained a built-in copy-to-clipboard action, and optional retry/dismiss wired to each tool's run action plus a new `clearError()` on every ViewModel.


### Live-filter (P1-3) — SELESAI (unreleased)


- Text filter across the Ping console log, Traceroute hops (by host/IP), Port Scan (port/service), and DNS records; WHOIS already had one.
