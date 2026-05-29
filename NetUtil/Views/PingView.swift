import SwiftUI
import Charts

struct PingView: View {
    @ObservedObject var vm: PingViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @AppStorage("defaultPingCount")    private var defaultCount: Int = 20
    @AppStorage("defaultPingInterval") private var defaultInterval: Double = 1.0
    @AppStorage("rttWarnThreshold")    private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")    private var rttCrit: Double = 100.0
    @AppStorage("pingBeepOnLoss")      private var beepOnLoss: Bool = false
    @State private var countText = ""
    @State private var intervalText = ""
    @State private var packetSizeText = ""
    @State private var infinite = false
    @State private var showRaw = false
    @State private var showLearningGuide = false
    @State private var selectedPacket: Int?

    private var resolvedCount: String { countText.isEmpty ? "\(defaultCount)" : countText }
    private var resolvedInterval: String { intervalText.isEmpty ? String(format: "%.1f", defaultInterval) : intervalText }
    private var resolvedPacketSize: Int? { Int(packetSizeText) }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if !vm.results.isEmpty {
                        statsBarSection
                        
                        latencyHistorySection
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Picker("", selection: $showRaw) {
                                    Text("Analysis").tag(false)
                                    Text("Console Log").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                                
                                Spacer()
                                rttLegend
                            }
                            
                            if showRaw {
                                rawOutput
                            } else {
                                resultsTable
                            }
                        }
                    } else if vm.isRunning {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Advanced Ping") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Advanced Ping")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    TextField("Hostname or IP address", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .frame(width: 250)
                        .onSubmit(startAction)
                        .overlay(alignment: .trailing) {
                            if !history.hosts.isEmpty {
                                Menu {
                                    ForEach(history.hosts, id: \.self) { h in
                                        Button(h) { host = h; startAction() }
                                    }
                                    Divider()
                                    Button("Clear History", role: .destructive) { history.clear() }
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.secondary)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 28)
                                .padding(.trailing, 4)
                            }
                        }

                    HStack(spacing: 8) {
                        Toggle(isOn: $infinite) {
                            Image(systemName: "infinity")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .toggleStyle(.button)
                        .help("Infinite Ping")
                        
                        Toggle(isOn: $beepOnLoss) {
                            Image(systemName: beepOnLoss ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 11))
                        }
                        .toggleStyle(.button)
                        .help("Audio Feedback on Loss")
                        
                        if !infinite {
                            TextField("Count", text: $countText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .help("Packet Count")
                        }
                        
                        TextField("Interval", text: $intervalText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .help("Wait Interval (s)")
                    }

                    if !vm.results.isEmpty {
                        Menu {
                            Button("Export PDF Report") { Exporter.savePingPDF(results: vm.results, stats: vm.stats, host: host, resolvedIP: vm.resolvedIP) }
                            Button("Export CSV Data") {
                                let date = DateFormatter(); date.dateFormat = "yyyy-MM-dd_HH.mm.ss"
                                Exporter.save(string: Exporter.csvString(from: vm.results), defaultName: "ping-\(host)-\(date.string(from: Date())).csv", ext: "csv")
                            }
                        } label: {
                            Label("Report", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: startAction) {
                        Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && host.isEmpty)
                    
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

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Transmitted", value: "\(vm.stats.transmitted)", icon: "paperplane")
            StatCard(title: "Received", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
            StatCard(title: "Packet Loss", value: String(format: "%.1f%%", vm.stats.loss), icon: "exclamationmark.triangle", color: vm.stats.loss > 0 ? .red : .primary)
            StatCard(title: "Average RTT", value: String(format: "%.1f", vm.stats.avgRtt), unit: "ms", icon: "equal", color: rttColor(vm.stats.avgRtt))
            StatCard(title: "Jitter", value: String(format: "%.1f", vm.stats.jitter), unit: "ms", icon: "waveform.path.ecg", color: vm.stats.jitter > 10 ? .orange : .primary)
        }
    }

    private var latencyHistorySection: some View {
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
            }
            
            VStack(spacing: 0) {
                rttChart
                    .frame(height: 160)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: 60)
                
                Divider().padding(.vertical, 12).opacity(0.5)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality Distribution")
                        .font(.system(.caption2, design: .default).weight(.bold))
                        .foregroundColor(.secondary)
                    distributionBar
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var rttChart: some View {
        Chart {
            ForEach(vm.results) { r in
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
            if let selected = selectedPacket, let res = vm.results.first(where: { $0.sequence == selected }) {
                RuleMark(x: .value("S", selected))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 4) {
                            Text("Seq \(res.sequence)").font(.caption2.bold())
                            Text(res.status == .success ? String(format: "%.2f ms", res.rtt) : "Timeout")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(rttColor(res.rtt))
                        }
                        .padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                    }
            }
        }
        .chartXSelection(value: $selectedPacket)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v)) ms")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }

    private var resultsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Sequence", width: 80)
                tHeader("Status", width: 100)
                tHeader("Latency", width: 120)
                tHeader("Target IP", flexible: true)
                tHeader("Timestamp", width: 120)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.results) { r in
                            HStack(spacing: 0) {
                                Text("\(r.sequence)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 80, alignment: .leading)
                                    .foregroundColor(.secondary)
                                
                                StatusBadge(isSuccess: r.status == .success)
                                    .frame(width: 100, alignment: .leading)
                                
                                let rttString = r.status == .success ? String(format: "%.2f ms", r.rtt) : "—"
                                Text(rttString)
                                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                                    .frame(width: 120, alignment: .leading)
                                    .foregroundColor(rttColor(r.rtt))
                                
                                let ipString = r.ipAddress ?? vm.resolvedIP ?? "—"
                                Text(ipString)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(r.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 16).id(r.id)
                            
                            if r.id != vm.results.last?.id {
                                Divider().padding(.horizontal, 16).opacity(0.5)
                            }
                        }
                    }
                }
                .onChange(of: vm.results.count) { if let last = vm.results.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private var healthStrip: some View {
        let results = vm.results.suffix(60)
        return HStack(spacing: 2) {
            ForEach(results) { r in
                RoundedRectangle(cornerRadius: 1)
                    .fill(healthColor(r))
                    .frame(width: 3, height: 12)
            }
        }
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
                distSegment(count: vm.stats.bucketLow, color: .primary.opacity(0.5), total: geo.size.width)
                distSegment(count: vm.stats.bucketMedium, color: .orange, total: geo.size.width)
                distSegment(count: vm.stats.bucketHigh, color: .red, total: geo.size.width)
                distSegment(count: vm.stats.bucketCritical, color: .purple, total: geo.size.width)
            }
        }.frame(height: 6).clipShape(Capsule())
    }

    private func distSegment(count: Int, color: Color, total: CGFloat) -> some View {
        let ratio = CGFloat(count) / CGFloat(max(1, vm.stats.received))
        return Rectangle().fill(color).frame(width: max(0, ratio * total))
    }

    private var rttLegend: some View {
        HStack(spacing: 16) {
            ForEach([("Normal", Color.primary.opacity(0.5)), ("High", Color.orange), ("Critical", Color.red)], id: \.0) { item in
                HStack(spacing: 6) {
                    Circle().fill(item.1).frame(width: 6, height: 6)
                    Text(item.0).font(.caption2.weight(.bold)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Host Target")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter an IP or hostname to analyze network performance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Waiting for ICMP sequence...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var rawOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .id(i)
                    }
                }
                .padding(16)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .onChange(of: vm.rawLines.count) { if let last = vm.rawLines.indices.last { proxy.scrollTo(last, anchor: .bottom) } }
        }
        .frame(minHeight: 300)
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, count: infinite ? nil : Int(resolvedCount), interval: Double(resolvedInterval) ?? defaultInterval, packetSize: resolvedPacketSize) }
    }
}

private struct StatusBadge: View {
    let isSuccess: Bool
    var body: some View {
        Text(isSuccess ? "Success" : "Timeout")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundColor(isSuccess ? .green : .red)
            .cornerRadius(4)
    }
}
