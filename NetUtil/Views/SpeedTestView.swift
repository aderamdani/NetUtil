import SwiftUI

struct SpeedTestView: View {
    @ObservedObject var vm: SpeedTestViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)

            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.system(size: 12, weight: .medium)).padding(.bottom, 16)
            }

            kindPicker.padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 24) {
                metricRow
                progressSection
                if !vm.history.isEmpty {
                    historySection
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "speedometer").foregroundColor(.accentColor)
                Text("Speed Test").font(.headline)
            }.frame(width: 250, alignment: .leading)

            Spacer()

            Button(action: { if vm.isTesting { vm.cancel() } else { vm.start() } }) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isTesting ? "stop.fill" : "play.fill")
                    Text(vm.isTesting ? "Cancel" : "Start Test")
                }.font(.system(size: 13, weight: .medium)).frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isTesting ? .red : .accentColor)
            .disabled(false)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.borderless)
        }
    }

    // MARK: - Kind Picker

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(SpeedTestKind.allCases) { kind in
                    kindButton(kind)
                }
            }
            Text(vm.kind.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func kindButton(_ kind: SpeedTestKind) -> some View {
        let selected = vm.kind == kind
        return Button {
            guard !vm.isTesting else { return }
            vm.kind = kind
        } label: {
            HStack(spacing: 6) {
                Image(systemName: kind.icon).font(.system(size: 12, weight: .medium))
                Text(kind.rawValue).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundColor(selected ? .white : .primary)
            .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                        in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(vm.isTesting)
        .opacity(vm.isTesting && !selected ? 0.45 : 1.0)
    }

    // MARK: - Metric Rows (per kind)

    @ViewBuilder
    private var metricRow: some View {
        switch vm.kind {
        case .speed:     speedMetrics
        case .browsing:  browsingMetrics
        case .gaming:    gamingMetrics
        case .streaming: streamingMetrics
        }
    }

    private var speedMetrics: some View {
        HStack(spacing: 16) {
            metricCard(title: "Download", value: String(format: "%.1f", vm.downloadMbps), unit: "Mbps", icon: "arrow.down", color: .blue, highlight: vm.phase == .download)
            metricCard(title: "Upload",   value: String(format: "%.1f", vm.uploadMbps),   unit: "Mbps", icon: "arrow.up",   color: .orange, highlight: vm.phase == .upload)
            metricCard(title: "Latency",  value: String(format: "%.0f", vm.pingMs),       unit: "ms",   icon: "timer",      color: .green,  highlight: vm.phase == .latency)
            metricCard(title: "Jitter",   value: String(format: "%.1f", vm.jitterMs),     unit: "ms",   icon: "waveform.path.ecg", color: .purple, highlight: false)
        }
    }

    private var browsingMetrics: some View {
        HStack(spacing: 16) {
            metricCard(title: "Avg Load",   value: String(format: "%.0f", vm.browsingAvgMs),       unit: "ms",     icon: "globe",       color: .blue,   highlight: vm.phase == .browsing)
            metricCard(title: "Median TTFB",value: String(format: "%.0f", vm.browsingMedianTtfb),  unit: "ms",     icon: "timer",       color: .orange, highlight: false)
            metricCard(title: "Sites",      value: "\(vm.browsingProcessed)",                       unit: "loaded", icon: "checkmark.circle", color: .green,  highlight: false)
            metricCard(title: "Verdict",    value: browsingVerdict,                                  unit: "",       icon: "hand.thumbsup",color: browsingVerdictColor, highlight: false)
        }
    }

    private var gamingMetrics: some View {
        HStack(spacing: 16) {
            metricCard(title: "Median Latency", value: String(format: "%.0f", vm.gameMedianMs), unit: "ms", icon: "timer",            color: gameLatencyColor, highlight: vm.phase == .gaming)
            metricCard(title: "P99 Latency",    value: String(format: "%.0f", vm.gameP99Ms),    unit: "ms", icon: "exclamationmark.triangle", color: .orange, highlight: false)
            metricCard(title: "Jitter",         value: String(format: "%.1f", vm.gameJitterMs), unit: "ms", icon: "waveform.path.ecg", color: .purple, highlight: false)
            metricCard(title: "Loss",           value: String(format: "%.1f", vm.gameLossPct),  unit: "%",  icon: "questionmark.circle", color: vm.gameLossPct > 1 ? .red : .green, highlight: false)
        }
    }

    private var streamingMetrics: some View {
        HStack(spacing: 16) {
            metricCard(title: "Avg Throughput", value: String(format: "%.1f", vm.streamAvgMbps),  unit: "Mbps", icon: "arrow.down",         color: .blue,   highlight: vm.phase == .streaming)
            metricCard(title: "Min Throughput", value: String(format: "%.1f", vm.streamMinMbps),  unit: "Mbps", icon: "arrow.down.to.line", color: .orange, highlight: false)
            metricCard(title: "Stable Tier",    value: vm.streamTier,                              unit: "",     icon: "play.tv",            color: .accentColor, highlight: false)
            metricCard(title: "Verdict",        value: streamingVerdict,                           unit: "",     icon: "hand.thumbsup",      color: streamingVerdictColor, highlight: false)
        }
    }

    // MARK: - Verdict helpers

    private var browsingVerdict: String {
        let avg = vm.browsingAvgMs
        guard avg > 0 else { return "—" }
        if avg < 500  { return "Fast" }
        if avg < 1500 { return "OK" }
        return "Slow"
    }

    private var browsingVerdictColor: Color {
        switch browsingVerdict {
        case "Fast": return .green
        case "OK":   return .orange
        case "Slow": return .red
        default:     return .secondary
        }
    }

    private var gameLatencyColor: Color {
        if vm.gameMedianMs == 0 { return .secondary }
        if vm.gameMedianMs < 30  { return .green }
        if vm.gameMedianMs < 80  { return .orange }
        return .red
    }

    private var streamingVerdict: String {
        let min = vm.streamMinMbps
        guard min > 0 else { return "—" }
        if min >= 25 { return "Excellent" }
        if min >= 5  { return "OK" }
        return "Poor"
    }

    private var streamingVerdictColor: Color {
        switch streamingVerdict {
        case "Excellent": return .green
        case "OK":        return .orange
        case "Poor":      return .red
        default:          return .secondary
        }
    }

    // MARK: - Metric Card

    private func metricCard(title: String, value: String, unit: String, icon: String, color: Color, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.subheadline).foregroundColor(color)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                if highlight { PulsingIndicator(color: color).scaleEffect(0.7) }
                Spacer()
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit).font(.caption.weight(.medium)).foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(highlight ? color.opacity(0.5) : Color(.separatorColor).opacity(0.1), lineWidth: highlight ? 1.5 : 0.5))
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status").font(.caption.weight(.medium)).foregroundColor(.secondary)
                Spacer()
                Text(vm.phase.rawValue).font(.caption.weight(.semibold))
                    .foregroundColor(phaseColor)
            }
            ProgressView(value: vm.progress).progressViewStyle(.linear).tint(phaseColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var phaseColor: Color {
        switch vm.phase {
        case .idle:      return .secondary
        case .latency:   return .green
        case .download:  return .blue
        case .upload:    return .orange
        case .browsing:  return .blue
        case .gaming:    return .purple
        case .streaming: return .pink
        case .done:      return .green
        case .failed:    return .red
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(.headline)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tHeader("Time",    width: 90)
                    tHeader("Kind",    width: 90)
                    tHeader("Primary", width: 120)
                    tHeader("Detail",  flexible: true)
                }.padding(.vertical, 8).padding(.horizontal, 12)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.history) { r in
                            HStack(spacing: 0) {
                                Text(r.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                                Text(r.kind.rawValue)
                                    .font(.system(size: 11, weight: .medium)).foregroundColor(.primary).frame(width: 90, alignment: .leading)
                                Text(primaryString(r))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.primary).frame(width: 120, alignment: .leading)
                                Text(detailString(r))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func primaryString(_ r: SpeedTestResult) -> String {
        switch r.kind {
        case .speed:     return String(format: "%.1f Mbps", r.downloadMbps)
        case .browsing:  return String(format: "%.0f ms",   r.browsingAvgMs)
        case .gaming:    return String(format: "%.0f ms",   r.gameMedianMs)
        case .streaming: return r.streamTier
        }
    }

    private func detailString(_ r: SpeedTestResult) -> String {
        switch r.kind {
        case .speed:
            return String(format: "↑ %.1f / ping %.0f ms / jitter %.1f", r.uploadMbps, r.pingMs, r.jitterMs)
        case .browsing:
            return String(format: "TTFB %.0f ms / %d sites", r.browsingMedianTtfb, r.browsingSites)
        case .gaming:
            return String(format: "P99 %.0f / jitter %.1f / loss %.1f%%", r.gameP99Ms, r.gameJitterMs, r.gameLossPct)
        case .streaming:
            return String(format: "avg %.1f / min %.1f Mbps", r.streamAvgMbps, r.streamMinMbps)
        }
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    // MARK: - Guide

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Speed Test Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "Speed", icon: "speedometer") {
                        Text("Sustained download (4 parallel connections, 10 s) and upload (single connection, 10 s) against speed.cloudflare.com. Latency is the median of 8 small HTTP round-trips. Jitter is the standard deviation of those samples.")
                    }
                    GuideSection(title: "Browsing", icon: "safari") {
                        Text("Fetches 8 popular sites sequentially. Reports average full-page load time and median Time-To-First-Byte. Use this to gauge real-world web responsiveness independent of raw Mbps.")
                    }
                    GuideSection(title: "Gaming", icon: "gamecontroller.fill") {
                        Text("Sends 50 HEAD requests to 1.1.1.1 with 50 ms inter-probe spacing — a burst pattern similar to in-game packets. Reports median, P99, jitter, and loss percentage. Under 30 ms median is excellent, over 80 ms is unplayable for competitive games.")
                    }
                    GuideSection(title: "Streaming", icon: "play.tv.fill") {
                        Text("Sustained 15 s download with 1 s window sampling. The MIN throughput across all 1 s windows determines the streaming tier you can sustain without buffering. 25 Mbps min = 4K UHD, 5 Mbps min = 720p HD.")
                    }
                }.padding(24)
            }
        }.frame(width: 540, height: 560)
    }
}
