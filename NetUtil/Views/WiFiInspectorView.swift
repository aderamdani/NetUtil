import SwiftUI
import CoreWLAN
import Combine

struct WiFiInspectorView: View {
    @EnvironmentObject private var vm: WiFiInspectorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolbar
            if let info = vm.info {
                signalCard(info)
                detailGrid(info)
            } else {
                noWiFiState
            }
            Spacer()
        }
        .padding()
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private var toolbar: some View {
        HStack {
            Text("Updated \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
            Button { vm.refresh() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
    }

    private func signalCard(_ info: WiFiInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: signalIcon(info.rssi))
                            .font(.title)
                            .foregroundColor(signalColor(info.rssi))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.ssid ?? "Hidden Network")
                                .font(.title2.bold())
                            if let bssid = info.bssid {
                                Text(bssid)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                Spacer()
                if let rssi = info.rssi {
                    VStack(spacing: 2) {
                        Text("\(rssi)")
                            .font(.system(.title, design: .monospaced).bold())
                            .foregroundColor(signalColor(rssi))
                        Text("dBm RSSI").font(.caption2).foregroundColor(.secondary)
                    }
                    if let noise = info.noise {
                        VStack(spacing: 2) {
                            Text("\(rssi - noise)")
                                .font(.system(.title, design: .monospaced).bold())
                                .foregroundColor(snrColor(rssi - noise))
                            Text("dB SNR").font(.caption2).foregroundColor(.secondary)
                        }
                        .help("Signal-to-Noise Ratio. ≥ 25 dB = good, 15–24 dB = acceptable, < 15 dB = poor")
                    }
                }
            }

            if vm.rssiHistory.count > 1 {
                rssiSparkline
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var rssiSparkline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RSSI history (last \(vm.rssiHistory.count) samples)")
                .font(.caption2)
                .foregroundColor(.secondary)

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
                .stroke(signalColor(history.last), lineWidth: 1.5)

                if let last = history.last {
                    let x = w
                    let ratio = CGFloat((Double(last) - minVal) / range)
                    let y = h - (ratio * (h - 4)) - 2
                    Circle()
                        .fill(signalColor(last))
                        .frame(width: 6, height: 6)
                        .position(x: x - 3, y: y)
                }
            }
            .frame(height: 32)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
        }
    }

    private func detailGrid(_ info: WiFiInfo) -> some View {
        let channelStr = [info.channel.map { "\($0)" }, info.band]
            .compactMap { $0 }.joined(separator: " · ")
        let items: [(String, String?)] = [
            ("Channel",      channelStr.isEmpty ? nil : channelStr),
            ("Security",     info.security),
            ("TX Rate",      info.transmitRate.map { String(format: "%.0f Mbps", $0) }),
            ("Country",      info.countryCode),
            ("Interface",    info.interfaceName),
            ("MAC",          info.hardwareAddress),
        ]

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 10) {
            ForEach(items, id: \.0) { label, value in
                if let value {
                    detailCell(label, value)
                }
            }
        }
    }

    private func detailCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var noWiFiState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Wi-Fi connection")
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private func signalIcon(_ rssi: Int?) -> String {
        guard let r = rssi else { return "wifi.slash" }
        if r >= -60 { return "wifi" }
        if r >= -75 { return "wifi.exclamationmark" }
        return "wifi.slash"
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
}

struct WiFiInfo {
    let ssid: String?
    let bssid: String?
    let rssi: Int?
    let noise: Int?
    let channel: Int?
    let band: String?
    let security: String?
    let countryCode: String?
    let transmitRate: Double?
    let hardwareAddress: String?
    let interfaceName: String?
}

@MainActor
class WiFiInspectorViewModel: ObservableObject {
    @Published var info: WiFiInfo?
    @Published var lastUpdated: Date = Date()
    @Published var rssiHistory: [Int] = []

    private var timer: Timer?
    private static let rssiHistoryLimit = 30

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        lastUpdated = Date()
        let client = CWWiFiClient.shared()
        guard let iface = client.interface() else { info = nil; return }

        let secLabel: String
        switch iface.security() {
        case .none:           secLabel = "Open"
        case .WEP:            secLabel = "WEP"
        case .wpaPersonal:    secLabel = "WPA"
        case .wpa2Personal:   secLabel = "WPA2"
        case .wpa3Personal:   secLabel = "WPA3"
        case .wpaEnterprise:  secLabel = "WPA-EAP"
        case .wpa2Enterprise: secLabel = "WPA2-EAP"
        default:              secLabel = "Unknown"
        }

        let rssi = iface.rssiValue() == 0 ? nil : iface.rssiValue()
        let wlanChannel = iface.wlanChannel()
        let bandLabel: String?
        switch wlanChannel?.channelBand {
        case .band2GHz:  bandLabel = "2.4 GHz"
        case .band5GHz:  bandLabel = "5 GHz"
        case .band6GHz:  bandLabel = "6 GHz"
        default:         bandLabel = nil
        }
        info = WiFiInfo(
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            rssi: rssi,
            noise: iface.noiseMeasurement() == 0 ? nil : iface.noiseMeasurement(),
            channel: wlanChannel?.channelNumber,
            band: bandLabel,
            security: secLabel,
            countryCode: iface.countryCode(),
            transmitRate: iface.transmitRate() == 0 ? nil : iface.transmitRate(),
            hardwareAddress: iface.hardwareAddress(),
            interfaceName: iface.interfaceName
        )

        if let r = rssi {
            rssiHistory.append(r)
            if rssiHistory.count > Self.rssiHistoryLimit {
                rssiHistory.removeFirst()
            }
        }
    }
}
