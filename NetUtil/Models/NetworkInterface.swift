import Foundation
import Darwin

struct NetworkInterface: Identifiable {
    let id = UUID()
    let name: String
    let ipv4: [String]
    let ipv6: [String]
    let mac: String?
    let mtu: Int?
    let isUp: Bool
    let isLoopback: Bool
    let ifType: UInt8

    var typeIcon: String {
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
                builders[name]?.ipv4.append(String(cString: buf))

            case AF_INET6:
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in6>.size),
                            &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                let raw = String(cString: buf)
                // Strip link-local scope suffix (e.g. %en0)
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

        return builders.values.map { $0.build() }
            .sorted { $0.name < $1.name }
    }

    private struct Builder {
        let name: String
        let flags: UInt32
        var ipv4: [String] = []
        var ipv6: [String] = []
        var mac: String?
        var mtu: Int?
        var ifType: UInt8 = 0

        func build() -> NetworkInterface {
            NetworkInterface(
                name: name,
                ipv4: ipv4,
                ipv6: ipv6,
                mac: mac,
                mtu: mtu,
                isUp: flags & UInt32(IFF_UP) != 0,
                isLoopback: flags & UInt32(IFF_LOOPBACK) != 0,
                ifType: ifType
            )
        }
    }
}
