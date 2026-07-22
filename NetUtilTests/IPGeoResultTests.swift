import XCTest
import CoreLocation
@testable import NetUtil

@MainActor
final class IPGeoResultTests: XCTestCase {

    func testParseValidResponse() {
        let json = """
        {
          "ip": "8.8.8.8",
          "hostname": "dns.google",
          "city": "Mountain View",
          "region": "California",
          "country": "US",
          "org": "AS15169 Google LLC",
          "postal": "94043",
          "timezone": "America/Los_Angeles",
          "loc": "37.4056,-122.0775"
        }
        """
        let result = IPGeoResult.parse(json.data(using: .utf8)!)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ip, "8.8.8.8")
        XCTAssertEqual(result?.city, "Mountain View")
        XCTAssertEqual(result?.country, "US")
        XCTAssertEqual(result?.asn, "AS15169")
        XCTAssertEqual(result?.ispName, "Google LLC")
        XCTAssertEqual(result?.coordinate?.latitude, 37.4056)
        XCTAssertEqual(result?.coordinate?.longitude, -122.0775)
    }

    func testParseMissingIPReturnsNil() {
        let json = """
        { "city": "Nowhere", "country": "US" }
        """
        XCTAssertNil(IPGeoResult.parse(json.data(using: .utf8)!))
    }

    func testParseMalformedJSONReturnsNil() {
        XCTAssertNil(IPGeoResult.parse("not json".data(using: .utf8)!))
    }

    func testOrgWithoutASNPrefixIsUsedAsIspNameVerbatim() {
        let json = """
        { "ip": "1.1.1.1", "org": "Cloudflare, Inc." }
        """
        let result = IPGeoResult.parse(json.data(using: .utf8)!)
        XCTAssertNil(result?.asn)
        XCTAssertEqual(result?.ispName, "Cloudflare, Inc.")
    }

    func testFlagBuildsFromCountryCode() {
        let json = """
        { "ip": "1.1.1.1", "country": "US", "city": "" }
        """
        let result = IPGeoResult.parse(json.data(using: .utf8)!)
        XCTAssertEqual(result?.flag, "🇺🇸")
        XCTAssertEqual(result?.shortLabel, "🇺🇸 US")
    }
}
