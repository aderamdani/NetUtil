import Foundation

enum WakeOnLanError: LocalizedError, Equatable {
    case invalidMAC
    case invalidBroadcastAddress
    case socketFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidMAC:              "Invalid MAC address — expected 6 pairs like AA:BB:CC:DD:EE:FF"
        case .invalidBroadcastAddress: "Invalid broadcast address — expected an IPv4 address"
        case .socketFailed(let why):   "Could not send packet: \(why)"
        }
    }
}

enum WakeOnLan {
    /// Accepts `AA:BB:CC:DD:EE:FF`, `aa-bb-cc-dd-ee-ff`, or 12 bare hex digits.
    static func parseMAC(_ input: String) -> [UInt8]? {
        let hex = input.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    /// Magic packet: 6 × 0xFF followed by the MAC repeated 16 times.
    static func magicPacket(mac: [UInt8]) -> Data {
        var data = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { data.append(contentsOf: mac) }
        return data
    }

    /// Sends the magic packet as a UDP broadcast datagram via a BSD socket —
    /// NWConnection cannot enable SO_BROADCAST for 255.255.255.255.
    static func send(mac: String, broadcast: String, port: UInt16) throws {
        guard let macBytes = parseMAC(mac) else { throw WakeOnLanError.invalidMAC }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, broadcast, &addr.sin_addr) == 1 else {
            throw WakeOnLanError.invalidBroadcastAddress
        }

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw WakeOnLanError.socketFailed(String(cString: strerror(errno))) }
        defer { close(fd) }

        var enable: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw WakeOnLanError.socketFailed(String(cString: strerror(errno)))
        }

        let packet = magicPacket(mac: macBytes)
        let sent = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else {
            throw WakeOnLanError.socketFailed(String(cString: strerror(errno)))
        }
    }
}
