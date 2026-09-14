import Foundation

/// Offline, best-effort OUI ("vendor") lookup for MAC addresses. Covers the
/// vendors most likely to show up on a home or office LAN; unknown prefixes
/// return nil rather than guessing.
enum OUILookup {
    /// Prefix (first three octets) → (vendor, device category).
    private nonisolated static let vendors: [String: (name: String, category: String)] = [
        // Apple
        "00:03:93": ("Apple", "Computer"), "00:1B:63": ("Apple", "Computer"),
        "00:1E:C2": ("Apple", "Computer"), "00:23:DF": ("Apple", "Computer"),
        "3C:07:54": ("Apple", "Computer"), "68:AB:1E": ("Apple", "Computer"),
        "8C:85:90": ("Apple", "Computer"), "AC:DE:48": ("Apple", "Computer"),
        "B8:E8:56": ("Apple", "Computer"), "F0:18:98": ("Apple", "Computer"),
        "DC:A9:04": ("Apple", "Computer"), "F4:F1:5A": ("Apple", "Computer"),
        // Phones / tablets
        "00:12:FB": ("Samsung", "Phone"), "5C:0A:5B": ("Samsung", "Phone"),
        "78:1F:DB": ("Samsung", "Phone"), "E8:50:8B": ("Samsung", "Phone"),
        "64:09:80": ("Xiaomi", "Phone"), "78:11:DC": ("Xiaomi", "Phone"),
        "28:3C:E4": ("Huawei", "Phone"), "48:DB:50": ("Huawei", "Phone"),
        // Computers
        "00:1E:64": ("Intel", "Computer"), "34:02:86": ("Intel", "Computer"),
        "48:51:B7": ("Intel", "Computer"), "7C:7A:91": ("Intel", "Computer"),
        "F8:16:54": ("Intel", "Computer"), "B8:27:EB": ("Raspberry Pi", "Computer"),
        "DC:A6:32": ("Raspberry Pi", "Computer"), "E4:5F:01": ("Raspberry Pi", "Computer"),
        // Routers / networking
        "14:CC:20": ("TP-Link", "Router"), "50:C7:BF": ("TP-Link", "Router"),
        "B0:48:7A": ("TP-Link", "Router"), "EC:08:6B": ("TP-Link", "Router"),
        "20:E5:2A": ("Netgear", "Router"), "A0:40:A0": ("Netgear", "Router"),
        "C4:04:15": ("Netgear", "Router"), "00:1A:A1": ("Cisco", "Router"),
        "2C:3F:38": ("Cisco", "Router"), "04:18:D6": ("Ubiquiti", "Router"),
        "24:A4:3C": ("Ubiquiti", "Router"), "78:8A:20": ("Ubiquiti", "Router"),
        "00:1B:11": ("D-Link", "Router"), "1C:7E:E5": ("D-Link", "Router"),
        "C8:3A:35": ("Tenda", "Router"), "00:13:49": ("Zyxel", "Router"),
        "00:0C:6E": ("ASUS", "Router"), "2C:56:DC": ("ASUS", "Router"),
        // Media / streaming
        "20:DF:B9": ("Google", "Media"), "F4:F5:D8": ("Google", "Media"),
        "18:B4:30": ("Nest", "Media"), "44:65:0D": ("Amazon", "Media"),
        "74:C2:46": ("Amazon", "Media"), "F0:27:2D": ("Amazon", "Media"),
        "00:0D:4B": ("Roku", "Media"), "AC:3A:7A": ("Roku", "Media"),
        "00:1C:62": ("LG", "Media"), "A8:16:B2": ("LG", "Media"),
        "00:13:A9": ("Sony", "Media"), "FC:F1:52": ("Sony", "Media"),
        // Speakers
        "00:0E:58": ("Sonos", "Speaker"), "5C:AA:FD": ("Sonos", "Speaker"),
        "78:28:CA": ("Sonos", "Speaker"), "B8:E9:37": ("Sonos", "Speaker"),
        // Smart home / IoT
        "24:0A:C4": ("Espressif", "IoT"), "30:AE:A4": ("Espressif", "IoT"),
        "84:CC:A8": ("Espressif", "IoT"), "A4:CF:12": ("Espressif", "IoT"),
        "0C:47:C9": ("Ring", "Camera"), "54:E0:19": ("Ring", "Camera"),
        // Printers
        "00:1F:29": ("HP", "Printer"), "94:57:A5": ("HP", "Printer"),
        "00:80:77": ("Brother", "Printer"), "30:05:5C": ("Brother", "Printer"),
        "00:1E:8F": ("Canon", "Printer"), "00:26:AB": ("Epson", "Printer"),
        // NAS
        "00:11:32": ("Synology", "NAS"), "24:5E:BE": ("Synology", "NAS"),
        "00:08:9B": ("QNAP", "NAS"), "00:14:EE": ("Western Digital", "NAS")
    ]

    nonisolated static func vendor(for mac: String) -> String? {
        entry(for: mac)?.name
    }

    nonisolated static func deviceCategory(for mac: String) -> String? {
        entry(for: mac)?.category
    }

    nonisolated private static func entry(for mac: String) -> (name: String, category: String)? {
        let normalized = mac.uppercased().replacingOccurrences(of: "-", with: ":")
        let parts = normalized.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let prefix = parts.prefix(3).joined(separator: ":")
        return vendors[prefix]
    }
}
