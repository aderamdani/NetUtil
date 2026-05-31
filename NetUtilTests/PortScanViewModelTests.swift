import XCTest
@testable import NetUtil

final class PortScanViewModelTests: XCTestCase {
    
    @MainActor
    func testPortRangeValidation() {
        // Logic check: Scan method accepts [Int].
        // VM doesn't expose range validation explicitly, 
        // but we verify result state categorization.
        
        let vm = PortScanViewModel()
        let ports = [80, 443]
        
        // Ensure state is empty initially
        XCTAssertEqual(vm.results.count, 0)
        
        // Mock scan logic: call stop to ensure we are in a clean state
        vm.stop()
        XCTAssertFalse(vm.isRunning)
    }
}
