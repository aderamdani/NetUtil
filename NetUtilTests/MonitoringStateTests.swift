import XCTest
@testable import NetUtil

/// Decision-table + idempotency tests for the three-tier monitoring state
/// machine. Pure inputs only — no timers, no NSApp, no real occlusion.
/// `MonitoringStateController` backs `ToolStore.applyMonitoringState`, so
/// its transition tests cover the no-op-on-repeat contract.
@MainActor
final class MonitoringStateTests: XCTestCase {

    // MARK: - targetState: full decision table

    func testVisibleRegularWithoutConsumerIsActive() {
        XCTAssertEqual(target(visible: true, regular: true, consumer: false), .active)
    }

    func testVisibleRegularWithConsumerIsActive() {
        XCTAssertEqual(target(visible: true, regular: true, consumer: true), .active)
    }

    func testVisibleAccessoryWithConsumerIsReduced() {
        XCTAssertEqual(target(visible: true, regular: false, consumer: true), .reduced)
    }

    func testVisibleAccessoryWithoutConsumerIsSuspended() {
        XCTAssertEqual(target(visible: true, regular: false, consumer: false), .suspended)
    }

    func testOccludedRegularWithConsumerIsReduced() {
        XCTAssertEqual(target(visible: false, regular: true, consumer: true), .reduced)
    }

    func testOccludedRegularWithoutConsumerIsSuspended() {
        XCTAssertEqual(target(visible: false, regular: true, consumer: false), .suspended)
    }

    func testOccludedAccessoryWithConsumerIsReduced() {
        XCTAssertEqual(target(visible: false, regular: false, consumer: true), .reduced)
    }

    func testOccludedAccessoryWithoutConsumerIsSuspended() {
        XCTAssertEqual(target(visible: false, regular: false, consumer: false), .suspended)
    }

    // MARK: - Controller idempotency

    func testInitialStateIsActive() {
        XCTAssertEqual(MonitoringStateController().current, .active)
    }

    func testRepeatTransitionIsNoop() {
        var controller = MonitoringStateController()
        XCTAssertFalse(controller.transition(to: .active))
        XCTAssertEqual(controller.current, .active)
    }

    func testRealTransitionsApplyExactlyOnce() {
        var controller = MonitoringStateController()

        XCTAssertTrue(controller.transition(to: .reduced))
        XCTAssertEqual(controller.current, .reduced)
        XCTAssertFalse(controller.transition(to: .reduced))

        XCTAssertTrue(controller.transition(to: .suspended))
        XCTAssertEqual(controller.current, .suspended)
        XCTAssertFalse(controller.transition(to: .suspended))

        XCTAssertTrue(controller.transition(to: .active))
        XCTAssertEqual(controller.current, .active)
    }

    // MARK: - Helper

    private func target(visible: Bool, regular: Bool, consumer: Bool) -> MonitoringState {
        MonitoringState.targetState(visible: visible, regular: regular, hasLiveConsumer: consumer)
    }
}
