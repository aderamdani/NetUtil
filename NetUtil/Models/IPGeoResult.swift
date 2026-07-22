import Foundation
import CoreLocation

/// Geolocation + ownership details for a single IP address, as reported by
/// ipinfo.io. Used by both the IP Geolocation tool (arbitrary lookups) and
/// ToolStore's cached lookup for this Mac's own public IP.
struct IPGeoResult {
    let ip: String
    let hostname: String?
    let city: String
    let region: String
    let country: String
    let org: String
    let postal: String?
    let timezone: String?
    let coordinate: CLLocationCoordinate2D?

    /// `org` is formatted "AS15169 Google LLC" by ipinfo.io — split it into
    /// the ASN and the operator name for display.
    var asn: String? {
        guard org.hasPrefix("AS"), let space = org.firstIndex(of: " ") else { return nil }
        return String(org[org.startIndex..<space])
    }

    var ispName: String {
        guard org.hasPrefix("AS"), let space = org.firstIndex(of: " ") else { return org }
        return String(org[org.index(after: space)...])
    }

    var flag: String {
        let base: UInt32 = 127397
        return country.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map(String.init).joined()
    }

    var shortLabel: String { "\(flag) \(city.isEmpty ? country : city)" }
}

extension IPGeoResult {
    nonisolated static func parse(_ data: Data) -> IPGeoResult? {
        struct Response: Decodable {
            let ip, hostname, city, region, country, org, postal, timezone, loc: String?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let ip = response.ip else { return nil }

        var coordinate: CLLocationCoordinate2D?
        if let loc = response.loc {
            let parts = loc.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { coordinate = CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1]) }
        }

        return IPGeoResult(ip: ip, hostname: response.hostname, city: response.city ?? "",
                            region: response.region ?? "", country: response.country ?? "",
                            org: response.org ?? "", postal: response.postal, timezone: response.timezone,
                            coordinate: coordinate)
    }
}
