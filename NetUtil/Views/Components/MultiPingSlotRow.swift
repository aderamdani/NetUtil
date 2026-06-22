import SwiftUI
import Charts
import Observation

struct MultiPingSlotRow: View {
    @Bindable var slot: PingSlot
    let isExpanded: Bool
    var rttWarn: Double
    var rttCrit: Double
    let onToggleExpand: () -> Void
    let onRemove: () -> Void
    let onCommitRename: () -> Void
    @FocusState private var isNameFocused: Bool

    @State private var hoveredSample: RTTSample? = nil
    @State private var hoveredIdx: Int = 0
    @State private var hoverLocation: CGPoint = .zero
    @State private var expandedChartWidth: CGFloat = 500

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TextField("Alias", text: $slot.customName)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 140, alignment: .leading)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false; onCommitRename() }
                    .accessibilityLabel("Host Alias")
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .opacity(slot.isRunning ? 1 : 0.3)
                    
                    Text(slot.host)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Endpoint: \(slot.host)")
                .accessibilityHint("Tap to toggle detailed chart")

                Text("\(slot.sent)")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 60, alignment: .leading)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Packets Sent")
                    .accessibilityValue("\(slot.sent)")
                
                Text(String(format: "%.0f%%", slot.loss))
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(slot.loss > 0 ? .red : .primary)
                    .frame(width: 70, alignment: .leading)
                    .accessibilityLabel("Packet Loss")
                    .accessibilityValue(String(format: "%.0f percent", slot.loss))
                
                Text(slot.lastRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(slot.lastRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)
                    .accessibilityLabel("Last Latency")
                    .accessibilityValue(slot.lastRtt.map { String(format: "%.1f ms", $0) } ?? "Unknown")
                
                Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(slot.avgRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)
                    .accessibilityLabel("Average Latency")
                    .accessibilityValue(slot.avgRtt.map { String(format: "%.1f ms", $0) } ?? "Unknown")

                healthStrip
                    .frame(width: 140)
                    .onTapGesture { onToggleExpand() }
                    .accessibilityLabel("Health History")

                HStack(spacing: 12) {
                    Button(action: { if slot.isRunning { slot.stop() } else { slot.start() } }) {
                        Image(systemName: slot.isRunning ? "pause.fill" : "play.fill")
                            .foregroundColor(slot.isRunning ? .secondary : .accentColor)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(slot.isRunning ? "Stop Monitoring" : "Start Monitoring")
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove Host")
                }
                .frame(width: 60)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
            
            if isExpanded {
                VStack(spacing: 0) {
                    expandedChart
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)

                    Divider().padding(.horizontal, 16).opacity(0.3)
                }
                .background(.regularMaterial)
            }
        }
    }

    private var expandedChart: some View {
        let samples = slot.samples
        let maxRTT = samples.compactMap { $0.rtt }.max() ?? 50.0
        let lastIdx = max(1, samples.count - 1)
        let strideVal: Double = samples.count < 30 ? 5 : samples.count < 60 ? 10 : 20

        return ZStack(alignment: .topLeading) {
            Chart {
                ForEach(Array(samples.enumerated()), id: \.offset) { idx, s in
                    if let rtt = s.rtt {
                        AreaMark(x: .value("P", idx), y: .value("R", rtt))
                            .foregroundStyle(LinearGradient(
                                colors: [rttColor(rtt).opacity(0.2), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("P", idx), y: .value("R", rtt))
                            .foregroundStyle(rttColor(rtt))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.monotone)
                    } else {
                        RuleMark(x: .value("P", idx))
                            .foregroundStyle(Color.red.opacity(0.2))
                    }
                }
                if hoveredSample != nil {
                    RuleMark(x: .value("Cursor", hoveredIdx))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                hoverLocation = loc
                                let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
                                if let idx: Int = proxy.value(atX: loc.x - plotOriginX) {
                                    let clamped = max(0, min(idx, samples.count - 1))
                                    hoveredIdx = clamped
                                    hoveredSample = samples.isEmpty ? nil : samples[clamped]
                                }
                            case .ended:
                                hoveredSample = nil
                            }
                        }
                }
            }
            .chartXScale(domain: 0...lastIdx)
            .chartYScale(domain: 0...max(10, maxRTT * 1.15))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel {
                        if let ms = val.as(Double.self) {
                            Text("\(Int(ms)) ms").font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: strideVal)) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel {
                        if let idx = val.as(Double.self) {
                            Text("#\(Int(idx))")
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
            .drawingGroup()
            .frame(height: 80)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { expandedChartWidth = $0 }

            if let s = hoveredSample {
                let tooltipEst: CGFloat = Metrics.tooltipEstimateNarrow
                let clampedX = max(0, min(hoverLocation.x - tooltipEst / 2, expandedChartWidth - tooltipEst))
                HStack(spacing: 5) {
                    Circle()
                        .fill(s.rtt.map { rttColor($0) } ?? Color.red)
                        .frame(width: 6, height: 6)
                    Text("#\(hoveredIdx)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                    if let rtt = s.rtt {
                        Text(String(format: "%.2f ms", rtt))
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundColor(rttColor(rtt))
                    } else {
                        Text("Timeout")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                .offset(x: clampedX, y: 4)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
    }

    private var healthStrip: some View {
        let history = Array(slot.samples.suffix(Metrics.sparklineWindow))
        return HStack(spacing: 1.5) {
            ForEach(Array(0..<Metrics.sparklineWindow), id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < history.count ? hColor(history[i]) : Color.secondary.opacity(0.1))
                    .frame(width: 2.5, height: 14)
            }
        }
        .drawingGroup() // PERFORMANCE: Optimized for mini health strip
    }

    private func hColor(_ sample: RTTSample?) -> Color {
        guard let s = sample, let rtt = s.rtt else { return .red }
        if rtt > rttCrit { return .red }
        if rtt > rttWarn { return .orange }
        return .green
    }

    private var statusColor: Color {
        if !slot.isRunning { return .secondary }
        return slot.loss > 10 ? .red : (slot.loss > 0 ? .orange : .green)
    }
    
    private func rttColor(_ rtt: Double) -> Color {
        rtt < rttWarn ? .primary : (rtt < rttCrit ? .orange : .red)
    }
}
