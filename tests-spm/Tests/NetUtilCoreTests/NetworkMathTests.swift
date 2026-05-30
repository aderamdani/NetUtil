import XCTest
@testable import NetUtilCore

final class NetworkMathTests: XCTestCase {

    // MARK: - IPv4Address parsing / formatting

    func testIPv4ParseValid() {
        let a = IPv4Address("192.168.1.1")
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.value, 0xC0A80101)
        XCTAssertEqual(a?.string, "192.168.1.1")
    }

    func testIPv4RoundTrip() {
        for s in ["0.0.0.0", "255.255.255.255", "10.0.0.1", "8.8.8.8"] {
            XCTAssertEqual(IPv4Address(s)?.string, s, "round-trip failed for \(s)")
        }
    }

    func testIPv4RejectsOutOfRangeOctet() {
        XCTAssertNil(IPv4Address("256.1.1.1"))
        XCTAssertNil(IPv4Address("1.2.3.300"))
    }

    func testIPv4RejectsWrongComponentCount() {
        XCTAssertNil(IPv4Address("1.2.3"))
        XCTAssertNil(IPv4Address("1.2.3.4.5"))
    }

    func testIPv4RejectsNonNumeric() {
        XCTAssertNil(IPv4Address("a.b.c.d"))
        XCTAssertNil(IPv4Address(""))
    }

    // MARK: - Subnet calculation (the common /24 case)

    func testSubnet24() {
        let r = NetworkMath.calculateSubnet(ip: "192.168.1.50", prefix: 24)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.networkAddress, "192.168.1.0")
        XCTAssertEqual(r?.broadcastAddress, "192.168.1.255")
        XCTAssertEqual(r?.firstHost, "192.168.1.1")
        XCTAssertEqual(r?.lastHost, "192.168.1.254")
        XCTAssertEqual(r?.totalHosts, 256)
        XCTAssertEqual(r?.usableHosts, 254)
        XCTAssertEqual(r?.mask, "255.255.255.0")
        XCTAssertEqual(r?.wildcardMask, "0.0.0.255")
        XCTAssertEqual(r?.ipClass, "C")
        XCTAssertEqual(r?.binaryMask, "11111111.11111111.11111111.00000000")
    }

    func testSubnet30() {
        let r = NetworkMath.calculateSubnet(ip: "10.0.0.5", prefix: 30)
        XCTAssertEqual(r?.networkAddress, "10.0.0.4")
        XCTAssertEqual(r?.broadcastAddress, "10.0.0.7")
        XCTAssertEqual(r?.totalHosts, 4)
        XCTAssertEqual(r?.usableHosts, 2)
    }

    // MARK: - Edge prefixes

    func testSubnet32IsSingleHost() {
        let r = NetworkMath.calculateSubnet(ip: "10.0.0.1", prefix: 32)
        XCTAssertEqual(r?.totalHosts, 1)
        XCTAssertEqual(r?.usableHosts, 0)
        XCTAssertEqual(r?.firstHost, "N/A")
        XCTAssertEqual(r?.lastHost, "N/A")
    }

    func testSubnet31IsPointToPoint() {
        let r = NetworkMath.calculateSubnet(ip: "10.0.0.0", prefix: 31)
        XCTAssertEqual(r?.totalHosts, 2)
        XCTAssertEqual(r?.usableHosts, 0)
    }

    /// REGRESSION: /0 used to compute UInt32(pow(2,32)) which overflow-trapped
    /// and crashed the app (the prefix picker offers /0). Must not crash.
    func testSubnet0DoesNotCrash() {
        let r = NetworkMath.calculateSubnet(ip: "10.0.0.1", prefix: 0)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.mask, "0.0.0.0")
        XCTAssertEqual(r?.networkAddress, "0.0.0.0")
        XCTAssertEqual(r?.totalHosts, UInt32.max)
    }

    func testSubnetInvalidIPReturnsNil() {
        XCTAssertNil(NetworkMath.calculateSubnet(ip: "not-an-ip", prefix: 24))
        XCTAssertNil(NetworkMath.calculateSubnet(ip: "999.1.1.1", prefix: 24))
    }

    // MARK: - Class detection

    func testClassDetection() {
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "10.0.0.1", prefix: 8)?.ipClass, "A")
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "127.0.0.1", prefix: 8)?.ipClass, "Loopback")
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "172.16.0.1", prefix: 16)?.ipClass, "B")
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "192.168.0.1", prefix: 24)?.ipClass, "C")
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "224.0.0.1", prefix: 4)?.ipClass, "D (Multicast)")
        XCTAssertEqual(NetworkMath.calculateSubnet(ip: "240.0.0.1", prefix: 4)?.ipClass, "E (Experimental)")
    }

    // MARK: - Rate / byte humanizers

    func testFormatRate() {
        XCTAssertEqual(NetworkMath.formatRate(512), "512 B/s")
        XCTAssertEqual(NetworkMath.formatRate(2048), "2.0 K")
        XCTAssertEqual(NetworkMath.formatRate(1_048_576), "1.00 M")
        XCTAssertEqual(NetworkMath.formatRate(1_073_741_824), "1.00 G")
    }

    func testFormatBytes() {
        XCTAssertEqual(NetworkMath.formatBytes(500), "500 B")
        XCTAssertEqual(NetworkMath.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(NetworkMath.formatBytes(1_048_576), "1.0 MB")
        XCTAssertEqual(NetworkMath.formatBytes(1_073_741_824), "1.00 GB")
        XCTAssertEqual(NetworkMath.formatBytes(1_099_511_627_776), "1.00 TB")
    }
}
