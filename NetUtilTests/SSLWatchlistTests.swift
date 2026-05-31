import XCTest
@testable import NetUtil

final class SSLWatchlistTests: XCTestCase {
    var sut: SSLWatchlist!

    override func setUp() {
        super.setUp()
        sut = SSLWatchlist()
        UserDefaults.standard.removeObject(forKey: "com.netutil.sslWatchlist")
        sut.items = []
    }

    func testAddDomain() {
        sut.add(domain: "google.com")
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.domain, "google.com")
    }

    func testRemoveDomain() {
        sut.add(domain: "google.com")
        sut.remove(id: sut.items[0].id)
        XCTAssertEqual(sut.items.count, 0)
    }

    func testCalculateStatus() {
        let now = Date()
        
        let safeDate = Calendar.current.date(byAdding: .day, value: 45, to: now)!
        XCTAssertEqual(sut.calculateStatus(expiryDate: safeDate), .safe)
        
        let warningDate = Calendar.current.date(byAdding: .day, value: 20, to: now)!
        XCTAssertEqual(sut.calculateStatus(expiryDate: warningDate), .warning)
        
        let criticalDate = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        XCTAssertEqual(sut.calculateStatus(expiryDate: criticalDate), .critical)
        
        let expiredDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(sut.calculateStatus(expiryDate: expiredDate), .expired)
    }
}
