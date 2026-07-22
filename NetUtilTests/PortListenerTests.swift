import XCTest
import Network
@testable import NetUtil

@MainActor
final class PortListenerTests: XCTestCase {

    func testRejectsInvalidPort() {
        let vm = PortListenerViewModel()
        vm.port = 0
        vm.start()
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isRunning)
    }

    /// End-to-end on loopback: start a TCP listener on a high port, connect
    /// to it, send a few bytes, and expect a logged event.
    func testLogsInboundTCPConnection() async throws {
        let vm = PortListenerViewModel()
        vm.port = Int.random(in: 40000...60000)
        vm.proto = .tcp
        vm.start()

        // Wait for the listener to become ready.
        for _ in 0..<50 where !vm.isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(vm.isRunning, "listener never became ready: \(vm.error ?? "no error")")

        let conn = NWConnection(host: "127.0.0.1",
                                port: NWEndpoint.Port(rawValue: UInt16(vm.port))!,
                                using: .tcp)
        conn.start(queue: .global())
        conn.send(content: Data("hello listener".utf8), completion: .contentProcessed { _ in })

        for _ in 0..<50 where vm.events.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        conn.cancel()
        vm.stop()

        XCTAssertFalse(vm.events.isEmpty, "inbound connection was never logged")
        XCTAssertTrue(vm.events[0].detail.contains("bytes"), "\(vm.events[0].detail)")
    }
}
