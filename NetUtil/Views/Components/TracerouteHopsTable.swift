import SwiftUI
import Charts

struct TracerouteHopsTable: View {
    let hops: [TracerouteHop]
    let selectedHopID: UUID?
    let rttWarn: Double
    let rttCrit: Double
    let onSelect: (UUID?) -> Void
    let onInfo: (TracerouteHop) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("#", width: 40)
                tHeader("Host/Endpoint", flexible: true)
                tHeader("Loss%", width: 60)
                tHeader("Average", width: 80)
                tHeader("Jitter", width: 80)
                tHeader("History", width: 120)
                tHeader("", width: 40)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(hops) { hop in
                        HopRowView(
                            hop: hop,
                            isSelected: selectedHopID == hop.id,
                            rttWarn: rttWarn,
                            rttCrit: rttCrit,
                            onInfo: { onInfo(hop) }
                        )
                        .onTapGesture { onSelect(selectedHopID == hop.id ? nil : hop.id) }
                        
                        if hop.id != hops.last?.id {
                            Divider().padding(.horizontal, 16).opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }
}

private struct HopRowView: View {
    let hop: TracerouteHop
    let isSelected: Bool
    let rttWarn: Double
    let rttCrit: Double
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hop.displayHost)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let ip = hop.ip, ip != hop.displayHost {
                    Text(ip)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(String(format: "%.0f%%", hop.loss))
                .font(.system(size: 11, design: .monospaced).weight(.bold))
                .foregroundColor(hop.loss > 0 ? .red : .primary)
                .frame(width: 60, alignment: .leading)
            
            Text(hop.avgRtt.map { String(format: "%.1f ms", $0) } ?? "—")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(avgColor)
                .frame(width: 80, alignment: .leading)
            
            Text(hop.jitter.map { String(format: "%.1f ms", $0) } ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            sparkline.frame(width: 120, height: 20)
            
            Button { onInfo() } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 40)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
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
