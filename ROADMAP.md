# NetUtil — Roadmap & Development Plan

> Last updated: 2026-05-27  
> Current version: 1.3.0  
> Based on full codebase audit of all 13 tools.

---

## Current Feature Inventory

| Tool | Core Capability | Status |
|------|----------------|--------|
| Dashboard | Live overview cards for all active tools | ✅ Shipped — minor bugs |
| Ping | RTT chart, stats, jitter, export | ✅ Shipped |
| Traceroute | Hops / Timeline / Map / Raw, geo, bottleneck, IP Info | ✅ Shipped (v1.3.0) |
| Multi-Ping | Concurrent ping sessions with sparklines | ✅ Shipped |
| Port Scanner | Preset/custom ranges, concurrency, ETA | ✅ Shipped |
| HTTP Latency | Waterfall chart (DNS/TCP/TLS/Request/TTFB/Download) | ✅ Shipped |
| DNS Lookup | dig-based, 8 record types, 4 server presets | ✅ Shipped |
| WHOIS | Parsed key/value display with filter | ✅ Shipped |
| SSL/TLS Inspector | Full chain, expiry countdown, TLS version, cipher | ✅ Shipped |
| Network Interfaces | getifaddrs, IPv4/IPv6/MAC/MTU/status | ✅ Shipped |
| Wi-Fi Inspector | RSSI/SNR/channel/band/security/tx rate, sparkline | ✅ Shipped |
| Route Table | netstat -rn, flag tooltips, live filter | ✅ Shipped |
| Bandwidth Monitor | Per-interface RX/TX with 60s rolling charts | ✅ Shipped |

---

## Known Bugs & Regressions

| # | Location | Issue |
|---|----------|-------|
| B-1 | `DashboardView` — `SystemStatBadge` | Hardcoded "Low Load" / "Healthy" values — not real metrics |
| B-2 | `DashboardView` — `bandwidthSummaryCard` | Shows no live data; just static text |
| B-3 | `DashboardView` — `dnsSummaryCard` | Navigates to `.ssl` instead of `.dns` |
| B-4 | `TracerouteHop.swift` + `TracerouteViewModel.swift` | `isPrivateIP` logic duplicated in both files |
| B-5 | `PingView`, `MultiPingView` (SlotRow), `TracerouteView` | `rttColor()` function duplicated in 3+ views |
| B-6 | `BandwidthView` | Creates its own `@StateObject var vm` locally — resets when navigating away |
| B-7 | `Dashboard` | No refresh timer — cards go stale after initial `.onAppear` |

---

## Tier 1 — Quick Fixes (1–2 files, low risk)

Target: ship as **v1.3.1 patch**.

| # | Task | File(s) | Description |
|---|------|---------|-------------|
| T1-1 | Fix Dashboard system stats | `DashboardView.swift` | Remove fake badges or replace with real `sysctl` CPU load |
| T1-2 | Fix Dashboard bandwidth card | `DashboardView.swift` | Wire to `ToolStore.bandwidth` to show top-interface live RX/TX |
| T1-3 | Fix Dashboard DNS navigation | `DashboardView.swift` | Change `dnsSummaryCard` action from `.ssl` to `.dns` |
| T1-4 | Deduplicate `isPrivateIP` | New `Utilities/NetworkUtils.swift` | Single static func, delete from `TracerouteHop` and `TracerouteViewModel` |
| T1-5 | Deduplicate `rttColor` | Same `NetworkUtils.swift` | One shared func with `warn`/`crit` params |
| T1-6 | WHOIS structured summary | `WhoisView.swift` | Parse registrar, created, expiry at top as a chip bar |
| T1-7 | SSL weak algo warnings | `SSLInspectorView.swift` | Banner for RSA < 2048-bit, SHA-1 signature chains |
| T1-8 | Port Scanner: copy open ports | `PortScanView.swift` | "Copy Open Ports" in export menu → comma-separated port list |
| T1-9 | Ping: right-click copy row | `PingView.swift` | Context menu on table row → copy as text |
| T1-10 | DNS: add ALL record type | `DNSViewModel.swift` | `dig @server host ANY` |
| T1-11 | Move BandwidthViewModel to ToolStore | `ToolStore.swift`, `BandwidthView.swift` | Persist bandwidth history across navigation |
| T1-12 | Dashboard refresh timer | `DashboardView.swift` | 5s timer to re-poll wifi/interface cards |

---

## Tier 2 — New Features in Existing Tools

Target: ship as **v1.4.0**.

### Ping
| # | Feature | Description |
|---|---------|-------------|
| T2-1 | Session history | Keep last 5 sessions (host + summary stats), table below chart — same pattern as HTTP Latency |
| T2-2 | Subnet sweep | Input `192.168.1.0/24` → ping all hosts, show alive/dead table |

### DNS Lookup
| # | Feature | Description |
|---|---------|-------------|
| T2-3 | Compare servers mode | Toggle "Compare" → runs same query on System / 8.8.8.8 / 1.1.1.1 / 9.9.9.9 in parallel, results in 4 columns |
| T2-4 | DNSSEC indicator | Parse `dig` output for `ad` flag → show "DNSSEC Validated" badge |

### Multi-Ping
| # | Feature | Description |
|---|---------|-------------|
| T2-5 | Expand row to chart | Click row → inline RTT area chart (60 samples, same style as Traceroute detail panel) |
| T2-6 | Bulk host import | Paste newline- or comma-separated host list into an import sheet |
| T2-7 | Quick traceroute action | Right-click slot with 100% loss → "Traceroute this host" navigates to Traceroute with host pre-filled |

### Port Scanner
| # | Feature | Description |
|---|---------|-------------|
| T2-8 | Banner grabbing | After TCP connect on open port, read first 256 bytes → display service banner in table |
| T2-9 | Scan history | Keep last 3 scan results per host; accessible via history dropdown |
| T2-10 | Security hints | Flag well-known insecure protocols (Telnet/23, FTP/21, rsh/514) with warning icon |

### HTTP Latency
| # | Feature | Description |
|---|---------|-------------|
| T2-11 | Response headers viewer | Collapsible section below waterfall showing response headers as key/value |
| T2-12 | Request body editor | Text area + Content-Type picker for POST/PUT methods |
| T2-13 | Compare URLs | Run same request to two URLs side by side |

### SSL/TLS Inspector
| # | Feature | Description |
|---|---------|-------------|
| T2-14 | HSTS check | Show `Strict-Transport-Security` header from HTTP response alongside cert info |
| T2-15 | Cert change detection | Hash last seen cert; warn if fingerprint changes on re-inspect |

### Network Interfaces
| # | Feature | Description |
|---|---------|-------------|
| T2-16 | DNS per interface | Run `scutil --dns` → show configured DNS servers per interface |
| T2-17 | Default gateway | Parse `netstat -rn` for `default` route → show gateway IP per interface |
| T2-18 | Ping gateway button | Quick "Ping Gateway" button on each interface row |

### Traceroute
| # | Feature | Description |
|---|---------|-------------|
| T2-19 | Split TracerouteView.swift | Refactor 1196-line file into `TracerouteHopsView.swift`, `TracerouteTimelineView.swift`, `TracerouteMapView.swift`, `IPInfoCard.swift` |
| T2-20 | Right-click hop context menu | Copy IP, Copy hostname, Open in browser, Quick traceroute hop |

### Bandwidth
| # | Feature | Description |
|---|---------|-------------|
| T2-21 | Total bytes counter | Show cumulative RX/TX bytes since monitoring started |
| T2-22 | Export bandwidth history | CSV export of 60s history per interface |

---

## Tier 3 — New Tools

Target: **v1.5.0** and **v1.6.0**.

### Speed Test *(v1.5.0)*
**Tool ID:** `speedTest`  
**Icon:** `speedometer`  
**Approach:** Pure URLSession — no third-party deps.

- Download test: concurrent downloads from configurable CDN endpoints (Cloudflare, fast.com-compatible)
- Upload test: multipart POST with generated payload
- Live throughput chart (Mbps over time)
- Summary: Download Mbps / Upload Mbps / Ping (RTT) / Server
- Multiple test server presets
- History table — keep last 10 runs

**ViewModel:** `SpeedTestViewModel` in `ToolStore`  
**Key files:** `SpeedTestViewModel.swift`, `Views/SpeedTestView.swift`

---

### Certificate Monitor *(v1.5.0)*
**Tool ID:** `certMonitor`  
**Icon:** `lock.shield.fill`  
**Approach:** Reuse `SSLInspectorViewModel.inspect()` logic.

- Saved list of host:port entries (persisted via `UserDefaults`)
- Background refresh on app launch + every 24h
- Table: Host · Port · Days Left · Issuer · Last Checked
- Color-coded rows: green > 30d, orange 7–30d, red ≤ 7d
- macOS notification when any cert < alert threshold
- Add/remove hosts, configurable alert threshold in Settings

**ViewModel:** `CertMonitorViewModel` in `ToolStore`  
**Key files:** `CertMonitorViewModel.swift`, `Views/CertMonitorView.swift`, extend `SettingsView`

---

### Subnet Scanner *(v1.5.0)*
**Tool ID:** `subnetScan`  
**Icon:** `dot.radiowaves.right`  
**Approach:** ICMP ping sweep via `/sbin/ping -c 1 -W 500` per host, concurrent.

- Input: CIDR notation (`192.168.1.0/24`) or IP range (`192.168.1.1-254`)
- Concurrent sweep (configurable threads, default 64)
- Results table: IP · Hostname (reverse DNS) · Status · RTT
- Progress bar with ETA
- Export alive hosts as CSV or plain list
- Quick actions: "Ping this host", "Traceroute", "Port Scan"

**ViewModel:** `SubnetScanViewModel` in `ToolStore`  
**Key files:** `SubnetScanViewModel.swift`, `Views/SubnetScanView.swift`

---

### mDNS / Bonjour Browser *(v1.6.0)*
**Tool ID:** `mdns`  
**Icon:** `bonjour`  
**Approach:** `NetServiceBrowser` + `NetService`.

- Browse common service types: `_http._tcp`, `_https._tcp`, `_ssh._tcp`, `_ftp._tcp`, `_smb._tcp`, `_afpovertcp._tcp`, `_printer._tcp`, `_airplay._tcp`, `_raop._tcp`
- Results table: Service Name · Type · Host · IP · Port
- Resolve on demand (click row → resolves host/port)
- Filter by service type
- Copy host:port to clipboard

**ViewModel:** `MDNSViewModel` in `ToolStore`  
**Key files:** `MDNSViewModel.swift`, `Views/MDNSView.swift`

---

## Tier 4 — UX Consistency & Polish

Target: ship alongside Tier 1 & 2.

| # | Change | Scope |
|---|--------|-------|
| UX-1 | Standardize empty states | All views — same icon size (`.largeTitle`), same caption font, same background |
| UX-2 | Standardize loading states | All views — use `.controlSize(.small)` `ProgressView`, remove `.scaleEffect` hacks |
| UX-3 | Sidebar live status dots | Show pulsing green dot overlay on running tools (Ping, Traceroute, Multi-Ping) without breaking `.tag()` |
| UX-4 | Global keyboard shortcuts | `⌘R` = Start/Run, `⌘.` = Stop — consistent across all active-probing tools |
| UX-5 | Window min size | Bump from 900×580 to 1000×640 — Traceroute Map needs more space |
| UX-6 | `@StateObject` cleanup | Remove unnecessary `@StateObject` wrappers for `HostHistory.shared` — all views use `.shared` directly anyway |
| UX-7 | Tool section header tooltips | Add `.help()` to sidebar section headers explaining each group |
| UX-8 | Cmd+K quick switcher | Sheet with search → jump to any tool by typing name |

---

## Tier 5 — Performance Optimizations

| # | Issue | Fix |
|---|-------|-----|
| P-1 | `rawLines.removeFirst(n)` is O(n) copy | Use `rawLines = Array(rawLines.suffix(limit))` — same O(n) but avoids repeated prepend cost at high line rates |
| P-2 | `TracerouteView.swift` 1196 lines → slow compile | Covered in T2-19 |
| P-3 | `Dashboard` no periodic refresh | Covered in T1-12 |
| P-4 | `BandwidthView` local VM resets on nav | Covered in T1-11 |
| P-5 | `RTTSample` stores `UUID` (16B each) per sample | Replace `UUID` with monotonic `UInt64` sequence counter — saves 16B × 100 samples × N hops |
| P-6 | Geo lookups fire after every `mergeRound()` | Already gated by `geoInFlight` set — OK, no change needed |
| P-7 | `detectBottlenecks()` iterates full hop array every round | O(n) where n ≤ 30 — negligible, no change needed |

---

## Versioning Plan

| Version | Contents | Target |
|---------|----------|--------|
| **v1.3.1** | Tier 1 bug fixes (B-1 through B-7 + T1 items) | Next sprint |
| **v1.4.0** | Tier 2 — features in existing tools + UX polish | Following sprint |
| **v1.5.0** | Speed Test + Certificate Monitor + Subnet Scanner | Sprint +3 |
| **v1.6.0** | mDNS Browser + remaining optimizations | Sprint +4 |

---

## Architecture Notes for New Tools

All new tools follow existing patterns:

```
1. Model(s) in NetUtil/Models/
2. ViewModel: @MainActor class XxxViewModel: ObservableObject
3. Register in ToolStore
4. Add Tool case to ContentView enum + icon + sidebar section
5. View in NetUtil/Views/
6. Add AppStorage keys to SettingsView if configurable
7. Add to CLAUDE.md Tools Overview table
```

No new dependencies. All CLI tools use existing `/usr/bin` or `/sbin` paths or native frameworks (`NetServiceBrowser`, `URLSession`, `Network.framework`).
