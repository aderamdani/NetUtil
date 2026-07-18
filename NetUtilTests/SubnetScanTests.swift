import XCTest
@testable import NetUtil

final class SubnetScanTests: XCTestCase {
    
    @MainActor
    func testCIDRGeneration() {
        let vm = SubnetScanViewModel()
        vm.cidrInput = "192.168.1.0/24"
        
        let components = vm.cidrInput.split(separator: "/")
        let prefix = Int(components[1])!
        _ = NetworkMath.calculateSubnet(ip: String(components[0]), prefix: prefix)!
        
        // This is a manual test of the logic used in SubnetScanViewModel
        let count = prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2
        XCTAssertEqual(count, 254)
    }
    
    func testInvalidCIDR() {
        let subnet = NetworkMath.calculateSubnet(ip: "invalid", prefix: 24)
        XCTAssertNil(subnet)
    }

    /// REGRESSION: /31 and /32 produced a host count of 0 and the `1...0`
    /// range in generateIPs crashed. startScan must now reject them cleanly.
    @MainActor
    func testHostlessPrefixIsRejectedWithoutCrash() async {
        let vm = SubnetScanViewModel()
        for cidr in ["10.0.0.0/31", "10.0.0.1/32"] {
            vm.cidrInput = cidr
            await vm.startScan()
            XCTAssertFalse(vm.isScanning, "scan must not start for \(cidr)")
            XCTAssertNotNil(vm.errorMessage, "expected validation error for \(cidr)")
        }
    }

    @MainActor
    func testTooWidePrefixIsRejected() async {
        let vm = SubnetScanViewModel()
        vm.cidrInput = "10.0.0.0/8"
        await vm.startScan()
        XCTAssertFalse(vm.isScanning)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.results.isEmpty)
    }

    @MainActor
    func testMalformedCIDRSetsError() async {
        let vm = SubnetScanViewModel()
        for cidr in ["not-a-cidr", "10.0.0.0", "10.0.0.0/x", "10.0.0.0/33"] {
            vm.cidrInput = cidr
            await vm.startScan()
            XCTAssertNotNil(vm.errorMessage, "expected error for \(cidr)")
        }
    }
}
