import Foundation

struct IPAddressDetails {
    let address: String
    
    var isIPv6: Bool {
        address.contains(":")
    }
    
    var ipClass: String {
        guard !isIPv6 else { return "IPv6" }
        let components = address.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return "Unknown" }
        
        let firstOctet = components[0]
        switch firstOctet {
        case 1...126:   return "A"
        case 128...191: return "B"
        case 192...223: return "C"
        case 224...239: return "D (Multicast)"
        case 240...255: return "E (Experimental)"
        case 127:       return "Loopback"
        default:        return "Unknown"
        }
    }
    
    var isPrivate: Bool {
        guard !isIPv6 else {
            return address.lowercased().starts(with: "fe80") || address.lowercased().starts(with: "fd")
        }
        let components = address.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return false }
        
        let o1 = components[0]
        let o2 = components[1]
        
        // RFC 1918
        if o1 == 10 { return true }
        if o1 == 172 && (16...31).contains(o2) { return true }
        if o1 == 192 && o2 == 168 { return true }
        if o1 == 169 && o2 == 254 { return true } // APIPA
        
        return false
    }
}
