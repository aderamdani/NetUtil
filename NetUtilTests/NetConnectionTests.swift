import XCTest
@testable import NetUtil

@MainActor
final class NetConnectionTests: XCTestCase {

    private let sample = """
    COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    Safari     1234 aderamdani   45u  IPv4 0xabc      0t0  TCP 192.168.1.5:52034->17.253.144.10:443 (ESTABLISHED)
    node       5678 aderamdani   23u  IPv6 0xdef      0t0  TCP *:8080 (LISTEN)
    mDNSRespo   169 aderamdani    7u  IPv4 0x123      0t0  UDP *:5353
    weird       999 aderamdani    3u  IPv4 0x456      0t0  ICMP *:*
    """

    func testParsesEstablishedConnection() {
        let conns = NetConnection.parse(sample)
        let safari = conns.first { $0.command == "Safari" }
        XCTAssertEqual(safari?.pid, 1234)
        XCTAssertEqual(safari?.proto, "TCP")
        XCTAssertEqual(safari?.local, "192.168.1.5:52034")
        XCTAssertEqual(safari?.remote, "17.253.144.10:443")
        XCTAssertEqual(safari?.state, "ESTABLISHED")
        XCTAssertFalse(safari?.isListening ?? true)
    }

    func testParsesListenerAndStatelessUDP() {
        let conns = NetConnection.parse(sample)
        let node = conns.first { $0.command == "node" }
        XCTAssertEqual(node?.local, "*:8080")
        XCTAssertNil(node?.remote)
        XCTAssertTrue(node?.isListening ?? false)

        let mdns = conns.first { $0.command == "mDNSRespo" }
        XCTAssertEqual(mdns?.proto, "UDP")
        XCTAssertNil(mdns?.state)
    }

    func testSkipsHeaderAndNonTCPUDPRows() {
        let conns = NetConnection.parse(sample)
        XCTAssertEqual(conns.count, 3, "header and ICMP rows must be skipped")
    }

    func testEmptyOutput() {
        XCTAssertTrue(NetConnection.parse("").isEmpty)
    }
}
