import Foundation
import Combine

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
    
    @Published var externalIP: String = "Checking..."
    @Published var isVPNActive: Bool = false

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
