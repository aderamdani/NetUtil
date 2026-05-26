import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI

enum Exporter {

    // MARK: - Ping Data Generation

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
    
    // MARK: - PDF Export
    
    @MainActor
    static func savePingPDF(results: [PingResult], stats: PingStats, host: String, resolvedIP: String?) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let fileDate = formatter.string(from: date)
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NetUtil-Ping-\(host)-\(fileDate).pdf"
        panel.allowedContentTypes = [.pdf]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.leftMargin = 40
            printInfo.rightMargin = 40
            printInfo.topMargin = 40
            printInfo.bottomMargin = 40
            
            // Create a dedicated view for PDF rendering
            let reportView = PingPDFReportView(results: results, stats: stats, host: host, resolvedIP: resolvedIP, generatedDate: date)
            let hostingView = NSHostingView(rootView: reportView)
            
            // Calculate height based on number of rows (simple estimate)
            let rowHeight: CGFloat = 20
            let headerHeight: CGFloat = 250
            let totalHeight = headerHeight + (CGFloat(min(results.count, 100)) * rowHeight)
            
            hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: totalHeight)
            
            // Use NSView's dataWithPDFInsideRect
            let data = hostingView.dataWithPDF(inside: hostingView.bounds)
            try? data.write(to: url)
        }
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

    // MARK: - Save panel helpers

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

// MARK: - PDF View Component

struct PingPDFReportView: View {
    let results: [PingResult]
    let stats: PingStats
    let host: String
    let resolvedIP: String?
    let generatedDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Logo
            HStack(alignment: .center, spacing: 15) {
                // App Logo Placeholder (using Image(nsImage:))
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetUtil")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.accentColor)
                    Text("Professional Network Diagnostics")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("REPORT GENERATED")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.secondary)
                    Text(generatedDate.formatted(date: .complete, time: .complete))
                        .font(.system(size: 10, weight: .bold))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.2")")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Title Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Ping Diagnostics Result")
                    .font(.system(size: 20, weight: .bold))
                
                HStack(spacing: 12) {
                    Label(host, systemImage: "link")
                    if let ip = resolvedIP {
                        Text("(\(ip))")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            
            // Stats Summary Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("SUMMARY STATISTICS")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 40) {
                    PDFStatItem(label: "Packets Sent", value: "\(stats.transmitted)")
                    PDFStatItem(label: "Packets Recv", value: "\(stats.received)")
                    PDFStatItem(label: "Packet Loss", value: String(format: "%.1f%%", stats.loss))
                    PDFStatItem(label: "Jitter", value: String(format: "%.2fms", stats.jitter))
                }
                
                HStack(spacing: 40) {
                    PDFStatItem(label: "Min RTT", value: String(format: "%.2fms", stats.minRtt))
                    PDFStatItem(label: "Avg RTT", value: String(format: "%.2fms", stats.avgRtt))
                    PDFStatItem(label: "Max RTT", value: String(format: "%.2fms", stats.maxRtt))
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            // Data Table
            VStack(alignment: .leading, spacing: 10) {
                Text("DETAILED MEASUREMENTS")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 0) {
                    // Table Header
                    HStack {
                        Text("SEQ").frame(width: 40, alignment: .leading)
                        Text("STATUS").frame(width: 80, alignment: .leading)
                        Text("RTT (MS)").frame(width: 80, alignment: .leading)
                        Text("TIMESTAMP").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    
                    ForEach(results.suffix(100)) { r in
                        HStack {
                            Text("\(r.sequence)").frame(width: 40, alignment: .leading)
                            Text(r.status == .success ? "Success" : "Timeout")
                                .foregroundColor(r.status == .success ? .green : .red)
                                .frame(width: 80, alignment: .leading)
                            Text(r.status == .success ? String(format: "%.3f", r.rtt) : "—")
                                .frame(width: 80, alignment: .leading)
                            Text(r.timestamp, format: .dateTime.hour().minute().second())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.system(size: 8, design: .monospaced))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        
                        Divider().opacity(0.3)
                    }
                    
                    if results.count > 100 {
                        Text("... showing last 100 measurements ...")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            
            Spacer(minLength: 20)
            
            // Footer
            Text("Generated by NetUtil for macOS — Zero Telemetry, Private Diagnostics.")
                .font(.system(size: 7))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(30)
        .frame(width: 500) // Fixed width for A4-style portrait rendering
        .background(Color.white)
    }
}

struct PDFStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }
}
