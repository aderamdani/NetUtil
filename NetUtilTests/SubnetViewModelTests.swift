import XCTest
@testable import NetUtil

@MainActor
final class SubnetViewModelTests: XCTestCase {
    
    @MainActor
    func testSubnetCalculation() {
        let vm = SubnetViewModel()
        vm.updateIP("192.168.1.1")
        vm.updatePrefix(24)
        
        // Ensure result is not nil and basic math was applied
        XCTAssertNotNil(vm.result)
        XCTAssertEqual(vm.result?.prefix, 24)
    }
    
    @MainActor
    func testApplyDetectedDefaultReplacesPlaceholderOnce() {
        let vm = SubnetViewModel()
        XCTAssertEqual(vm.ipAddress, "192.168.1.1")
        XCTAssertFalse(vm.didApplyDetectedDefault)

        let iface = NetworkInterface(name: "en0", ipv4: ["10.0.0.5"], ipv6: [],
                                     netmasks: ["255.255.0.0"], mac: nil, mtu: nil,
                                     isUp: true, isLoopback: false, ifType: 6)
        vm.applyDetectedDefault(from: iface)
        XCTAssertEqual(vm.ipAddress, "10.0.0.5")
        XCTAssertEqual(vm.prefix, 16)
        XCTAssertTrue(vm.didApplyDetectedDefault)
        XCTAssertEqual(vm.result?.prefix, 16)

        // A second call must not clobber a value the user has since typed.
        vm.updateIP("172.16.0.1")
        let other = NetworkInterface(name: "en1", ipv4: ["192.168.50.1"], ipv6: [],
                                     netmasks: ["255.255.255.0"], mac: nil, mtu: nil,
                                     isUp: true, isLoopback: false, ifType: 6)
        vm.applyDetectedDefault(from: other)
        XCTAssertEqual(vm.ipAddress, "172.16.0.1")
    }

    @MainActor
    func testApplyDetectedDefaultNoOpWithoutInterface() {
        let vm = SubnetViewModel()
        vm.applyDetectedDefault(from: nil)
        XCTAssertEqual(vm.ipAddress, "192.168.1.1")
        XCTAssertFalse(vm.didApplyDetectedDefault)
    }

    @MainActor
    func testInvalidInputDoesNotCrash() {
        let vm = SubnetViewModel()
        vm.updateIP("invalid-ip")
        vm.updatePrefix(99) // Invalid prefix
        
        // Should handle gracefully
        vm.calculate()
        XCTAssertTrue(true) 
    }
}
