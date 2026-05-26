# NetUtil

A professional network diagnostics toolkit for macOS, built with SwiftUI.

![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey?style=flat-square)
![Swift](https://img.shields.io/badge/swift-6.0-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

---

## Overview

NetUtil bundles 12 network diagnostic tools into a single native macOS app. No third-party dependencies — everything runs on system frameworks and standard CLI tools already present on macOS.

## Tools

### Active Probing

| Tool | Description |
|------|-------------|
| **Ping** | ICMP echo latency with live chart, min/avg/max/loss stats, configurable count and interval |
| **Traceroute** | Hop-by-hop path discovery with RTT per probe and optional IP geolocation (country + city via ipinfo.io) |
| **Multi-Ping** | Simultaneous ping sessions to multiple hosts — live sparklines, loss %, avg RTT per host |
| **Port Scanner** | TCP port reachability across preset or custom ranges, configurable concurrency and timeout, CSV export |
| **HTTP Latency** | Full request waterfall — DNS, TCP, TLS, request, TTFB, download phases via `URLSessionTaskMetrics` |

### Lookup

| Tool | Description |
|------|-------------|
| **DNS Lookup** | Query A, AAAA, MX, TXT, NS, CNAME, SOA, PTR records via `/usr/bin/dig` |
| **WHOIS** | Domain and IP registration info via `/usr/bin/whois` with color-coded output and export |
| **SSL/TLS Inspector** | Full certificate chain inspection — subject, issuer, SANs, validity dates, key type, SHA-256 fingerprint, expiry countdown |

### Network Info

| Tool | Description |
|------|-------------|
| **Network Interfaces** | All interfaces with IPv4/IPv6/MAC/MTU and Up/Down status, auto-refreshes every 3 s |
| **Wi-Fi Inspector** | SSID, BSSID, channel, security type, RSSI, SNR, transmit rate via CoreWLAN |
| **Route Table** | IPv4 and IPv6 routing table from `netstat -rn` with flag descriptions and text filter |
| **Bandwidth Monitor** | Per-interface RX/TX byte rate with 60-second rolling chart, auto-scales to peak rate |

### Menu Bar Extra

Always-available network indicator in the menu bar. Shows live ping RTT to a configurable host, active interfaces, and quick-access Open/Quit buttons.

---

## Screenshots

> _Add screenshots here_

---

## Requirements

- macOS 15 Sequoia or later
- Xcode 16+
- Apple Developer account (for code signing)

---

## Building

```bash
git clone https://github.com/aderamdani/NetUtil.git
cd NetUtil
open NetUtil.xcodeproj
```

1. Select your Team in **Signing & Capabilities** (required for `Network.framework` and `CoreWLAN`)
2. Build and run with **⌘R**

### Regenerating the app icon

```bash
swift generate_icon.swift
```

Outputs PNGs to `NetUtil/Assets.xcassets/AppIcon.appiconset/` at all required sizes (16 → 1024 px).

---

## Architecture

```
NetUtil/
├── Models/          # Plain data types and service helpers
│   ├── CertInfo.swift           # SSL certificate chain model
│   ├── DNSRecord.swift          # DNS record types
│   ├── Exporter.swift           # NSSavePanel CSV/text export helper
│   ├── HTTPLatencyResult.swift  # HTTP phase timing model
│   ├── HostHistory.swift        # Shared recent-host history (UserDefaults)
│   ├── NetworkInterface.swift   # getifaddrs() wrapper
│   ├── PingResult.swift         # Ping sample model
│   ├── PortResult.swift         # Port scan result + service name lookup
│   ├── RouteEntry.swift         # Routing table entry parser
│   └── TracerouteHop.swift      # Hop model with optional GeoInfo
│
├── ViewModels/      # ObservableObject classes, all @MainActor
│   ├── DNSViewModel.swift
│   ├── HTTPLatencyViewModel.swift   # URLSessionTaskMetrics delegate
│   ├── MultiPingViewModel.swift     # PingSlot per host, concurrent tasks
│   ├── NetworkInterfaceViewModel.swift
│   ├── PingViewModel.swift          # Process + Pipe → /sbin/ping
│   ├── PortScanViewModel.swift      # withTaskGroup concurrent TCP probes
│   ├── SSLInspectorViewModel.swift  # SecTrust chain extraction
│   └── TracerouteViewModel.swift    # /usr/sbin/traceroute + geo lookup
│
└── Views/           # SwiftUI views
    ├── AboutView.swift
    ├── BandwidthView.swift
    ├── DNSView.swift
    ├── HTTPLatencyView.swift
    ├── HelpView.swift
    ├── MenuBarView.swift
    ├── MultiPingView.swift
    ├── NetworkInterfaceView.swift
    ├── PingView.swift
    ├── PortScanView.swift
    ├── RouteTableView.swift
    ├── SSLInspectorView.swift
    ├── SettingsView.swift
    ├── TracerouteView.swift
    ├── WhoisView.swift
    └── WiFiInspectorView.swift
```

### Key design decisions

- **No third-party dependencies.** Every tool uses system frameworks (`Network.framework`, `CoreWLAN`, `CryptoKit`) or standard CLI binaries already on macOS.
- **`@MainActor` throughout.** All ViewModels are `@MainActor`-isolated; background work runs in `Task.detached` or `nonisolated static` functions, then publishes results back on the main actor.
- **`Process` + `Pipe` for CLI tools.** Ping, traceroute, dig, whois, and netstat are spawned as subprocesses. Output is read line-by-line via `readabilityHandler` so the UI updates live.
- **`URLSessionTaskMetrics` for HTTP timing.** Phase breakdown (DNS/TCP/TLS/TTFB/download) is extracted from `URLSessionTaskTransactionMetrics` dates without any custom instrumentation.
- **`SecTrustCopyCertificateChain`** (macOS 12+) replaces the deprecated `SecTrustGetCertificateAtIndex` for certificate chain traversal.
- **`getifaddrs()` for bandwidth.** Polls `if_data.ifi_ibytes`/`ifi_obytes` each second and computes deltas — no elevated privileges required.

---

## Settings

All settings persist via `@AppStorage` (UserDefaults).

| Setting | Default | Effect |
|---------|---------|--------|
| Ping count | 100 | Packets per run |
| Ping interval | 0.5 s | Delay between pings |
| Traceroute max hops | 30 | `traceroute -m` value |
| RTT warn threshold | 20 ms | Green → orange color cutoff |
| RTT critical threshold | 100 ms | Orange → red color cutoff |
| Loss alert threshold | 5% | Highlights loss stat in red |
| Port scan concurrency | 50 | Simultaneous TCP probes |
| Port scan timeout | 1.5 s | Per-port TCP connect timeout |
| HTTP timeout | 15 s | URLSession task timeout |
| SSL timeout | 10 s | TLS handshake timeout |
| Geolocation | On | ipinfo.io lookups in Traceroute |

---

## Entitlements

`com.apple.security.network.client` — required for outbound network connections (ping, traceroute, HTTP, DNS, SSL, port scan, geolocation API).

---

## Acknowledgements

NetUtil uses the following system tools and frameworks:

- `/sbin/ping` — ICMP echo requests
- `/usr/sbin/traceroute` — Hop discovery
- `/usr/bin/whois` — WHOIS queries
- `/usr/bin/dig` — DNS lookups
- `/usr/sbin/netstat` — Routing table
- `Network.framework` — Apple Inc.
- `CoreWLAN.framework` — Apple Inc.
- `CryptoKit` — SHA-256 certificate fingerprinting

Geolocation data provided by [ipinfo.io](https://ipinfo.io).

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Developed by **Ade Ramdani**
