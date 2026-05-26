<div align="center">
  <img src="NetUtil/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="NetUtil Logo">
  <h1>NetUtil</h1>
  <p><b>Professional Network Diagnostics Toolkit for macOS</b></p>

  [![Latest Release](https://img.shields.io/github/v/release/aderamdani/NetUtil?style=flat-square&color=007AFF)](https://github.com/aderamdani/NetUtil/releases)
  [![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey?style=flat-square&logo=apple)](https://developer.apple.com/macos/)
  [![Language](https://img.shields.io/badge/language-Swift%206-orange?style=flat-square&logo=swift)](https://swift.org)
  [![Build Status](https://img.shields.io/github/actions/workflow/status/aderamdani/NetUtil/swift.yml?style=flat-square&label=build)](https://github.com/aderamdani/NetUtil/actions)
  [![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
</div>

---

### 🌐 Select Language / Pilih Bahasa
<div align="center">
  <b><a href="#english">English</a></b> | <b><a href="#bahasa-indonesia">Bahasa Indonesia</a></b>
</div>

---

<a name="english"></a>
## 🇺🇸 English

**NetUtil** is a high-performance, native macOS utility designed for network engineers and power users. It combines classic CLI power with a modern, intuitive SwiftUI interface to help you monitor and troubleshoot network connectivity with surgical precision.

### 🌟 Key Features

#### 📡 Connectivity & Performance
*   **Advanced Ping**: Beyond just ICMP. Features real-time RTT charts, jitter analysis, distribution histograms, and audible alerts for packet loss.
*   **Multi-Ping**: Monitor multiple targets simultaneously with live stability sparklines—ideal for server farm monitoring.
*   **Traceroute**: Comprehensive hop-by-hop analysis with integrated geolocation and visual path stability tracking.
*   **HTTP Latency**: Detailed breakdown of every request phase (DNS, TCP, TLS, TTFB) using native `URLSessionTaskMetrics`.

#### 🔍 Inspection & Discovery
*   **SSL/TLS Inspector**: Full certificate chain validation, expiration countdowns, and cipher suite auditing.
*   **High-Speed Port Scanner**: Parallelized TCP scanner with customizable concurrency and port ranges.
*   **DNS & WHOIS**: Direct access to `dig` and `whois` with parsed, readable output and syntax highlighting.

#### 📊 Real-time Monitoring
*   **Bandwidth Monitor**: Live RX/TX throughput charts per interface.
*   **Wi-Fi Inspector**: Deep dive into SSID, BSSID, RSSI/SNR history, and channel congestion.
*   **Interface Explorer**: Detailed hardware state for every physical and virtual adapter.

### 🚀 Technical Excellence
*   **Native Swift & SwiftUI**: Built for macOS 15+ using Swift 6 to ensure maximum battery efficiency and UI responsiveness.
*   **Zero Dependencies**: No third-party frameworks. Clean, secure, and lightweight (8MB).
*   **Apple Silicon Native**: Optimized for M1/M2/M3/M4 architectures.
*   **CI/CD Pipeline**: Fully automated testing, DMG packaging, and GitHub Releases via GitHub Actions.

### 🛠 Installation
1.  Visit the **[Releases](https://github.com/aderamdani/NetUtil/releases)** page.
2.  Download the latest `NetUtil-vX.X.X.dmg`.
3.  Drag **NetUtil** to your `Applications` folder.
4.  *Note: On first launch, if prompted, please Right-Click -> Open to bypass Gatekeeper.*

---

<a name="bahasa-indonesia"></a>
## 🇮🇩 Bahasa Indonesia

**NetUtil** adalah utilitas macOS native berperforma tinggi yang dirancang untuk network engineer dan pengguna tingkat lanjut. Menggabungkan kekuatan alat CLI klasik dengan antarmuka SwiftUI yang modern dan intuitif untuk membantu Anda memantau dan memperbaiki koneksi jaringan dengan presisi tinggi.

### 🌟 Fitur Utama

#### 📡 Konektivitas & Performa
*   **Advanced Ping**: Lebih dari sekadar ICMP. Dilengkapi grafik latensi real-time, analisis jitter, histogram distribusi, dan peringatan suara saat terjadi paket hilang.
*   **Multi-Ping**: Pantau banyak target secara bersamaan dengan grafik sparkline stabilitas—cocok untuk pemantauan server farm.
*   **Traceroute**: Analisis rute per hop yang lengkap dengan geolokasi terintegrasi dan pelacakan stabilitas jalur visual.
*   **HTTP Latency**: Breakdown detail setiap fase permintaan (DNS, TCP, TLS, TTFB) menggunakan `URLSessionTaskMetrics` bawaan.

#### 🔍 Inspeksi & Discovery
*   **SSL/TLS Inspector**: Validasi rantai sertifikat lengkap, hitung mundur masa berlaku, dan audit cipher suite.
*   **High-Speed Port Scanner**: Pemindai TCP paralel dengan kontrol konkurensi dan rentang port yang dapat disesuaikan.
*   **DNS & WHOIS**: Akses langsung ke `dig` dan `whois` dengan output yang terurai rapi dan sintaks yang jelas.

#### 📊 Pemantauan Real-time
*   **Bandwidth Monitor**: Grafik throughput RX/TX langsung untuk setiap antarmuka.
*   **Wi-Fi Inspector**: Analisis mendalam SSID, BSSID, riwayat RSSI/SNR, dan kemacetan saluran.
*   **Interface Explorer**: Status perangkat keras detail untuk setiap adapter fisik maupun virtual.

### 🚀 Keunggulan Teknis
*   **Native Swift & SwiftUI**: Dibangun untuk macOS 15+ menggunakan Swift 6 untuk menjamin efisiensi baterai dan responsivitas UI yang maksimal.
*   **Tanpa Dependensi**: Tanpa framework pihak ketiga. Bersih, aman, dan ringan (8MB).
*   **Apple Silicon Native**: Dioptimalkan untuk arsitektur M1/M2/M3/M4.
*   **CI/CD Pipeline**: Pengujian otomatis, pengemasan DMG, dan Rilis GitHub melalui GitHub Actions.

### 🛠 Instalasi
1.  Kunjungi halaman **[Releases](https://github.com/aderamdani/NetUtil/releases)**.
2.  Unduh file `NetUtil-vX.X.X.dmg` terbaru.
3.  Tarik **NetUtil** ke folder `Applications` Anda.
4.  *Catatan: Pada peluncuran pertama, jika muncul peringatan, silakan Klik Kanan -> Open untuk melewati Gatekeeper.*

---

## 📄 Documentation
For advanced technical details and development guides, please refer to **[DOCUMENTATION.md](./DOCUMENTATION.md)**.

## ✍️ Author
**Ade Ramdani** - [GitHub](https://github.com/aderamdani)

---
<div align="center">
  <sub>Built with ❤️ using SwiftUI. Zero Third-Party Dependencies.</sub>
</div>
