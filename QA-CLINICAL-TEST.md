# NetUtil — Clinical Test Report

Scope: end-to-end functional + HIG audit of every tool, with an automated
regression suite. Generated 2026-05-30 against `main` @ v3.2.0.

Two deliverables:

1. **Automated suite** — `tests-spm/` (SwiftPM + XCTest). 71 tests over the
   pure-logic core (parsers, subnet math, stats, models). Run:
   ```bash
   swift test --package-path tests-spm
   ```
   Sources are **symlinks** to the real app files (`NetUtil/Models`,
   `NetUtil/ViewModels`), so tests run against production code with zero drift.
2. **This document** — manual scenarios per tool, HIG findings, and a bug ledger.

---

## 1. Functional Bug Ledger

### Fixed in this pass (verified by tests)

| # | Severity | Tool | Bug | Fix | Test |
|---|----------|------|-----|-----|------|
| F1 | **Crash** | Subnet Calc | Selecting prefix `/0` ran `UInt32(pow(2,32))` → integer-overflow trap → app crash (the picker offers `/0`). | `NetworkMath.swift`: bit-shift with `/0` guard returning `.max`. | `testSubnet0DoesNotCrash` |
| F2 | High | HTTP Latency | "Follow Redirects = off" was a no-op: it set `httpMaximumConnectionsPerHost = 1`, which does not stop redirects; 3xx were always followed. | `HTTPLatencyViewModel.swift`: implement `willPerformHTTPRedirection`, return `nil` when disabled. | manual (network) |
| F3 | Medium | Multi-Ping | No-route replies never counted as packet loss — code matched lowercase `"no route"` but ping prints `No route to host` (capital N). | `MultiPingViewModel.swift`: case-insensitive match. | `testParseNoRouteCountsAsLoss` |

### Open / minor (documented, not changed — cosmetic or low-impact)

| # | Sev | Where | Note |
|---|-----|-------|------|
| O1 | low | `RouteEntry.flagDescriptions` | Only UPPERCASE route flags decoded. macOS also emits lowercase `c` (cloning), `m`, `r` — shown raw, never expanded. |
| O2 | low | `NetworkMath.detectClass` vs `IPAddressDetails.ipClass` | Two class detectors disagree on first-octet `0` (`A` vs `Unknown`). Pick one source of truth. |
| O3 | low | `SystemMonitor.updateMemory` | `sysctlbyname("kern.memo_status_level")` is a non-existent key; its branch is dead code. Pressure is actually derived from the `host_statistics64` fallback (works). `memoryColor` returns `"blue"` for healthy while the rest of the app uses `"green"`. |
| O4 | low | `TracerouteViewModel.isPrivateIP` / `TracerouteHop.isPrivateIP` | `169.254/16` (APIPA) not treated as private, so geo lookups can fire on link-local addresses. `IPAddressDetails` already handles APIPA — align them. |
| O5 | trivial | `NetworkMath.formatBytes` | Inconsistent precision: 1 decimal for KB/MB, 2 for GB/TB. |

---

## 2. Apple HIG Audit

The project's own `CLAUDE.md` defines hard rules (≥10pt fonts, no `Color(...).opacity()`
card backgrounds, no forced ALL CAPS, no 40pt+ empty-state icons, card radius 8–12).

**STATUS: H1–H4 all RESOLVED** (build verified, `BUILD SUCCEEDED`). Counts after fix:
sub-10pt fonts = 0, forced ALL CAPS = 0, opacity card/table backgrounds = 0,
40pt+ empty-state icons = 0. Findings retained below for the record.

### H1 — Empty-state icons exceed the 40pt ceiling (systemic)
Rule: "No 40pt+ empty state icons. Silent secondary text only."
`size: 48` empty-state icons in: `PingView:406`, `TracerouteView:268`,
`WhoisView:226`, `SSLInspectorView:282`, `PortScanView:222`, `MultiPingView:184`,
`WiFiInspectorView:197`, `HTTPLatencyView:286`, `SubnetCalculatorView:201`,
`DNSView:246`. `size: 32` variants in `StatisticsView:362`, `TopProcessesView:218`,
`BandwidthView:195`, `NetworkInterfaceView:151`.
Fix: drop the icon, keep the `.headline`/`.secondary` text (per rule), or reduce to ≤24pt.
(`AboutView:19` size 40 is the app-logo glyph — acceptable.)

### H2 — Sub-10pt fonts
Rule: "Minimum font size 10pt."
`size: 6` `SpeedTestView:290`; `size: 7` `PortScanView:305`;
`size: 8` in `TracerouteView:302`, `WiFiInspectorView:58`, `PingView:456`,
`BandwidthView:317`, `DNSView:284`, `HTTPLatencyView:329`, `NetworkInterfaceView:254`,
`Components/TracerouteMapView:18`; `size: 9` in `SSLInspectorView:256`,
`MultiPingView:235,306`, `WiFiInspectorView:119,164`, `RouteTableView:132,157`,
`HTTPLatencyView:186`, `NetworkInterfaceView:124,226`, `Components/TracerouteTimelineView:52`.
Fix: raise to `.caption2` (11pt floor) or `size: 10` minimum.

### H3 — Forced ALL CAPS
Rule: "No forced ALL CAPS on labels or dynamic data."
`PortScanView:304` (`status.label.uppercased()`, size 7, `.black`),
`SpeedTestView:212` (`phase.rawValue.uppercased()`, `.black`),
`HTTPLatencyView:185` (`phase.rawValue.uppercased()`).
Fix: use Title Case; drop `.uppercased()` and `.black`.

### H4 — `Color(...).opacity()` backgrounds on cards/tables
Rule: "Cards/containers always `.regularMaterial`; never `Color(...).opacity()`."
Genuine card/table offenders: `PingView:285`, `DNSView:168`, `HTTPLatencyView:221`,
`TopProcessesView:133`, `MultiPingView:170`, `SpeedTestView:247`, `StatisticsView:300`,
`Components/TracerouteHopsTable:24` (all `Color.secondary.opacity(0.05)`).
Fix: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))`.
*Acceptable (rule explicitly allows colored opacity for status badges/error banners):*
`Color.red.opacity(0.1)` error banners, `Color.green/red.opacity(0.15)` status pills,
`Color.accentColor.opacity(0.05)` selection highlights.

### Compliant areas (spot-checked, no action)
- Control bars: fixed-top, icon+`.headline` title, no colored background. ✓
- Learning-guide buttons: `questionmark.circle` + `.borderless`. ✓ (Subnet, etc.)
- Card corner radius 8–12 throughout; no 20pt+ found. ✓
- Materials used correctly on most cards (`.regularMaterial`). ✓
- PDF report views (`Exporter.swift`) use <10pt fonts and ALL CAPS — **exempt**: print medium, not on-screen UI.

---

## 3. Per-Tool Test Scenarios (manual)

Legend: ▶ steps · ✓ expected · ⚠ edge.

### Dashboard
- ▶ Launch app. ✓ Header shows Hostname, Local IP, Public IP (resolves from "Checking…"), VPN status. ✓ Cards show live sparklines; CPU/RAM badges update ~2s.
- ▶ Click a tool card. ✓ Sidebar selection follows; detail view swaps.
- ▶ Circle play on Ping card. ✓ Card shows activity; sidebar dot pulses.
- ⚠ No network: Public IP → "Unknown" (no hang/crash).

### Ping
- ▶ Enter `8.8.8.8`, Start. ✓ Rows stream; header resolves IP; stats (sent/recv/loss/avg/jitter) update; distribution buckets fill.
- ▶ IPv6 host (`2607:f8b0::...`). ✓ `icmp6_seq/hlim` lines parse.
- ▶ Unplug network mid-run. ✓ "Request timeout" rows; loss% climbs; optional beep when enabled.
- ▶ Stop. ✓ Process terminates, `isRunning=false`, sidebar dot clears.
- ▶ Export CSV / JSON / PDF. ✓ Files written with ISO-8601 timestamps; PDF renders summary + last 100.
- ⚠ Invalid host → error string surfaced, no crash. ⚠ count limit honored (`-c`).
- Covered: `testParseLineIPv4/IPv6`, `testParseHeader*`, `testParseTimeout*`, `PingStats*`.

### Traceroute
- ▶ `google.com`, Start. ✓ Hops fill incrementally; per-hop avg/min/max/jitter/loss; bottleneck flag on >30ms jump & >50ms.
- ▶ Geo enabled. ✓ Public hops get flag/city/org via ipinfo.io; private hops show "Private", no lookup.
- ▶ Multiple rounds. ✓ Samples append, history capped at 100; sparkline per hop.
- ⚠ `* * *` timeout hops display `*`. ⚠ Stop cancels loop cleanly.
- Covered: `testParseStandardLine`, `HostnameWithIP`, `FullTimeoutLine`, `MixedTimeout`, `BareIPSwaps`, `RejectsHeader`, all `TracerouteHopTests`.

### Multi-Ping
- ▶ Add several hosts. ✓ Each slot pings @1s; live RTT/avg/loss/sparkline.
- ▶ Sort by Alias/Host/Latency/Loss. ✓ Reorders correctly.
- ▶ No-route host (e.g. unreachable RFC1918). ✓ **(F3 fix)** loss climbs.
- ▶ Remove slot. ✓ Process stops; row gone. ▶ Export PDF. ✓ Consolidated report.
- ⚠ Duplicate host ignored. ⚠ Empty host ignored.
- Covered: `MultiPingSlotParserTests` (success, `time<`, timeout, no-route, header).

### Port Scanner
- ▶ `scanme.nmap.org`, Web preset, Start. ✓ Progress/ETA; open ports green with service name + ms.
- ▶ Custom ports. ✓ Honored. ▶ Concurrency slider. ✓ Throughput changes.
- ⚠ Filtered (no response) → "Filtered" after timeout. ⚠ Stop cancels task group, partial results kept.
- Covered: `PortModelTests` (presets, well-known map, status labels).

### HTTP Latency
- ▶ `https://apple.com`, GET, Start. ✓ Status, total ms, body size; waterfall DNS→TCP→TLS→Request→TTFB→Download.
- ▶ Toggle **Redirects off** on a redirecting URL (e.g. `http://google.com`). ✓ **(F2 fix)** stops at 3xx, `redirectCount=0`.
- ▶ History (≤20) + PDF export. ✓.
- ⚠ Bad URL → error. ⚠ Bare host auto-prefixed `https://`.
- Covered: `HTTPModelTests`.

### Subnet Calc
- ▶ `192.168.1.50` /24. ✓ Network .0, broadcast .255, range .1–.254, 256 total / 254 usable, class C, binary mask, wildcard.
- ▶ Slide prefix to **/0**. ✓ **(F1 fix)** no crash; mask 0.0.0.0.
- ▶ /31, /32. ✓ host range "N/A", usable 0.
- ⚠ Invalid IP → empty state, no result.
- Covered: `NetworkMathTests` (14), `IPAddressDetailsTests` (7).

### DNS Lookup
- ▶ `apple.com` A via Google/Cloudflare/Quad9/System. ✓ Records (name/ttl/type/value), query time, resolved server.
- ▶ MX/TXT/NS. ✓ Multi-token values preserved.
- ⚠ NXDOMAIN → empty answer, no crash.
- Covered: `DNSParserTests` (6).

### SSL/TLS Inspector
- ▶ `apple.com:443`. ✓ Chain (leaf→root), subject/issuer/SANs/serial/SHA-256/key type; expiry color (green>30d, orange>7d, red≤7d).
- ⚠ `https://`/path stripped from input. ⚠ Untrusted/no-cert host → error surfaced.
- Covered: `CertInfoTests` (expiry color + daysRemaining).

### WHOIS
- ▶ Domain + IP. ✓ Raw whois rendered; copy works. ⚠ Empty/garbage → graceful.

### Bandwidth / Statistics / Speed Test / Top Processes
- Bandwidth: ▶ live rx/tx per interface, aggregate, peaks; pause/resume baseline reset; active-only filter.
- Statistics: ▶ daily totals persist (UserDefaults, 90-day cap), session counters, averages; reset clears.
- Speed Test: ▶ Speed/Browsing/Gaming/Streaming run via Cloudflare; live values, progress, history (≤50), rename/delete; cancel mid-run is clean.
- Top Processes: ▶ `nettop` via `script` tty; top-10 by max(rx,tx); >500 B/s filter; stop terminates.
- ⚠ All: stop/cancel must terminate child processes (verified in `stop()`/`cancel()` paths).

### Interfaces / Wi-Fi / Routes
- Interfaces: ▶ `getifaddrs` list, IPv4/IPv6/MAC/MTU/up/type icon; VLAN tag+parent via ifconfig; 3s refresh.
- Wi-Fi: ▶ CoreWLAN SSID/RSSI/channel/Tx rate; updates on poll.
- Routes: ▶ `netstat -rn` parsed; default route flagged; flag legend (see O1).

---

## 4. Automated Coverage Matrix

| Area | Tests | Status |
|------|-------|--------|
| Subnet math + IPv4 parse/format | 14 | ✓ |
| IP class / private / IPv6 | 7 | ✓ |
| Ping stats + parsers (v4/v6/timeout) | 14 | ✓ |
| Multi-ping slot parser | 5 | ✓ |
| Traceroute parser + hop stats | 12 | ✓ |
| DNS dig parser + servers | 6 | ✓ |
| Route / port / HTTP / cert models | 13 | ✓ |
| **Total** | **71** | **✓ all green after F1–F3** |

Not unit-covered (require live network / system frameworks / UI — verify manually
per §3): port `NWConnection` scan, SSL `SecTrust` chain, `getifaddrs`/CoreWLAN,
Speed Test transfers, PDF rendering, all SwiftUI views.

---

## 5. How to extend

Add a logic file to the suite by symlinking it into `tests-spm/Sources/NetUtilCore/`
(Foundation/AppKit/Combine/CoreLocation/Security/Network only — no SwiftUI) and
writing a matching `*Tests.swift`. Keep parser funcs `internal` (not `private`) so
`@testable import NetUtilCore` can reach them.
