import SwiftUI

struct PortScanTable: View {
    let results: [PortResult]
    let resolvedIP: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TableHeader("Port", width: 80)
                TableHeader("Status", width: 100)
                TableHeader("Service", width: 150)
                TableHeader("Latency", width: 100)
                TableHeader("Target IP", flexible: true)
            }
            .padding(.vertical, Metrics.spacingMD).padding(.horizontal, Metrics.spacingLG)
            .background(.regularMaterial)
            .accessibilityElement(children: .ignore)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { r in
                        HStack(spacing: 0) {
                            Text("\(r.port)")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .frame(width: 80, alignment: .leading)
                            
                            PortStatusBadge(status: r.status)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(r.service ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 150, alignment: .leading)
                                .lineLimit(1)
                            
                            Text(r.responseMs.map { String(format: "%.1f ms", $0) } ?? "—")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(resolvedIP ?? "—")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, Metrics.spacingSM).padding(.horizontal, Metrics.spacingLG)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityLabel(for: r))
                        
                        if r.id != results.last?.id {
                            Divider().padding(.horizontal, Metrics.spacingLG).opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func accessibilityLabel(for r: PortResult) -> String {
        let status = r.status.rawValue
        let service = r.service ?? "Unknown"
        return "Port \(r.port), Status: \(status), Service: \(service)"
    }
}

private struct PortStatusBadge: View {
    let status: PortStatus
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch status {
        case .open: return .green
        case .closed: return .red
        case .filtered: return .orange
        }
    }
}
