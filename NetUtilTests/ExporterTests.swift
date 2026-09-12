import XCTest
@testable import NetUtil

@MainActor
final class ExporterTests: XCTestCase {
    
    func testCSVGeneration() {
        let result = PingResult(
            sequence: 1,
            bytes: 64,
            host: "example.com",
            ipAddress: "127.0.0.1",
            ttl: 64,
            rtt: 10.5,
            status: .success
        )
        
        let csv = Exporter.csvString(from: [result])
        XCTAssertTrue(csv.contains("example.com"))
        XCTAssertTrue(csv.contains("10.5"))
    }
    
    func testEmptyCSVGeneration() {
        let results: [PingResult] = []
        let csv = Exporter.csvString(from: results)
        XCTAssertEqual(csv, "timestamp,sequence,host,bytes,ttl,rtt_ms,status")
    }

    // MARK: - RFC 4180 field escaping

    func testCSVFieldPassthroughForPlainValues() {
        XCTAssertEqual(Exporter.csvField("example.com"), "example.com")
        XCTAssertEqual(Exporter.csvField(""), "")
    }

    func testCSVFieldQuotesCommas() {
        XCTAssertEqual(Exporter.csvField("a,b"), "\"a,b\"")
    }

    func testCSVFieldEscapesEmbeddedQuotes() {
        XCTAssertEqual(Exporter.csvField(#"say "hi""#), #""say ""hi""""#)
    }

    func testCSVFieldQuotesNewlines() {
        XCTAssertEqual(Exporter.csvField("line1\nline2"), "\"line1\nline2\"")
    }

    /// A DNS TXT value with commas must stay in one column.
    func testCSVRowStaysAlignedWithCommaValue() {
        let row = "\(Exporter.csvField("v=spf1, include:x.com")),300"
        XCTAssertEqual(row, "\"v=spf1, include:x.com\",300")
    }


    // MARK: - CSV header / column-order integrity


    func testCSVHeadersMatchColumnSpec() {
        XCTAssertEqual(Exporter.csvString(from: [TracerouteHop]()),
                       "hop,host,ip,sent,recv,loss_pct,min_rtt_ms,avg_rtt_ms,max_rtt_ms")
        XCTAssertEqual(Exporter.csvString(from: [PingSlot]()),
                       "host,alias,sent,loss_pct,avg_rtt_ms,last_rtt_ms")
        XCTAssertEqual(Exporter.csvString(from: [HTTPLatencyResult]()),
                       "timestamp,method,url,status_code,total_ms,dns_ms,tcp_ms,tls_ms,request_ms,ttfb_ms,download_ms")
        XCTAssertEqual(Exporter.csvString(from: [SubnetScanResult]()),
                       "ip,hostname,status,rtt_ms,mac_address")
        XCTAssertEqual(Exporter.csvString(from: [NetworkInterface]()),
                       "name,type,status,ipv4,ipv6,mac,mtu")
        XCTAssertEqual(Exporter.csvString(from: [RouteEntry]()),
                       "destination,gateway,flags,interface,ipv6")
        XCTAssertEqual(Exporter.csvString(from: [ARPEntry]()),
                       "ip,mac,interface,type")
        XCTAssertEqual(Exporter.csvString(from: [NetConnection]()),
                       "process,pid,proto,local,remote,state")
        XCTAssertEqual(Exporter.csvString(from: [DNSResolverEntry]()),
                       "scope,domain,nameserver,interface,reachable,latency_ms")
        XCTAssertEqual(Exporter.csvString(from: [SpeedTestResult]()),
                       "timestamp,kind,name,download_mbps,upload_mbps,ping_ms,jitter_ms,browsing_avg_ms,game_median_ms,stream_avg_mbps,stream_tier")
    }
}
