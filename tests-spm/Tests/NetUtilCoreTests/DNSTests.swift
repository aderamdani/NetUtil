import XCTest
@testable import NetUtilCore

final class DNSParserTests: XCTestCase {

    private let sample = """
    ; <<>> DiG 9.10 <<>> example.com A
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1234
    ;; QUESTION SECTION:
    ;example.com.\t\t\tIN\tA

    ;; ANSWER SECTION:
    example.com.\t\t3600\tIN\tA\t93.184.216.34
    example.com.\t\t3600\tIN\tA\t93.184.216.35

    ;; Query time: 23 msec
    ;; SERVER: 8.8.8.8#53(8.8.8.8)
    ;; WHEN: Mon May 30 2026
    """

    func testParsesAnswerRecords() {
        let r = DNSViewModel.parse(output: sample, server: .google)
        XCTAssertEqual(r.records.count, 2)
        XCTAssertEqual(r.records.first?.name, "example.com.")
        XCTAssertEqual(r.records.first?.ttl, 3600)
        XCTAssertEqual(r.records.first?.type, "A")
        XCTAssertEqual(r.records.first?.value, "93.184.216.34")
    }

    func testParsesQueryTime() {
        let r = DNSViewModel.parse(output: sample, server: .google)
        XCTAssertEqual(r.queryTimeMs, 23)
    }

    func testParsesServer() {
        let r = DNSViewModel.parse(output: sample, server: .google)
        XCTAssertEqual(r.server, "8.8.8.8")
    }

    func testMXMultiTokenValue() {
        let mx = """
        ;; ANSWER SECTION:
        example.com.\t\t300\tIN\tMX\t10 mail.example.com.
        """
        let r = DNSViewModel.parse(output: mx, server: .system)
        XCTAssertEqual(r.records.first?.type, "MX")
        XCTAssertEqual(r.records.first?.value, "10 mail.example.com.")
    }

    func testEmptyAnswer() {
        let r = DNSViewModel.parse(output: ";; Query time: 5 msec\n", server: .cloudflare)
        XCTAssertTrue(r.records.isEmpty)
    }

    func testServerEnumAddresses() {
        XCTAssertNil(DNSServer.system.address)
        XCTAssertEqual(DNSServer.google.address, "8.8.8.8")
        XCTAssertEqual(DNSServer.cloudflare.address, "1.1.1.1")
        XCTAssertEqual(DNSServer.quad9.address, "9.9.9.9")
    }
}
