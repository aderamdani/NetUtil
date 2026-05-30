import XCTest
@testable import NetUtilCore

final class TracerouteParserTests: XCTestCase {

    func testParseStandardLine() {
        let h = TracerouteViewModel.parseLine("1  192.168.1.1 (192.168.1.1)  0.345 ms  0.211 ms  0.198 ms")
        XCTAssertNotNil(h)
        XCTAssertEqual(h?.hop, 1)
        XCTAssertEqual(h?.ip, "192.168.1.1")
        XCTAssertEqual(h?.rtts.compactMap { $0 }, [0.345, 0.211, 0.198])
    }

    func testParseHostnameWithIP() {
        let h = TracerouteViewModel.parseLine("4  router.example.net (10.0.0.1)  5.0 ms  6.0 ms  7.0 ms")
        XCTAssertEqual(h?.host, "router.example.net")
        XCTAssertEqual(h?.ip, "10.0.0.1")
        XCTAssertEqual(h?.displayHost, "router.example.net (10.0.0.1)")
    }

    func testParseFullTimeoutLine() {
        let h = TracerouteViewModel.parseLine("2  * * *")
        XCTAssertEqual(h?.hop, 2)
        XCTAssertNil(h?.ip)
        XCTAssertEqual(h?.rtts.count, 3)
        XCTAssertEqual(h?.rtts.compactMap { $0 }.count, 0)
        XCTAssertEqual(h?.displayHost, "*")
    }

    func testParseMixedTimeout() {
        let h = TracerouteViewModel.parseLine("3  as-5.net (1.2.3.4)  10.5 ms * 11.2 ms")
        XCTAssertEqual(h?.ip, "1.2.3.4")
        XCTAssertEqual(h?.rtts.count, 3)
        XCTAssertEqual(h?.rtts.compactMap { $0 }, [10.5, 11.2])
    }

    func testParseBareIPSwapsToIPField() {
        let h = TracerouteViewModel.parseLine("3  10.0.0.1  5.0 ms")
        XCTAssertEqual(h?.ip, "10.0.0.1")
    }

    func testParseRejectsHeader() {
        XCTAssertNil(TracerouteViewModel.parseLine("traceroute to google.com (142.250.4.100), 30 hops max, 60 byte packets"))
        XCTAssertNil(TracerouteViewModel.parseLine(""))
    }
}

final class TracerouteHopTests: XCTestCase {

    private func hop(ip: String?) -> TracerouteHop {
        TracerouteHop(hop: 1, host: nil, ip: ip, rtts: [], samples: [])
    }

    func testIsPrivateIP() {
        XCTAssertTrue(hop(ip: "10.1.2.3").isPrivateIP)
        XCTAssertTrue(hop(ip: "172.16.0.1").isPrivateIP)
        XCTAssertTrue(hop(ip: "192.168.0.1").isPrivateIP)
        XCTAssertTrue(hop(ip: "127.0.0.1").isPrivateIP)
        XCTAssertFalse(hop(ip: "172.32.0.1").isPrivateIP)
        XCTAssertFalse(hop(ip: "8.8.8.8").isPrivateIP)
    }

    func testNilIPTreatedAsPrivate() {
        XCTAssertTrue(hop(ip: nil).isPrivateIP)
    }

    func testIPv6PrivacyHeuristic() {
        XCTAssertTrue(hop(ip: "::1").isPrivateIP)
        XCTAssertTrue(hop(ip: "fe80::1").isPrivateIP)
    }

    func testAppendRoundComputesPerRoundAverage() {
        var h = hop(ip: "1.2.3.4")
        h.appendRound([10, 20, 30], at: Date())   // avg 20
        h.appendRound([nil, nil, nil], at: Date()) // full loss this round
        XCTAssertEqual(h.sent, 2)
        XCTAssertEqual(h.recv, 1)
        XCTAssertEqual(h.loss, 50, accuracy: 0.0001)
        XCTAssertEqual(h.avgRtt ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(h.minRtt ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(h.consecutiveLoss, 1)
    }

    func testStatsNilWhenNoSamples() {
        let h = hop(ip: "1.2.3.4")
        XCTAssertNil(h.avgRtt)
        XCTAssertNil(h.minRtt)
        XCTAssertNil(h.jitter)
        XCTAssertEqual(h.loss, 0)
    }

    func testHistoryCapAt100() {
        var h = hop(ip: "1.2.3.4")
        for _ in 0..<150 { h.appendRound([5], at: Date()) }
        XCTAssertEqual(h.sent, 100)
    }
}
