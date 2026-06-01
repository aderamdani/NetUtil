import Foundation
import Observation
import Combine
import SystemConfiguration
import CoreWLAN

@MainActor
@Observable
final class ToolStore {
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
    let subnetScan  = SubnetScanViewModel()
    let system      = SystemMonitor()
    let bandwidth   = BandwidthMonitor()
    let topApps     = TopProcessesViewModel()
    let speedTest   = SpeedTestViewModel()
    let statistics  = TrafficStatistics()
    let sslWatchlist  = SSLWatchlist()
    let favorites     = FavoritesManager()
    let sessionHistory = SessionHistory()

    private(set) var externalIP: String = "Checking..."
    private(set) var isVPNActive: Bool = false
    private(set) var primaryLocalIP: String = "—"
    private(set) var currentConnectionName: String = "Unknown"
    private(set) var primaryInterface: NetworkInterface?

    var menuBarCurrentRTT: Double = -1.0
    private(set) var healthIcon: String = "checkmark.shield.fill"
    private(set) var healthColor: String = "green"
    private(set) var healthMessage: String = "All Systems Normal"

    init() {
        bandwidth.onAggregateDelta = { [weak self] rx, tx in
            self?.statistics.record(rxDelta: rx, txDelta: tx)
        }
        bandwidth.start()
        wireSessionLogging()
        refreshGlobalStatus()
    }

    private func wireSessionLogging() {
        ping.onSessionComplete = { [weak self] record in self?.sessionHistory.log(record) }
        traceroute.onSessionComplete = { [weak self] record in self?.sessionHistory.log(record) }
        portScan.onSessionComplete = { [weak self] record in self?.sessionHistory.log(record) }
    }

    /// Refreshes expensive cached properties.
    func refreshGlobalStatus() {
        updatePrimaryInterface()
        checkVPN()
        updateConnectionName()
        fetchExternalIP()
        updateHealthStatus()
    }

    private func updateHealthStatus() {
        let criticalSSL = sslWatchlist.items.filter { $0.status == .critical || $0.status == .expired }
        let warningSSL  = sslWatchlist.items.filter { $0.status == .warning }
        let pingLoss    = ping.stats.loss
        let wifiRSSI    = wifi.info?.rssi ?? 0

        if !criticalSSL.isEmpty {
            let n = criticalSSL.count
            healthIcon = "exclamationmark.triangle.fill"
            healthColor = "red"
            healthMessage = "\(n) SSL cert\(n == 1 ? "" : "s") critical or expired"
        } else if !ping.results.isEmpty && pingLoss > 5 && !ping.currentHost.isEmpty {
            healthIcon = "exclamationmark.triangle.fill"
            healthColor = "orange"
            healthMessage = "Ping: \(String(format: "%.0f", pingLoss))% packet loss to \(ping.currentHost)"
        } else if wifiRSSI < -70 && wifiRSSI != 0 {
            healthIcon = "exclamationmark.triangle.fill"
            healthColor = "orange"
            healthMessage = "Wi-Fi signal weak: \(wifiRSSI) dBm"
        } else if !warningSSL.isEmpty {
            let n = warningSSL.count
            healthIcon = "exclamationmark.triangle.fill"
            healthColor = "orange"
            healthMessage = "\(n) SSL cert\(n == 1 ? "" : "s") expiring soon"
        } else {
            healthIcon = "checkmark.shield.fill"
            healthColor = "green"
            healthMessage = "All Systems Normal"
        }
    }

    private func updatePrimaryInterface() {
        primaryInterface = interfaces.interfaces.first {
            $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty &&
            !$0.name.hasPrefix("utun") && !$0.name.hasPrefix("ipsec") &&
            !$0.name.hasPrefix("awdl") && !$0.name.hasPrefix("llw") &&
            !$0.name.hasPrefix("bridge") && !$0.name.hasPrefix("tun") &&
            !$0.name.hasPrefix("tap")
        }
        primaryLocalIP = primaryInterface?.ipv4.first ?? "—"
    }

    private func updateConnectionName() {
        if let iface = primaryInterface {
            if iface.ifType == 161 {
                if let ssid = Self.currentSSID(), !ssid.isEmpty {
                    currentConnectionName = ssid
                    return
                }
                currentConnectionName = "Wi-Fi"
                return
            }
            if let localized = Self.localizedInterfaceName(for: iface.name) {
                currentConnectionName = localized
                return
            }
            currentConnectionName = iface.typeName
            return
        }
        currentConnectionName = "Unknown"
    }

    private static func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
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

    private func checkVPN() {
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
                    self.externalIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                self.externalIP = "Unknown"
            }
        }
    }
}
