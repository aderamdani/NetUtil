import SwiftUI
import CoreWLAN
import Combine

struct WiFiInspectorView: View {
    @ObservedObject var vm: WiFiInspectorViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if let info = vm.info {
                        interpretationHeader(info)
                        statsBar(info).padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            if vm.rssiHistory.count > 1 {
                                sectionHeader("Signal Stability")
                                rssiSparkline
                                    .padding(16)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Network Parameters")
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
        .sheet(isPresented: $showLearningGuide) { wifiLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi").foregroundColor(.accentColor)
                Text(vm.info?.ssid ?? "Searching...").font(.headline)
            }
            .frame(width: 250, alignment: .leading)

            HStack(spacing: 8) {
                Text("Updated").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { vm.refresh() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }.font(.system(size: 13, weight: .medium))
            }.buttonStyle(.bordered)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private func interpretationHeader(_ info: WiFiInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let rssi = info.rssi ?? -100
            let (status, desc, icon, color): (String, String, String, Color) = {
                if rssi >= -60 { return ("Excellent Signal", "Strong association with very low interference.", "wifi", .green) }
                if rssi >= -75 { return ("Good Signal", "Stable connection, suitable for most tasks.", "wifi", .orange) }
                return ("Weak Signal", "Connection may be unstable or slow.", "wifi.exclamationmark", .red)
            }()
            
            Image(systemName: icon).font(.title2).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(status).font(.headline)
                Text(desc).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func statsBar(_ info: WiFiInfo) -> some View {
        HStack(spacing: 12) {
            if let rssi = info.rssi { StatCard(title: "Signal (RSSI)", value: "\(rssi)", unit: "dBm", icon: "waveform", color: signalColor(rssi)) }
            if let noise = info.noise, let rssi = info.rssi { StatCard(title: "SNR", value: "\(rssi - noise)", unit: "dB", icon: "shield.checkerboard", color: snrColor(rssi - noise)) }
            StatCard(title: "Band", value: info.band ?? "Unknown", icon: "antenna.radiowaves.left.and.right")
            Spacer()
        }
    }

    private var rssiSparkline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("\(vm.rssiHistory.count) samples").font(.system(size: 11)).foregroundColor(.secondary)
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
                .stroke(signalColor(history.last), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let last = history.last {
                    let x = w
                    let ratio = CGFloat((Double(last) - minVal) / range)
                    let y = h - (ratio * (h - 4)) - 2
                    Circle().fill(signalColor(last)).frame(width: 6, height: 6).position(x: x - 3, y: y)
                }
            }
            .frame(height: 50)
        }
    }

    private func detailGrid(_ info: WiFiInfo) -> some View {
        let channelStr = [info.channel.map { "\($0)" }, info.band].compactMap { $0 }.joined(separator: " · ")
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
                if let value { WiFiDetailCard(label: label, value: value, icon: icon) }
            }
        }
    }

    private var noWiFiState: some View {
        VStack { Spacer(); Text("No Wi-Fi Connection").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack { Text("Wi-Fi Analytics Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "Signal Strength (RSSI)", icon: "waveform") { Text("RSSI measures how well your device can hear a signal.") }
                }.padding(24)
            }
        }.frame(width: 500, height: 600)
    }
}

struct WiFiDetailCard: View {
    let label: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.weight(.medium)).foregroundColor(.secondary)
            Text(value).font(.system(.callout, design: .monospaced)).lineLimit(1).textSelection(.enabled)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
        
        let security: String = switch iface.security() {
        case .none: "Open"; case .WEP: "WEP"; case .wpaPersonal: "WPA Personal"; case .wpa2Personal: "WPA2 Personal"
        case .wpaEnterprise: "WPA Enterprise"; case .wpa2Enterprise: "WPA2 Enterprise"; case .dynamicWEP: "Dynamic WEP"
        case .wpa3Personal: "WPA3 Personal"; case .wpa3Enterprise: "WPA3 Enterprise"; default: "Unknown"
        }

        self.lastUpdated = Date()
        self.info = WiFiInfo(
            ssid: iface.ssid(), bssid: iface.bssid(), rssi: rssi, noise: noise, channel: channelNum, band: bandStr,
            security: security, transmitRate: iface.transmitRate(), countryCode: iface.countryCode(),
            interfaceName: iface.interfaceName, hardwareAddress: iface.hardwareAddress()
        )

        if rssi != 0 {
            rssiHistory.append(rssi)
            if rssiHistory.count > Self.rssiHistoryLimit { rssiHistory.removeFirst() }
        }
    }
}
