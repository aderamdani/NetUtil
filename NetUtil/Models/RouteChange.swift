import Foundation

/// A detected change in the traceroute path between two rounds of the same run.
struct RouteChange: Identifiable {
    let id = UUID()
    let timestamp: Date
    let previousHopCount: Int
    let currentHopCount: Int
    let changedHops: [Int]

    var summary: String {
        let hops = changedHops.map(String.init).joined(separator: ", ")
        let count: String
        if currentHopCount != previousHopCount {
            count = " (\(previousHopCount) → \(currentHopCount) hops)"
        } else {
            count = ""
        }
        return "Hop\(changedHops.count == 1 ? "" : "s") \(hops) changed\(count)"
    }
}
