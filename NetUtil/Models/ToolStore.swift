import Foundation
import Combine
import SystemConfiguration

@MainActor
class ToolStore: ObservableObject {
    let ping        = PingViewModel()
    let traceroute  = TracerouteViewModel()
    let portScan    = PortScanViewModel()
    let multiPing   = MultiPingViewModel()
    let dns         = DNSViewModel()
    let httpLatency = HTTPLatencyViewModel()
    let ssl         = SSLInspectorViewModel()
    let whois       = WhoisViewModel()
    let wifi        = WiFiInspectorViewModel()
    let interfaces  = NetworkInterfaceViewModel()
    let subnet      = SubnetViewModel()
    let system      = SystemMonitor()
    let bandwidth   = BandwidthMonitor()
    let topApps     = TopProcessesViewModel()
    let speedTest   = SpeedTestViewModel()
    let statistics  = TrafficStatistics()
    
    @Published var externalIP: String = "Checking..."
    @Published var isVPNActive: Bool = false

    init() {
        bandwidth.onAggregateDelta = { [weak self] rx, tx in
            self?.statistics.record(rxDelta: rx, txDelta: tx)
        }
        bandwidth.start()
    }

    /// Primary LAN/Wi-Fi interface — excludes tunnels, AirDrop, tethering.
    var primaryInterface: NetworkInterface? {
        interfaces.interfaces.first {
            $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty &&
            !$0.name.hasPrefix("utun") && !$0.name.hasPrefix("ipsec") &&
            !$0.name.hasPrefix("awdl") && !$0.name.hasPrefix("llw") &&
            !$0.name.hasPrefix("bridge") && !$0.name.hasPrefix("tun") &&
            !$0.name.hasPrefix("tap")
        }
    }

    var primaryLocalIP: String { primaryInterface?.ipv4.first ?? "—" }

    /// User-facing connection label.
    /// - Wi-Fi: returns SSID if connected, falls back to "Wi-Fi".
    /// - Ethernet / others: returns localized System Settings display name
    ///   (e.g. "USB 10/100/1000 LAN") via SystemConfiguration.
    var currentConnectionName: String {
        if let iface = primaryInterface {
            if iface.ifType == 161 {
                if let ssid = wifi.info?.ssid, !ssid.isEmpty { return ssid }
                return "Wi-Fi"
            }
            if let localized = Self.localizedInterfaceName(for: iface.name) {
                return localized
            }
            return iface.typeName
        }
        return "Unknown"
    }

    private static func localizedInterfaceName(for bsdName: String) -> String? {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return nil }
        for iface in interfaces {
            if let name = SCNetworkInterfaceGetBSDName(iface) as String?, name == bsdName {
                return SCNetworkInterfaceGetLocalizedDisplayName(iface) as String?
            }
        }
        return nil
    }

    func refreshGlobalStatus() {
        checkVPN()
        fetchExternalIP()
    }

    private func checkVPN() {
        // utun with an IPv4 address = user VPN (WireGuard, OpenVPN, etc.)
        // utun without IPv4 = Apple internal (iCloud Private Relay, Network Extensions) — not a VPN
        isVPNActive = interfaces.interfaces.contains {
            $0.isUp &&
            ($0.name.hasPrefix("utun") || $0.name.hasPrefix("ipsec")) &&
            !$0.ipv4.isEmpty
        }
    }
    
    private func fetchExternalIP() {
        Task {
            guard let url = URL(string: "https://api.ipify.org") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ip = String(data: data, encoding: .utf8) {
                    self.externalIP = ip
                }
            } catch {
                self.externalIP = "Unknown"
            }
        }
    }
}
