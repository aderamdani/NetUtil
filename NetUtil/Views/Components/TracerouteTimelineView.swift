import SwiftUI

struct TracerouteTimelineView: View {
    let hops: [TracerouteHop]
    let rttWarn: Double
    let rttCrit: Double
    let selectedHopID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let globalMax = max(hops.compactMap(\.maxRtt).max() ?? 100, 10)
                ForEach(hops) { hop in
                    TimelineHopRow(
                        hop: hop,
                        globalMax: globalMax,
                        rttWarn: rttWarn,
                        rttCrit: rttCrit,
                        isSelected: selectedHopID == hop.id
                    )
                    .onTapGesture { onSelect(selectedHopID == hop.id ? nil : hop.id) }
                    
                    if hop.id != hops.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }
}

private struct TimelineHopRow: View {
    let hop: TracerouteHop
    let globalMax: Double
    let rttWarn: Double
    let rttCrit: Double
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text("\(hop.hop)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hop.displayHost)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(hop.ip ?? "—")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            
            GeometryReader { geo in
                let samples = Array(hop.samples.suffix(60))
                let sw = geo.size.width / 60
                HStack(spacing: 0) {
                    ForEach(0..<60) { i in
                        let s = i < samples.count ? samples[i] : nil
                        Rectangle()
                            .fill(sampleColor(s))
                            .frame(width: sw)
                            .frame(maxHeight: sampleHeight(s, total: geo.size.height), alignment: .bottom)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            
            Text(hop.avgRtt.map { String(format: "%.1f ms", $0) } ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    private func sampleColor(_ s: RTTSample?) -> Color {
        guard let rtt = s?.rtt else { return .red.opacity(0.1) }
        if rtt > rttCrit { return .red }
        if rtt > rttWarn { return .orange }
        return .accentColor.opacity(0.4)
    }

    private func sampleHeight(_ s: RTTSample?, total: CGFloat) -> CGFloat {
        guard let rtt = s?.rtt else { return total }
        return max(2, total * CGFloat(min(rtt / globalMax, 1.0)))
    }
}
