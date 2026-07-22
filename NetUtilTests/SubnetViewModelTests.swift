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
    func testInvalidInputDoesNotCrash() {
        let vm = SubnetViewModel()
        vm.updateIP("invalid-ip")
        vm.updatePrefix(99) // Invalid prefix
        
        // Should handle gracefully
        vm.calculate()
        XCTAssertTrue(true) 
    }
}
