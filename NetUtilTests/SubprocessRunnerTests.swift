import XCTest
@testable import NetUtil

@MainActor
final class SubprocessRunnerTests: XCTestCase {

    func testRunCapturesOutput() {
        let out = SubprocessRunner.run(executable: "/bin/echo", arguments: ["hello"])
        XCTAssertEqual(out.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testRunReturnsEmptyOnLaunchFailure() {
        let out = SubprocessRunner.run(executable: "/nonexistent/binary", arguments: [])
        XCTAssertEqual(out, "")
    }

    /// REGRESSION: reading only after waitUntilExit deadlocks once output
    /// exceeds the ~64 KB pipe buffer (the RouteTableView netstat hang).
    /// 220 KB of awk output must come back complete, without hanging.
    func testRunDrainsLargeOutputWithoutDeadlock() {
        let out = SubprocessRunner.run(
            executable: "/usr/bin/awk",
            arguments: ["BEGIN { for (i = 0; i < 20000; i++) print \"0123456789\" }"])
        XCTAssertEqual(out.split(separator: "\n").count, 20000)
    }

    @MainActor
    func testCancellableCollectsOutput() async throws {
        let sub = CancellableSubprocess()
        try sub.launch(executable: "/bin/echo", arguments: ["dig-style output"])
        let out = await sub.collectOutput()
        XCTAssertTrue(out.contains("dig-style output"))
    }

    @MainActor
    func testCancellableLaunchFailureThrows() {
        let sub = CancellableSubprocess()
        XCTAssertThrowsError(try sub.launch(executable: "/nonexistent/binary", arguments: []))
    }

    /// Terminating an in-flight run must not hang collectOutput — this is
    /// the Stop-button path for DNS/WHOIS.
    @MainActor
    func testCancellableTerminateStopsInFlightRun() async throws {
        let sub = CancellableSubprocess()
        try sub.launch(executable: "/bin/sleep", arguments: ["30"])
        sub.terminate()
        let start = Date()
        _ = await sub.collectOutput()
        XCTAssertLessThan(Date().timeIntervalSince(start), 5,
                          "collectOutput must return promptly after terminate()")
    }

    @MainActor
    func testStreamingDeliversChunksAndTermination() async throws {
        let sub = StreamingSubprocess()
        let gotChunk = expectation(description: "chunk")
        let terminated = expectation(description: "terminated")
        nonisolated(unsafe) var received = ""
        try sub.run(executable: "/bin/echo", arguments: ["streamed line"],
                    onChunk: { text in
                        received += text
                        gotChunk.fulfill()
                    },
                    onTerminate: { terminated.fulfill() })
        await fulfillment(of: [gotChunk, terminated], timeout: 5)
        XCTAssertTrue(received.contains("streamed line"))
    }
}

@MainActor
final class PrimaryInterfaceTests: XCTestCase {

    private func iface(_ name: String, up: Bool = true, loopback: Bool = false,
                       ipv4: [String] = ["192.168.1.10"]) -> NetworkInterface {
        NetworkInterface(name: name, ipv4: ipv4, ipv6: [], netmasks: [],
                         mac: nil, mtu: nil, isUp: up, isLoopback: loopback, ifType: 6)
    }

    func testPhysicalInterfaceIsCandidate() {
        XCTAssertTrue(iface("en0").isPrimaryCandidate)
    }

    func testVirtualAndTunnelPrefixesAreExcluded() {
        for name in ["utun3", "ipsec0", "awdl0", "llw0", "bridge0", "tun0", "tap1"] {
            XCTAssertFalse(iface(name).isPrimaryCandidate, "\(name) must not be primary")
        }
    }

    func testDownLoopbackAndAddresslessAreExcluded() {
        XCTAssertFalse(iface("en0", up: false).isPrimaryCandidate)
        XCTAssertFalse(iface("lo0", loopback: true).isPrimaryCandidate)
        XCTAssertFalse(iface("en0", ipv4: []).isPrimaryCandidate)
    }

    /// The MenuBarView/ToolStore divergence this helper replaced: a plain
    /// tun0 must never win over a later physical interface.
    func testPrimaryPicksFirstCandidateInFetchOrder() {
        let picked = NetworkInterface.primary(in: [iface("tun0"), iface("en0"), iface("en1")])
        XCTAssertEqual(picked?.name, "en0")
        XCTAssertNil(NetworkInterface.primary(in: [iface("utun0"), iface("lo0", loopback: true)]))
    }
}

@MainActor
final class PrivateIPTests: XCTestCase {

    func testRFC1918AndSpecialRangesArePrivate() {
        for ip in ["10.0.0.1", "10.255.255.255", "127.0.0.1", "169.254.1.1",
                   "172.16.0.1", "172.31.255.254", "192.168.0.1"] {
            XCTAssertTrue(NetworkMath.isPrivateIP(ip), "\(ip) must be private")
        }
    }

    func testPublicAndNearMissRangesAreNotPrivate() {
        for ip in ["8.8.8.8", "1.1.1.1", "169.253.0.1", "169.255.0.1",
                   "172.15.0.1", "172.32.0.1", "192.169.0.1", "11.0.0.1"] {
            XCTAssertFalse(NetworkMath.isPrivateIP(ip), "\(ip) must be public")
        }
    }

    func testIPv6Heuristics() {
        XCTAssertTrue(NetworkMath.isPrivateIP("fe80::1"))
        XCTAssertTrue(NetworkMath.isPrivateIP("fc00::1"))
        XCTAssertTrue(NetworkMath.isPrivateIP("fd12:3456::1"))
        XCTAssertTrue(NetworkMath.isPrivateIP("::1"))
        XCTAssertFalse(NetworkMath.isPrivateIP("2607:f8b0::1"))
    }

    func testGarbageInputIsNotPrivate() {
        XCTAssertFalse(NetworkMath.isPrivateIP(""))
        XCTAssertFalse(NetworkMath.isPrivateIP("not-an-ip"))
    }
}
