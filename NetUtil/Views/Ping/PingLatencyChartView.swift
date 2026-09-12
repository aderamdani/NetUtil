import SwiftUI
import Charts
import Accessibility

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
                        HStack(spacing: 4) {
                            Circle()
                                .fill(point.status == .success ? rttColor(point.rtt) : Color.red)
                                .frame(width: 6, height: 6)
                            Text(verbatim: "#\(point.sequence)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            if point.status == .success {
                                Text(verbatim: String(format: "%.1f ms", point.rtt))
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundColor(rttColor(point.rtt))
                            } else {
                                Text(verbatim: "Timeout")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
                        .offset(x: clampedX, y: 4)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }

                Divider().padding(.vertical, 12).opacity(0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality Distribution")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                    distributionBar
                        .accessibilityLabel("RTT distribution bar")
                }
            }
            .padding(Metrics.spacingXL)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var rttChart: some View {
        let windowed = Array(chartData.suffix(Metrics.chartWindow))
        let maxRtt = windowed.compactMap { $0.status == .success ? $0.rtt : nil }.max() ?? 50.0
        let firstSeq = windowed.first?.sequence ?? 0
        let lastSeq  = windowed.last?.sequence  ?? 100
        let strideValue: Double = windowed.count < 50 ? 10 : windowed.count < 200 ? 25 : 50

        let successRtts = windowed.compactMap { $0.status == .success ? $0.rtt : nil }
        let timeoutCount = windowed.count - successRtts.count
        let yTop = max(50, maxRtt * 1.2)

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
                            .font(.caption2.monospaced())
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
                            .font(.caption2.monospaced())
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.padding(.top, 10).padding(.bottom, 10)
        }
        .accessibilityChartDescriptor(PingLatencyDescriptor(
            points: windowed.compactMap { $0.status == .success ? (seq: $0.sequence, rtt: $0.rtt) : nil },
            yTop: yTop,
            summary: Self.pingChartSummary(
                count: windowed.count,
                timeouts: timeoutCount,
                minMs: successRtts.min() ?? 0,
                avgMs: successRtts.isEmpty ? 0 : successRtts.reduce(0, +) / Double(successRtts.count),
                maxMs: successRtts.max() ?? 0,
                top: yTop)
        ))
        .accessibilityLabel("Line chart of ping round-trip time by sequence number")
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

    /// Pure spoken-summary builder for the latency chart — testable
    /// without rendering. Sequence (X) first, describes data not colors.
    static nonisolated func pingChartSummary(count: Int, timeouts: Int, minMs: Double, avgMs: Double, maxMs: Double, top: Double) -> String {
        guard count > 0 else { return "Line chart. No ping data yet." }
        return "Line chart. Ping sequence on the X axis, round-trip time in milliseconds on the Y axis from 0 to \(Int(top)). \(count) pings, \(timeouts) timed out. Fastest \(String(format: "%.1f", minMs)), average \(String(format: "%.1f", avgMs)), slowest \(String(format: "%.1f", maxMs)) milliseconds."
    }
}

/// VoiceOver descriptor for the ping latency line chart. Successful pings
/// only; timeouts surface in the summary. Points are downsampled and each
/// carries a spoken label — never colors, sequence (X) always first.
private struct PingLatencyDescriptor: AXChartDescriptorRepresentable {
    let points: [(seq: Int, rtt: Double)]
    let yTop: Double
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let stride = max(1, points.count / 60)
        let sampled = points.enumerated().compactMap { index, point in
            index % stride == 0 ? point : nil
        }
        return AXChartDescriptor(
            title: "Latency history",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Ping sequence",
                categoryOrder: sampled.map { "ping \($0.seq)" }
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: "Round-trip time",
                range: 0...yTop,
                gridlinePositions: [0, yTop / 2, yTop],
                valueDescriptionProvider: { String(format: "%.0f milliseconds", $0) }
            ),
            series: [
                AXDataSeriesDescriptor(
                    name: "Round-trip time",
                    isContinuous: true,
                    dataPoints: sampled.map {
                        AXDataPoint(
                            x: "ping \($0.seq)",
                            y: $0.rtt,
                            label: "Ping \($0.seq), \(String(format: "%.1f", $0.rtt)) milliseconds")
                    }
                )
            ]
        )
    }
}
