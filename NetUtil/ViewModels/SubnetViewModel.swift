import Foundation
import Observation

@Observable
@MainActor
final class SubnetViewModel {
    var ipAddress: String = "192.168.1.1"
    var prefix: Int = 24
    private(set) var result: SubnetResult?

    /// True once the current network's own IP/prefix has replaced the
    /// placeholder — applied at most once, so it never clobbers a value the
    /// user has since typed.
    private(set) var didApplyDetectedDefault = false

    init() {
        calculate()
    }

    func calculate() {
        result = NetworkMath.calculateSubnet(ip: ipAddress, prefix: prefix)
    }

    /// Replaces the placeholder IP/prefix with the network this Mac is
    /// actually on, the first time a primary interface becomes available.
    func applyDetectedDefault(from interface: NetworkInterface?) {
        guard !didApplyDetectedDefault,
              let cidr = interface?.defaultScanCIDR else { return }
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let prefix = Int(parts[1]) else { return }
        didApplyDetectedDefault = true
        ipAddress = String(parts[0])
        self.prefix = prefix
        calculate()
    }
    
    func updateIP(_ ip: String) {
        self.ipAddress = ip
        calculate()
    }
    
    func updatePrefix(_ prefix: Int) {
        self.prefix = prefix
        calculate()
    }
}
