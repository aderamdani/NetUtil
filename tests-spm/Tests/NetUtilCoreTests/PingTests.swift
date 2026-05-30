import XCTest
@testable import NetUtilCore

final class PingStatsTests: XCTestCase {

    func testRecordTracksMinMaxAvg() {
        var s = PingStats()
        s.record(rtt: 10)
        s.record(rtt: 30)
        XCTAssertEqual(s.transmitted, 2)
        XCTAssertEqual(s.received, 2)
        XCTAssertEqual(s.minRtt, 10)
        XCTAssertEqual(s.maxRtt, 30)
        XCTAssertEqual(s.avgRtt, 20, accuracy: 0.0001)
    }

    func testJitterIsStdDev() {
        var s = PingStats()
        s.record(rtt: 10)
        s.record(rtt: 30)
        // population std dev of {10,30} = 10
        XCTAssertEqual(s.jitter, 10, accuracy: 0.0001)
    }

    func testLossWithTimeouts() {
        var s = PingStats()
        s.record(rtt: 10)
        s.record(rtt: 20)
        s.recordTimeout()
        XCTAssertEqual(s.transmitted, 3)
        XCTAssertEqual(s.received, 2)
        XCTAssertEqual(s.loss, 100.0 / 3.0, accuracy: 0.0001)
    }

    func testLossZeroWhenNothingSent() {
        let s = PingStats()
        XCTAssertEqual(s.loss, 0)
    }

    func testDistributionBuckets() {
        var s = PingStats()
        s.record(rtt: 5)     // low   (<20)
        s.record(rtt: 35)    // medium(20-50)
        s.record(rtt: 75)    // high  (50-100)
        s.record(rtt: 150)   // critical(>100)
        XCTAssertEqual(s.bucketLow, 1)
        XCTAssertEqual(s.bucketMedium, 1)
        XCTAssertEqual(s.bucketHigh, 1)
        XCTAssertEqual(s.bucketCritical, 1)
    }
}

final class PingParserTests: XCTestCase {

    func testParseHeaderIPv4() {
        let ip = PingViewModel.parseHeader("PING google.com (142.250.4.100): 56 data bytes")
        XCTAssertEqual(ip, "142.250.4.100")
    }

    func testParseHeaderNoMatch() {
        XCTAssertNil(PingViewModel.parseHeader("round-trip min/avg/max = ..."))
    }

    func testParseLineIPv4() {
        let r = PingViewModel.parseLine("64 bytes from 142.250.4.100: icmp_seq=0 ttl=116 time=12.3 ms", ip: "142.250.4.100")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.bytes, 64)
        XCTAssertEqual(r?.sequence, 0)
        XCTAssertEqual(r?.ttl, 116)
        XCTAssertEqual(r?.rtt, 12.3)
        XCTAssertEqual(r?.status, .success)
        XCTAssertEqual(r?.ipAddress, "142.250.4.100")
    }

    func testParseLineIPv6() {
        let r = PingViewModel.parseLine("64 bytes from 2607:f8b0::1: icmp6_seq=3 hlim=58 time=20.1 ms", ip: nil)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.sequence, 3)
        XCTAssertEqual(r?.ttl, 58)
        XCTAssertEqual(r?.rtt, 20.1)
        XCTAssertEqual(r?.host, "2607:f8b0::1")
    }

    func testParseLineIntegerRtt() {
        let r = PingViewModel.parseLine("64 bytes from 1.1.1.1: icmp_seq=1 ttl=64 time=5 ms", ip: nil)
        XCTAssertEqual(r?.rtt, 5)
    }

    func testParseLineRejectsGarbage() {
        XCTAssertNil(PingViewModel.parseLine("PING google.com (1.2.3.4): 56 data bytes", ip: nil))
        XCTAssertNil(PingViewModel.parseLine("", ip: nil))
    }

    func testParseTimeoutIPv4() {
        XCTAssertEqual(PingViewModel.parseTimeout("Request timeout for icmp_seq 5"), 5)
    }

    func testParseTimeoutIPv6() {
        XCTAssertEqual(PingViewModel.parseTimeout("Request timeout for icmp6_seq 9"), 9)
    }

    func testParseTimeoutNoMatch() {
        XCTAssertNil(PingViewModel.parseTimeout("64 bytes from 1.1.1.1: icmp_seq=1 ttl=64 time=5 ms"))
    }
}

final class MultiPingSlotParserTests: XCTestCase {

    func testParseSuccess() {
        let r = PingSlot.parseLine("64 bytes from 1.1.1.1: icmp_seq=0 ttl=55 time=12.3 ms")
        guard case .some(.some(let v)) = r else { return XCTFail("expected rtt") }
        XCTAssertEqual(v, 12.3)
    }

    func testParseSuccessLessThanOperator() {
        // some pings emit "time<1 ms"
        let r = PingSlot.parseLine("64 bytes from 1.1.1.1: icmp_seq=0 ttl=55 time<1 ms")
        guard case .some(.some(let v)) = r else { return XCTFail("expected rtt") }
        XCTAssertEqual(v, 1)
    }

    func testParseTimeoutCountsAsLoss() {
        let r = PingSlot.parseLine("Request timeout for icmp_seq 3")
        guard case .some(.none) = r else { return XCTFail("expected timeout sentinel") }
    }

    func testParseNoRouteCountsAsLoss() {
        let r = PingSlot.parseLine("ping: sendto: No route to host")
        guard case .some(.none) = r else { return XCTFail("expected timeout sentinel") }
    }

    func testParseHeaderIgnored() {
        // Non-result lines yield outer nil (neither rtt nor loss sentinel).
        let r = PingSlot.parseLine("PING 1.1.1.1 (1.1.1.1): 56 data bytes")
        if case .some = r { XCTFail("header line should not parse to a sample") }
    }
}
