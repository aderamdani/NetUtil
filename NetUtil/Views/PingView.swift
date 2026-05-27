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
    @AppStorage("pingAutoStopLimit")   private var autoStopLimit: Int = 5
    @State private var countText = ""
    @State private var intervalText = ""
    @State private var packetSizeText = ""
    @State private var infinite = false
    @State private var showRaw = false
    @State private var showHistory = false
    @State private var tableScrollID: PingResult.ID?
    @State private var showLearningGuide = false
    
    // Interactive chart state
    @State private var selectedPacket: Int?
    @State private var isHoveringChart = false

    private var resolvedCount: String { countText.isEmpty ? "\(defaultCount)" : countText }
    private var resolvedInterval: String { intervalText.isEmpty ? String(format: "%.1f", defaultInterval) : intervalText }
    private var resolvedPacketSize: Int? { Int(packetSizeText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // STANDARD HEADER
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let err = vm.error {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                            Text(err)
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .bold))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if !vm.results.isEmpty {
                        interpretationHeader
                        
                        statsBar
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("RTT LATENCY HISTORY", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                Spacer()
                                if let selected = selectedPacket, let result = vm.results.first(where: { $0.sequence == selected }) {
                                    HStack(spacing: 8) {
                                        Text("Packet #\(result.sequence)").font(.system(size: 12, weight: .bold))
                                        Text("\(String(format: "%.2f", result.rtt)) ms").font(.system(size: 12)).foregroundColor(rttColor(result.rtt))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            
                            rttChart
                                .frame(height: 180)
                                .chartScrollableAxes(.horizontal)
                                .chartXVisibleDomain(length: 60)
                            
                            distributionBar
                        }
                        .padding(16)
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("", selection: $showRaw) {
                                    Text("Data Table").tag(false)
                                    Text("Console Output").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                
                                Spacer()
                                
                                rttLegend
                            }
                            
                            if showRaw {
                                rawOutput
                            } else {
                                resultsTable
                            }
                        }
                    } else {
                        emptyState
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            learningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("Target host to ping.")
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

            // 2. Variable Settings
            Group {
                Toggle("∞", isOn: $infinite)
                    .toggleStyle(.button)
                    .help("Infinite ping")
                
                Toggle(isOn: $beepOnLoss) {
                    Image(systemName: beepOnLoss ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .toggleStyle(.button)
                .help("Beep on packet loss")

                if !infinite {
                    TextField("Count", text: $countText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }

                TextField("Interval", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 65)

                TextField("Size", text: $packetSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }

            Spacer()

            // 3. Action Group (Standardized)
            if !vm.results.isEmpty {
                Menu {
                    Button("Copy Text Summary") {
                        let summary = """
                        Ping Summary for \(host) (\(vm.resolvedIP ?? "unresolved")):
                        Sent: \(vm.stats.transmitted) | Received: \(vm.stats.received) | Loss: \(String(format: "%.1f%%", vm.stats.loss))
                        RTT Min/Avg/Max/Jitter: \(String(format: "%.2f/%.2f/%.2f/%.2f", vm.stats.minRtt, vm.stats.avgRtt, vm.stats.maxRtt, vm.stats.jitter)) ms
                        """
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summary, forType: .string)
                    }
                    Divider()
                    Button("Export as PDF Report...") {
                        Exporter.savePingPDF(results: vm.results, stats: vm.stats, host: host, resolvedIP: vm.resolvedIP)
                    }
                    Button("Export as CSV...") {
                        let date = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
                        let fileDate = formatter.string(from: date)
                        Exporter.save(string: Exporter.csvString(from: vm.results), defaultName: "NetUtil-Ping-\(host)-\(fileDate).csv", ext: "csv")
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Start Ping")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Ping Learning Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let interpretation = interpretConnection()
            Image(systemName: interpretation.icon)
                .font(.title2)
                .foregroundColor(interpretation.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(interpretation.status)
                    .font(.headline)
                Text(interpretation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            healthStrip
        }
        .padding(.bottom, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready to measure connection stability. Enter a target host and press Start.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }
    
    private func startAction() {
        if vm.isRunning {
            vm.stop()
        } else {
            guard !host.isEmpty else { return }
            history.record(host)
            let count = infinite ? nil : Int(resolvedCount)
            vm.beepOnLoss = beepOnLoss
            vm.start(host: host, count: count,
                     interval: Double(resolvedInterval) ?? defaultInterval,
                     packetSize: resolvedPacketSize)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "SENT", value: "\(vm.stats.transmitted)", icon: "paperplane")
            StatCard(title: "RECEIVED", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
            StatCard(title: "LOSS", value: String(format: "%.1f%%", vm.stats.loss), icon: "exclamationmark.triangle", 
                     color: vm.stats.loss > 0 ? .red : .secondary)
            
            Divider().frame(height: 30).padding(.horizontal, 4)
            
            StatCard(title: "AVG RTT", value: String(format: "%.1f", vm.stats.avgRtt), unit: "ms", icon: "equal", color: rttColor(vm.stats.avgRtt))
            StatCard(title: "JITTER", value: String(format: "%.1f", vm.stats.jitter), unit: "ms", icon: "waveform.path.ecg", 
                     color: vm.stats.jitter > 10 ? .orange : .secondary)
        }
    }

    private var healthStrip: some View {
        let results = vm.results.suffix(100)
        return HStack(spacing: 2) {
            ForEach(results) { r in
                RoundedRectangle(cornerRadius: 1)
                    .fill(healthColor(r))
                    .frame(width: 4, height: 14)
            }
        }
        .help("Health Strip: Last 100 packets. Red = Timeout, Orange = High Latency, Green = Healthy.")
    }

    private func healthColor(_ r: PingResult) -> Color {
        if r.status == .timeout { return .red }
        if r.rtt > rttCrit { return .red }
        if r.rtt > rttWarn { return .orange }
        return .green
    }

    private func interpretConnection() -> (status: String, description: String, icon: String, color: Color) {
        let loss = vm.stats.loss
        let jitter = vm.stats.jitter
        let avg = vm.stats.avgRtt
        
        if loss > 10 {
            return ("Intermittent", "Significant packet loss detected. Check your physical connection or ISP.", "wifi.exclamationmark", .red)
        } else if avg > rttCrit {
            return ("Severe Latency", "Extremely slow response times. Network congestion is likely.", "tortoise.fill", .red)
        } else if jitter > 20 {
            return ("Unstable (High Jitter)", "Large RTT variations. Common on congested Wi-Fi or saturated links.", "waveform.path.ecg", .orange)
        } else if loss > 0 {
            return ("Minor Instability", "Occasional packet drops. Usually acceptable but not ideal.", "shield.exclamationmark.fill", .orange)
        } else if avg > rttWarn {
            return ("Moderate Latency", "Solid connection but slightly higher response time than ideal.", "hand.thumbsup.fill", .green)
        } else {
            return ("Excellent", "Perfectly stable connection with minimal latency.", "checkmark.seal.fill", .green)
        }
    }

    private var rttChart: some View {
        Chart {
            ForEach(vm.results) { r in
                if r.status == .success {
                    AreaMark(
                        x: .value("Packet", r.sequence),
                        y: .value("RTT", r.rtt)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [rttColor(r.rtt).opacity(0.3), rttColor(r.rtt).opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Packet", r.sequence),
                        y: .value("RTT", r.rtt)
                    )
                    .foregroundStyle(rttColor(r.rtt))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                    
                    if vm.results.count < 30 || selectedPacket == r.sequence {
                        PointMark(
                            x: .value("Packet", r.sequence),
                            y: .value("RTT", r.rtt)
                        )
                        .symbolSize(selectedPacket == r.sequence ? 100 : 40)
                        .foregroundStyle(rttColor(r.rtt))
                    }
                } else {
                    BarMark(
                        x: .value("Packet", r.sequence),
                        yStart: .value("Base", 0),
                        yEnd: .value("Max", vm.stats.maxRtt > 0 ? vm.stats.maxRtt : 100)
                    )
                    .foregroundStyle(Color.red.opacity(0.2))
                }
            }
            
            if let selected = selectedPacket, let _ = vm.results.first(where: { $0.sequence == selected }) {
                RuleMark(x: .value("Selected", selected))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            
            RuleMark(y: .value("Avg", vm.stats.avgRtt))
                .foregroundStyle(Color.primary.opacity(0.2))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("avg").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                }
        }
        .chartXScale(domain: .automatic)
        .chartYScale(domain: 0...(max(vm.stats.maxRtt * 1.1, 50)))
        .chartXSelection(value: $selectedPacket)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text("\(Int(val))ms").font(.system(size: 9))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text("#\(val)").font(.system(size: 9))
                    }
                }
            }
        }
    }

    private var distributionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LATENCY DISTRIBUTION")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                HStack(spacing: 1) {
                    distributionSegment(count: vm.stats.bucketLow, color: .green, total: geo.size.width)
                    distributionSegment(count: vm.stats.bucketMedium, color: .orange, total: geo.size.width)
                    distributionSegment(count: vm.stats.bucketHigh, color: .red, total: geo.size.width)
                    distributionSegment(count: vm.stats.bucketCritical, color: .purple, total: geo.size.width)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
    }

    private func distributionSegment(count: Int, color: Color, total: CGFloat) -> some View {
        let totalCount = max(1, vm.stats.received)
        let ratio = CGFloat(count) / CGFloat(totalCount)
        return Rectangle()
            .fill(color)
            .frame(width: max(0, ratio * total))
    }

    private var resultsTable: some View {
        VStack(spacing: 0) {
            // macOS Style Sticky Header
            HStack(spacing: 0) {
                headerCell("Seq", width: 60)
                headerCell("Status", width: 90)
                headerCell("RTT", width: 110)
                headerCell("IP Address", width: nil)
                headerCell("TTL", width: 50)
                headerCell("Timestamp", width: 140)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.results) { r in
                            HStack(spacing: 0) {
                                Text("\(r.sequence)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundColor(r.status == .timeout ? .red : .primary)
                                
                                HStack(spacing: 8) {
                                    Circle().fill(r.status == .success ? rttColor(r.rtt) : .red).frame(width: 6, height: 6)
                                    Text(r.status == .success ? "Success" : "Timeout")
                                        .font(.system(size: 11))
                                }
                                .frame(width: 90, alignment: .leading)
                                
                                Text(r.status == .success ? String(format: "%.3f ms", r.rtt) : "—")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(width: 110, alignment: .leading)
                                    .foregroundColor(rttColor(r.rtt))
                                
                                Text(r.ipAddress ?? vm.resolvedIP ?? "—")
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.secondary)
                                
                                Text(r.status == .success ? "\(r.ttl)" : "—")
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 50, alignment: .leading)
                                    .foregroundColor(.secondary)
                                
                                Text(r.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 140, alignment: .trailing)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .id(r.id)
                            
                            Divider().opacity(0.2)
                        }
                    }
                }
                .onChange(of: vm.results.count) {
                    if let lastID = vm.results.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }
    
    private func headerCell(_ title: String, width: CGFloat?) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private var rawOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.system(size: 11))
                            .padding(.horizontal, 4)
                            .id(i)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .onChange(of: vm.rawLines.count) {
                if let last = vm.rawLines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private var rttLegend: some View {
        HStack(spacing: 16) {
            legendItem(.green,  "Stable")
            legendItem(.orange, "Lagging")
            legendItem(.red,    "Critical")
            legendItem(.purple, "Spiking")
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        if rtt < 250 { return .red }
        return .purple
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ping Learning Guide").font(.title2.bold())
                    Text("Learn how to interpret network latency diagnostics.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is Ping?", icon: "antenna.radiowaves.left.and.right") {
                        Text("Ping is a basic diagnostic tool that sends a small packet of data (ICMP Echo Request) to a destination and waits for a reply. It measures how fast your connection is and if any data is being lost.")
                    }
                    
                    GuideSection(title: "Understanding Metrics", icon: "gauge.medium") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "RTT (Round Trip Time)", desc: "The time (in milliseconds) it takes for a packet to go to the host and back. Lower is better (e.g., <20ms for gaming, <100ms for browsing).")
                            GuidePoint(title: "Jitter", desc: "The variation in RTT between packets. High jitter (>20ms) causes stuttering in video calls and online gaming.")
                            GuidePoint(title: "Packet Loss", desc: "The percentage of packets that failed to reach the destination. Even 1% loss can cause noticeable lag.")
                        }
                    }
                    
                    GuideSection(title: "Reading the Chart", icon: "chart.line.uptrend.xyaxis") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• **Green Zone**: Stable connection with low latency.")
                            Text("• **Orange/Red Peaks**: Sudden lag spikes, often caused by local network congestion or ISP routing issues.")
                            Text("• **Red Bars**: Timeouts (100% loss) where the destination didn't respond.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Educational Components

struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.accentColor).font(.headline)
                Text(title).font(.headline)
            }
            content.font(.subheadline).foregroundColor(.secondary)
        }
    }
}

struct GuidePoint: View {
    let title: String
    let desc: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .black)).foregroundColor(.primary)
            Text(desc).fixedSize(horizontal: false, vertical: true)
        }
    }
}
