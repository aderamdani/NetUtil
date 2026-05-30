import SwiftUI
import Observation

struct SpeedTestView: View {
    @Bindable var vm: SpeedTestViewModel
    @Environment(ToolStore.self) private var tools
    @State private var showLearningGuide = false
    @State private var renamingId: UUID?
    @State private var renameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }

                    interpretationSection
                    
                    kindPickerSection
                    
                    metricRowSection
                    
                    progressSection
                    
                    if !vm.history.isEmpty {
                        historySection
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Speed Test") }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
    }

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
                
                Spacer()
                
                HStack(spacing: 16) {
                    if vm.isTesting {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Testing...").font(.system(size: 11, weight: .bold)).foregroundColor(.accentColor)
                        }
                    }
                    
                    Divider().frame(height: 16)
                    
                    Button(action: { if vm.isTesting { vm.cancel() } else { vm.start(connectionName: tools.currentConnectionName) } }) {
                        Label(vm.isTesting ? "Cancel" : "Start Test", systemImage: vm.isTesting ? "stop.fill" : "play.fill")
                            .frame(minWidth: 90)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isTesting ? .red : .accentColor)

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
    }

    private var interpretationSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: vm.kind.icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.kind.rawValue)
                    .font(.headline)
                Text(vm.kind.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var kindPickerSection: some View {
        HStack(spacing: 12) {
            ForEach(SpeedTestKind.allCases) { kind in
                kindButton(kind)
            }
            Spacer()
        }
    }

    private func kindButton(_ kind: SpeedTestKind) -> some View {
        let selected = vm.kind == kind
        return Button {
            guard !vm.isTesting else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.kind = kind }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(kind.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(selected ? .white : .primary)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(vm.isTesting)
        .opacity(vm.isTesting && !selected ? 0.4 : 1.0)
    }

    @ViewBuilder
    private var metricRowSection: some View {
        HStack(spacing: 12) {
            switch vm.kind {
            case .speed:
                metricCard(title: "Download", value: String(format: "%.1f", vm.downloadMbps), unit: "Mbps", icon: "arrow.down", color: .blue, active: vm.phase == .download)
                metricCard(title: "Upload", value: String(format: "%.1f", vm.uploadMbps), unit: "Mbps", icon: "arrow.up", color: .orange, active: vm.phase == .upload)
                metricCard(title: "Latency", value: String(format: "%.0f", vm.pingMs), unit: "ms", icon: "timer", color: .green, active: vm.phase == .latency)
                metricCard(title: "Jitter", value: String(format: "%.1f", vm.jitterMs), unit: "ms", icon: "waveform.path.ecg", color: .purple, active: false)
                
            case .browsing:
                metricCard(title: "Avg Load", value: String(format: "%.0f", vm.browsingAvgMs), unit: "ms", icon: "globe", color: .blue, active: vm.phase == .browsing)
                metricCard(title: "Median TTFB", value: String(format: "%.0f", vm.browsingMedianTtfb), unit: "ms", icon: "timer", color: .orange, active: false)
                metricCard(title: "Success", value: "\(vm.browsingProcessed)", unit: "sites", icon: "checkmark.circle", color: .green, active: false)
                metricCard(title: "Verdict", value: browsingVerdict, unit: "", icon: "checkmark.seal.fill", color: browsingVerdictColor, active: false)
                
            case .gaming:
                metricCard(title: "Median RTT", value: String(format: "%.0f", vm.gameMedianMs), unit: "ms", icon: "timer", color: gameLatencyColor, active: vm.phase == .gaming)
                metricCard(title: "P99 RTT", value: String(format: "%.0f", vm.gameP99Ms), unit: "ms", icon: "exclamationmark.triangle", color: .orange, active: false)
                metricCard(title: "Jitter", value: String(format: "%.1f", vm.gameJitterMs), unit: "ms", icon: "waveform.path.ecg", color: .purple, active: false)
                metricCard(title: "Loss", value: String(format: "%.1f", vm.gameLossPct), unit: "%", icon: "network.slash", color: vm.gameLossPct > 1 ? .red : .green, active: false)
                
            case .streaming:
                metricCard(title: "Avg Rate", value: String(format: "%.1f", vm.streamAvgMbps), unit: "Mbps", icon: "arrow.down", color: .blue, active: vm.phase == .streaming)
                metricCard(title: "Min Rate", value: String(format: "%.1f", vm.streamMinMbps), unit: "Mbps", icon: "arrow.down.to.line", color: .orange, active: false)
                metricCard(title: "Stable Tier", value: vm.streamTier, unit: "", icon: "play.tv", color: .accentColor, active: false)
                metricCard(title: "Verdict", value: streamingVerdict, unit: "", icon: "checkmark.seal.fill", color: streamingVerdictColor, active: false)
            }
        }
    }

    private func metricCard(title: String, value: String, unit: String, icon: String, color: Color, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                if active { PulsingIndicator(color: color).scaleEffect(0.6) }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? color.opacity(0.3) : Color(.separatorColor).opacity(0.1), lineWidth: active ? 1.5 : 0.5))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Operational Status")
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(vm.phase.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(phaseColor)
            }
            
            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(phaseColor)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Historical Benchmarks", icon: "clock.arrow.circlepath")
                Spacer()
                Button(role: .destructive) { vm.clearHistory() } label: {
                    Label("Clear All", systemImage: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tHeader("Timestamp", width: 120)
                    tHeader("Category", width: 80)
                    tHeader("Connection", width: 140)
                    tHeader("Primary Metric", width: 120)
                    tHeader("Verdict", flexible: true)
                }
                .padding(.vertical, 10).padding(.horizontal, 16)
                .background(.regularMaterial)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.history) { r in
                            historyRow(r)
                            if r.id != vm.history.last?.id {
                                Divider().padding(.horizontal, 16).opacity(0.5)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func historyRow(_ r: SpeedTestResult) -> some View {
        let verdict = verdictFor(r)
        return HStack(spacing: 0) {
            Text(r.timestamp.formatted(date: .numeric, time: .shortened))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(r.kind.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            nameCell(r)
                .frame(width: 140, alignment: .leading)
            
            Text(primaryString(r))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(width: 120, alignment: .leading)
            
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(verdict.color)
                Text(verdict.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(verdict.color)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .contextMenu {
            Button("Rename Label...") { renamingId = r.id; renameDraft = r.name ?? "" }
            Button("Copy Summary") { copySummary(r) }
            Divider()
            Button("Delete Result", role: .destructive) { vm.deleteResult(r.id) }
        }
    }

    // MARK: - Verdict Helpers

    private var browsingVerdict: String { let avg = vm.browsingAvgMs; guard avg > 0 else { return "—" }; return avg < 500 ? "Fast" : (avg < 1500 ? "Stable" : "Slow") }
    private var browsingVerdictColor: Color { switch browsingVerdict { case "Fast": .green; case "Stable": .orange; case "Slow": .red; default: .secondary } }
    private var gameLatencyColor: Color { if vm.gameMedianMs == 0 { return .secondary }; return vm.gameMedianMs < 30 ? .green : (vm.gameMedianMs < 80 ? .orange : .red) }
    private var streamingVerdict: String { let min = vm.streamMinMbps; guard min > 0 else { return "—" }; return min >= 25 ? "Excellent" : (min >= 5 ? "Good" : "Poor") }
    private var streamingVerdictColor: Color { switch streamingVerdict { case "Excellent": .green; case "Good": .orange; case "Poor": .red; default: .secondary } }

    private func verdictFor(_ r: SpeedTestResult) -> (label: String, color: Color) {
        switch r.kind {
        case .speed:     let d = r.downloadMbps; return d >= 100 ? ("Excellent", .green) : (d >= 25 ? ("Good", .green) : (d >= 5 ? ("Stable", .orange) : ("Slow", .red)))
        case .browsing:  let a = r.browsingAvgMs; return a <= 0 ? ("—", .secondary) : (a < 500 ? ("Fast", .green) : (a < 1500 ? ("Stable", .orange) : ("Slow", .red)))
        case .gaming:    let p = r.gameMedianMs; if r.gameLossPct > 2 { return ("Lossy", .red) }; return p <= 0 ? ("—", .secondary) : (p < 30 ? ("Excellent", .green) : (p < 80 ? ("Stable", .orange) : ("Unstable", .red)))
        case .streaming: let m = r.streamMinMbps; return m <= 0 ? ("—", .secondary) : (m >= 25 ? ("4K HDR", .green) : (m >= 5 ? ("HD 1080p", .orange) : ("SD 480p", .red)))
        }
    }

    private func primaryString(_ r: SpeedTestResult) -> String {
        switch r.kind {
        case .speed: return String(format: "%.1f Mbps", r.downloadMbps)
        case .browsing: return String(format: "%.0f ms", r.browsingAvgMs)
        case .gaming: return String(format: "%.0f ms", r.gameMedianMs)
        case .streaming: return r.streamTier
        }
    }

    @ViewBuilder
    private func nameCell(_ r: SpeedTestResult) -> some View {
        if renamingId == r.id {
            TextField("", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .onSubmit { vm.renameResult(r.id, to: renameDraft); renamingId = nil }
        } else {
            HStack(spacing: 6) {
                Image(systemName: connectionIcon(r.name))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(r.name ?? "Unnamed Link")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(r.name?.isEmpty == false ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private func connectionIcon(_ name: String?) -> String {
        guard let n = name?.lowercased() else { return "network" }
        if n.contains("wi-fi") || n.contains("wifi") { return "wifi" }
        if n.contains("ethernet") || n.contains("lan") { return "cable.connector" }
        if n.contains("vpn") { return "lock.shield" }
        return "network"
    }

    private func copySummary(_ r: SpeedTestResult) {
        let v = verdictFor(r).label
        let summary = "\(r.timestamp.formatted())  \(r.kind.rawValue)  \(primaryString(r))  [\(v)]"
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(summary, forType: .string)
    }

    private var phaseColor: Color {
        switch vm.phase {
        case .idle: .secondary; case .latency: .green; case .download: .blue; case .upload: .orange; case .browsing: .blue; case .gaming: .purple; case .streaming: .pink; case .done: .green; case .failed: .red
        }
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(msg).font(.subheadline.weight(.medium))
            Spacer()
        }.padding(12).background(Color.red.opacity(0.1)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }
}
