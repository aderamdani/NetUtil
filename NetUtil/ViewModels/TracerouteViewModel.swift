import Foundation
import Combine
import CoreLocation

@MainActor
class TracerouteViewModel: ObservableObject {
    @Published var hops: [TracerouteHop] = []
    @Published var isRunning = false
    @Published var rawLines: [String] = []
    @Published var error: String?
    @Published var round = 0
    @Published var currentHost: String = ""
    @Published var startTime: Date?

    var pathAvgRtt: Double? {
        let avgs = hops.compactMap(\.avgRtt)
        guard !avgs.isEmpty else { return nil }
        return avgs.reduce(0, +) / Double(avgs.count)
    }
    var pathLoss: Double { hops.map(\.loss).max() ?? 0 }

    private var interval: Double = 5
    private var maxHops: Int = 30
    private var targetHost: String = ""
    private var process: Process?
    private var outputPipe: Pipe?
    private var pendingHops: [TracerouteHop] = []

    private static let rawLinesLimit = 500
    private var geoCache: [String: GeoInfo] = [:]
    private var geoInFlight: Set<String> = []

    deinit {
        process?.terminate()
    }

    func start(host: String, maxHops: Int, interval: Double) {
        stop()
        hops.removeAll()
        geoCache.removeAll()
        geoInFlight.removeAll()
        rawLines.removeAll()
        error = nil
        round = 0
        startTime = Date()
        targetHost = host
        currentHost = host
        self.maxHops = maxHops
        self.interval = interval
        isRunning = true
        runOnce()
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
    }

    private func runOnce() {
        pendingHops = []

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
        p.arguments = ["-m", "\(maxHops)", targetHost]
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            guard let self else { return }
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            let parsed = lines.compactMap { Self.parseLine($0) }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rawLines.append(contentsOf: lines)
                if self.rawLines.count > Self.rawLinesLimit {
                    self.rawLines.removeFirst(self.rawLines.count - Self.rawLinesLimit)
                }
                self.pendingHops.append(contentsOf: parsed)
            }
        }

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.mergeRound()
                self.lookupGeoForNewHops()
                self.round += 1
                guard self.isRunning else { return }
                try? await Task.sleep(for: .seconds(self.interval))
                guard self.isRunning else { return }
                self.runOnce()
            }
        }

        process = p
        outputPipe = pipe

        do {
            try p.run()
        } catch {
            self.error = error.localizedDescription
            isRunning = false
        }
    }

    private func mergeRound() {
        let now = Date()
        for newHop in pendingHops {
            if let idx = hops.firstIndex(where: { $0.hop == newHop.hop }) {
                hops[idx].host = newHop.host ?? hops[idx].host
                hops[idx].ip = newHop.ip ?? hops[idx].ip
                hops[idx].rtts = newHop.rtts
                hops[idx].lastSeen = now
                hops[idx].appendRound(newHop.rtts, at: now)
            } else {
                var h = newHop
                h.lastSeen = now
                h.appendRound(newHop.rtts, at: now)
                hops.append(h)
            }
        }
        hops.sort { $0.hop < $1.hop }
        detectBottlenecks()
    }

    private func detectBottlenecks() {
        guard hops.count > 1 else { return }
        var prevAvg: Double? = nil
        for i in 0..<hops.count {
            guard let curr = hops[i].avgRtt else { prevAvg = nil; continue }
            if let prev = prevAvg {
                let delta = curr - prev
                hops[i].isBottleneck = delta > 30 && curr > 50
            } else {
                hops[i].isBottleneck = false
            }
            prevAvg = curr
        }
    }

    private func lookupGeoForNewHops() {
        guard UserDefaults.standard.object(forKey: "geoEnabled") as? Bool != false else { return }
        let ipsNeeded = hops.compactMap { hop -> String? in
            guard let ip = hop.ip, hop.geo == nil,
                  !geoInFlight.contains(ip),
                  !Self.isPrivateIP(ip) else { return nil }
            return ip
        }
        for ip in ipsNeeded {
            geoInFlight.insert(ip)
            Task {
                let geo = await Self.fetchGeo(ip: ip)
                geoCache[ip] = geo
                geoInFlight.remove(ip)
                if let geo, let idx = hops.firstIndex(where: { $0.ip == ip }) {
                    hops[idx].geo = geo
                }
            }
        }
    }

    private nonisolated static func isPrivateIP(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return ip.hasPrefix("::") || ip.hasPrefix("fe80") || ip.hasPrefix("fc") || ip.hasPrefix("fd")
        }
        switch parts[0] {
        case 10:  return true
        case 127: return true
        case 172: return (16...31).contains(parts[1])
        case 192: return parts[1] == 168
        default:  return false
        }
    }

    private nonisolated static func fetchGeo(ip: String) async -> GeoInfo? {
        struct GeoResponse: Decodable {
            let city, country, org, hostname, loc, postal, timezone: String?
        }
        
        guard let url = URL(string: "https://ipinfo.io/\(ip)/json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeoResponse.self, from: data)
            
            var coord: CLLocationCoordinate2D?
            if let loc = response.loc {
                let parts = loc.split(separator: ",").compactMap { Double($0) }
                if parts.count == 2 { coord = CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1]) }
            }
            return GeoInfo(country: response.country ?? "", city: response.city ?? "", org: response.org ?? "",
                           hostname: response.hostname, postal: response.postal, timezone: response.timezone,
                           coordinate: coord)
        } catch { return nil }
    }

    nonisolated static func parseLine(_ line: String) -> TracerouteHop? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Standard traceroute line: 1  192.168.1.1 (192.168.1.1)  0.345 ms  0.211 ms  0.198 ms
        // Or multi-IP: 2  * * *
        // Or mixed: 3  as-5.example.net (1.2.3.4)  10.5 ms * 11.2 ms
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.count >= 2, let hopNum = Int(tokens[0]) else { return nil }

        var host: String?
        var ip: String?
        var rtts: [Double?] = []
        
        // Use a more robust token iterator
        var i = 1
        while i < tokens.count {
            let t = tokens[i]
            
            // Check for timeout
            if t == "*" {
                rtts.append(nil)
                i += 1
                continue
            }
            
            // Check for IP in parentheses (most common format)
            if t.hasPrefix("(") && t.hasSuffix(")") {
                ip = String(t.dropFirst().dropLast())
                i += 1
                continue
            }
            
            // Check for RTT values
            if let val = Double(t) {
                // Peek at next token to see if it's "ms"
                if i + 1 < tokens.count && tokens[i+1].lowercased() == "ms" {
                    rtts.append(val)
                    i += 2
                    continue
                }
            }
            
            // If we don't have a host yet and it's not "ms", assume this is the hostname
            if host == nil && t.lowercased() != "ms" {
                host = t
            }
            
            i += 1
        }

        // If ip is missing but host looks like an IP, swap them
        if ip == nil, let h = host, h.range(of: #"^\d+\.\d+\.\d+\.\d+$"#, options: .regularExpression) != nil {
            ip = h
        }

        return TracerouteHop(hop: hopNum, host: host, ip: ip, rtts: rtts, samples: [])
    }
}
