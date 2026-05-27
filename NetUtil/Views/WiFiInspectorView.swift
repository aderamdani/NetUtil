import SwiftUI
import CoreWLAN
import Combine

struct WiFiInspectorView: View {
    @ObservedObject var vm: WiFiInspectorViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let info = vm.info {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader(info)
                        
                        // 3. STATS BAR
                        statsBar(info)
                        
                        // 4. SIGNAL & DETAILS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SIGNAL STABILITY")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            
                            if vm.rssiHistory.count > 1 {
                                rssiSparkline
                                    .padding(20)
                                    .background(Color(.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NETWORK PARAMETERS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            
                            detailGrid(info)
                        }
                    } else {
                        noWiFiState
                    }
                }
            }
        }
        .padding(32)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) {
            wifiLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Static Info (Visual Anchor)
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .foregroundColor(.accentColor)
                Text(vm.info?.ssid ?? "Searching...")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 250, alignment: .leading)

            // 2. Variable Settings (Centered)
            HStack(spacing: 8) {
                Text("Update:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 3. Action Group
            Button(action: { vm.refresh() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Wi-Fi Analytics Guide")
        }
    }
    
    private func interpretationHeader(_ info: WiFiInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let rssi = info.rssi ?? -100
            let (status, desc, icon, color): (String, String, String, Color) = {
                if rssi >= -60 { return ("Excellent Signal", "Strong association with very low interference.", "wifi", .green) }
                if rssi >= -75 { return ("Good Signal", "Stable connection, suitable for most tasks.", "wifi", .orange) }
                return ("Weak Signal", "Connection may be unstable or slow.", "wifi.exclamationmark", .red)
            }()
            
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status).font(.headline)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func statsBar(_ info: WiFiInfo) -> some View {
        HStack(spacing: 12) {
            if let rssi = info.rssi {
                StatCard(title: "SIGNAL (RSSI)", value: "\(rssi)", unit: "dBm", icon: "waveform", color: signalColor(rssi))
            }
            if let noise = info.noise, let rssi = info.rssi {
                StatCard(title: "SNR", value: "\(rssi - noise)", unit: "dB", icon: "shield.checkerboard", color: snrColor(rssi - noise))
            }
            StatCard(title: "BAND", value: info.band ?? "Unknown", icon: "antenna.radiowaves.left.and.right")
            Spacer()
        }
    }

    private var rssiSparkline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RSSI HISTORY").font(.system(size: 9, weight: .black)).foregroundColor(.secondary)
                Spacer()
                Text("\(vm.rssiHistory.count) samples").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                let history = vm.rssiHistory
                let minVal = Double(history.min() ?? -100)
                let maxVal = Double(history.max() ?? -30)
                let range = max(maxVal - minVal, 10)
                let w = geo.size.width
                let h = geo.size.height
                let slotW = w / CGFloat(max(history.count - 1, 1))

                Path { path in
                    for (i, rssi) in history.enumerated() {
                        let x = CGFloat(i) * slotW
                        let ratio = CGFloat((Double(rssi) - minVal) / range)
                        let y = h - (ratio * (h - 4)) - 2
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(signalColor(history.last), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = history.last {
                    let x = w
                    let ratio = CGFloat((Double(last) - minVal) / range)
                    let y = h - (ratio * (h - 4)) - 2
                    Circle()
                        .fill(signalColor(last))
                        .frame(width: 8, height: 8)
                        .position(x: x - 4, y: y)
                }
            }
            .frame(height: 60)
        }
    }

    private func detailGrid(_ info: WiFiInfo) -> some View {
        let channelStr = [info.channel.map { "\($0)" }, info.band]
            .compactMap { $0 }.joined(separator: " · ")
        let items: [(String, String?, String)] = [
            ("Channel",      channelStr.isEmpty ? nil : channelStr, "number.square"),
            ("Security",     info.security, "lock.shield"),
            ("TX Rate",      info.transmitRate.map { String(format: "%.0f Mbps", $0) }, "bolt.horizontal"),
            ("Country",      info.countryCode, "globe"),
            ("Interface",    info.interfaceName, "network"),
            ("MAC Address",  info.hardwareAddress, "barcode"),
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon in
                if let value {
                    WiFiDetailCard(label: label, value: value, icon: icon)
                }
            }
        }
    }

    private var noWiFiState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "wifi.slash").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("No Wi-Fi Connection")
                .font(.title3.bold())
            Text("Please ensure Wi-Fi is enabled and connected to a network.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func signalColor(_ rssi: Int?) -> Color {
        guard let r = rssi else { return .secondary }
        if r >= -60 { return .green }
        if r >= -75 { return .orange }
        return .red
    }

    private func snrColor(_ snr: Int) -> Color {
        if snr >= 25 { return .green }
        if snr >= 15 { return .orange }
        return .red
    }
    
    private var wifiLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wi-Fi Analytics Guide").font(.title2.bold())
                    Text("Learn how to audit wireless performance.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "Signal Strength (RSSI)", icon: "waveform") {
                        Text("RSSI measures how well your device can hear a signal from a router. -30 dBm is perfect, while -80 dBm is unusable.")
                    }
                    
                    GuideSection(title: "Noise & SNR", icon: "shield.checkerboard") {
                        Text("SNR (Signal-to-Noise Ratio) tells you how much stronger the signal is compared to background noise. Aim for ≥ 25 dB for a stable connection.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct WiFiDetailCard: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.accentColor).font(.system(size: 10))
                Text(label.uppercased()).font(.system(size: 9, weight: .black)).foregroundColor(.secondary).kerning(0.5)
            }
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).lineLimit(1).textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
}

struct WiFiInfo {
    var ssid: String?
    var bssid: String?
    var rssi: Int?
    var noise: Int?
    var channel: Int?
    var band: String?
    var security: String?
    var transmitRate: Double?
    var countryCode: String?
    var interfaceName: String?
    var hardwareAddress: String?
}

@MainActor
class WiFiInspectorViewModel: ObservableObject {
    @Published var info: WiFiInfo?
    @Published var rssiHistory: [Int] = []
    @Published var lastUpdated = Date()
    
    private var timer: Timer?
    private let client = CWWiFiClient.shared()
    private static let rssiHistoryLimit = 100

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let iface = client.interface() else { 
            self.info = nil
            return 
        }
        
        let rssi = iface.rssiValue()
        let noise = iface.noiseMeasurement()
        
        // Channel/Band info
        var channelNum: Int? = nil
        var bandStr: String? = nil
        if let chan = iface.wlanChannel() {
            channelNum = chan.channelNumber
            switch chan.channelBand {
            case .band2GHz: bandStr = "2.4 GHz"
            case .band5GHz: bandStr = "5 GHz"
            case .band6GHz: bandStr = "6 GHz"
            default: bandStr = "Unknown"
            }
        }
        
        // Security info
        let security: String = switch iface.security() {
        case .none: "Open"
        case .WEP: "WEP"
        case .wpaPersonal: "WPA Personal"
        case .wpa2Personal: "WPA2 Personal"
        case .wpaEnterprise: "WPA Enterprise"
        case .wpa2Enterprise: "WPA2 Enterprise"
        case .dynamicWEP: "Dynamic WEP"
        case .wpa3Personal: "WPA3 Personal"
        case .wpa3Enterprise: "WPA3 Enterprise"
        default: "Unknown"
        }

        self.lastUpdated = Date()
        self.info = WiFiInfo(
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            rssi: rssi,
            noise: noise,
            channel: channelNum,
            band: bandStr,
            security: security,
            transmitRate: iface.transmitRate(),
            countryCode: iface.countryCode(),
            interfaceName: iface.interfaceName,
            hardwareAddress: iface.hardwareAddress()
        )

        if rssi != 0 {
            rssiHistory.append(rssi)
            if rssiHistory.count > Self.rssiHistoryLimit {
                rssiHistory.removeFirst()
            }
        }
    }
}
