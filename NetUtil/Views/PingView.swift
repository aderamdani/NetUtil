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

    private var resolvedCount: String { countText.isEmpty ? "\(defaultCount)" : countText }
    private var resolvedInterval: String { intervalText.isEmpty ? String(format: "%.1f", defaultInterval) : intervalText }
    private var resolvedPacketSize: Int? { Int(packetSizeText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
                .onAppear {
                    if host.isEmpty, !vm.currentHost.isEmpty {
                        host = vm.currentHost
                    }
                }
            
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            
            if let ip = vm.resolvedIP {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .foregroundColor(.secondary)
                    Text("Pinging \(host) (\(ip))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if vm.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .opacity(0.8)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !vm.results.isEmpty {
                statsBar
            }
            if vm.results.count > 1 {
                rttChart
                distributionBar
            }
            HStack {
                Picker("", selection: $showRaw) {
                    Text("Table").tag(false)
                    Text("Raw").tag(true)
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
        .padding()
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Hostname or IP", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .help("Enter the domain name (e.g., google.com) or IP address to test connectivity.")
                    .onSubmit {
                        guard !host.isEmpty, !vm.isRunning else { return }
                        history.record(host)
                        let count = infinite ? nil : Int(resolvedCount)
                        vm.beepOnLoss = beepOnLoss
                        vm.autoStopTimeoutLimit = autoStopLimit > 0 ? autoStopLimit : nil
                        vm.start(host: host, count: count,
                                 interval: Double(resolvedInterval) ?? defaultInterval,
                                 packetSize: resolvedPacketSize)
                    }
                if !history.hosts.isEmpty {
                    Menu {
                        ForEach(history.hosts, id: \.self) { h in
                            Button(h) { host = h }
                        }
                        Divider()
                        Button("Clear History", role: .destructive) { history.clear() }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .help("Recent host history")
                }
            }

            Toggle("Continuous", isOn: $infinite)
                .toggleStyle(.checkbox)
                .help("If enabled, ping will run indefinitely until stopped manually.")
            
            Toggle(isOn: $beepOnLoss) {
                Image(systemName: "speaker.wave.2")
            }
            .toggleStyle(.button)
            .help("Play a system beep sound whenever a packet is lost (timeout).")

            if !infinite {
                HStack(spacing: 4) {
                    Text("Packets:")
                        .fixedSize()
                    TextField("", text: $countText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 45)
                }
                .help("Number of packets to send before stopping automatically.")
            }

            HStack(spacing: 4) {
                Text("Delay:")
                    .fixedSize()
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
                Text("sec")
                    .fixedSize()
            }
            .help("Wait time between sending each packet (in seconds).")

            HStack(spacing: 4) {
                Text("Size:")
                    .fixedSize()
                TextField("56", text: $packetSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
                Text("bytes")
                    .fixedSize()
            }
            .help("Size of the data payload in bytes. Default is 56 (64 bytes total with header).")

            Spacer()

            if !vm.results.isEmpty {
                Menu {
                    Button("Copy Summary") {
                        let summary = """
                        Ping Summary for \(host) (\(vm.resolvedIP ?? "unresolved")):
                        Sent: \(vm.stats.transmitted)
                        Received: \(vm.stats.received)
                        Loss: \(String(format: "%.1f%%", vm.stats.loss))
                        RTT Min/Avg/Max/Jitter: \(String(format: "%.2f/%.2f/%.2f/%.2f", vm.stats.minRtt, vm.stats.avgRtt, vm.stats.maxRtt, vm.stats.jitter)) ms
                        """
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summary, forType: .string)
                    }
                    Divider()
                    Button("Export CSV") {
                        Exporter.save(
                            string: Exporter.csvString(from: vm.results),
                            defaultName: "ping-\(host).csv", ext: "csv"
                        )
                    }
                    Button("Export JSON") {
                        if let data = try? Exporter.jsonData(from: vm.results) {
                            Exporter.save(data: data, defaultName: "ping-\(host).json", ext: "json")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
            }

            Button(vm.isRunning ? "Stop" : "Ping") {
                if vm.isRunning {
                    vm.stop()
                } else {
                    history.record(host)
                    let count = infinite ? nil : Int(resolvedCount)
                    vm.beepOnLoss = beepOnLoss
                    vm.autoStopTimeoutLimit = autoStopLimit > 0 ? autoStopLimit : nil
                    vm.start(host: host, count: count, 
                             interval: Double(resolvedInterval) ?? defaultInterval,
                             packetSize: resolvedPacketSize)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Sent", value: "\(vm.stats.transmitted)", icon: "paperplane")
                .help("Total number of ICMP echo request packets sent.")
            StatCard(title: "Received", value: "\(vm.stats.received)", icon: "tray.and.arrow.down")
                .help("Total number of successful echo replies received back from the host.")
            StatCard(title: "Loss", 
                     value: String(format: "%.1f%%", vm.stats.loss), 
                     icon: "exclamationmark.triangle",
                     color: vm.stats.loss > lossAlert ? .red : vm.stats.loss > 0 ? .orange : .primary)
                .help("Percentage of packets that failed to return (Packet Loss). Lower is better.")
            StatCard(title: "Min", 
                     value: vm.stats.minRtt == .infinity ? "—" : String(format: "%.2f", vm.stats.minRtt), 
                     unit: "ms",
                     icon: "arrow.down.to.line",
                     color: vm.stats.minRtt == .infinity ? .secondary : rttColor(vm.stats.minRtt))
                .help("Minimum Round Trip Time recorded during this session.")
            StatCard(title: "Avg", 
                     value: String(format: "%.2f", vm.stats.avgRtt), 
                     unit: "ms",
                     icon: "equal",
                     color: rttColor(vm.stats.avgRtt))
                .help("Average Round Trip Time. This is the typical latency of your connection.")
            StatCard(title: "Max", 
                     value: String(format: "%.2f", vm.stats.maxRtt), 
                     unit: "ms",
                     icon: "arrow.up.to.line",
                     color: rttColor(vm.stats.maxRtt))
                .help("Maximum Round Trip Time recorded. High values can indicate temporary congestion.")
            StatCard(title: "Jitter", 
                     value: vm.stats.jitter == 0 ? "—" : String(format: "%.2f", vm.stats.jitter), 
                     unit: "ms",
                     icon: "waveform.path.ecg",
                     color: vm.stats.jitter == 0 ? .secondary
                         : vm.stats.jitter < 5 ? .green
                         : vm.stats.jitter < 20 ? .orange : .red)
                .help("Standard deviation of RTT. Measures latency stability. < 5ms is excellent, > 20ms may affect real-time apps like gaming or VOIP.")
        }
    }

    @AppStorage("lossAlertThreshold") private var lossAlert: Double = 10.0

    private var rttChart: some View {
        let recent = Array(vm.results.suffix(60))
        return Chart {
            ForEach(recent) { r in
                if r.status == .success {
                    LineMark(
                        x: .value("Seq", r.sequence),
                        y: .value("RTT", r.rtt)
                    )
                    .foregroundStyle(.blue.opacity(0.8))
                    .interpolationMethod(.monotone)
                    
                    AreaMark(
                        x: .value("Seq", r.sequence),
                        y: .value("RTT", r.rtt)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.blue.opacity(0.2), .blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Seq", r.sequence),
                        y: .value("RTT", r.rtt)
                    )
                    .symbolSize(20)
                    .foregroundStyle(rttColor(r.rtt))
                } else {
                    // Show timeouts as red bars at the bottom
                    BarMark(
                        x: .value("Seq", r.sequence),
                        y: .value("RTT", 10) // Fixed height for visualization
                    )
                    .foregroundStyle(.red.opacity(0.6))
                }
            }
            RuleMark(y: .value("Warn", rttWarn))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.orange.opacity(0.55))
            RuleMark(y: .value("Crit", rttCrit))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.red.opacity(0.55))
        }
        .chartYAxisLabel("RTT (ms)")
        .chartXAxisLabel("Packet No.")
        .frame(height: 130)
        .padding(.horizontal, 2)
    }

    private var distributionBar: some View {
        HStack(spacing: 2) {
            distributionSegment(count: vm.stats.bucketLow, color: .green, label: "<20ms")
            distributionSegment(count: vm.stats.bucketMedium, color: .orange, label: "20-50ms")
            distributionSegment(count: vm.stats.bucketHigh, color: .red.opacity(0.8), label: "50-100ms")
            distributionSegment(count: vm.stats.bucketCritical, color: .purple, label: ">100ms")
        }
        .frame(height: 12)
        .cornerRadius(6)
        .padding(.horizontal, 2)
    }

    private func distributionSegment(count: Int, color: Color, label: String) -> some View {
        let total = max(1, vm.stats.received)
        let width = CGFloat(count) / CGFloat(total)
        return Group {
            if count > 0 {
                Rectangle()
                    .fill(color)
                    .frame(maxWidth: width * 1000) // proportional width
                    .help("\(label): \(count) (\(Int(width * 100))%)")
            }
        }
    }

    private var rawOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .id(i)
                    }
                }
                .padding(8)
            }
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .onChange(of: vm.rawLines.count) {
                if let last = vm.rawLines.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private var resultsTable: some View {
        Table(vm.results) {
            TableColumn("Time") { r in
                Text(r.timestamp, format: .dateTime.hour().minute().second())
                    .font(.system(.body, design: .monospaced))
            }
            .width(80)
            TableColumn("#") { r in
                Text("\(r.sequence)")
                    .font(.system(.body, design: .monospaced))
            }
            .width(50)
            TableColumn("Host") { r in
                Text(r.host)
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("Bytes") { r in
                Text("\(r.bytes)")
                    .font(.system(.body, design: .monospaced))
            }
            .width(60)
            TableColumn("TTL") { r in
                Text("\(r.ttl)")
                    .font(.system(.body, design: .monospaced))
            }
            .width(50)
            TableColumn("RTT") { r in
                Text(String(format: "%.3f ms", r.rtt))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(rttColor(r.rtt))
            }
            .width(100)
        }
        .scrollPosition(id: $tableScrollID)
        .onChange(of: vm.results.count) {
            tableScrollID = vm.results.last?.id
        }
    }

    private var rttLegend: some View {
        HStack(spacing: 12) {
            Text("RTT:").font(.caption2).foregroundColor(.secondary)
            legendItem(.green,  "< \(Int(rttWarn)) ms")
            legendItem(.orange, "\(Int(rttWarn))–\(Int(rttCrit)) ms")
            legendItem(.red,    "> \(Int(rttCrit)) ms")
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
