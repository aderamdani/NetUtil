import Foundation
import SwiftUI
import CoreWLAN
import Observation

struct SignalSample: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let rssi: Int
}

@MainActor
@Observable
final class WiFiInspectorViewModel {
    private(set) var info: WiFiInfo?
    private(set) var rssiSamples: [SignalSample] = []
    private(set) var lastUpdated = Date()
    
    private var timer: Timer?
    private let client = CWWiFiClient.shared()
    private static let rssiSamplesLimit = 100

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
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
            rssiSamples.append(SignalSample(rssi: rssi))
            if rssiSamples.count > Self.rssiSamplesLimit { rssiSamples.removeFirst() }
        }
    }
}
