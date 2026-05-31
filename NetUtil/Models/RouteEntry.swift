import Foundation

struct RouteEntry: Identifiable {
    let id = UUID()
    let destination: String
    let gateway: String
    let flags: String
    let netif: String
    let isIPv6: Bool

    var isDefault: Bool { destination == "default" || destination == "0.0.0.0" || destination == "::" }

    var flagDescriptions: [String] {
        var desc: [String] = []
        let f = flags.uppercased()
        if f.contains("U") { desc.append("Up") }
        if f.contains("G") { desc.append("Gateway") }
        if f.contains("H") { desc.append("Host") }
        if f.contains("S") { desc.append("Static") }
        if f.contains("C") { desc.append("Cloned") }
        if f.contains("W") { desc.append("WasCloned") }
        return desc
    }
}
