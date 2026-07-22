import XCTest
@testable import NetUtil

@MainActor
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
    /// range in generateIPs crashed. start() must now reject them cleanly.
    @MainActor
    func testHostlessPrefixIsRejectedWithoutCrash() async {
        let vm = SubnetScanViewModel()
        for cidr in ["10.0.0.0/31", "10.0.0.1/32"] {
            vm.cidrInput = cidr
            await vm.start()
            XCTAssertFalse(vm.isRunning, "scan must not start for \(cidr)")
            XCTAssertNotNil(vm.error, "expected validation error for \(cidr)")
        }
    }

    @MainActor
    func testTooWidePrefixIsRejected() async {
        let vm = SubnetScanViewModel()
        vm.cidrInput = "10.0.0.0/8"
        await vm.start()
        XCTAssertFalse(vm.isRunning)
        XCTAssertNotNil(vm.error)
        XCTAssertTrue(vm.results.isEmpty)
    }

    @MainActor
    func testDefaultScanCIDRFromInterface() {
        let iface = NetworkInterface(name: "en0", ipv4: ["192.168.1.42"], ipv6: [],
                                     netmasks: ["255.255.255.0"], mac: nil, mtu: nil,
                                     isUp: true, isLoopback: false, ifType: 6)
        XCTAssertEqual(iface.defaultScanCIDR, "192.168.1.42/24")
    }

    func testDefaultScanCIDRNilWithoutIPOrMask() {
        let noIP = NetworkInterface(name: "en0", ipv4: [], ipv6: [], netmasks: ["255.255.255.0"],
                                    mac: nil, mtu: nil, isUp: true, isLoopback: false, ifType: 6)
        XCTAssertNil(noIP.defaultScanCIDR)
        let noMask = NetworkInterface(name: "en0", ipv4: ["192.168.1.42"], ipv6: [], netmasks: [],
                                      mac: nil, mtu: nil, isUp: true, isLoopback: false, ifType: 6)
        XCTAssertNil(noMask.defaultScanCIDR)
    }

    @MainActor
    func testApplyDetectedDefaultReplacesPlaceholderOnce() {
        let vm = SubnetScanViewModel()
        XCTAssertEqual(vm.cidrInput, "192.168.1.0/24")
        XCTAssertFalse(vm.didApplyDetectedDefault)

        let iface = NetworkInterface(name: "en0", ipv4: ["10.0.0.5"], ipv6: [],
                                     netmasks: ["255.255.0.0"], mac: nil, mtu: nil,
                                     isUp: true, isLoopback: false, ifType: 6)
        vm.applyDetectedDefault(from: iface)
        XCTAssertEqual(vm.cidrInput, "10.0.0.5/16")
        XCTAssertTrue(vm.didApplyDetectedDefault)

        // A second call — even with a different interface — must not clobber
        // whatever the user (or the app) has since put in cidrInput.
        vm.cidrInput = "172.16.0.0/24"
        let other = NetworkInterface(name: "en1", ipv4: ["192.168.50.1"], ipv6: [],
                                     netmasks: ["255.255.255.0"], mac: nil, mtu: nil,
                                     isUp: true, isLoopback: false, ifType: 6)
        vm.applyDetectedDefault(from: other)
        XCTAssertEqual(vm.cidrInput, "172.16.0.0/24")
    }

    @MainActor
    func testApplyDetectedDefaultNoOpWithoutInterface() {
        let vm = SubnetScanViewModel()
        vm.applyDetectedDefault(from: nil)
        XCTAssertEqual(vm.cidrInput, "192.168.1.0/24")
        XCTAssertFalse(vm.didApplyDetectedDefault)
    }

    func testMalformedCIDRSetsError() async {
        let vm = SubnetScanViewModel()
        for cidr in ["not-a-cidr", "10.0.0.0", "10.0.0.0/x", "10.0.0.0/33"] {
            vm.cidrInput = cidr
            await vm.start()
            XCTAssertNotNil(vm.error, "expected error for \(cidr)")
        }
    }
}
