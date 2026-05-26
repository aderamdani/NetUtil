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
    @State private var countText = ""
    @State private var intervalText = ""
    @State private var infinite = false
    @State private var showRaw = false
    @State private var showHistory = false
    @State private var tableScrollID: PingResult.ID?

    private var resolvedCount: String { countText.isEmpty ? "\(defaultCount)" : countText }
    private var resolvedInterval: String { intervalText.isEmpty ? String(format: "%.1f", defaultInterval) : intervalText }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if !vm.results.isEmpty {
                statsBar
            }
            if vm.results.count > 1 {
                rttChart
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
                    .onSubmit {
                        guard !host.isEmpty, !vm.isRunning else { return }
                        history.record(host)
                        let count = infinite ? nil : Int(resolvedCount)
                        vm.start(host: host, count: count,
                                 interval: Double(resolvedInterval) ?? defaultInterval)
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
                }
            }

            Toggle("∞", isOn: $infinite)
                .toggleStyle(.checkbox)

            if !infinite {
                HStack(spacing: 4) {
                    Text("Count:")
                    TextField("", text: $countText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                }
            }

            HStack(spacing: 4) {
                Text("Interval:")
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("s")
            }

            Spacer()

            if !vm.results.isEmpty {
                Menu {
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
                    vm.start(host: host, count: count, interval: Double(resolvedInterval) ?? defaultInterval)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            statChip("Sent", "\(vm.stats.transmitted)", .primary)
            statChip("Recv", "\(vm.stats.received)", .primary)
            statChip("Loss", String(format: "%.1f%%", vm.stats.loss),
                     vm.stats.loss > lossAlert ? .red : vm.stats.loss > 0 ? .orange : .primary)
            .help("Packet loss percentage")
            statChip("Min", vm.stats.minRtt == .infinity ? "—" : String(format: "%.2f ms", vm.stats.minRtt),
                     vm.stats.minRtt == .infinity ? .secondary : rttColor(vm.stats.minRtt))
            statChip("Avg", String(format: "%.2f ms", vm.stats.avgRtt), rttColor(vm.stats.avgRtt))
            statChip("Max", String(format: "%.2f ms", vm.stats.maxRtt), rttColor(vm.stats.maxRtt))
            statChip("Jitter",
                     vm.stats.jitter == 0 ? "—" : String(format: "%.2f ms", vm.stats.jitter),
                     vm.stats.jitter == 0 ? .secondary
                         : vm.stats.jitter < 5 ? .green
                         : vm.stats.jitter < 20 ? .orange : .red)
            .help("Jitter: standard deviation of RTT. < 5 ms = good, < 20 ms = acceptable, > 20 ms = poor")
        }
    }

    @AppStorage("lossAlertThreshold") private var lossAlert: Double = 10.0

    private var rttChart: some View {
        let recent = Array(vm.results.suffix(60))
        return Chart {
            ForEach(recent) { r in
                LineMark(
                    x: .value("Seq", r.sequence),
                    y: .value("RTT", r.rtt)
                )
                .foregroundStyle(.blue.opacity(0.8))
                AreaMark(
                    x: .value("Seq", r.sequence),
                    y: .value("RTT", r.rtt)
                )
                .foregroundStyle(.blue.opacity(0.1))
                PointMark(
                    x: .value("Seq", r.sequence),
                    y: .value("RTT", r.rtt)
                )
                .symbolSize(25)
                .foregroundStyle(rttColor(r.rtt))
            }
            RuleMark(y: .value("Warn", rttWarn))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.orange.opacity(0.55))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("warn").font(.system(size: 8)).foregroundColor(.orange).opacity(0.8)
                }
            RuleMark(y: .value("Crit", rttCrit))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.red.opacity(0.55))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("crit").font(.system(size: 8)).foregroundColor(.red).opacity(0.8)
                }
        }
        .chartYAxisLabel("RTT (ms)")
        .chartXAxisLabel("icmp_seq")
        .frame(height: 130)
        .padding(.horizontal, 2)
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

    private func statChip(_ label: String, _ value: String, _ valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(valueColor)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
