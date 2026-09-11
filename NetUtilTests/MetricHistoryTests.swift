import XCTest
@testable import NetUtil

@MainActor
final class MetricHistoryTests: XCTestCase {

    // MARK: - Empty buffer

    func testEmptyBuffer() {
        let buffer = MetricHistory<Int>(capacity: 4)
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertEqual(buffer.values, [])
        XCTAssertNil(buffer.last)
        XCTAssertEqual(buffer.suffix(3), [])
    }

    // MARK: - Partial fill (below capacity)

    func testPartialFillKeepsPushOrder() {
        var buffer = MetricHistory<Int>(capacity: 4)
        buffer.push(10)
        buffer.push(20)
        XCTAssertFalse(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 2)
        XCTAssertEqual(buffer.values, [10, 20])
        XCTAssertEqual(buffer.last, 20)
    }

    // MARK: - Exactly full

    func testExactlyFullKeepsAllInOrder() {
        var buffer = MetricHistory<Int>(capacity: 3)
        buffer.push(1)
        buffer.push(2)
        buffer.push(3)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.values, [1, 2, 3])
        XCTAssertEqual(buffer.last, 3)
    }

    // MARK: - Overflow / wraparound

    func testOverflowOverwritesOldest() {
        var buffer = MetricHistory<Int>(capacity: 3)
        for i in 1...4 { buffer.push(i) }
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.values, [2, 3, 4])
        XCTAssertEqual(buffer.last, 4)
    }

    func testMultipleWraparoundsStayChronological() {
        var buffer = MetricHistory<Int>(capacity: 4)
        for i in 1...9 { buffer.push(i) } // 2 * capacity + 1
        XCTAssertEqual(buffer.count, 4)
        XCTAssertEqual(buffer.values, [6, 7, 8, 9])
        XCTAssertEqual(buffer.last, 9)
    }

    func testRepeatedIdenticalValues() {
        var buffer = MetricHistory<Int>(capacity: 3)
        for _ in 0..<5 { buffer.push(7) }
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.values, [7, 7, 7])
        XCTAssertEqual(buffer.last, 7)
    }

    // MARK: - Capacity edge cases

    func testCapacityOneReplacesSingleElement() {
        var buffer = MetricHistory<Int>(capacity: 1)
        buffer.push(1)
        XCTAssertEqual(buffer.values, [1])
        XCTAssertEqual(buffer.last, 1)
        buffer.push(2)
        XCTAssertEqual(buffer.count, 1)
        XCTAssertEqual(buffer.values, [2])
        XCTAssertEqual(buffer.last, 2)
    }

    func testZeroCapacityClampsToOne() {
        var buffer = MetricHistory<Int>(capacity: 0)
        XCTAssertEqual(buffer.capacity, 1)
        buffer.push(1)
        buffer.push(2)
        XCTAssertEqual(buffer.values, [2])
        XCTAssertEqual(buffer.last, 2)
    }

    func testNegativeCapacityClampsToOne() {
        var buffer = MetricHistory<Int>(capacity: -5)
        XCTAssertEqual(buffer.capacity, 1)
        buffer.push(1)
        XCTAssertEqual(buffer.values, [1])
        XCTAssertEqual(buffer.last, 1)
    }

    // MARK: - suffix(k)

    func testSuffixReturnsLastKInOrder() {
        var buffer = MetricHistory<Int>(capacity: 5)
        for i in 1...5 { buffer.push(i) }
        XCTAssertEqual(buffer.suffix(3), [3, 4, 5])
    }

    func testSuffixLargerThanCountReturnsAll() {
        var buffer = MetricHistory<Int>(capacity: 5)
        buffer.push(1)
        buffer.push(2)
        XCTAssertEqual(buffer.suffix(10), [1, 2])
    }

    func testSuffixZeroReturnsEmpty() {
        var buffer = MetricHistory<Int>(capacity: 5)
        for i in 1...5 { buffer.push(i) }
        XCTAssertEqual(buffer.suffix(0), [])
    }

    func testSuffixAfterWraparound() {
        var buffer = MetricHistory<Int>(capacity: 4)
        for i in 1...7 { buffer.push(i) }
        XCTAssertEqual(buffer.values, [4, 5, 6, 7])
        XCTAssertEqual(buffer.suffix(2), [6, 7])
    }

    // MARK: - removeAll

    func testRemoveAllEmptiesBuffer() {
        var buffer = MetricHistory<Int>(capacity: 3)
        for i in 1...5 { buffer.push(i) }
        buffer.removeAll()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.count, 0)
        XCTAssertEqual(buffer.values, [])
        XCTAssertNil(buffer.last)
    }

    func testPushAfterRemoveAllStartsClean() {
        var buffer = MetricHistory<Int>(capacity: 3)
        for i in 1...5 { buffer.push(i) }
        buffer.removeAll()
        buffer.push(10)
        buffer.push(20)
        XCTAssertEqual(buffer.values, [10, 20])
        XCTAssertEqual(buffer.last, 20)
        // Fill past the old wraparound point: no stale elements may resurface.
        buffer.push(30)
        buffer.push(40)
        XCTAssertEqual(buffer.values, [20, 30, 40])
    }

    // MARK: - Sendable element type

    func testSendableStructElements() {
        struct Sample: Sendable, Equatable {
            let timestamp: Date
            let value: Double
        }
        var buffer = MetricHistory<Sample>(capacity: 2)
        let first = Sample(timestamp: Date(timeIntervalSince1970: 100), value: 1.5)
        let second = Sample(timestamp: Date(timeIntervalSince1970: 200), value: 2.5)
        buffer.push(first)
        buffer.push(second)
        XCTAssertEqual(buffer.values, [first, second])
        XCTAssertEqual(buffer.last, second)
    }
}
