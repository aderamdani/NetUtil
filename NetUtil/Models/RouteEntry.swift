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
        if flags.contains("U") { desc.append("Up") }
        if flags.contains("G") { desc.append("Gateway") }
        if flags.contains("H") { desc.append("Host") }
        if flags.contains("S") { desc.append("Static") }
        if flags.contains("C") { desc.append("Cloned") }
        if flags.contains("W") { desc.append("WasCloned") }
        return desc
    }
}
