import XCTest
@testable import NetUtil

final class SSLInspectorViewModelTests: XCTestCase {
    
    // As the parsing logic is private inside TLSDelegate, we test the public API
    // by ensuring invalid inputs are handled gracefully and result/error states are reset.
    
    @MainActor
    func testInspectorStateReset() {
        let vm = SSLInspectorViewModel()
        
        // Mocking inspection of an invalid host
        vm.inspect(host: "invalid-host-that-wont-resolve", port: 443)
        XCTAssertTrue(vm.isRunning)
        
        vm.cancel()
        XCTAssertFalse(vm.isRunning)
    }
}
