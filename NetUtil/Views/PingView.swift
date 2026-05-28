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
        VStack(alignment: .leading, spacing: 0) {
            controlBar
                .padding(.bottom, 24)
            
            if let err = vm.error {
                errorBanner(err).padding(.bottom, 16)
            }
            
            if !vm.results.isEmpty {
                statsBar.padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        sectionHeader("Latency History")
                        Spacer()
                        healthStrip
                    }
                    
                    rttChart
                        .frame(height: 140)
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: 60)
                    
                    distributionBar
                }
                .padding(.bottom, 32)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("", selection: $showRaw) {
                            Text("Data").tag(false)
                            Text("Log").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        
                        Spacer()
                        rttLegend
                    }
                    
                    if showRaw {
                        rawOutput
                    } else {
                        resultsTable
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .onSubmit(startAction)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { host = h; startAction() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }
                        .menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Toggle("∞", isOn: $infinite).toggleStyle(.button).help("Infinite ping")
                Toggle(isOn: $beepOnLoss) { Image(systemName: beepOnLoss ? "speaker.wave.2.fill" : "speaker.slash.fill") }.toggleStyle(.button)
                if !infinite { TextField("Count", text: $countText).textFieldStyle(.roundedBorder).frame(width: 55) }
                TextField("Interval", text: $intervalText).textFieldStyle(.roundedBorder).frame(width: 60)
            }

            Spacer()

            if !vm.results.isEmpty {
                Menu {
                    Button("Export PDF...") { Exporter.savePingPDF(results: vm.results, stats: vm.stats, host: host, resolvedIP: vm.resolvedIP) }
                    Button("Export CSV...") {
                        let date = DateFormatter(); date.dateFormat = "yyyy-MM-dd_HH.mm.ss"
                        Exporter.save(string: Exporter.csvString(from: vm.results), defaultName: "ping-\(host)-\(date.string(from: Date())).csv", ext: "csv")
                    }
                } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }
                .buttonStyle(.bordered)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                    Text(vm.isRunning ? "Stop" : "Start")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
            .buttonStyle(.borderless)
        }
    }
    
    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Sent", value: "\(vm.stats.transmitted)", icon: "paperplane")
            StatCard(title: "Received", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
            StatCard(title: "Loss", value: String(format: "%.1f%%", vm.stats.loss), icon: "exclamationmark.triangle", color: vm.stats.loss > 0 ? .red : .primary)
            StatCard(title: "Avg RTT", value: String(format: "%.1f", vm.stats.avgRtt), unit: "ms", icon: "equal", color: rttColor(vm.stats.avgRtt))
            StatCard(title: "Jitter", value: String(format: "%.1f", vm.stats.jitter), unit: "ms", icon: "waveform.path.ecg", color: vm.stats.jitter > 10 ? .orange : .primary)
            Spacer()
        }
    }

    private var rttChart: some View {
        Chart {
            ForEach(vm.results) { r in
                if r.status == .success {
                    AreaMark(x: .value("P", r.sequence), y: .value("R", r.rtt))
                        .foregroundStyle(LinearGradient(colors: [rttColor(r.rtt).opacity(0.15), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)

                    LineMark(x: .value("P", r.sequence), y: .value("R", r.rtt))
                        .foregroundStyle(rttColor(r.rtt))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                } else {
                    RuleMark(x: .value("P", r.sequence)).foregroundStyle(Color.red.opacity(0.3))
                }
            }
            if let selected = selectedPacket, let _ = vm.results.first(where: { $0.sequence == selected }) {
                RuleMark(x: .value("S", selected)).foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .chartXSelection(value: $selectedPacket)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))").font(.system(size: 10)) } }
            }
        }
        .chartXAxis(.hidden)
    }

    private var resultsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Seq", width: 60)
                tHeader("Status", width: 90)
                tHeader("RTT", width: 100)
                tHeader("IP Address", flexible: true)
                tHeader("Timestamp", width: 100)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.results) { r in
                            HStack(spacing: 0) {
                                Text("\(r.sequence)").font(.system(size: 11, design: .monospaced)).frame(width: 60, alignment: .leading).foregroundColor(.secondary)
                                Text(r.status == .success ? "Success" : "Timeout").font(.system(size: 11)).foregroundColor(r.status == .success ? .primary : .red).frame(width: 90, alignment: .leading)
                                
                                let rttString = r.status == .success ? String(format: "%.2f ms", r.rtt) : "—"
                                Text(rttString).font(.system(size: 11, design: .monospaced)).frame(width: 100, alignment: .leading).foregroundColor(rttColor(r.rtt))
                                
                                let ipString = r.ipAddress ?? vm.resolvedIP ?? "—"
                                Text(ipString).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(r.timestamp, format: .dateTime.hour().minute().second()).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 100, alignment: .trailing)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12).id(r.id)
                            Divider().opacity(0.5)
                        }
                    }
                }
                .onChange(of: vm.results.count) { if let last = vm.results.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.headline).foregroundColor(.primary)
    }
    
    private func errorBanner(_ msg: String) -> some View {
        Text(msg).foregroundColor(.red).font(.system(size: 12, weight: .medium))
    }

    private var healthStrip: some View {
        let results = vm.results.suffix(60)
        return HStack(spacing: 2) {
            ForEach(results) { r in RoundedRectangle(cornerRadius: 1).fill(healthColor(r)).frame(width: 3, height: 12) }
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
        }.frame(height: 4).clipShape(Capsule())
    }

    private func distSegment(count: Int, color: Color, total: CGFloat) -> some View {
        let ratio = CGFloat(count) / CGFloat(max(1, vm.stats.received))
        return Rectangle().fill(color).frame(width: max(0, ratio * total))
    }

    private var rttLegend: some View {
        HStack(spacing: 12) {
            ForEach([("Normal", Color.primary.opacity(0.5)), ("High", Color.orange), ("Critical", Color.red)], id: \.0) { item in
                HStack(spacing: 4) {
                    Circle().fill(item.1).frame(width: 6, height: 6)
                    Text(item.0).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No Target Selected").font(.headline).foregroundColor(.secondary)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rawOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).id(i)
                    }
                }.padding(12)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: vm.rawLines.count) { if let last = vm.rawLines.indices.last { proxy.scrollTo(last, anchor: .bottom) } }
        }
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, count: infinite ? nil : Int(resolvedCount), interval: Double(resolvedInterval) ?? defaultInterval, packetSize: resolvedPacketSize) }
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Ping Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is Ping?", icon: "antenna.radiowaves.left.and.right") { Text("Measures round-trip time.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}
