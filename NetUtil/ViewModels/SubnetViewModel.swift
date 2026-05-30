import Foundation
import Combine
import Observation

@Observable
@MainActor
final class SubnetViewModel {
    var ipAddress: String = "192.168.1.1"
    var prefix: Int = 24
    private(set) var result: SubnetResult?
    
    init() {
        calculate()
    }
    
    func calculate() {
        result = NetworkMath.calculateSubnet(ip: ipAddress, prefix: prefix)
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
