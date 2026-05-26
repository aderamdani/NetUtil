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
    let system      = SystemMonitor()
    
    @Published var externalIP: String = "Checking..."
    @Published var isVPNActive: Bool = false
    
    func refreshGlobalStatus() {
        checkVPN()
        fetchExternalIP()
    }
    
    private func checkVPN() {
        // Simple check: looking for 'utun' interfaces which are typical for VPNs on macOS
        isVPNActive = interfaces.interfaces.contains { $0.name.starts(with: "utun") && $0.isUp }
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
