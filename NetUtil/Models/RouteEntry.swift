import Foundation

struct RouteEntry: Identifiable {
    let id = UUID()
    let destination: String
    let gateway: String
    let flags: String
    let netif: String
    let isIPv6: Bool

    var isDefault: Bool { destination == "default" || destination == "0.0.0.0" || destination == "::" }
}
