import SwiftUI
import Charts

struct PingLatencyChartView: View {
    /// Full result set (for health strip / distribution bar — cheap views)
    let results: [PingResult]
    /// Throttled snapshot for the chart body — avoids per-frame full redraw
    let chartData: [PingResult]
    let stats: PingStats
    let rttWarn: Double
    let rttCrit: Double
    @Binding var hoveredPoint: PingResult?
    @Binding var hoverLocation: CGPoint
    @Binding var chartWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latency History")
                        .font(.headline)
                    Text("Real-time round-trip performance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                healthStrip
                    .accessibilityLabel("Recent health history strip")
            }

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    rttChart
                        .frame(height: 160)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                            if abs(chartWidth - newWidth) > 1 { chartWidth = newWidth }
                        }

                    if let point = hoveredPoint {
                        let tooltipEst: CGFloat = Metrics.tooltipEstimate
                        let clampedX = max(0, min(hoverLocation.x - tooltipEst / 2, chartWidth - tooltipEst))
                        HStack(spacing: 5) {
                            Circle()
                                .fill(point.status == .success ? rttColor(point.rtt) : Color.red)
                                .frame(width: 6, height: 6)
                            Text(verbatim: "#\(point.sequence)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            if point.status == .success {
                                Text(verbatim: String(format: "%.1f ms", point.rtt))
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundColor(rttColor(point.rtt))
                            } else {
                                Text(verbatim: "Timeout")
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .offset(x: clampedX, y: 4)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }

                Divider().padding(.vertical, 12).opacity(0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality Distribution")
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundColor(.secondary)
                    distributionBar
                        .accessibilityLabel("RTT distribution bar")
                }
            }
            .padding(20)
            .glassEffect(in: .rect(cornerRadius: 12))
        }
    }

    private var rttChart: some View {
        let windowed = Array(chartData.suffix(Metrics.chartWindow))
        let maxRtt = windowed.compactMap { $0.status == .success ? $0.rtt : nil }.max() ?? 50.0
        let firstSeq = windowed.first?.sequence ?? 0
        let lastSeq  = windowed.last?.sequence  ?? 100
        let strideValue: Double = windowed.count < 50 ? 10 : windowed.count < 200 ? 25 : 50

        return Chart {
            ForEach(windowed) { r in
                if r.status == .success {
                    AreaMark(x: .value("P", r.sequence), y: .value("R", r.rtt))
                        .foregroundStyle(LinearGradient(colors: [rttColor(r.rtt).opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("P", r.sequence), y: .value("R", r.rtt))
                        .foregroundStyle(rttColor(r.rtt))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                } else {
                    RuleMark(x: .value("P", r.sequence))
                        .foregroundStyle(Color.red.opacity(0.3))
                }
            }
            if let point = hoveredPoint {
                RuleMark(x: .value("Cursor", point.sequence))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverLocation = location
                            let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
                            if let seq: Int = proxy.value(atX: location.x - plotOriginX),
                               let match = windowed.min(by: { abs($0.sequence - seq) < abs($1.sequence - seq) }) {
                                hoveredPoint = match
                            }
                        case .ended:
                            hoveredPoint = nil
                        }
                    }
            }
        }
        .chartXScale(domain: firstSeq...max(firstSeq + 1, lastSeq))
        .chartYScale(domain: 0...max(50, maxRtt * 1.2))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(verbatim: "\(Int(v)) ms")
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: strideValue)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let seq = value.as(Double.self) {
                        Text(verbatim: "#\(Int(seq))")
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.padding(.top, 10).padding(.bottom, 10)
        }
    }

    private var healthStrip: some View {
        let samples = results.suffix(Metrics.healthStripWindow)
        return HStack(spacing: 2) {
            ForEach(samples) { r in
                RoundedRectangle(cornerRadius: 1)
                    .fill(healthColor(r))
                    .frame(width: 3, height: 12)
            }
        }
        .drawingGroup()
    }

    private func healthColor(_ r: PingResult) -> Color {
        if r.status == .timeout { return .red }
        if r.rtt > rttCrit { return .red }
        if r.rtt > rttWarn { return .orange }
        return .green
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }

    private var distributionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                distSegment(count: stats.bucketLow, color: .green.opacity(0.6), total: geo.size.width)
                distSegment(count: stats.bucketMedium, color: .orange.opacity(0.8), total: geo.size.width)
                distSegment(count: stats.bucketHigh, color: .red.opacity(0.8), total: geo.size.width)
                distSegment(count: stats.bucketCritical, color: .purple.opacity(0.8), total: geo.size.width)
            }
        }.frame(height: 6).clipShape(Capsule())
    }

    private func distSegment(count: Int, color: Color, total: CGFloat) -> some View {
        let ratio = CGFloat(count) / CGFloat(max(1, stats.received))
        return Rectangle().fill(color).frame(width: max(0, ratio * total))
    }
}
