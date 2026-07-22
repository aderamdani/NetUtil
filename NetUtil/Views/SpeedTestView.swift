import SwiftUI
import Observation

struct SpeedTestView: View {
    @Bindable var vm: SpeedTestViewModel
    @State private var showLearningGuide = false
    @State private var editingResultID: UUID?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            speedMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error { errorBanner(err) }

                    if vm.isRunning || vm.lastResult != nil {
                        liveMetricsSection
                        if vm.isRunning { progressSection }
                    } else {
                        emptyState
                    }

                    if !vm.history.isEmpty {
                        historySection
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Speed Test") }
    }

    // MARK: - Mood Bar

    private var speedMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .accentColor, "Running \(vm.kind.rawValue) test...") }
            guard let r = vm.lastResult else {
                return ("speedometer", .secondary, "No test results yet — select a test type and tap Start")
            }
            switch r.kind {
            case .speed:
                return ("speedometer", .green, "Last: ↓ \(String(format: "%.1f", r.downloadMbps)) / ↑ \(String(format: "%.1f", r.uploadMbps)) Mbps  —  \(Int(r.pingMs)) ms ping")
            case .browsing:
                return ("safari.fill", .blue, "Last browsing: \(String(format: "%.0f", r.browsingAvgMs)) ms avg")
            case .gaming:
                return ("gamecontroller.fill", .purple, "Last gaming: \(String(format: "%.0f", r.gameMedianMs)) ms median")
            case .streaming:
                return ("play.rectangle.fill", .orange, "Last streaming: \(r.streamTier)")
            }
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Speed Test")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Speed Test Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                Picker("", selection: $vm.kind) {
                    ForEach(SpeedTestKind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
                .disabled(vm.isRunning)
                .accessibilityLabel("Test Kind")

                Spacer()

                HStack(spacing: 12) {
                    if !vm.history.isEmpty {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveSpeedTestPDF(history: vm.history) },
                            onExportCSV: {
                                let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: Exporter.csvString(from: vm.history),
                                              defaultName: "NetUtil-SpeedTest-\(ts.string(from: Date())).csv",
                                              ext: "csv")
                            }
                        )
                    }

                    Button(action: { if vm.isRunning { vm.cancel() } else { vm.start() } }) {
                        Label(vm.isRunning ? "Stop" : "Start",
                              systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .accessibilityLabel(vm.isRunning ? "Stop Speed Test" : "Start Speed Test")

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            Divider()
        }
    }

    // MARK: - Live Metrics

    @ViewBuilder
    private var liveMetricsSection: some View {
        switch vm.kind {
        case .speed:     speedMetrics
        case .browsing:  browsingMetrics
        case .gaming:    gamingMetrics
        case .streaming: streamingMetrics
        }
    }

    private var speedMetrics: some View {
        HStack(spacing: 12) {
            StatCard(title: "Download",
                     value: String(format: "%.1f", vm.downloadMbps),
                     unit: "Mbps", icon: "arrow.down.circle.fill",
                     color: speedColor(vm.downloadMbps))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f megabits per second download", vm.downloadMbps))
            StatCard(title: "Upload",
                     value: String(format: "%.1f", vm.uploadMbps),
                     unit: "Mbps", icon: "arrow.up.circle.fill",
                     color: speedColor(vm.uploadMbps))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f megabits per second upload", vm.uploadMbps))
            StatCard(title: "Ping",
                     value: String(format: "%.0f", vm.pingMs),
                     unit: "ms", icon: "timer",
                     color: pingColor(vm.pingMs))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.0f milliseconds ping", vm.pingMs))
            StatCard(title: "Jitter",
                     value: String(format: "%.1f", vm.jitterMs),
                     unit: "ms", icon: "waveform.path.ecg",
                     color: vm.jitterMs > 20 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f milliseconds jitter", vm.jitterMs))
        }
    }

    private var browsingMetrics: some View {
        HStack(spacing: 12) {
            StatCard(title: "Sites Tested",
                     value: "\(vm.browsingProcessed)",
                     unit: "/ 8", icon: "safari")
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(vm.browsingProcessed) of 8 sites tested")
            StatCard(title: "Avg Load",
                     value: String(format: "%.0f", vm.browsingAvgMs),
                     unit: "ms", icon: "clock",
                     color: vm.browsingAvgMs > 1000 ? .red : vm.browsingAvgMs > 500 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.0f milliseconds average load time", vm.browsingAvgMs))
            StatCard(title: "Median TTFB",
                     value: String(format: "%.0f", vm.browsingMedianTtfb),
                     unit: "ms", icon: "bolt",
                     color: vm.browsingMedianTtfb > 300 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.0f milliseconds median TTFB", vm.browsingMedianTtfb))
        }
    }

    private var gamingMetrics: some View {
        HStack(spacing: 12) {
            StatCard(title: "Median Ping",
                     value: String(format: "%.0f", vm.gameMedianMs),
                     unit: "ms", icon: "gamecontroller.fill",
                     color: pingColor(vm.gameMedianMs))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.0f milliseconds median ping", vm.gameMedianMs))
            StatCard(title: "P99 Ping",
                     value: String(format: "%.0f", vm.gameP99Ms),
                     unit: "ms", icon: "chart.line.uptrend.xyaxis",
                     color: pingColor(vm.gameP99Ms))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.0f milliseconds P99", vm.gameP99Ms))
            StatCard(title: "Jitter",
                     value: String(format: "%.1f", vm.gameJitterMs),
                     unit: "ms", icon: "waveform.path.ecg",
                     color: vm.gameJitterMs > 10 ? .orange : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f milliseconds jitter", vm.gameJitterMs))
            StatCard(title: "Packet Loss",
                     value: String(format: "%.1f", vm.gameLossPct),
                     unit: "%", icon: "exclamationmark.triangle",
                     color: vm.gameLossPct > 1 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent packet loss", vm.gameLossPct))
        }
    }

    private var streamingMetrics: some View {
        HStack(spacing: 12) {
            StatCard(title: "Avg Speed",
                     value: String(format: "%.1f", vm.streamAvgMbps),
                     unit: "Mbps", icon: "play.tv.fill",
                     color: speedColor(vm.streamAvgMbps))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f megabits per second average", vm.streamAvgMbps))
            StatCard(title: "Min Speed",
                     value: String(format: "%.1f", vm.streamMinMbps),
                     unit: "Mbps", icon: "arrow.down.to.line",
                     color: speedColor(vm.streamMinMbps))
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f megabits per second minimum", vm.streamMinMbps))
            StatCard(title: "Stream Tier",
                     value: vm.streamTier,
                     icon: "tv.fill",
                     color: tierColor(vm.streamTier))
                .accessibilityElement(children: .combine)
                .accessibilityValue("Stream quality tier: \(vm.streamTier)")
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vm.phase.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(vm.progress * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.phase.rawValue) — \(Int(vm.progress * 100)) percent complete")
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.headline)
                    Text("Click a label cell to rename a result")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    withAnimation { vm.clearHistory() }
                } label: {
                    Label("Clear", systemImage: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear all history")
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tHeader("Time",      width: 80)
                    tHeader("Kind",      width: 90)
                    tHeader("Label",     flexible: true)
                    tHeader("Primary",   width: 180)
                    tHeader("Secondary", width: 170)
                    tHeader("",          width: 32)
                }
                .padding(.vertical, 10).padding(.horizontal, 16)
                .background(.regularMaterial)

                Divider()

                LazyVStack(spacing: 0) {
                    ForEach(vm.history) { result in
                        historyRow(result)
                        if result.id != vm.history.last?.id {
                            Divider().padding(.horizontal, 16).opacity(0.5)
                        }
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func historyRow(_ result: SpeedTestResult) -> some View {
        HStack(spacing: 0) {
            Text(result.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: result.kind.icon).font(.caption2)
                Text(result.kind.rawValue).font(.caption)
            }
            .foregroundColor(.secondary)
            .frame(width: 90, alignment: .leading)

            Group {
                if editingResultID == result.id {
                    TextField("Label", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            vm.renameResult(result.id, to: editingName)
                            editingResultID = nil
                        }
                } else {
                    Text(result.name ?? "—")
                        .font(.caption)
                        .foregroundColor(result.name != nil ? .primary : .secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingResultID = result.id
                            editingName = result.name ?? ""
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(primaryMetric(result))
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .frame(width: 180, alignment: .leading)

            Text(secondaryMetric(result))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)

            Button {
                withAnimation { vm.deleteResult(result.id) }
            } label: {
                Image(systemName: "trash").font(.caption2).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 32, alignment: .center)
            .accessibilityLabel("Delete result")
        }
        .padding(.vertical, 8).padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.kind.rawValue) test: \(primaryMetric(result))")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("No Test Results")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(SpeedTestKind.allCases) { kind in
                    kindCard(kind)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func kindCard(_ kind: SpeedTestKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: kind.icon)
                .font(.title3)
                .foregroundColor(vm.kind == kind ? .accentColor : .secondary)
            Text(kind.rawValue)
                .font(.system(.subheadline, weight: .semibold))
            Text(kind.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .fill(vm.kind == kind ? Color.accentColor.opacity(0.08) : Color.clear)
            RoundedRectangle(cornerRadius: 10)
                .stroke(vm.kind == kind ? Color.accentColor.opacity(0.5) : Color(.separatorColor).opacity(0.1),
                        lineWidth: vm.kind == kind ? 1 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { if !vm.isRunning { vm.kind = kind } }
        .accessibilityLabel("\(kind.rawValue): \(kind.subtitle)")
        .accessibilityAddTraits(vm.kind == kind ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Error Banner

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(msg).font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        .accessibilityLabel("Error: \(msg)")
    }

    // MARK: - Helpers

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func primaryMetric(_ r: SpeedTestResult) -> String {
        switch r.kind {
        case .speed:     return String(format: "↓%.1f  ↑%.1f Mbps", r.downloadMbps, r.uploadMbps)
        case .browsing:  return String(format: "%.0f ms avg load", r.browsingAvgMs)
        case .gaming:    return String(format: "%.0f ms median", r.gameMedianMs)
        case .streaming: return r.streamTier
        }
    }

    private func secondaryMetric(_ r: SpeedTestResult) -> String {
        switch r.kind {
        case .speed:     return String(format: "%.0f ms ping  ±%.1f ms jitter", r.pingMs, r.jitterMs)
        case .browsing:  return String(format: "%.0f ms TTFB  %d sites", r.browsingMedianTtfb, r.browsingSites)
        case .gaming:    return String(format: "P99 %.0f ms  %.1f%% loss", r.gameP99Ms, r.gameLossPct)
        case .streaming: return String(format: "avg %.1f  min %.1f Mbps", r.streamAvgMbps, r.streamMinMbps)
        }
    }

    private func speedColor(_ mbps: Double) -> Color {
        if mbps >= 100 { return .green }
        if mbps >= 25  { return .primary }
        if mbps >= 5   { return .orange }
        return mbps > 0 ? .red : .primary
    }

    private func pingColor(_ ms: Double) -> Color {
        if ms == 0    { return .primary }
        if ms < 30    { return .green }
        if ms < 80    { return .primary }
        if ms < 150   { return .orange }
        return .red
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "8K UHD", "4K UHD":   return .green
        case "1080p HD", "720p HD": return .primary
        case "480p SD":             return .orange
        case "240p":                return .red
        default:                    return .secondary
        }
    }
}
