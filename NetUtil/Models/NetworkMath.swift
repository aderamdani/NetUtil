import Foundation

struct SubnetResult: Identifiable {
    let id = UUID()
    let address: String
    let mask: String
    let prefix: Int
    
    let networkAddress: String
    let broadcastAddress: String
    let firstHost: String
    let lastHost: String
    let totalHosts: UInt32
    let usableHosts: UInt32
    let wildcardMask: String
    let binaryMask: String
    let ipClass: String
}

struct NetworkMath {
    static func calculateSubnet(ip: String, prefix: Int) -> SubnetResult? {
        guard let ipAddr = IPv4Address(ip) else { return nil }
        
        let maskValue: UInt32 = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix))
        let wildcardValue = ~maskValue
        
        let networkValue = ipAddr.value & maskValue
        let broadcastValue = networkValue | wildcardValue
        
        let firstHostValue = networkValue + 1
        let lastHostValue = broadcastValue - 1
        
        let totalHosts = prefix >= 31 ? (prefix == 32 ? 1 : 2) : UInt32(pow(2.0, Double(32 - prefix)))
        let usableHosts = prefix >= 31 ? 0 : totalHosts - 2
        
        return SubnetResult(
            address: ip,
            mask: IPv4Address(maskValue).string,
            prefix: prefix,
            networkAddress: IPv4Address(networkValue).string,
            broadcastAddress: IPv4Address(broadcastValue).string,
            firstHost: prefix >= 31 ? "N/A" : IPv4Address(firstHostValue).string,
            lastHost: prefix >= 31 ? "N/A" : IPv4Address(lastHostValue).string,
            totalHosts: totalHosts,
            usableHosts: usableHosts,
            wildcardMask: IPv4Address(wildcardValue).string,
            binaryMask: toBinary(maskValue),
            ipClass: detectClass(ipAddr.value)
        )
    }
    
    private static func toBinary(_ value: UInt32) -> String {
        let s = String(value, radix: 2)
        let padded = String(repeating: "0", count: 32 - s.count) + s
        var result = ""
        for (i, char) in padded.enumerated() {
            if i > 0 && i % 8 == 0 { result += "." }
            result.append(char)
        }
        return result
    }
    
    private static func detectClass(_ value: UInt32) -> String {
        let firstOctet = value >> 24
        if firstOctet <= 126 { return "A" }
        if firstOctet == 127 { return "Loopback" }
        if firstOctet <= 191 { return "B" }
        if firstOctet <= 223 { return "C" }
        if firstOctet <= 239 { return "D (Multicast)" }
        return "E (Experimental)"
    }
    
    static func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f K", bps / 1024) }
        if bps < 1_073_741_824 { return String(format: "%.2f M", bps / 1_048_576) }
        return String(format: "%.2f G", bps / 1_073_741_824)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes < 1_099_511_627_776 { return String(format: "%.2f GB", Double(bytes) / 1_073_741_824) }
        return String(format: "%.2f TB", Double(bytes) / 1_099_511_627_776)
    }
}

struct IPv4Address {
    let value: UInt32
    
    init?(_ string: String) {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var val: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            val = (val << 8) | octet
        }
        self.value = val
    }
    
    init(_ value: UInt32) {
        self.value = value
    }
    
    var string: String {
        let o1 = (value >> 24) & 0xFF
        let o2 = (value >> 16) & 0xFF
        let o3 = (value >> 8) & 0xFF
        let o4 = value & 0xFF
        return "\(o1).\(o2).\(o3).\(o4)"
    }
}
