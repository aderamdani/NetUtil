<div align="center">
  <img src="NetUtil/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="NetUtil Logo">
  <h1>NetUtil</h1>
  <p><b>The Professional macOS Network Diagnostics Toolkit</b></p>

  [![Latest Release](https://img.shields.io/github/v/release/aderamdani/NetUtil?style=flat-square&color=007AFF)](https://github.com/aderamdani/NetUtil/releases)
  [![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey?style=flat-square&logo=apple)](https://developer.apple.com/macos/)
  [![Language](https://img.shields.io/badge/language-Swift%206-orange?style=flat-square&logo=swift)](https://swift.org)
  [![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
</div>

<br>

**NetUtil** is a high-performance, meticulously handcrafted macOS utility designed for network engineers and power users. It combines the raw power of classic CLI tools with a modern, symmetrical SwiftUI interface. Born from the principles of "Apple Artisan" design, NetUtil delivers zero-compromise diagnostics with flat hierarchies, vibrant materials, and data-dense analytics.

---

### Core Diagnostics

NetUtil provides 16 integrated tools designed for precision monitoring, infrastructure auditing, and rapid troubleshooting:

*   **Bento Dashboard**: A dynamic mission control featuring live sparklines, pulsing activity indicators, and real-time CPU/RAM gauges.
*   **Advanced Ping**: Beyond ICMP. Visualizes latency history, analyzes jitter, and provides GitHub-style health strips.
*   **Multi-Ping**: Monitor multiple server nodes simultaneously with real-time sparklines and consolidated PDF reporting.
*   **Traceroute**: Hop-by-hop path discovery with a visual timeline, MapKit geographic routing, and automatic bottleneck detection.
*   **Port Scanner**: High-speed, parallelized TCP reachability auditing using a modern mini-card grid system.
*   **HTTP Latency**: Millisecond-precise breakdown of web requests (DNS, TCP, TLS, TTFB) using native `URLSessionTaskMetrics`.
*   **IP Toolbox**: Subnet calculator supporting CIDR prefixes, wildcard masking, and IP class detection.
*   **Security Audit**: Deep inspection of SSL/TLS certificate chains, SANs, and SHA-256 fingerprints.
*   **DNS & WHOIS**: Direct access to `dig` and `whois` queries with elegantly parsed, copy-ready outputs.
*   **Traffic & Interfaces**: Live bandwidth throughput monitors (RX/TX), Wi-Fi signal/SNR analytics, and automatic VLAN (802.1Q) detection.
*   **Speed Test & Statistics**: Nperf-style four-tier speed tests (Speed, Browsing, Gaming, Streaming), real-time per-process network traffic (`nettop`), and historical data usage.

---

### Native Mac Polish

NetUtil is engineered with an absolute zero-tolerance policy for generic "AI Slop" or web-style designs. 

*   **100% Symmetrical Harmony**: Every single diagnostic tool shares an identical visual structure—Fixed Top Headers, Interpretation Mood Bars, and unified action placements.
*   **True Material Vibrancy**: UI panels react dynamically to your macOS wallpaper using native `.regularMaterial`.
*   **Flat Data Hierarchy**: Information flows naturally with ultra-fine `0.5pt` system dividers, avoiding nested borders or heavy shadows.
*   **Keyboard First**: Navigate seamlessly across all tools using `⌘1` through `⌘9` and utilize Global Search (`⌘F`) to instantly recall historical targets.

---

### Technical Excellence

*   **Swift 6 & SwiftUI**: Built exclusively for macOS 15+ ensuring maximum efficiency and minimal battery footprint.
*   **Zero Dependencies**: No third-party frameworks or bloated SDKs. Pure Apple APIs (`Network`, `CoreWLAN`, `MapKit`).
*   **Apple Silicon Native**: Hardware-accelerated for M1/M2/M3/M4 chips.
*   **Enterprise Reporting**: Generate branded, timestamped PDF and CSV reports for professional auditing.

---

### Installation

1.  Visit the **[Releases](https://github.com/aderamdani/NetUtil/releases)** page.
2.  Download the latest `NetUtil-vX.X.X.dmg`.
3.  Open the DMG and drag **NetUtil** to your `Applications` folder.
4.  *Note: On first launch, macOS Gatekeeper may prompt you. Simply Right-Click -> Open.*

---

## Bahasa Indonesia

**NetUtil** adalah utilitas macOS berperforma tinggi yang dirakit secara manual (*handcrafted*) untuk para *network engineer*. Menggabungkan kekuatan alat CLI klasik dengan antarmuka SwiftUI yang simetris dan modern. Dirancang dengan prinsip "Apple Artisan", NetUtil menghadirkan diagnosa jaringan tanpa kompromi, mengedepankan analitik yang padat data dan bebas dari desain *web* generik.

### Fitur Utama
*   **Dashboard Bento**: Pusat kendali dengan *sparkline* hidup, indikator aktivitas yang berdenyut, serta pantauan CPU/RAM secara *real-time*.
*   **Advanced Ping & Multi-Ping**: Visualisasi riwayat latensi, analisis *jitter*, dan pemantauan banyak *server* sekaligus dengan laporan PDF terpadu.
*   **Traceroute Geografis**: Deteksi *hop-by-hop* dengan Peta Rute, grafik *timeline*, dan deteksi *bottleneck* otomatis.
*   **Port & Security Audit**: Pemindai TCP berkecepatan tinggi dengan sistem *mini-card* modern, serta inspektor sertifikat SSL/TLS mendalam.
*   **HTTP Latency**: Analisis presisi setiap fase akses *web* (DNS, TCP, TLS, TTFB).
*   **IP Toolbox & DNS/WHOIS**: Kalkulator *Subnet* (CIDR), resolusi DNS komprehensif, dan data kepemilikan domain.
*   **Traffic & Interface**: Monitor *Bandwidth* (RX/TX) *real-time*, analisis sinyal Wi-Fi, dan deteksi otomatis untuk *Virtual LAN* (VLAN).
*   **Speed Test & Statistik**: Uji kecepatan jaringan komprehensif, pemantauan trafik *real-time* per aplikasi, dan riwayat penggunaan data.

### Keunggulan Teknis
Didesain 100% menggunakan **Swift 6 & SwiftUI** tanpa *framework* pihak ketiga mana pun (*Zero Dependencies*). Mendukung penuh arsitektur Apple Silicon dan fitur *Keyboard Shortcuts* (`⌘1` - `⌘9`, `⌘F`) untuk navigasi super cepat.

---

## Documentation & Links

*   **[DOCUMENTATION.md](./DOCUMENTATION.md)** - Technical details and architecture guide.
*   **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Guidelines for contributing to the project.
*   **[SECURITY.md](./SECURITY.md)** - Vulnerability reporting and security policy.

## License

This project is licensed under the MIT License - see the **[LICENSE](./LICENSE)** file for details.

<div align="center">
  <br>
  <sub>Built by Ade Ramdani. Native Swift. Zero Third-Party Dependencies.</sub>
</div>
