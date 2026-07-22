import Foundation

/// One row of the system ARP table (`arp -an`).
struct ARPEntry: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    /// nil when the kernel has an unresolved ("incomplete") entry.
    let mac: String?
    let interface: String
    let isPermanent: Bool

    enum Kind { case host, broadcast, multicast }

    var kind: Kind {
        if ip.hasSuffix(".255") || mac == "ff:ff:ff:ff:ff:ff" { return .broadcast }
        if let first = ip.components(separatedBy: ".").first.flatMap(Int.init),
           (224...239).contains(first) { return .multicast }
        return .host
    }

    /// Parses `arp -an` output, e.g.
    /// `? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]`
    /// `? (192.168.1.50) at (incomplete) on en0 ifscope [ethernet]`
    nonisolated static func parse(_ output: String) -> [ARPEntry] {
        output.components(separatedBy: "\n").compactMap { line in
            guard let ipStart = line.firstIndex(of: "("),
                  let ipEnd = line.firstIndex(of: ")"),
                  ipStart < ipEnd,
                  let atRange = line.range(of: " at "),
                  let onRange = line.range(of: " on ") else { return nil }
            let ip = String(line[line.index(after: ipStart)..<ipEnd])
            let macToken = String(line[atRange.upperBound..<onRange.lowerBound])
            let afterOn = line[onRange.upperBound...]
            guard let iface = afterOn.split(separator: " ").first else { return nil }
            return ARPEntry(ip: ip,
                            mac: macToken == "(incomplete)" ? nil : macToken,
                            interface: String(iface),
                            isPermanent: line.contains(" permanent "))
        }
    }
}
