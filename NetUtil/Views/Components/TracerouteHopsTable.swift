import SwiftUI

struct TracerouteHopsTable: View {
    let hops: [TracerouteHop]
    let selectedHopID: UUID?
    let rttWarn: Double
    let rttCrit: Double
    /// Bottleneck hop (biggest latency jump) to highlight, if any.
    var bottleneckHopID: UUID? = nil
    var bottleneckAddedMs: Double? = nil
    let onSelect: (UUID?) -> Void
    let onInfo: (TracerouteHop) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TableHeader("#", width: 40)
                TableHeader("Host/Endpoint", flexible: true)
                TableHeader("Loss%", width: 60)
                TableHeader("Average", width: 80)
                TableHeader("Jitter", width: 80)
                TableHeader("History", width: 120)
                TableHeader("", width: 40)
            }
            .padding(.vertical, Metrics.spacingSM).padding(.horizontal, Metrics.spacingLG)
            .background(.regularMaterial)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(hops) { hop in
                        HopRowView(
                            hop: hop,
                            isSelected: selectedHopID == hop.id,
                            isBottleneck: bottleneckHopID == hop.id,
                            bottleneckAddedMs: hop.id == bottleneckHopID ? bottleneckAddedMs : nil,
                            rttWarn: rttWarn,
                            rttCrit: rttCrit,
                            onInfo: { onInfo(hop) }
                        )
                        .onTapGesture { onSelect(selectedHopID == hop.id ? nil : hop.id) }
                        
                        if hop.id != hops.last?.id {
                            Divider().padding(.horizontal, Metrics.spacingLG).opacity(0.5)
                        }
                    }
                }
            }
        }
    }
}

private struct HopRowView: View {
    let hop: TracerouteHop
    let isSelected: Bool
    var isBottleneck: Bool = false
    var bottleneckAddedMs: Double? = nil
    let rttWarn: Double
    let rttCrit: Double
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hop.displayHost)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let ip = hop.ip, ip != hop.displayHost {
                    Text(ip)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
                if isBottleneck, let added = bottleneckAddedMs {
                    Text("Slowest jump +\(String(format: "%.0f", added)) ms")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.orange)
                        .accessibilityLabel("Slowest jump on this path, adds \(String(format: "%.0f", added)) milliseconds")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(String(format: "%.0f%%", hop.loss))
                .font(.caption.monospaced().weight(.bold))
                .foregroundColor(hop.loss > 0 ? .red : .primary)
                .frame(width: 60, alignment: .leading)

            Text(hop.avgRtt.map { String(format: "%.1f ms", $0) } ?? "—")
                .font(.caption.monospaced().weight(.bold))
                .foregroundColor(avgColor)
                .frame(width: 80, alignment: .leading)

            Text(hop.jitter.map { String(format: "%.1f ms", $0) } ?? "—")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            sparkline.frame(width: 120, height: 20)
            
            Button { onInfo() } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 40)
            .accessibilityLabel("Show IP Geolocation Info")
        }
        .padding(.vertical, Metrics.spacingSM).padding(.horizontal, Metrics.spacingLG)
        .background(isSelected ? Color.accentColor.opacity(0.05) : (isBottleneck ? Color.orange.opacity(0.07) : Color.clear))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hop \(hop.hop): \(hop.displayHost). Latency: \(hop.avgRtt.map { String(format: "%.1f ms", $0) } ?? "Timeout")")
    }

    private var avgColor: Color {
        guard let avg = hop.avgRtt else { return .secondary }
        return avg < rttWarn ? .primary : (avg < rttCrit ? .orange : .red)
    }

    private var sparkline: some View {
        Canvas { ctx, size in
            let history = Array(hop.samples.suffix(30))
            guard !history.isEmpty else { return }
            let maxV = max(history.compactMap(\.rtt).max() ?? 100, 10)
            let sw = size.width / 30
            for (i, s) in history.enumerated() {
                let x = CGFloat(i) * sw
                if let rtt = s.rtt {
                    let h = CGFloat(rtt / maxV) * size.height
                    ctx.fill(Path(CGRect(x: x, y: size.height - h, width: sw - 1, height: h)), with: .color(rtt < rttWarn ? .accentColor.opacity(0.3) : .orange.opacity(0.6)))
                } else {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: sw - 1, height: size.height)), with: .color(.red.opacity(0.2)))
                }
            }
        }
    }
}
