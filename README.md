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
*   **Advanced Ping**: Beyond ICMP. Visualizes latency history with GPU-accelerated charts, analyzes jitter, and provides GitHub-style health strips.
*   **Multi-Ping**: Monitor multiple server nodes simultaneously with real-time sparklines, bulk import, and consolidated PDF reporting.
*   **Traceroute**: Comprehensive hop-by-hop path discovery with a visual timeline, MapKit geographic routing, and automatic bottleneck detection.
*   **Port Scanner**: High-speed, parallelized TCP reachability auditing using a modern mini-card grid system.
*   **HTTP Latency**: Millisecond-precise breakdown of web requests (DNS, TCP, TLS, TTFB) using native `URLSessionTaskMetrics`.
*   **Subnet Scanner**: Concurrent ping sweep across entire subnets with host discovery, ARP enrichment, hostname resolution, MAC address detection, and CSV/PDF export.
*   **DNS Comparison**: Parallel DNS resolution across multiple resolvers (System, Google, Cloudflare, Quad9) with query-time comparison.
*   **SSL Watchlist**: Automated tracking of certificate lifecycles with local notification alerts for near-expiry domains.
*   **Bulk Host Import**: Import or paste host lists into Multi-Ping with duplicate detection.
*   **Gateway Actions**: Direct diagnostic triggers (Ping/Traceroute) integrated into network gateway analysis.
*   **Speed Test & Statistics**: Nperf-style four-tier speed tests and daily data usage tracking.

---

### Native Mac Polish

NetUtil is engineered with an absolute zero-tolerance policy for generic "AI Slop" or web-style designs. 

*   **100% Symmetrical Harmony**: Every single diagnostic tool shares an identical visual structure—Fixed Top Headers, Interpretation Mood Bars, and unified action placements.
*   **Accessibility First**: Fully audited for VoiceOver inclusivity. Every interactive element has descriptive labels, dynamic values, and logical grouping.
*   **GPU-Accelerated Charts**: Real-time visualizations utilize `.drawingGroup()` for butter-smooth rendering even during high-frequency monitoring.
*   **True Material Vibrancy**: UI panels react dynamically to your macOS wallpaper using native `.regularMaterial`.
*   **Keyboard First**: Navigate seamlessly across all tools using `⌘1` through `⌘9` and utilize Global Search (`⌘F`) to instantly recall historical targets.

---

### Technical Excellence

*   **Swift 6 & SwiftUI**: Built exclusively for macOS 15+ ensuring maximum efficiency and minimal battery footprint.
*   **Zero Dependencies**: No third-party frameworks or bloated SDKs. Pure Apple APIs (`Network`, `CoreWLAN`, `MapKit`).
*   **Native Testing**: Robust test suite integrated directly into Xcode, covering core network logic and parsers.
*   **Apple Silicon Native**: Hardware-accelerated for M1/M2/M3/M4 chips.
*   **Enterprise Reporting**: Generate branded, timestamped PDF and CSV reports for professional auditing.

---

### Installation

1.  Visit the **[Releases](https://github.com/aderamdani/NetUtil/releases)** page.
2.  Download the latest `NetUtil-vX.X.X.dmg`.
3.  Open the DMG and drag **NetUtil** to your `Applications` folder.

---

## Bahasa Indonesia

**NetUtil** adalah utilitas macOS berperforma tinggi yang dirakit secara manual (*handcrafted*) untuk para *network engineer*. Menggabungkan kekuatan alat CLI klasik dengan antarmuka SwiftUI yang simetris dan modern. Dirancang dengan prinsip "Apple Artisan", NetUtil menghadirkan diagnosa jaringan tanpa kompromi, mengedepankan analitik yang padat data dan bebas dari desain *web* generik.

### Fitur Utama
*   **Dashboard Bento**: Pusat kendali dengan *sparkline* hidup, indikator aktivitas yang berdenyut, serta pantauan CPU/RAM secara *real-time*.
*   **Aksesibilitas Penuh**: Dukungan VoiceOver lengkap di seluruh aplikasi untuk pengguna dengan keterbatasan penglihatan.
*   **Advanced Ping & Multi-Ping**: Visualisasi riwayat latensi yang diakselerasi GPU, analisis *jitter*, pemantauan banyak *server* sekaligus, dan impor host massal (*bulk import*).
*   **Traceroute Geografis**: Deteksi *hop-by-hop* dengan Peta Rute, grafik *timeline*, dan deteksi *bottleneck* otomatis.
*   **Port & Security Audit**: Pemindai TCP berkecepatan tinggi dan inspektor sertifikat SSL/TLS mendalam dengan fitur *Watchlist* untuk pemantauan kadaluwarsa.
*   **HTTP Latency**: Analisis presisi setiap fase akses *web* (DNS, TCP, TLS, TTFB).
*   **Subnet Scanner**: Pemindaian ping serentak di seluruh subnet untuk penemuan host, pengayaan ARP, resolusi hostname, deteksi MAC address, dan ekspor CSV/PDF.
*   **DNS Comparison**: Resolusi DNS paralel lintas *resolver* (System, Google, Cloudflare, Quad9) dengan perbandingan waktu kueri.
*   **SSL Watchlist**: Pemantauan otomatis siklus hidup sertifikat dengan notifikasi lokal untuk domain yang akan kedaluwarsa.
*   **Bulk Host Import**: Impor atau tempel daftar host ke dalam Multi-Ping dengan deteksi duplikat.
*   **Gateway Actions**: Pemicu diagnostik langsung (Ping/Traceroute) yang terintegrasi ke dalam analisis gateway jaringan.
*   **Speed Test & Statistik**: Uji kecepatan jaringan komprehensif dan riwayat penggunaan data harian.

### Keunggulan Teknis
Didesain 100% menggunakan **Swift 6 & SwiftUI** tanpa *framework* pihak ketiga mana pun (*Zero Dependencies*). Mendukung penuh arsitektur Apple Silicon, akselerasi grafik GPU, dan fitur *Keyboard Shortcuts* (`⌘1` - `⌘9`, `⌘F`) untuk navigasi super cepat.

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
