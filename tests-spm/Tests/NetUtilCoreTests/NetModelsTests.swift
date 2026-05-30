import XCTest
@testable import NetUtilCore

final class RouteEntryTests: XCTestCase {

    func testFlagDescriptions() {
        // NOTE: flagDescriptions only matches UPPERCASE letters; macOS also emits
        // lowercase 'c' (cloning) which is not decoded — see audit doc.
        let e = RouteEntry(destination: "0.0.0.0", gateway: "192.168.1.1",
                           flags: "UGSC", netif: "en0", isIPv6: false)
        XCTAssertEqual(e.flagDescriptions, ["Up", "Gateway", "Static", "Cloned"])
    }

    func testIsDefault() {
        let v4 = RouteEntry(destination: "default", gateway: "g", flags: "UG", netif: "en0", isIPv6: false)
        let v40 = RouteEntry(destination: "0.0.0.0", gateway: "g", flags: "UG", netif: "en0", isIPv6: false)
        let v6 = RouteEntry(destination: "::", gateway: "g", flags: "UG", netif: "en0", isIPv6: true)
        let host = RouteEntry(destination: "10.0.0.5", gateway: "g", flags: "UH", netif: "en0", isIPv6: false)
        XCTAssertTrue(v4.isDefault)
        XCTAssertTrue(v40.isDefault)
        XCTAssertTrue(v6.isDefault)
        XCTAssertFalse(host.isDefault)
    }
}

final class PortModelTests: XCTestCase {

    func testWebPresetPorts() {
        XCTAssertEqual(PortPreset.web.ports?.first, 80)
        XCTAssertTrue(PortPreset.web.ports?.contains(443) ?? false)
    }

    func testCustomPresetHasNoFixedPorts() {
        XCTAssertNil(PortPreset.custom.ports)
    }

    func testWellKnownServiceNames() {
        XCTAssertEqual(wellKnownPorts[22], "SSH")
        XCTAssertEqual(wellKnownPorts[443], "HTTPS")
        XCTAssertEqual(wellKnownPorts[3306], "MySQL")
        XCTAssertNil(wellKnownPorts[12345])
    }

    func testStatusLabels() {
        XCTAssertEqual(PortStatus.open.label, "Open")
        XCTAssertEqual(PortStatus.closed.label, "Closed")
        XCTAssertEqual(PortStatus.filtered.label, "Filtered")
    }
}

final class HTTPModelTests: XCTestCase {

    func testPhaseEndMs() {
        let t = HTTPPhaseTiming(phase: .tcp, startMs: 10, durationMs: 5)
        XCTAssertEqual(t.endMs, 15)
    }

    func testAllPhasesHaveColor() {
        for p in HTTPPhase.allCases {
            XCTAssertFalse(p.color.isEmpty, "\(p) missing color")
        }
    }
}

final class CertInfoTests: XCTestCase {

    private func cert(expiresInDays days: Int?) -> CertInfo {
        let notAfter = days.map { Date().addingTimeInterval(Double($0) * 86_400) }
        return CertInfo(subject: "cn", issuer: "ca", notBefore: nil, notAfter: notAfter,
                        serialNumber: "00", sans: [], keyType: "RSA-2048", sha256: "ab", isLeaf: true)
    }

    func testExpiryColorGreen() {
        XCTAssertEqual(cert(expiresInDays: 45).expiryColor, "green")
    }

    func testExpiryColorOrange() {
        XCTAssertEqual(cert(expiresInDays: 14).expiryColor, "orange")
    }

    func testExpiryColorRed() {
        XCTAssertEqual(cert(expiresInDays: 2).expiryColor, "red")
    }

    func testExpiryColorSecondaryWhenUnknown() {
        XCTAssertEqual(cert(expiresInDays: nil).expiryColor, "secondary")
    }

    func testDaysRemainingNilWhenNoExpiry() {
        XCTAssertNil(cert(expiresInDays: nil).daysRemaining)
    }
}
