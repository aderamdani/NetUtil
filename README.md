# NetUtil

A native macOS network diagnostics toolkit — 12 tools, zero third-party dependencies, built entirely with SwiftUI.

![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/swift-6.0-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Release](https://img.shields.io/github/v/release/aderamdani/NetUtil?style=flat-square)

---

## Download

**[Latest Release →](https://github.com/aderamdani/NetUtil/releases/latest)**

Download `NetUtil-x.x.x.dmg`, drag to Applications, and run. On first launch, right-click → Open to bypass Gatekeeper (app is signed for local development).

---

## Tools

### Active Probing

| Tool | Description |
|------|-------------|
| **Ping** | ICMP echo latency with live RTT chart, min/avg/max/jitter/loss%, configurable count and interval |
| **Traceroute** | Hop-by-hop path discovery with RTT per probe, path summary strip, optional IP geolocation (ipinfo.io) |
| **Multi-Ping** | Simultaneous ping to multiple hosts — live sparklines, loss%, avg RTT, color-coded rows |
| **Port Scanner** | TCP port reachability with preset ranges (Common/Well-known/All) or custom, concurrency + timeout control, CSV export |
| **HTTP Latency** | Full request waterfall — DNS, TCP, TLS, request, TTFB, download phases via `URLSessionTaskMetrics`, history table |

### Lookup

| Tool | Description |
|------|-------------|
| **DNS Lookup** | A, AAAA, MX, TXT, NS, CNAME, SOA, PTR via `/usr/bin/dig` with syntax-highlighted output |
| **WHOIS** | Domain and IP registration info via `/usr/bin/whois`, color-coded key/value output, export |
| **SSL/TLS Inspector** | Full certificate chain — subject, issuer, SANs, validity, key type, SHA-256 fingerprint, TLS version + cipher suite, expiry countdown |

### Network Info

| Tool | Description |
|------|-------------|
| **Network Interfaces** | All interfaces with IPv4/IPv6/MAC/MTU and Up/Down status, auto-refreshes every 3 s |
| **Wi-Fi Inspector** | SSID, BSSID, channel, security type, RSSI, SNR (color-coded), transmit rate, RSSI history sparkline via CoreWLAN |
| **Route Table** | IPv4 and IPv6 routing table from `netstat -rn` with flag descriptions and live text filter |
| **Bandwidth Monitor** | Per-interface RX/TX byte rate with 60-second rolling area chart, auto-scales to peak |

---

## Screenshots

> _Add screenshots here_

---

## Requirements

| | Version |
|--|---------|
| macOS | 15 Sequoia or later |
| Xcode | 16.0+ (for building) |
| Swift | 6.0 |

---

## Building from Source

```bash
git clone https://github.com/aderamdani/NetUtil.git
cd NetUtil
open NetUtil.xcodeproj
```

1. Select your Team in **Signing & Capabilities** (required for `Network.framework` and `CoreWLAN`)
2. Press **⌘R**

See [Building from Source](https://github.com/aderamdani/NetUtil/wiki/Building-from-Source) in the wiki for full instructions including DMG packaging.

---

## Architecture

```
NetUtil/
├── Models/          # Plain data types and service helpers
│   ├── ToolStore.swift              # App-level ViewModel container (process persistence)
│   ├── PingResult.swift             # PingStats: min/avg/max/jitter (sum-of-squares), loss%
│   ├── CertInfo.swift               # SSL certificate chain model
│   ├── HTTPLatencyResult.swift      # HTTP phase timing model
│   ├── HostHistory.swift            # Shared recent-host list (UserDefaults)
│   ├── NetworkInterface.swift       # getifaddrs() wrapper
│   ├── PortResult.swift             # Port scan result + service name lookup
│   ├── RouteEntry.swift             # Routing table entry parser
│   └── TracerouteHop.swift          # Hop model with optional GeoInfo
│
├── ViewModels/      # @MainActor ObservableObject classes
│   ├── PingViewModel.swift          # Process + Pipe → /sbin/ping
│   ├── TracerouteViewModel.swift    # /usr/sbin/traceroute + geo lookup
│   ├── MultiPingViewModel.swift     # PingSlot per host, concurrent tasks
│   ├── PortScanViewModel.swift      # withTaskGroup concurrent TCP probes
│   ├── HTTPLatencyViewModel.swift   # URLSessionTaskMetrics delegate
│   ├── DNSViewModel.swift
│   ├── SSLInspectorViewModel.swift  # SecTrust chain extraction
│   └── WhoisViewModel.swift
│
└── Views/           # SwiftUI views (one per tool + About/Help/Settings/MenuBar)
```

### Key design decisions

- **Process persistence across navigation** — `ToolStore` owns all active-probing ViewModels at the App level. Views use `@ObservedObject` (not `@StateObject`), so navigating away destroys the view but leaves the running process untouched.
- **No third-party dependencies** — every tool uses system frameworks (`Network.framework`, `CoreWLAN`, `CryptoKit`) or standard CLI binaries already on macOS.
- **`@MainActor` throughout** — all ViewModels are `@MainActor`-isolated; background work dispatches results back via `Task { @MainActor in ... }`.
- **`Process` + `Pipe` for CLI tools** — output is read line-by-line via `readabilityHandler` for live UI updates.
- **No `.badge()` on tagged List rows** — on macOS, `.badge()` after `.tag()` in `List(selection:)` breaks tag propagation. Sidebar uses plain `Label(...).tag($0)`.

---

## Settings

All settings persist via `@AppStorage` (UserDefaults). Open with **⌘,**.

| Setting | Default | Effect |
|---------|---------|--------|
| Ping count | 100 | Packets per run |
| Ping interval | 0.5 s | Delay between pings |
| Traceroute max hops | 30 | `traceroute -m` value |
| RTT warn threshold | 20 ms | Green → orange cutoff |
| RTT critical threshold | 100 ms | Orange → red cutoff |
| Loss alert threshold | 5% | Highlights loss stat in red |
| Port scan concurrency | 50 | Simultaneous TCP probes |
| Port scan timeout | 1.5 s | Per-port TCP connect timeout |
| HTTP timeout | 15 s | URLSession task timeout |
| SSL timeout | 10 s | TLS handshake timeout |
| Geolocation | On | ipinfo.io lookups in Traceroute |

---

## Entitlements

`com.apple.security.network.client` — required for all outbound network connections (ping, traceroute, HTTP, DNS, SSL, port scan, geolocation API).

---

## Documentation

Full documentation is available in the [Wiki](https://github.com/aderamdani/NetUtil/wiki):

- [Getting Started](https://github.com/aderamdani/NetUtil/wiki/Getting-Started)
- [Tools Overview](https://github.com/aderamdani/NetUtil/wiki/Tools-Overview)
- [Architecture](https://github.com/aderamdani/NetUtil/wiki/Architecture)
- [Settings](https://github.com/aderamdani/NetUtil/wiki/Settings)
- [Building from Source](https://github.com/aderamdani/NetUtil/wiki/Building-from-Source)

---

## Acknowledgements

| Tool / Framework | Purpose |
|-----------------|---------|
| `/sbin/ping` | ICMP echo requests |
| `/usr/sbin/traceroute` | Hop discovery |
| `/usr/bin/whois` | WHOIS queries |
| `/usr/bin/dig` | DNS lookups |
| `/usr/sbin/netstat` | Routing table |
| `Network.framework` | TCP port scanning |
| `CoreWLAN.framework` | Wi-Fi inspection |
| `CryptoKit` | SHA-256 certificate fingerprinting |

Geolocation data provided by [ipinfo.io](https://ipinfo.io).

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Developed by **Ade Ramdani**
