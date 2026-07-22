# NetUtil — Clinical Test Report

Scope: end-to-end functional + HIG audit of every tool, with an automated
regression suite. Generated 2026-05-31 against `main` @ v4.3.0.

Two deliverables:

1. **Automated suite** — **NetUtilTests** (Native Xcode Target). 71 tests over the
   pure-logic core (parsers, subnet math, stats, models). Run via `Cmd+U` or:
   ```bash
   xcodebuild test -project NetUtil.xcodeproj -scheme NetUtil -destination 'platform=macOS'
   ```
2. **This document** — manual scenarios per tool, HIG findings, and a bug ledger.

---

## 1. Functional Bug Ledger

### Fixed in this pass (verified by tests)

| # | Severity | Tool | Bug | Fix | Test |
|---|----------|------|-----|-----|------|
| F1 | **Crash** | Subnet Calc | Selecting prefix `/0` ran `UInt32(pow(2,32))` → integer-overflow trap → app crash (the picker offers `/0`). | `NetworkMath.swift`: bit-shift with `/0` guard returning `.max`. | `testSubnet0DoesNotCrash` |
| F2 | High | HTTP Latency | "Follow Redirects = off" was a no-op: it set `httpMaximumConnectionsPerHost = 1`, which does not stop redirects; 3xx were always followed. | `HTTPLatencyViewModel.swift`: implement `willPerformHTTPRedirection`, return `nil` when disabled. | manual (network) |
| F3 | Medium | Multi-Ping | No-route replies never counted as packet loss — code matched lowercase `"no route"` but ping prints `No route to host` (capital N). | `MultiPingViewModel.swift`: case-insensitive match. | `testParseNoRouteCountsAsLoss` |

### Open / minor — re-audited 2026-07-22 against v4.8.1

| # | Sev | Where | Status |
|---|-----|-------|------|
| O1 | low | route flag decoding | **Fixed.** The live code path (`RouteTableView.flagDescription`, not the dead `RouteEntry.flagDescriptions` this row originally cited) now uppercases before matching, so lowercase flags (`c`, `m`, `r`, …) decode correctly. `RouteEntry.flagDescriptions` itself was unreferenced dead code and has been deleted. |
| O2 | low | `NetworkMath.detectClass` vs `IPAddressDetails.ipClass` | **Moot.** `IPAddressDetails` was removed as dead code in v4.7.1 — `NetworkMath.detectClass` is the sole class detector. |
| O3 | low | `SystemMonitor.updateMemory` | **Resolved** (prior pass) — dead `sysctlbyname` branch removed, `memoryColor` consistently green/orange/red. |
| O4 | low | `TracerouteViewModel.isPrivateIP` / `TracerouteHop.isPrivateIP` | **Fixed.** Both call sites now share one `NetworkMath.isPrivateIP(_:)` helper (APIPA `169.254/16` included) instead of two independently-maintained copies that could drift. |
| O5 | trivial | `NetworkMath.formatBytes` | **Resolved** (prior pass) — uniform `%.2f` across all tiers. A separate duplicate formatter in `HTTPLatencyView` (different precision rules) has also been removed in favor of `NetworkMath.formatBytes`. |

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

## T1-1: DNS Server Comparison

**Test Case 1: Basic Comparison**
1. Buka DNS Lookup → switch mode ke "Compare"
2. Ketik "google.com", record type A, klik Lookup
3. Verify: 4 hasil muncul (System, Google, Cloudflare, Quad9)
4. Verify: semua menampilkan IP yang sama atau serupa
5. Verify: response time ditampilkan dalam ms, monospaced
6. Verify: hasil diurutkan tercepat di atas
7. Verify: baris tercepat ter-highlight subtle

**Test Case 2: Multiple Record Types**
1. Compare "google.com" dengan record type MX
2. Verify: setiap resolver menampilkan MX records
3. Compare "google.com" dengan record type TXT
4. Verify: SPF/DKIM records muncul

**Test Case 3: Non-existent Domain**
1. Compare "thisdomaindoesnotexist12345.com"
2. Verify: semua resolver menampilkan status Error atau NXDOMAIN
3. Verify: app tidak crash, error message clinical

**Test Case 4: Resolver Timeout**
1. Compare domain saat salah satu resolver lambat
2. Verify: hasil yang sudah selesai tampil duluan
3. Verify: resolver yang timeout menampilkan "Timeout" status

**Test Case 5: Switch Mode**
1. Jalankan Compare query
2. Switch kembali ke mode "Single"
3. Verify: comparison results hilang, kembali ke single result view
4. Jalankan single query — verify berfungsi normal

## T1-2: SSL Certificate Expiry Watchlist

**Test Case 1: Add to Watchlist**
1. Buka SSL/TLS Inspector → scan "google.com"
2. Verify: tombol "Watch" (bell.badge) muncul setelah scan selesai
3. Klik Watch → verify domain ditambahkan ke watchlist
4. Verify: tombol berubah jadi "Unwatch" (bell.slash)

**Test Case 2: Watchlist View**
1. Tambahkan 3 domain ke watchlist: google.com, github.com, expired.badssl.com
2. Buka watchlist view
3. Verify: google.com dan github.com menampilkan badge hijau "Safe"
4. Verify: expired.badssl.com menampilkan badge merah "Expired"
5. Verify: expiry dates ditampilkan monospaced

**Test Case 3: Remove from Watchlist**
1. Swipe atau klik remove pada satu domain
2. Verify: domain hilang dari list
3. Buka SSL Inspector untuk domain tersebut — verify tombol kembali ke "Watch"

**Test Case 4: Check All**
1. Tambahkan 3+ domain ke watchlist
2. Klik "Check All Now"
3. Verify: semua domain di-refresh, lastChecked diupdate
4. Verify: loading indicator muncul selama proses

**Test Case 5: Dashboard Integration**
1. Tambahkan minimal 1 domain ke watchlist
2. Buka Dashboard
3. Verify: mini-card "SSL Watchlist" muncul
4. Verify: menampilkan jumlah watched dan status summary
5. Klik card → verify navigate ke SSL Inspector atau watchlist

**Test Case 6: Notification Permission**
1. Hapus semua domain dari watchlist
2. Tambahkan domain pertama
3. Verify: macOS permission dialog muncul untuk notifications
4. Allow → verify notification terdaftar di System Settings > Notifications

## T1-3: Multi-Ping Bulk Import

**Test Case 1: Basic Import**
1. Buka Multi-Ping → klik "Import"
2. Paste teks berikut ke TextEditor:
   ```
   google.com
   1.1.1.1
   cloudflare.com
   8.8.8.8
   ```
3. Verify: "4 hosts detected" muncul
4. Klik Import → verify 4 slot terisi dengan host tersebut
5. Start All → verify semua slot mulai ping

**Test Case 2: Input dengan noise**
1. Paste teks berikut (ada baris kosong dan duplikat):
   ```
   google.com

   1.1.1.1

   1.1.1.1

   cloudflare.com

   google.com
   ```
2. Klik "Import Hosts"
3. Verify: hanya 3 unique hosts yang terdeteksi (`google.com`, `1.1.1.1`, `cloudflare.com`).
4. Verify: duplikat dan baris kosong diskip.

**Test Case 3: Paste from Clipboard**
1. Copy list host ke clipboard (⌘C dari Notes atau TextEdit).
2. Buka Import sheet → klik "Paste from Clipboard".
3. Verify: TextEditor terisi dengan konten clipboard.

**Test Case 4: Overflow**
1. Pastikan hanya ada 2 slot kosong di Multi-Ping.
2. Import 5 hosts.
3. Verify: warning muncul bahwa hanya 2 yang bisa diimport.
4. Verify: 2 slot terisi, sisanya tidak.

**Test Case 5: Input kosong**
1. Buka Import sheet, biarkan TextEditor kosong.
2. Verify: tombol Import disabled atau "0 hosts detected".

## T1-4: Gateway Actions

**Test Case 1: Gateway Detection**
1. Buka Network Interfaces atau Dashboard
2. Verify: gateway terdeteksi dengan benar (misal: 192.168.1.1)
3. Verify: ada icon "Action" (antenna.radiowaves.left.and.right / point.3.connected.trianglepath.dotted) di sebelah IP gateway

**Test Case 2: Ping Gateway**
1. Klik icon Ping di sebelah gateway
2. Verify: berpindah ke tool Ping dengan host diisi IP gateway
3. Verify: otomatis memulai ping

**Test Case 3: Traceroute Gateway**
1. Klik icon Traceroute di sebelah gateway
2. Verify: berpindah ke tool Traceroute dengan host diisi IP gateway
3. Verify: otomatis memulai traceroute

## v4.x Feature & Fix Verification (v4.0.0 – v4.3.0)

### Subnet Scanner (v4.0.0)
1. Enter `192.168.1.0/24`, click Scan. Verify: hosts discovered, status Alive/Unreachable, RTT displayed.
2. Wait for scan to finish. Verify: hostname and MAC address columns populate for Alive hosts.
3. Right-click an Alive host → Ping. Verify: navigates to Ping tool with that IP, ping starts automatically.
4. Right-click an Alive host → Port Scan. Verify: navigates to Port Scanner, scan starts automatically.
5. Right-click an Alive host → Traceroute. Verify: navigates to Traceroute, trace starts automatically.
6. Export PDF. Verify: NSSavePanel opens, file saves with correct filename pattern.
7. Export CSV. Verify: CSV contains ip, hostname, status, rtt_ms, mac_address columns.
8. Click learning guide button. Verify: HelpView opens.

### Speed Test (v4.1.0)
1. Select Speed kind, click Start. Verify: Download/Upload/Ping/Jitter cards update live, progress bar shows phase.
2. Select Browsing kind, click Start. Verify: Sites Tested/Avg Load/Median TTFB cards update.
3. Select Gaming kind. Verify: Median Ping/P99/Jitter/Loss cards shown.
4. Select Streaming kind. Verify: Avg Speed/Min Speed/Tier cards shown.
5. After a Speed test completes: verify result in history table with timestamp, kind icon, primary metric.
6. Click a label cell in history. Verify: inline text field opens for rename.
7. Click trash icon on a result. Verify: row removed.
8. Click Clear. Verify: all history removed.
9. Export PDF and CSV. Verify: both generate correctly.

### Bandwidth Monitor (v4.3.0)
1. Open Bandwidth Monitor. Verify: aggregate stat cards show live Download/Upload values (not 0 after a few seconds).
2. Verify: 60-second chart renders with green (RX) above axis and blue (TX) below.
3. Verify: Y-axis labels fully visible, not clipped at the top (e.g., "500 Kbps" label fully readable).
4. Verify: per-interface table shows at least en0 or en1 with type icon and IP.
5. Verify: sparkline per interface updates every second.
6. Click Pause. Verify: chart freezes, "Paused" badge appears.
7. Click Resume. Verify: chart continues updating.
8. Toggle Active Only. Verify: interfaces with no traffic are hidden.
9. Export CSV. Verify: file contains timestamp, interface, rx_bps, tx_bps columns.
10. Generate traffic (download something). Verify: Peak RX stat updates; click reset arrow, verify it resets.

### Traceroute Host History (v4.3.0)
1. Run a traceroute to `8.8.8.8`. Verify: host recorded in history.
2. Clear host field. Verify: clock icon appears in TextField trailing edge.
3. Click clock icon. Verify: dropdown with recent hosts appears.
4. Select a host from dropdown. Verify: host field fills AND traceroute starts automatically.
5. Click "Clear History" in dropdown. Verify: history cleared, clock icon disappears.

### Chart Y-axis Clipping (v4.3.0)
1. Open Bandwidth Monitor with active traffic. Verify: highest Y-axis label (e.g., "1.5 Mbps") fully visible.
2. Open Statistics view with data. Verify: top label on throughput chart not cut off.
3. Open Wi-Fi Inspector. Verify: highest dBm label on RSSI chart not cut off.
4. Open Multi-Ping with an expanded slot. Verify: highest "X ms" label on RTT chart not cut off.

### Export PDF — All Tools (v4.0.1 + v4.3.0)
Verify Export PDF works (NSSavePanel opens, file saves) for every tool:
- Ping, Multi-Ping, Traceroute, HTTP Latency, DNS Lookup
- Port Scanner, WHOIS, SSL/TLS, Subnet Scanner, Speed Test

## T1-5: Regression Testing

1. Ping: test valid/invalid, export PDF/CSV.
2. Traceroute: test standard/map view, export PDF.
3. Speed Test: test complete cycle.
4. Port Scanner: test concurrency slider.
5. Interfaces: test refresh, VLAN identification.
6. Statistics: test reset counters.
7. Settings: test threshold panes.

---

