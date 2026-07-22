import XCTest
@testable import NetUtil

@MainActor
final class NetworkDoctorTests: XCTestCase {

    private func checks(gateway: Bool, dns: Bool, http: Bool, tls: Bool) -> [DoctorCheck] {
        func state(_ ok: Bool) -> DoctorStepState { ok ? .passed("ok") : .failed("bad") }
        return [
            DoctorCheck(id: .gateway, state: state(gateway)),
            DoctorCheck(id: .dns,     state: state(dns)),
            DoctorCheck(id: .http,    state: state(http)),
            DoctorCheck(id: .tls,     state: state(tls)),
        ]
    }

    func testVerdictAllHealthy() {
        let v = NetworkDoctorViewModel.verdict(for: checks(gateway: true, dns: true, http: true, tls: true),
                                               captivePortal: false)
        XCTAssertEqual(v.color, "green")
    }

    func testVerdictBlamesFirstBrokenLayer() {
        let gw = NetworkDoctorViewModel.verdict(for: checks(gateway: false, dns: false, http: false, tls: false),
                                                captivePortal: false)
        XCTAssertTrue(gw.message.contains("router"), "gateway failure must be blamed first: \(gw.message)")

        let dns = NetworkDoctorViewModel.verdict(for: checks(gateway: true, dns: false, http: false, tls: false),
                                                 captivePortal: false)
        XCTAssertTrue(dns.message.contains("DNS"), "\(dns.message)")

        let http = NetworkDoctorViewModel.verdict(for: checks(gateway: true, dns: true, http: false, tls: false),
                                                  captivePortal: false)
        XCTAssertTrue(http.message.contains("No internet"), "\(http.message)")

        let tls = NetworkDoctorViewModel.verdict(for: checks(gateway: true, dns: true, http: true, tls: false),
                                                 captivePortal: false)
        XCTAssertTrue(tls.message.contains("Encrypted"), "\(tls.message)")
    }

    func testCaptivePortalOverridesOtherFailures() {
        let v = NetworkDoctorViewModel.verdict(for: checks(gateway: true, dns: true, http: false, tls: false),
                                               captivePortal: true)
        XCTAssertEqual(v.color, "orange")
        XCTAssertTrue(v.message.contains("Captive portal"))
    }
}
