import SwiftUI
import Charts

struct TracerouteView: View {
    @StateObject private var vm = TracerouteViewModel()
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var maxHopsText = "30"
    @State private var intervalText = "5"
    @State private var showRaw = false
    @State private var selectedHopID: UUID?
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0
    @AppStorage("geoEnabled") private var geoEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            Picker("", selection: $showRaw) {
                Text("Hops").tag(false)
                Text("Raw").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            rttLegend

            if !vm.hops.isEmpty {
                pathSummary
            }

            if showRaw {
                rawOutput
            } else {
                VSplitView {
                    hopsTable
                        .frame(minHeight: 120)
                    detailPanel
                        .frame(minHeight: 160)
                }
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
                        vm.start(host: host,
                                 maxHops: Int(maxHopsText) ?? 30,
                                 interval: Double(intervalText) ?? 5)
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

            HStack(spacing: 4) {
                Text("Max hops:")
                TextField("", text: $maxHopsText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
            }

            HStack(spacing: 4) {
                Text("Interval:")
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
                Text("s").foregroundColor(.secondary)
            }

            Spacer()

            if vm.isRunning {
                ProgressView().scaleEffect(0.65)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Round \(vm.round)").font(.caption.monospacedDigit())
                    Text("\(vm.hops.count) hops").font(.caption)
                }
                .foregroundColor(.secondary)
            }

            if !vm.hops.isEmpty {
                Menu {
                    Button("Export CSV") {
                        Exporter.save(
                            string: Exporter.csvString(from: vm.hops),
                            defaultName: "traceroute-\(host).csv", ext: "csv"
                        )
                    }
                    Button("Export JSON") {
                        if let data = try? Exporter.jsonData(from: vm.hops) {
                            Exporter.save(data: data, defaultName: "traceroute-\(host).json", ext: "json")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
            }

            Button(vm.isRunning ? "Stop" : "Trace") {
                if vm.isRunning {
                    vm.stop()
                } else {
                    history.record(host)
                    vm.start(
                        host: host,
                        maxHops: Int(maxHopsText) ?? 30,
                        interval: Double(intervalText) ?? 5
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private var hopsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("#", width: 32)
                headerCell("Host / IP", flexible: true)
                headerCell("Location", width: 140)
                headerCell("Snt", width: 42)
                headerCell("Loss%", width: 62)
                headerCell("Last", width: 72)
                headerCell("Avg", width: 72)
                headerCell("Best", width: 72)
                headerCell("Wrst", width: 72)
                headerCell("Updated", width: 78)
                headerCell("Graph", width: 128)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.hops) { hop in
                        HopRow(hop: hop, isSelected: selectedHopID == hop.id,
                               rttWarn: rttWarn, rttCrit: rttCrit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedHopID = selectedHopID == hop.id ? nil : hop.id
                            }
                        Divider().opacity(0.5)
                    }
                }
            }
            .background(Color(.textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }

    private var pathSummary: some View {
        let finalResponding = vm.hops.last(where: { $0.avgRtt != nil })
        let reachHop = vm.hops.last(where: { $0.ip != nil || $0.host != nil })

        return HStack(spacing: 10) {
            summaryChip("Hops", "\(vm.hops.count)", .primary)
            if let hop = reachHop {
                summaryChip("Last Seen", hop.displayHost, .accentColor)
            }
            if let hop = finalResponding, let avg = hop.avgRtt {
                summaryChip("Last RTT", String(format: "%.1f ms", avg), rttColorLocal(avg))
            }
            let totalLoss = vm.hops.isEmpty ? 0.0 :
                vm.hops.map(\.loss).reduce(0, +) / Double(vm.hops.count)
            if totalLoss > 0 {
                summaryChip("Avg Loss", String(format: "%.0f%%", totalLoss),
                            totalLoss >= 20 ? .red : .orange)
            }
            Spacer()
        }
    }

    private func summaryChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(color)
                .lineLimit(1)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func rttColorLocal(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
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

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private var detailPanel: some View {
        Group {
            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                HopDetailChart(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
            } else {
                VStack {
                    Spacer()
                    Text("Select a hop to view RTT history")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
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
}

private struct HopRow: View {
    let hop: TracerouteHop
    let isSelected: Bool
    var rttWarn: Double = 20.0
    var rttCrit: Double = 100.0

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 32, alignment: .leading)

            Text(hop.displayHost)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(hop.host == nil && hop.ip == nil ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let geo = hop.geo {
                    Text(geo.shortLabel)
                        .help(geo.org)
                } else if hop.ip != nil {
                    Text("…").foregroundColor(.secondary)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
            .font(.system(.caption, design: .monospaced))
            .lineLimit(1)
            .frame(width: 140, alignment: .leading)

            Text(hop.sent == 0 ? "—" : "\(hop.sent)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 42, alignment: .trailing)

            lossCell
            rttCell(hop.lastRtt, width: 72)
            rttCell(hop.avgRtt, width: 72)
            rttCell(hop.minRtt, width: 72)
            rttCell(hop.maxRtt, width: 72)

            Text(hop.lastSeen, format: .dateTime.hour().minute().second())
                .font(.system(.caption, design: .monospaced))
                .frame(width: 78, alignment: .trailing)

            sparkline
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.12) }
        if hop.loss >= 50 { return Color.red.opacity(0.06) }
        if hop.loss > 0 { return Color.orange.opacity(0.04) }
        return Color.clear
    }

    private var lossCell: some View {
        let text = hop.samples.isEmpty ? "—" : String(format: "%.1f%%", hop.loss)
        return Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(lossColor(hop.loss))
            .frame(width: 62, alignment: .trailing)
    }

    @ViewBuilder
    private func rttCell(_ rtt: Double?, width: CGFloat) -> some View {
        if let rtt {
            Text(String(format: "%.1f", rtt))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(rttColor(rtt))
                .frame(width: width, alignment: .trailing)
        } else {
            Text("—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: width, alignment: .trailing)
        }
    }

    private var sparkline: some View {
        let history = Array(hop.samples.suffix(60))
        let maxVal = history.compactMap { $0.rtt }.max() ?? 1

        return Canvas { ctx, size in
            let slotW = size.width / CGFloat(max(history.count, 30))
            let barW = max(1, slotW - 1)

            for (i, sample) in history.enumerated() {
                let x = CGFloat(i) * slotW
                if let v = sample.rtt {
                    let ratio = CGFloat(v / maxVal)
                    let h = max(3, ratio * (size.height - 4)) + 4
                    let rect = CGRect(x: x, y: size.height - h, width: barW, height: h)
                    ctx.fill(Path(rect), with: .color(rttColor(v).opacity(0.75)))
                } else {
                    let rect = CGRect(x: x, y: size.height - 5, width: barW, height: 5)
                    ctx.fill(Path(rect), with: .color(Color.red.opacity(0.7)))
                }
            }
        }
        .frame(width: 120, height: 28)
        .background(Color(.separatorColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.leading, 8)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }

    private func lossColor(_ loss: Double) -> Color {
        if loss == 0 { return .secondary }
        if loss < 10 { return .orange }
        return .red
    }
}

private struct HopDetailChart: View {
    let hop: TracerouteHop
    var rttWarn: Double = 20.0
    var rttCrit: Double = 100.0

    private var validSamples: [RTTSample] { hop.samples.filter { $0.rtt != nil } }
    private var timeoutSamples: [RTTSample] { hop.samples.filter { $0.rtt == nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hop.displayHost).font(.caption.bold())
                    if let geo = hop.geo {
                        Text("\(geo.flag) \(geo.city.isEmpty ? geo.country : "\(geo.city), \(geo.country)") · \(geo.org)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Text("Hop \(hop.hop)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let avg = hop.avgRtt {
                    Text(String(format: "Avg %.1f ms", avg))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Text(String(format: "Loss %.1f%%", hop.loss))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(hop.loss > 0 ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if hop.samples.isEmpty {
                Spacer()
                Text("No data yet").foregroundColor(.secondary).font(.caption)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Chart {
                    if !validSamples.isEmpty {
                        ForEach(validSamples) { s in
                            AreaMark(
                                x: .value("Time", s.timestamp),
                                y: .value("RTT", s.rtt!)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [rttColor(s.rtt!).opacity(0.3), rttColor(s.rtt!).opacity(0.05)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Time", s.timestamp),
                                y: .value("RTT", s.rtt!)
                            )
                            .foregroundStyle(rttColor(s.rtt!).opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            PointMark(
                                x: .value("Time", s.timestamp),
                                y: .value("RTT", s.rtt!)
                            )
                            .symbolSize(20)
                            .foregroundStyle(rttColor(s.rtt!))
                        }
                    }
                    ForEach(timeoutSamples) { s in
                        PointMark(
                            x: .value("Time", s.timestamp),
                            y: .value("RTT", 0)
                        )
                        .symbol(.cross)
                        .symbolSize(40)
                        .foregroundStyle(Color.red.opacity(0.8))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { val in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute().second())
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisGridLine()
                        AxisValueLabel {
                            if let ms = val.as(Double.self) {
                                Text(String(format: "%.0f ms", ms))
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(hop.maxRtt.map { $0 * 1.2 } ?? 100))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
