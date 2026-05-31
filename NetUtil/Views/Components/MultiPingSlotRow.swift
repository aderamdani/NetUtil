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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TextField("Alias", text: $slot.customName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
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
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
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
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60, alignment: .leading)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Packets Sent")
                    .accessibilityValue("\(slot.sent)")
                
                Text(String(format: "%.0f%%", slot.loss))
                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                    .foregroundColor(slot.loss > 0 ? .red : .primary)
                    .frame(width: 70, alignment: .leading)
                    .accessibilityLabel("Packet Loss")
                    .accessibilityValue(String(format: "%.0f percent", slot.loss))
                
                Text(slot.lastRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(slot.lastRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)
                    .accessibilityLabel("Last Latency")
                    .accessibilityValue(slot.lastRtt.map { String(format: "%.1f ms", $0) } ?? "Unknown")
                
                Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                    Chart {
                        ForEach(slot.samples) { s in
                            if let rtt = s.rtt {
                                AreaMark(x: .value("T", s.timestamp), y: .value("R", rtt))
                                    .foregroundStyle(LinearGradient(colors: [rttColor(rtt).opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.monotone)
                                
                                LineMark(x: .value("T", s.timestamp), y: .value("R", rtt))
                                    .foregroundStyle(rttColor(rtt))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    .interpolationMethod(.monotone)
                            } else {
                                RuleMark(x: .value("T", s.timestamp))
                                    .foregroundStyle(Color.red.opacity(0.2))
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { val in
                            AxisValueLabel {
                                if let ms = val.as(Double.self) {
                                    Text("\(Int(ms)) ms").font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
                    .drawingGroup()
                    .frame(height: 80)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    
                    Divider().padding(.horizontal, 16).opacity(0.3)
                }
                .background(.regularMaterial)
            }
        }
    }

    private var healthStrip: some View {
        let history = Array(slot.samples.suffix(40))
        return HStack(spacing: 1.5) {
            ForEach(0..<40) { i in
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
