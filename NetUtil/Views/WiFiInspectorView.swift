import SwiftUI
import CoreWLAN
import Combine

struct WiFiInspectorView: View {
    @StateObject private var vm = WiFiInspectorViewModel()

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
                            .foregroundColor(.primary)
                        Text("dB SNR").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func detailGrid(_ info: WiFiInfo) -> some View {
        let items: [(String, String?)] = [
            ("Channel",      info.channel.map { "\($0)" }),
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
        if r >= -50 { return "wifi" }
        if r >= -70 { return "wifi" }
        return "wifi"
    }

    private func signalColor(_ rssi: Int?) -> Color {
        guard let r = rssi else { return .secondary }
        if r >= -50 { return .green }
        if r >= -70 { return .orange }
        return .red
    }
}

struct WiFiInfo {
    let ssid: String?
    let bssid: String?
    let rssi: Int?
    let noise: Int?
    let channel: Int?
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

    private var timer: Timer?

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

        info = WiFiInfo(
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            rssi: iface.rssiValue() == 0 ? nil : iface.rssiValue(),
            noise: iface.noiseMeasurement() == 0 ? nil : iface.noiseMeasurement(),
            channel: iface.wlanChannel()?.channelNumber,
            security: secLabel,
            countryCode: iface.countryCode(),
            transmitRate: iface.transmitRate() == 0 ? nil : iface.transmitRate(),
            hardwareAddress: iface.hardwareAddress(),
            interfaceName: iface.interfaceName
        )
    }
}
