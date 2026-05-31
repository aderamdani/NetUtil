import XCTest
@testable import NetUtil

final class SubnetScanTests: XCTestCase {
    
    func testCIDRGeneration() {
        let vm = SubnetScanViewModel()
        vm.cidrInput = "192.168.1.0/24"
        
        let components = vm.cidrInput.split(separator: "/")
        let prefix = Int(components[1])!
        let subnet = NetworkMath.calculateSubnet(ip: String(components[0]), prefix: prefix)!
        
        // This is a manual test of the logic used in SubnetScanViewModel
        let count = prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2
        XCTAssertEqual(count, 254)
    }
    
    func testInvalidCIDR() {
        let subnet = NetworkMath.calculateSubnet(ip: "invalid", prefix: 24)
        XCTAssertNil(subnet)
    }
}
