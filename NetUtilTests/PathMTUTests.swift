import XCTest
@testable import NetUtil

@MainActor
final class PathMTUTests: XCTestCase {

    /// Simulates a path with the given MTU: a probe passes iff its full
    /// packet (payload + 28) fits.
    private func vm(simulatedMTU: Int) -> PathMTUViewModel {
        PathMTUViewModel(probe: { _, payload in
            payload + PathMTUViewModel.headerOverhead <= simulatedMTU
        })
    }

    func testFindsExactEthernetMTU() async {
        let vm = vm(simulatedMTU: 1500)
        vm.start(host: "h")
        // The fast path (1472 payload) passes immediately; wait for the task.
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(vm.mtu, 1500)
        XCTAssertFalse(vm.isRunning)
    }

    func testConvergesOnTunnelMTU() async {
        let vm = vm(simulatedMTU: 1436)
        vm.start(host: "h")
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(vm.mtu, 1436, "binary search must converge exactly")
        XCTAssertTrue(vm.probes.count <= 13, "should need ~11 probes, used \(vm.probes.count)")
    }

    func testUnreachableHostSetsError() async {
        let vm = PathMTUViewModel(probe: { _, _ in false })
        vm.start(host: "h")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(vm.mtu)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isRunning)
    }

    func testInterpretationBands() {
        XCTAssertTrue(PathMTUViewModel.interpretation(mtu: 1500).contains("Ethernet"))
        XCTAssertTrue(PathMTUViewModel.interpretation(mtu: 1492).contains("PPPoE"))
        XCTAssertTrue(PathMTUViewModel.interpretation(mtu: 1436).contains("tunnel"))
        XCTAssertTrue(PathMTUViewModel.interpretation(mtu: 1000).contains("small"))
    }
}
