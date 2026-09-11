import Foundation

/// A fixed-capacity ring buffer for time-series metric samples.
///
/// Backs the app's live charts (aggregate throughput, per-interface
/// sparklines) with O(1) appends and no per-tick array shifting. Once the
/// buffer is full the oldest sample is overwritten, so memory stays flat no
/// matter how long sampling runs.
///
/// A value type: mutating `push(_:)` on a stored property is enough for
/// `@Observable` to see the change, so views bound to the derived arrays
/// still refresh.
struct MetricHistory<Element> {
    private var storage: [Element] = []
    private var head = 0          // index of the oldest element once full
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    var isEmpty: Bool { storage.isEmpty }
    var count: Int { storage.count }

    /// Appends a sample, overwriting the oldest once capacity is reached.
    mutating func push(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    /// Samples in chronological order (oldest → newest).
    var values: [Element] {
        guard storage.count == capacity else { return storage }
        var result = [Element]()
        result.reserveCapacity(capacity)
        for offset in 0..<capacity {
            result.append(storage[(head + offset) % capacity])
        }
        return result
    }

    /// The most recent sample, if any.
    var last: Element? {
        guard !storage.isEmpty else { return nil }
        guard storage.count == capacity else { return storage.last }
        return storage[(head + capacity - 1) % capacity]
    }

    /// The most recent `k` samples in chronological order.
    func suffix(_ k: Int) -> [Element] { Array(values.suffix(k)) }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
    }
}

extension MetricHistory: Sendable where Element: Sendable {}
