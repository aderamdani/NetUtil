import Foundation

/// Session-lifetime cache for ipinfo.io lookups shared by every tool that
/// resolves an address (Traceroute hop geolocation, IP Geolocation). Caches
/// results per target and deduplicates concurrent requests so N callers asking
/// for the same address make one network call.
actor GeoLookupCache {
    static let shared = GeoLookupCache()

    private var cache: [String: IPGeoResult] = [:]
    private var inFlight: [String: Task<IPGeoResult?, Never>] = [:]

    /// `target` is an IP or hostname; an empty string means "this Mac's public
    /// IP". Returns a cached result when available.
    func lookup(_ target: String) async -> IPGeoResult? {
        let key = target.isEmpty ? "\u{0}self" : target
        if let hit = cache[key] { return hit }
        if let task = inFlight[key] { return await task.value }
        let task = Task<IPGeoResult?, Never> { await Self.fetch(target) }
        inFlight[key] = task
        let value = await task.value
        inFlight[key] = nil
        if let value { cache[key] = value }
        return value
    }

    /// Seeds the cache from a result fetched elsewhere (e.g. ToolStore's
    /// public-IP lookup on launch).
    func store(_ result: IPGeoResult) {
        cache[result.ip] = result
    }

    private nonisolated static func fetch(_ target: String) async -> IPGeoResult? {
        let path = target.isEmpty
            ? "json"
            : "\(target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target)/json"
        guard let url = URL(string: "https://ipinfo.io/\(path)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return IPGeoResult.parse(data)
        } catch {
            return nil
        }
    }
}
