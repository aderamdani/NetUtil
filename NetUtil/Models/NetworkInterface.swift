import Foundation
import Darwin

struct NetworkInterface: Identifiable {
    let id = UUID()
    let name: String
    let ipv4: [String]
    let ipv6: [String]
    let netmasks: [String]
    let mac: String?
    let mtu: Int?
    let isUp: Bool
    let isLoopback: Bool
    let ifType: UInt8
    
    var ipAddress: String? { ipv4.first }

    /// True for a real, user-facing IPv4 link — excludes loopback and the
    /// virtual/tunnel interfaces (VPN, AWDL/AirDrop, low-latency Wi-Fi,
    /// bridges) that shouldn't be surfaced as "the" primary interface.
    var isPrimaryCandidate: Bool {
        isUp && !isLoopback && !ipv4.isEmpty &&
        !name.hasPrefix("utun") && !name.hasPrefix("ipsec") &&
        !name.hasPrefix("awdl") && !name.hasPrefix("llw") &&
        !name.hasPrefix("bridge") && !name.hasPrefix("tun") &&
        !name.hasPrefix("tap")
    }

    /// The single interface the app treats as "primary" — first candidate,
    /// in fetch order. Shared by ToolStore and MenuBarView so they can't diverge.
    static func primary(in interfaces: [NetworkInterface]) -> NetworkInterface? {
        interfaces.first { $0.isPrimaryCandidate }
    }

    // VLAN Details
    var isVLAN: Bool { name.hasPrefix("vlan") }
    var vlanTag: Int?
    var parentInterface: String?

    var typeIcon: String {
        if isVLAN { return "tag.fill" }
        if isLoopback { return "arrow.clockwise" }
        switch ifType {
        case 6:   return "cable.connector"       // IFT_ETHER
        case 161: return "wifi"                  // IFT_IEEE80211
        case 23, 150: return "phone.connection"  // IFT_PPP / cellular
        case 131: return "lock.shield"           // IFT_TUNNEL
        default:
            if name.hasPrefix("utun") || name.hasPrefix("ipsec") { return "lock.shield" }
            if name.hasPrefix("awdl") || name.hasPrefix("llw")   { return "wifi" }
            return "network"
        }
    }

    var typeName: String {
        if isVLAN { return "VLAN Interface" }
        if isLoopback { return "Loopback" }
        switch ifType {
        case 6:   return "Ethernet"
        case 161: return "Wi-Fi"
        case 23:  return "PPP"
        case 131: return "Tunnel"
        default:
            if name.hasPrefix("utun")  { return "VPN" }
            if name.hasPrefix("awdl")  { return "AWDL" }
            if name.hasPrefix("llw")   { return "Low-Latency WLAN" }
            return "Other"
        }
    }
}

// MARK: - Fetcher

struct NetworkInterfaceFetcher {
    private static var vlanCache: [String: (tag: Int?, parent: String?)] = [:]
    
    static func fetch() -> [NetworkInterface] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var builders: [String: Builder] = [:]

        var ptr = ifaddr
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }
            let name = String(cString: ifa.pointee.ifa_name)

            if builders[name] == nil {
                builders[name] = Builder(name: name, flags: ifa.pointee.ifa_flags)
            }

            guard let addr = ifa.pointee.ifa_addr else { continue }
            let family = addr.pointee.sa_family

            switch Int32(family) {
            case AF_INET:
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in>.size),
                            &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                builders[name]?.ipv4.append(string(from: buf))
                
                if let netmask = ifa.pointee.ifa_netmask {
                    var mbuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(netmask, socklen_t(MemoryLayout<sockaddr_in>.size),
                                &mbuf, socklen_t(mbuf.count), nil, 0, NI_NUMERICHOST)
                    builders[name]?.netmasks.append(string(from: mbuf))
                }

            case AF_INET6:
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in6>.size),
                            &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                let raw = string(from: buf)
                let clean = raw.components(separatedBy: "%").first ?? raw
                builders[name]?.ipv6.append(clean)

            case AF_LINK:
                addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dlPtr in
                    let dl = dlPtr.pointee
                    if dl.sdl_alen == 6 {
                        let nlen = Int(dl.sdl_nlen)
                        withUnsafeBytes(of: dl.sdl_data) { rawPtr in
                            guard nlen + 6 <= rawPtr.count else { return }
                            let mac = (nlen..<nlen+6)
                                .map { String(format: "%02x", rawPtr[$0]) }
                                .joined(separator: ":")
                            builders[name]?.mac = mac
                        }
                    }
                }
                if let data = ifa.pointee.ifa_data {
                    let ifdata = data.assumingMemoryBound(to: if_data.self).pointee
                    builders[name]?.mtu    = Int(ifdata.ifi_mtu)
                    builders[name]?.ifType = ifdata.ifi_type
                }

            default:
                break
            }
        }

        var results = builders.values.map { $0.build() }
        
        // Enrich VLAN interfaces with details from ifconfig (cached)
        for i in 0..<results.count {
            if results[i].isVLAN {
                let name = results[i].name
                if let cached = vlanCache[name] {
                    results[i].vlanTag = cached.tag
                    results[i].parentInterface = cached.parent
                } else {
                    let (tag, parent) = fetchVLANDetails(for: name)
                    vlanCache[name] = (tag, parent)
                    results[i].vlanTag = tag
                    results[i].parentInterface = parent
                }
            }
        }

        return results.sorted { $0.name < $1.name }
    }

    /// Decodes a NUL-terminated C buffer (e.g. from getnameinfo) into a String.
    private static func string(from buf: [CChar]) -> String {
        String(decoding: buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func fetchVLANDetails(for name: String) -> (tag: Int?, parent: String?) {
        let output = SubprocessRunner.run(executable: "/sbin/ifconfig", arguments: [name])

        // Expected line: "vlan: 10 parent interface: en0"
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("vlan:") && line.contains("parent interface:") {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                var tag: Int? = nil
                var parent: String? = nil

                if let tagIdx = parts.firstIndex(of: "vlan:"), tagIdx + 1 < parts.count {
                    tag = Int(parts[tagIdx + 1].trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
                }
                if let parentIdx = parts.firstIndex(of: "interface:"), parentIdx + 1 < parts.count {
                    parent = parts[parentIdx + 1]
                }
                return (tag, parent)
            }
        }
        return (nil, nil)
    }

    private struct Builder {
        let name: String
        let flags: UInt32
        var ipv4: [String] = []
        var ipv6: [String] = []
        var netmasks: [String] = []
        var mac: String?
        var mtu: Int?
        var ifType: UInt8 = 0

        func build() -> NetworkInterface {
            NetworkInterface(
                name: name,
                ipv4: ipv4,
                ipv6: ipv6,
                netmasks: netmasks,
                mac: mac,
                mtu: mtu,
                isUp: flags & UInt32(IFF_UP) != 0,
                isLoopback: flags & UInt32(IFF_LOOPBACK) != 0,
                ifType: ifType
            )
        }
    }
}
