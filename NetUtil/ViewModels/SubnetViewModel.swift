import Foundation
import Combine

@MainActor
class SubnetViewModel: ObservableObject {
    @Published var ipAddress: String = "192.168.1.1"
    @Published var prefix: Int = 24
    @Published var result: SubnetResult?
    
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
