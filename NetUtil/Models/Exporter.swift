import Foundation
import AppKit
import UniformTypeIdentifiers

enum Exporter {

    // MARK: - CSV: Ping
    static func csvString(from results: [PingResult]) -> String {
        let fmt = ISO8601DateFormatter()
        let header = "timestamp,sequence,host,bytes,ttl,rtt_ms,status"
        let rows = results.map {
            "\(fmt.string(from: $0.timestamp)),\($0.sequence),\($0.host),\($0.bytes),\($0.ttl),\($0.rtt),\($0.status == .success ? "success" : "timeout")"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - CSV: Traceroute
    static func csvString(from hops: [TracerouteHop]) -> String {
        let header = "hop,host,ip,sent,recv,loss_pct,min_rtt_ms,avg_rtt_ms,max_rtt_ms"
        let rows = hops.map { h -> String in
            let loss = String(format: "%.1f", h.loss)
            let min  = h.minRtt.map { String(format: "%.2f", $0) } ?? ""
            let avg  = h.avgRtt.map { String(format: "%.2f", $0) } ?? ""
            let max  = h.maxRtt.map { String(format: "%.2f", $0) } ?? ""
            return "\(h.hop),\(h.host ?? ""),\(h.ip ?? ""),\(h.sent),\(h.recv),\(loss),\(min),\(avg),\(max)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - CSV: Multi-Ping
    static func csvString(from slots: [PingSlot]) -> String {
        let header = "host,alias,sent,loss_pct,avg_rtt_ms,last_rtt_ms"
        let rows = slots.map { s -> String in
            let loss = String(format: "%.1f", s.loss)
            let avg  = s.avgRtt.map  { String(format: "%.2f", $0) } ?? ""
            let last = s.lastRtt.map { String(format: "%.2f", $0) } ?? ""
            return "\(s.host),\(s.customName),\(s.sent),\(loss),\(avg),\(last)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - CSV: HTTP Latency
    static func csvString(from history: [HTTPLatencyResult]) -> String {
        let fmt = ISO8601DateFormatter()
        let header = "timestamp,method,url,status_code,total_ms,dns_ms,tcp_ms,tls_ms,request_ms,ttfb_ms,download_ms"
        let rows = history.map { r -> String in
            func ms(_ phase: HTTPPhase) -> String {
                r.phases.first(where: { $0.phase == phase }).map { String(format: "%.1f", $0.durationMs) } ?? "0"
            }
            return "\(fmt.string(from: r.timestamp)),\(r.method),\"\(r.url)\",\(r.statusCode ?? 0),\(String(format: "%.1f", r.totalMs)),\(ms(.dns)),\(ms(.tcp)),\(ms(.tls)),\(ms(.request)),\(ms(.ttfb)),\(ms(.download))"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - CSV: Subnet Scan
    static func csvString(from results: [SubnetScanResult]) -> String {
        let header = "ip,hostname,status,rtt_ms,mac_address"
        let rows = results.map { r -> String in
            let rtt = r.rtt.map { String(format: "%.2f", $0) } ?? ""
            return "\(r.ip),\(r.hostname ?? ""),\(r.status.rawValue),\(rtt),\(r.macAddress ?? "")"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - CSV: Speed Test
    static func csvString(from history: [SpeedTestResult]) -> String {
        let fmt = ISO8601DateFormatter()
        let header = "timestamp,kind,name,download_mbps,upload_mbps,ping_ms,jitter_ms,browsing_avg_ms,game_median_ms,stream_avg_mbps,stream_tier"
        let rows = history.map { r -> String in
            "\(fmt.string(from: r.timestamp)),\(r.kind.rawValue),\(r.name ?? ""),\(String(format: "%.2f", r.downloadMbps)),\(String(format: "%.2f", r.uploadMbps)),\(String(format: "%.1f", r.pingMs)),\(String(format: "%.1f", r.jitterMs)),\(String(format: "%.1f", r.browsingAvgMs)),\(String(format: "%.1f", r.gameMedianMs)),\(String(format: "%.2f", r.streamAvgMbps)),\(r.streamTier)"
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Generic text save
    static func save(string: String, defaultName: String, ext: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        if let contentType = UTType(filenameExtension: ext) { panel.allowedContentTypes = [contentType] }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? string.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - PDF: Ping
    @MainActor static func savePingPDF(results: [PingResult], stats: PingStats, host: String, resolvedIP: String?) {
        let ts = timestamp()
        let metaRows: [[String]] = [
            ["Host", host],
            ["Resolved IP", resolvedIP ?? "—"],
            ["Transmitted", "\(stats.transmitted)"],
            ["Received", "\(stats.received)"],
            ["Packet Loss", String(format: "%.1f%%", stats.loss)],
            ["Avg RTT", String(format: "%.2f ms", stats.avgRtt)],
            ["Min RTT", stats.minRtt == .infinity ? "—" : String(format: "%.2f ms", stats.minRtt)],
            ["Max RTT", String(format: "%.2f ms", stats.maxRtt)],
            ["Jitter", String(format: "%.2f ms", stats.jitter)],
        ]
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm:ss"
        let dataRows: [[String]] = results.map { r in
            ["\(r.sequence)", r.status == .success ? "Success" : "Timeout",
             r.status == .success ? String(format: "%.2f ms", r.rtt) : "—",
             r.ipAddress ?? resolvedIP ?? "—", timeFmt.string(from: r.timestamp)]
        }
        let pdf = PDFReport.build(tool: "Ping", target: host, sections: [
            ("Summary", metaRows),
            ("Sequence", [["Seq", "Status", "RTT", "IP", "Time"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-Ping-\(host)-\(ts).pdf")
    }

    // MARK: - PDF: Multi-Ping
    @MainActor static func saveMultiPingPDF(slots: [PingSlot]) {
        let ts = timestamp()
        let dataRows: [[String]] = slots.map { s in
            [s.host, s.customName, "\(s.sent)", String(format: "%.1f%%", s.loss),
             s.avgRtt.map  { String(format: "%.2f ms", $0) } ?? "—",
             s.lastRtt.map { String(format: "%.2f ms", $0) } ?? "—"]
        }
        let pdf = PDFReport.build(tool: "Multi-Ping", target: "\(slots.count) hosts", sections: [
            ("Hosts", [["Host", "Alias", "Sent", "Loss", "Avg RTT", "Last RTT"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-MultiPing-\(ts).pdf")
    }

    // MARK: - PDF: HTTP Latency
    @MainActor static func saveHTTPLatencyPDF(result: HTTPLatencyResult, history: [HTTPLatencyResult]) {
        let ts = timestamp()
        let phaseRows: [[String]] = result.phases.map { p in
            [p.phase.rawValue, String(format: "%.1f ms", p.startMs), String(format: "%.1f ms", p.durationMs)]
        }
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm:ss"
        let histRows: [[String]] = history.map { r in
            [timeFmt.string(from: r.timestamp), r.method,
             "\(r.statusCode ?? 0)", String(format: "%.0f ms", r.totalMs),
             String(r.url.prefix(45))]
        }
        let pdf = PDFReport.build(tool: "HTTP Latency", target: result.url, sections: [
            ("Waterfall", [["Phase", "Start", "Duration"]] + phaseRows),
            ("History",   [["Time", "Method", "Status", "Latency", "URL"]] + histRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-HTTPLatency-\(ts).pdf")
    }

    // MARK: - PDF: Traceroute
    @MainActor static func saveTraceroutePDF(hops: [TracerouteHop], host: String, round: Int) {
        let ts = timestamp()
        let dataRows: [[String]] = hops.map { h in
            ["\(h.hop)", h.displayHost, String(format: "%.1f%%", h.loss),
             h.avgRtt.map { String(format: "%.2f ms", $0) } ?? "—",
             h.geo.map { "\($0.flag) \($0.city)" } ?? "—"]
        }
        let pdf = PDFReport.build(tool: "Traceroute", target: host, sections: [
            ("Summary", [["Target", host], ["Round", "\(round)"], ["Hops", "\(hops.count)"]]),
            ("Path", [["Hop", "Host", "Loss", "Avg RTT", "Location"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-Traceroute-\(host)-\(ts).pdf")
    }

    // MARK: - PDF: DNS
    @MainActor static func saveDNSPDF(result: DNSResult, host: String) {
        let ts = timestamp()
        let metaRows: [[String]] = [
            ["Domain", host],
            ["Server", result.server],
            ["Query Time", result.queryTimeMs.map { "\($0) ms" } ?? "—"],
            ["Records", "\(result.records.count)"],
        ]
        let dataRows: [[String]] = result.records.map { r in [r.name, "\(r.ttl)", r.type, r.value] }
        let pdf = PDFReport.build(tool: "DNS Lookup", target: host, sections: [
            ("Summary", metaRows),
            ("Records", [["Name", "TTL", "Type", "Value"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-DNS-\(host)-\(ts).pdf")
    }

    // MARK: - PDF: Subnet Scan
    @MainActor static func saveSubnetScanPDF(results: [SubnetScanResult], cidr: String) {
        let ts = timestamp()
        let alive = results.filter { $0.status == .alive }.count
        let metaRows: [[String]] = [
            ["CIDR", cidr],
            ["Total IPs", "\(results.count)"],
            ["Alive", "\(alive)"],
            ["Unreachable", "\(results.count - alive)"],
        ]
        let dataRows: [[String]] = results.map { r in
            [r.ip, r.hostname ?? "—", r.status.rawValue,
             r.rtt.map { String(format: "%.2f ms", $0) } ?? "—",
             r.macAddress ?? "—"]
        }
        let pdf = PDFReport.build(tool: "Subnet Scanner", target: cidr, sections: [
            ("Summary", metaRows),
            ("Hosts", [["IP", "Hostname", "Status", "RTT", "MAC"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-SubnetScan-\(cidr.replacingOccurrences(of: "/", with: "_"))-\(ts).pdf")
    }

    // MARK: - PDF: SSL
    @MainActor static func saveSSLPDF(result: CertResult, host: String) {
        let ts = timestamp()
        let leaf = result.chain.first
        let metaRows: [[String]] = [
            ["Host", host],
            ["Port", "\(result.port)"],
            ["TLS Version", result.tlsVersion ?? "—"],
            ["Cipher Suite", result.cipherSuite ?? "—"],
            ["Chain Depth", "\(result.chain.count)"],
            ["Status", (leaf?.daysRemaining ?? 0) < 0 ? "Expired" : "Trusted"],
            ["Days Remaining", leaf?.daysRemaining.map { "\($0)" } ?? "—"],
        ]
        let dateFmt = DateFormatter(); dateFmt.dateStyle = .medium
        let chainRows: [[String]] = result.chain.map { c in
            [c.isLeaf ? "End-Entity" : "CA",
             c.subject.components(separatedBy: "CN=").last?.components(separatedBy: ",").first ?? c.subject,
             c.notAfter.map { dateFmt.string(from: $0) } ?? "—",
             c.daysRemaining.map { "\($0) days" } ?? "—"]
        }
        let pdf = PDFReport.build(tool: "SSL/TLS Inspector", target: host, sections: [
            ("Summary", metaRows),
            ("Certificate Chain", [["Role", "Common Name", "Expires", "Days Left"]] + chainRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-SSL-\(host)-\(ts).pdf")
    }

    // MARK: - PDF: Speed Test
    @MainActor static func saveSpeedTestPDF(history: [SpeedTestResult]) {
        let ts = timestamp()
        let timeFmt = DateFormatter(); timeFmt.dateStyle = .short; timeFmt.timeStyle = .short
        let dataRows: [[String]] = history.map { r in
            let primary: String
            switch r.kind {
            case .speed:     primary = String(format: "↓%.1f / ↑%.1f Mbps", r.downloadMbps, r.uploadMbps)
            case .browsing:  primary = String(format: "%.0f ms avg", r.browsingAvgMs)
            case .gaming:    primary = String(format: "%.0f ms median", r.gameMedianMs)
            case .streaming: primary = "\(r.streamTier)"
            }
            return [timeFmt.string(from: r.timestamp), r.kind.rawValue, r.name ?? "—", primary]
        }
        let pdf = PDFReport.build(tool: "Speed Test", target: "Cloudflare", sections: [
            ("History", [["Timestamp", "Kind", "Label", "Result"]] + dataRows)
        ])
        savePDF(data: pdf, defaultName: "NetUtil-SpeedTest-\(ts).pdf")
    }

    // MARK: - Internal

    @MainActor private static func savePDF(data: Data, defaultName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.pdf]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private static func timestamp() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd-HHmmss"
        return fmt.string(from: Date())
    }
}

// MARK: - PDF Report Builder

private enum PDFReport {
    static let pageW:  CGFloat = 595
    static let pageH:  CGFloat = 842
    static let margin: CGFloat = 48
    static let lineH:  CGFloat = 14

    static func build(tool: String, target: String, sections: [(title: String, rows: [[String]])]) -> Data {
        var pageRect = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let buf = NSMutableData()
        guard let consumer = CGDataConsumer(data: buf as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else { return Data() }

        ctx.beginPDFPage(nil)
        var y = drawHeader(ctx, tool: tool, target: target, y: pageH - margin)
        for section in sections {
            if y < margin + 60 { y = newPage(ctx) }
            y = drawSection(ctx, title: section.title, rows: section.rows, y: y)
        }
        drawFooter(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return buf as Data
    }

    @discardableResult
    private static func drawHeader(_ ctx: CGContext, tool: String, target: String, y: CGFloat) -> CGFloat {
        var cy = y
        draw(ctx, "NetUtil — \(tool) Report", x: margin, y: cy, font: .boldSystemFont(ofSize: 16))
        cy -= 22

        let dateFmt = DateFormatter(); dateFmt.dateStyle = .medium; dateFmt.timeStyle = .medium
        draw(ctx, "Target: \(target)   |   \(dateFmt.string(from: Date()))",
             x: margin, y: cy, font: .systemFont(ofSize: 10), color: .secondaryLabelColor)
        cy -= 18

        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: cy))
        ctx.addLine(to: CGPoint(x: pageW - margin, y: cy))
        ctx.strokePath()
        cy -= 16
        return cy
    }

    private static func drawSection(_ ctx: CGContext, title: String, rows: [[String]], y: CGFloat) -> CGFloat {
        var cy = y
        draw(ctx, title, x: margin, y: cy, font: .boldSystemFont(ofSize: 11))
        cy -= lineH + 4

        let contentW = pageW - 2 * margin
        for (idx, row) in rows.enumerated() {
            guard !row.isEmpty else { continue }
            let colW = contentW / CGFloat(row.count)
            let isHeader = idx == 0
            let font: NSFont = isHeader ? .boldSystemFont(ofSize: 9) : .monospacedSystemFont(ofSize: 9, weight: .regular)
            let color: NSColor = isHeader ? .secondaryLabelColor : .labelColor

            if !isHeader && idx % 2 == 0 {
                ctx.setFillColor(NSColor.labelColor.withAlphaComponent(0.04).cgColor)
                ctx.fill(CGRect(x: margin, y: cy - 2, width: contentW, height: lineH + 2))
            }

            for (col, cell) in row.enumerated() {
                let clipped = cell.count > 42 ? String(cell.prefix(40)) + "…" : cell
                draw(ctx, clipped, x: margin + CGFloat(col) * colW, y: cy, font: font, color: color)
            }
            cy -= lineH

            if cy < margin + 40 { cy = newPage(ctx) }
        }
        return cy - 10
    }

    private static func drawFooter(_ ctx: CGContext) {
        draw(ctx, "Generated by NetUtil v4.0.0",
             x: margin, y: margin - 18, font: .systemFont(ofSize: 8), color: .tertiaryLabelColor)
    }

    private static func newPage(_ ctx: CGContext) -> CGFloat {
        ctx.endPDFPage()
        ctx.beginPDFPage(nil)
        return pageH - margin
    }

    private static func draw(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor = .labelColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSAttributedString(string: text, attributes: attrs).draw(at: CGPoint(x: x, y: y))
        NSGraphicsContext.restoreGraphicsState()
    }
}
