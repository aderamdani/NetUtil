import Foundation

/// A single `resolver #N` block from `scutil --dns` — the actual DNS servers
/// macOS will query, which domain(s) they're scoped to, and whether the
/// system currently sees them as reachable.
struct DNSResolverEntry: Identifiable {
    let id = UUID()
    let index: Int
    let domain: String?
    let searchDomains: [String]
    var nameservers: [String]
    let interface: String?
    let isReachable: Bool
    let isScoped: Bool
    var latencyMs: [String: Double] = [:]

    var scopeLabel: String {
        guard isScoped else { return "General" }
        return interface.map { "Scoped (\($0))" } ?? "Scoped"
    }
}

extension DNSResolverEntry {
    /// Parses the full text output of `scutil --dns`. The command prints two
    /// sections back to back — general resolvers, then a "(for scoped
    /// queries)" section restricted to specific interfaces — separated by a
    /// blank `resolver #` block boundary that this walks line by line.
    nonisolated static func parse(_ output: String) -> [DNSResolverEntry] {
        var entries: [DNSResolverEntry] = []
        var isScopedSection = false

        var index: Int?
        var domain: String?
        var searchDomains: [String] = []
        var nameservers: [String] = []
        var interface: String?
        var isReachable = false

        func flush() {
            guard let index else { return }
            entries.append(DNSResolverEntry(index: index, domain: domain, searchDomains: searchDomains,
                                             nameservers: nameservers, interface: interface,
                                             isReachable: isReachable, isScoped: isScopedSection))
        }
        func resetBlock() {
            index = nil; domain = nil; searchDomains = []; nameservers = []
            interface = nil; isReachable = false
        }

        for rawLine in output.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("DNS configuration (for scoped queries)") {
                flush(); resetBlock(); isScopedSection = true
                continue
            }
            if line.hasPrefix("DNS configuration") {
                flush(); resetBlock(); isScopedSection = false
                continue
            }
            if line.hasPrefix("resolver #") {
                flush(); resetBlock()
                index = Int(line.dropFirst("resolver #".count).trimmingCharacters(in: .whitespaces))
                continue
            }
            guard index != nil, let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)

            if key.hasPrefix("nameserver") {
                nameservers.append(value)
            } else if key.hasPrefix("search domain") {
                searchDomains.append(value)
            } else if key == "domain" {
                domain = value
            } else if key == "if_index" {
                if let open = value.firstIndex(of: "("), let close = value.firstIndex(of: ")") {
                    interface = String(value[value.index(after: open)..<close])
                } else {
                    interface = value
                }
            } else if key == "reach" {
                isReachable = value.contains("Reachable") && !value.contains("Not Reachable")
            }
        }
        flush()
        return entries
    }
}
