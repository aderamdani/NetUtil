import Foundation
import AppKit
import UniformTypeIdentifiers

enum Exporter {

    // MARK: - Ping

    static func csvString(from results: [PingResult]) -> String {
        var lines = ["timestamp,sequence,host,bytes,ttl,rtt_ms"]
        let fmt = ISO8601DateFormatter()
        for r in results {
            lines.append("\(fmt.string(from: r.timestamp)),\(r.sequence),\(r.host),\(r.bytes),\(r.ttl),\(r.rtt)")
        }
        return lines.joined(separator: "\n")
    }

    static func jsonData(from results: [PingResult]) throws -> Data {
        let fmt = ISO8601DateFormatter()
        let payload = results.map { r -> [String: Any] in
            ["timestamp": fmt.string(from: r.timestamp),
             "sequence": r.sequence,
             "host": r.host,
             "bytes": r.bytes,
             "ttl": r.ttl,
             "rtt_ms": r.rtt]
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Traceroute

    static func csvString(from hops: [TracerouteHop]) -> String {
        var lines = ["hop,host,ip,sent,loss_pct,last_ms,avg_ms,best_ms,worst_ms,updated"]
        let fmt = ISO8601DateFormatter()
        for h in hops {
            let lastMs  = h.lastRtt.map { String(format: "%.2f", $0) } ?? ""
            let avgMs   = h.avgRtt.map  { String(format: "%.2f", $0) } ?? ""
            let bestMs  = h.minRtt.map  { String(format: "%.2f", $0) } ?? ""
            let worstMs = h.maxRtt.map  { String(format: "%.2f", $0) } ?? ""
            let row = ["\(h.hop)", h.host ?? "", h.ip ?? "", "\(h.sent)",
                       String(format: "%.1f", h.loss),
                       lastMs, avgMs, bestMs, worstMs, fmt.string(from: h.lastSeen)]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func jsonData(from hops: [TracerouteHop]) throws -> Data {
        let fmt = ISO8601DateFormatter()
        let payload = hops.map { h -> [String: Any] in
            var d: [String: Any] = [
                "hop": h.hop,
                "sent": h.sent,
                "loss_pct": h.loss,
                "updated": fmt.string(from: h.lastSeen)
            ]
            if let host = h.host { d["host"] = host }
            if let ip   = h.ip   { d["ip"] = ip }
            if let v = h.lastRtt { d["last_ms"] = v }
            if let v = h.avgRtt  { d["avg_ms"]  = v }
            if let v = h.minRtt  { d["best_ms"] = v }
            if let v = h.maxRtt  { d["worst_ms"] = v }
            d["samples"] = h.samples.map { s -> [String: Any] in
                var sd: [String: Any] = ["timestamp": fmt.string(from: s.timestamp)]
                if let rtt = s.rtt { sd["rtt_ms"] = rtt }
                return sd
            }
            return d
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Save panel

    static func save(string: String, defaultName: String, ext: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.init(filenameExtension: ext)!]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? string.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func save(data: Data, defaultName: String, ext: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.init(filenameExtension: ext)!]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}
