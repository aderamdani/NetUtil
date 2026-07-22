import Foundation
import Observation
import SystemConfiguration
import CoreWLAN
import AppKit

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
    let speedTest   = SpeedTestViewModel()
    let netQuality  = NetQualityViewModel()
    let wakeOnLAN   = WakeOnLanViewModel()
    let doctor      = NetworkDoctorViewModel()
    let pathMTU     = PathMTUViewModel()
    let neighbors   = NeighborsViewModel()
    let connections = ConnectionsViewModel()
    let portListener = PortListenerViewModel()
    let ipGeolocation = IPGeolocationViewModel()
    let dnsResolver   = DNSResolverViewModel()
    let statistics  = TrafficStatistics()
    let sslWatchlist  = SSLWatchlist()
    let favorites     = FavoritesManager()
    let sessionHistory = SessionHistory()

    private(set) var externalIP: String = "Checking..."
    private(set) var externalIPGeo: IPGeoResult?
    private(set) var isVPNActive: Bool = false
    private(set) var primaryLocalIP: String = "—"
    private(set) var currentConnectionName: String = "Unknown"
    private(set) var primaryInterface: NetworkInterface?

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
        dnsResolver.start()
        observeActivationPolicy()
        observeOcclusion()
    }

    /// Wi-Fi is view-scoped (only polls while Dashboard/Wi-Fi Inspector is
    /// shown), not an app-lifetime poller — remember whether it was actually
    /// running so pause/resume doesn't start it for a view that isn't visible.
    private var wifiWasActive = false

    /// Stops all app-lifetime pollers to save battery when no window is visible.
    func pauseMonitoring() {
        bandwidth.stop()
        system.stop()
        statistics.stop()
        interfaces.stop()
        wifiWasActive = wifi.isRunning
        wifi.stop()
    }

    /// Restarts pollers. Pass `reduced: true` for accessory/menu-bar mode.
    func resumeMonitoring(reduced: Bool = false) {
        if reduced {
            bandwidth.backgroundInterval = 10.0
            bandwidth.start()
            system.start(interval: 10)
            statistics.start()
            interfaces.start(interval: 15)
        } else {
            bandwidth.backgroundInterval = 5.0
            bandwidth.start()
            system.start()
            statistics.start()
            interfaces.start()
            if wifiWasActive { wifi.start() }
        }
    }

    private func observeActivationPolicy() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMonitoringState),
            name: .init("netutil.activationPolicyChanged"),
            object: nil
        )
    }

    /// Also drop to reduced cadence when every window is minimized or fully
    /// covered — activation policy alone only catches close-to-menu-bar.
    private func observeOcclusion() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMonitoringState),
            name: NSApplication.didChangeOcclusionStateNotification,
            object: nil
        )
    }

    @objc private func updateMonitoringState() {
        pauseMonitoring()
        let occluded = !NSApp.occlusionState.contains(.visible)
        resumeMonitoring(reduced: occluded || NSApp.activationPolicy() != .regular)
    }

    private func wireSessionLogging() {
        let log: (SessionRecord) -> Void = { [weak self] record in self?.sessionHistory.log(record) }
        ping.onSessionComplete        = log
        traceroute.onSessionComplete  = log
        portScan.onSessionComplete    = log
        dns.onSessionComplete         = log
        whois.onSessionComplete       = log
        ssl.onSessionComplete         = log
        httpLatency.onSessionComplete = log
        speedTest.onSessionComplete   = log
        netQuality.onSessionComplete  = log
        doctor.onSessionComplete      = log
        pathMTU.onSessionComplete     = log
        ipGeolocation.onSessionComplete = log
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
        primaryInterface = NetworkInterface.primary(in: interfaces.interfaces)
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
    
    /// Fetches this Mac's public IP and its geolocation in a single call —
    /// used for both the header's "Public" chip and the Dashboard's IP
    /// Geolocation card (which seeds from `externalIPGeo` instead of making
    /// its own request).
    private func fetchExternalIP() {
        Task {
            guard let url = URL(string: "https://ipinfo.io/json") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let geo = IPGeoResult.parse(data) {
                    self.externalIP = geo.ip
                    self.externalIPGeo = geo
                } else {
                    self.externalIP = "Unknown"
                }
            } catch {
                self.externalIP = "Unknown"
            }
        }
    }
}
