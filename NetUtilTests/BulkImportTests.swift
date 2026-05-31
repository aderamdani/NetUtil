import XCTest
@testable import NetUtil

final class BulkImportTests: XCTestCase {
    
    func testParsingHosts() {
        let input = "google.com\n1.1.1.1\n\ncloudflare.com\n  8.8.8.8\n\ngoogle.com"
        
        let expected = ["google.com", "1.1.1.1", "cloudflare.com", "8.8.8.8"]
        
        let result = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .unique()
        
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result, expected)
    }
    
    func testEmptyInput() {
        let input = ""
        let result = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .unique()
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testDuplicatesAndSpaces() {
        let input = "host1\nhost2\nhost1"
        let result = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .unique()
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result, ["host1", "host2"])
    }
}