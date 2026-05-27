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
            
            // Unified Report View based on Multi-Ping reference
            let reportView = SinglePingPDFReportView(results: results, stats: stats, host: host, resolvedIP: resolvedIP, generatedDate: date)
            let hostingView = NSHostingView(rootView: reportView)
            
            let totalHeight = 350 + (CGFloat(min(results.count, 100)) * 25)
            hostingView.frame = NSRect(x: 0, y: 0, width: 550, height: totalHeight)
            
            let data = hostingView.dataWithPDF(inside: hostingView.bounds)
            try? data.write(to: url)
        }
    }

    @MainActor
    static func saveMultiPingPDF(slots: [PingSlot]) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let fileDate = formatter.string(from: date)
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NetUtil-MultiPing-Report-\(fileDate).pdf"
        panel.allowedContentTypes = [.pdf]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.leftMargin = 40
            printInfo.rightMargin = 40
            
            let reportView = MultiPingPDFReportView(slots: slots, generatedDate: date)
            let hostingView = NSHostingView(rootView: reportView)
            
            let totalHeight = 300 + (CGFloat(slots.count) * 40)
            hostingView.frame = NSRect(x: 0, y: 0, width: 550, height: totalHeight)
            
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

// MARK: - Common PDF Components

struct PDFHeaderView: View {
    let title: String
    let subtitle: String
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 15) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetUtil")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.accentColor)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("REPORT GENERATED")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.secondary)
                    Text(date.formatted(date: .complete, time: .complete))
                        .font(.system(size: 10, weight: .bold))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.2")")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Divider()
        }
    }
}

struct PDFSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.secondary)
            .padding(.top, 10)
    }
}

struct PDFFooterInfo: View {
    var body: some View {
        Text("Generated by NetUtil for macOS — Native Infrastructure Monitoring.")
            .font(.system(size: 7))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 20)
    }
}

// MARK: - Single Ping PDF Report

struct SinglePingPDFReportView: View {
    let results: [PingResult]
    let stats: PingStats
    let host: String
    let resolvedIP: String?
    let generatedDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PDFHeaderView(title: "Ping Report", subtitle: "Diagnostic Endpoint Measurement", date: generatedDate)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostic Result")
                    .font(.system(size: 22, weight: .bold))
                HStack(spacing: 12) {
                    Label(host, systemImage: "link")
                    if let ip = resolvedIP { Text("(\(ip))") }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            PDFSectionHeader(title: "Summary Statistics")
            HStack(spacing: 30) {
                PDFSummaryBox(label: "Packets Sent", value: "\(stats.transmitted)")
                PDFSummaryBox(label: "Packets Recv", value: "\(stats.received)")
                PDFSummaryBox(label: "Loss %", value: String(format: "%.1f%%", stats.loss), color: stats.loss > 0 ? .red : .primary)
                PDFSummaryBox(label: "Jitter", value: String(format: "%.2fms", stats.jitter))
                PDFSummaryBox(label: "Avg RTT", value: String(format: "%.2fms", stats.avgRtt))
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(10)
            
            PDFSectionHeader(title: "Detailed Measurements (Last 100)")
            VStack(spacing: 0) {
                HStack {
                    Text("SEQ").frame(width: 40, alignment: .leading)
                    Text("STATUS").frame(width: 80, alignment: .leading)
                    Text("RTT (MS)").frame(width: 80, alignment: .leading)
                    Text("TIMESTAMP").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 8, weight: .black))
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.1))
                
                ForEach(results.suffix(100)) { r in
                    HStack {
                        Text("\(r.sequence)").frame(width: 40, alignment: .leading)
                        Text(r.status == .success ? "SUCCESS" : "TIMEOUT")
                            .foregroundColor(r.status == .success ? .green : .red)
                            .font(.system(size: 8, weight: .bold))
                            .frame(width: 80, alignment: .leading)
                        Text(r.status == .success ? String(format: "%.3f", r.rtt) : "—")
                            .frame(width: 80, alignment: .leading)
                        Text(r.timestamp, format: .dateTime.hour().minute().second())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    Divider().opacity(0.3)
                }
            }
            
            Spacer(minLength: 20)
            PDFFooterInfo()
        }
        .padding(35)
        .frame(width: 550)
        .background(Color.white)
    }
}

struct PDFSummaryBox: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 7, weight: .black))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Multi-Ping PDF Report

struct MultiPingPDFReportView: View {
    let slots: [PingSlot]
    let generatedDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PDFHeaderView(title: "Multi-Ping", subtitle: "Consolidated Infrastructure Report", date: generatedDate)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Infrastructure Status")
                    .font(.system(size: 22, weight: .bold))
                Text("Monitoring \(slots.count) active network endpoints.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            PDFSectionHeader(title: "Overview")
            HStack(spacing: 40) {
                PDFSummaryBox(label: "Targets", value: "\(slots.count)")
                let avgLoss = slots.isEmpty ? 0 : slots.map(\.loss).reduce(0, +) / Double(slots.count)
                PDFSummaryBox(label: "Avg Global Loss", value: String(format: "%.1f%%", avgLoss), color: avgLoss > 10 ? .red : .primary)
                let healthyCount = slots.filter { $0.loss == 0 }.count
                PDFSummaryBox(label: "Healthy Nodes", value: "\(healthyCount)", color: healthyCount == slots.count ? .green : .primary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(10)

            PDFSectionHeader(title: "Endpoint Details")
            VStack(spacing: 0) {
                HStack {
                    Text("HOST / ENDPOINT").frame(maxWidth: .infinity, alignment: .leading)
                    Text("SENT").frame(width: 40)
                    Text("LOSS").frame(width: 50)
                    Text("AVG RTT").frame(width: 70)
                    Text("STATUS").frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 8, weight: .black))
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.1))
                
                ForEach(slots) { slot in
                    HStack {
                        Text(slot.host)
                            .font(.system(size: 9, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(slot.sent)").frame(width: 40)
                        
                        Text(String(format: "%.0f%%", slot.loss))
                            .foregroundColor(slot.loss > 0 ? .red : .secondary)
                            .frame(width: 50)
                        
                        Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—")
                            .frame(width: 70)
                        
                        Text(interpretStatus(slot))
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(statusColor(slot))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    
                    Divider().opacity(0.3)
                }
            }
            
            Spacer(minLength: 20)
            PDFFooterInfo()
        }
        .padding(35)
        .frame(width: 550)
        .background(Color.white)
    }
    
    private func statusColor(_ slot: PingSlot) -> Color {
        if slot.loss >= 50 { return .red }
        if slot.loss > 0 { return .orange }
        return .green
    }
    
    private func interpretStatus(_ slot: PingSlot) -> String {
        if slot.loss >= 50 { return "CRITICAL" }
        if slot.loss > 0 { return "DEGRADED" }
        return "HEALTHY"
    }
}
