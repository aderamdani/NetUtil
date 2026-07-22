import XCTest
@testable import NetUtil

@MainActor
final class WakeOnLanTests: XCTestCase {

    func testParseMACAcceptsCommonFormats() {
        let expected: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        XCTAssertEqual(WakeOnLan.parseMAC("AA:BB:CC:DD:EE:FF"), expected)
        XCTAssertEqual(WakeOnLan.parseMAC("aa-bb-cc-dd-ee-ff"), expected)
        XCTAssertEqual(WakeOnLan.parseMAC("aabbccddeeff"), expected)
        XCTAssertEqual(WakeOnLan.parseMAC("  AA:BB:CC:DD:EE:FF  "), expected)
    }

    func testParseMACRejectsInvalidInput() {
        XCTAssertNil(WakeOnLan.parseMAC(""))
        XCTAssertNil(WakeOnLan.parseMAC("AA:BB:CC:DD:EE"))
        XCTAssertNil(WakeOnLan.parseMAC("AA:BB:CC:DD:EE:FF:00"))
        XCTAssertNil(WakeOnLan.parseMAC("GG:BB:CC:DD:EE:FF"))
        XCTAssertNil(WakeOnLan.parseMAC("192.168.1.1"))
    }

    func testMagicPacketLayout() {
        let mac: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        let packet = WakeOnLan.magicPacket(mac: mac)
        XCTAssertEqual(packet.count, 102)
        XCTAssertEqual(Array(packet.prefix(6)), Array(repeating: 0xFF, count: 6))
        for i in 0..<16 {
            let start = 6 + i * 6
            XCTAssertEqual(Array(packet[start..<start + 6]), mac, "repetition \(i) corrupt")
        }
    }

    func testSendRejectsBadInputWithoutTouchingNetwork() {
        XCTAssertThrowsError(try WakeOnLan.send(mac: "nope", broadcast: "255.255.255.255", port: 9)) {
            XCTAssertEqual($0 as? WakeOnLanError, .invalidMAC)
        }
        XCTAssertThrowsError(try WakeOnLan.send(mac: "AA:BB:CC:DD:EE:FF", broadcast: "not-an-ip", port: 9)) {
            XCTAssertEqual($0 as? WakeOnLanError, .invalidBroadcastAddress)
        }
    }
}

@MainActor
final class NetQualityParseTests: XCTestCase {

    /// Keys as emitted by `networkQuality -c` on macOS 26.
    private let sample = """
    {"base_rtt": 66.29, "dl_throughput": 363052160, "ul_throughput": 371732064,
     "responsiveness": 423.99, "interface_name": "en4",
     "test_endpoint": "sgsin4-edge-fx-023.aaplimg.com", "dl_flows": 13}
    """

    func testParsesRealOutputShape() throws {
        let r = try XCTUnwrap(NetQualityViewModel.parse(sample))
        XCTAssertEqual(r.downloadMbps, 363.05216, accuracy: 0.001)
        XCTAssertEqual(r.uploadMbps, 371.732064, accuracy: 0.001)
        XCTAssertEqual(r.responsivenessRPM, 424)
        XCTAssertEqual(try XCTUnwrap(r.baseRttMs), 66.29, accuracy: 0.001)
        XCTAssertEqual(r.interfaceName, "en4")
        XCTAssertEqual(r.endpoint, "sgsin4-edge-fx-023.aaplimg.com")
    }

    func testParseRejectsGarbageAndMissingKeys() {
        XCTAssertNil(NetQualityViewModel.parse(""))
        XCTAssertNil(NetQualityViewModel.parse("not json"))
        XCTAssertNil(NetQualityViewModel.parse(#"{"dl_throughput": 1000000}"#))
    }

    func testRPMGradeBands() {
        func result(rpm: Int) -> NetQualityResult {
            NetQualityResult(downloadMbps: 0, uploadMbps: 0, responsivenessRPM: rpm,
                             baseRttMs: nil, interfaceName: nil, endpoint: nil, timestamp: Date())
        }
        XCTAssertEqual(result(rpm: 800).rpmGrade.label, "High")
        XCTAssertEqual(result(rpm: 799).rpmGrade.label, "Medium")
        XCTAssertEqual(result(rpm: 300).rpmGrade.label, "Medium")
        XCTAssertEqual(result(rpm: 299).rpmGrade.label, "Low")
    }
}
