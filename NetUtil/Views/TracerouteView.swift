import SwiftUI
import Charts

private enum TraceViewMode { case hops, timeline, raw }

struct TracerouteView: View {
    @ObservedObject var vm: TracerouteViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var maxHopsText = "30"
    @State private var intervalText = "5"
    @State private var viewMode: TraceViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var showColumnHelp = false
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0
    @AppStorage("geoEnabled") private var geoEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            modeBar
            rttLegend
            if !vm.hops.isEmpty {
                pathSummary
                routeHealthBanner
            }
            switch viewMode {
            case .hops:
                VSplitView {
                    hopsTable.frame(minHeight: 120)
                    detailPanel.frame(minHeight: 160)
                }
            case .timeline:
                timelineView
            case .raw:
                rawOutput
            }
        }
        .padding()
        .sheet(isPresented: $showColumnHelp) {
            columnHelpSheet
        }
    }

    // MARK: - Control bar

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
            .help("Maximum number of hops (routers) to probe before stopping")

            HStack(spacing: 4) {
                Text("Interval:")
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
                Text("s").foregroundColor(.secondary)
            }
            .help("Seconds between re-trace rounds")

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
                    vm.start(host: host,
                             maxHops: Int(maxHopsText) ?? 30,
                             interval: Double(intervalText) ?? 5)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    // MARK: - Mode bar

    private var modeBar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $viewMode) {
                Text("Hops").tag(TraceViewMode.hops)
                Text("Timeline").tag(TraceViewMode.timeline)
                Text("Raw").tag(TraceViewMode.raw)
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            Spacer()
            Button {
                showColumnHelp = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                    Text("Column Guide").font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Open column descriptions and traceroute reading guide")
        }
    }

    // MARK: - RTT Legend

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

    // MARK: - Path Summary

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

    // MARK: - Route Health Banner

    private var routeHealthBanner: some View {
        let maxLoss = vm.hops.map(\.loss).max() ?? 0
        let criticalHops = vm.hops.filter { $0.consecutiveLoss >= 3 }
        let worstRttHop = vm.hops.max(by: { ($0.avgRtt ?? 0) < ($1.avgRtt ?? 0) })
        let worstRtt = worstRttHop.flatMap(\.avgRtt) ?? 0

        let (label, color, icon): (String, Color, String)
        if maxLoss >= 50 || !criticalHops.isEmpty {
            (label, color, icon) = ("Critical", .red, "xmark.circle.fill")
        } else if maxLoss >= 10 || worstRtt > 200 {
            (label, color, icon) = ("Degraded", .orange, "exclamationmark.triangle.fill")
        } else {
            (label, color, icon) = ("Healthy", .green, "checkmark.circle.fill")
        }

        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text("Route \(label)")
                .font(.callout.bold())
                .foregroundColor(color)

            if !criticalHops.isEmpty {
                Text("·").foregroundColor(.secondary)
                Text("Consecutive loss at hop \(criticalHops.map { "\($0.hop)" }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let worst = worstRttHop, let avg = worst.avgRtt, avg > 50 {
                Text("·").foregroundColor(.secondary)
                Text("Slowest: Hop \(worst.hop) \(String(format: "%.0f ms avg", avg))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Round \(vm.round) · \(vm.hops.count) hops")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Hops Table

    private var hopsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("#", width: 32)
                    .help("Hop number — sequential position in the route")
                headerCell("Host / IP", flexible: true)
                    .help("Hostname and IP of the router at this hop. * = no response")
                headerCell("Location", width: 140)
                    .help("Geographic location and ISP from ipinfo.io (public IPs only)")
                headerCell("Snt", width: 42)
                    .help("Total packets sent to this hop")
                headerCell("Loss%", width: 62)
                    .help("Packet loss %. Intermediate loss may be ICMP rate-limiting, not real path degradation")
                headerCell("Last", width: 72)
                    .help("RTT of the most recent packet (ms)")
                headerCell("Avg", width: 72)
                    .help("Average RTT across all packets (ms)")
                headerCell("Best", width: 72)
                    .help("Lowest observed RTT (ms)")
                headerCell("Wrst", width: 72)
                    .help("Highest observed RTT (ms)")
                headerCell("Jitter", width: 68)
                    .help("RTT standard deviation — low = stable, high = inconsistent latency")
                headerCell("Updated", width: 78)
                    .help("Time of last received response from this hop")
                headerCell("Graph", width: 128)
                    .help("RTT sparkline — bar height = RTT, red bars = timeouts")
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

    private var detailPanel: some View {
        Group {
            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                HopDetailChart(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "cursorarrow.click")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Select a hop to view RTT history")
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .padding(.top, 4)
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

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    // MARK: - Timeline View (PingPlotter-style)

    private var timelineView: some View {
        let globalMax = vm.hops.compactMap(\.maxRtt).max() ?? 100
        let sampleCount = vm.hops.first.map { "\($0.samples.count)" } ?? "0"

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Hop")
                    .font(.caption.bold()).foregroundColor(.secondary)
                    .frame(width: 32, alignment: .leading)
                Text("Host / IP")
                    .font(.caption.bold()).foregroundColor(.secondary)
                    .frame(width: 155, alignment: .leading)
                Text("RTT history (\(sampleCount) rounds) — bars = RTT, red = timeout")
                    .font(.caption.bold()).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Avg")
                    .font(.caption.bold()).foregroundColor(.secondary)
                    .frame(width: 52, alignment: .trailing)
                Text("Loss")
                    .font(.caption.bold()).foregroundColor(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.hops) { hop in
                        TimelineHopRow(hop: hop, globalMax: globalMax, rttWarn: rttWarn, rttCrit: rttCrit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedHopID = selectedHopID == hop.id ? nil : hop.id
                                }
                            }
                            .background(selectedHopID == hop.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        Divider().opacity(0.5)
                    }
                }
            }
            .background(Color(.textBackgroundColor))

            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                Divider()
                HopDetailChart(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
                    .frame(height: 200)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor), lineWidth: 0.5))
        .animation(.spring(duration: 0.2), value: selectedHopID)
    }

    // MARK: - Raw Output

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

    // MARK: - Column Help Sheet

    private var columnHelpSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                Text("Traceroute Column Guide")
                    .font(.headline)
                Spacer()
                Button("Done") { showColumnHelp = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        helpEntry("#", "Hop number. Each router along the path gets a sequential number starting at 1.")
                        helpEntry("Host / IP", "Reverse DNS hostname and IP address of the router. Shows '*' when a router doesn't respond to ICMP probes.")
                        helpEntry("Location", "Geographic city/country and ISP/AS name from ipinfo.io. Private IP ranges (10.x, 192.168.x, 172.16-31.x) are not looked up. Requires geo enabled in Settings → Privacy.")
                        helpEntry("Snt", "Total packets sent to this hop across all rounds.")
                        helpEntry("Loss %", "Percentage of packets with no response.\n⚠️ Intermediate routers often rate-limit or deprioritize ICMP. Loss at a middle hop does NOT necessarily mean real packet loss — if the destination responds fine, traffic is flowing.")
                        helpEntry("Last", "RTT of the most recent packet in milliseconds.")
                        helpEntry("Avg", "Average RTT across all received responses.")
                        helpEntry("Best", "Lowest (minimum) RTT seen for this hop.")
                        helpEntry("Wrst", "Highest (maximum) RTT — the worst latency spike.")
                        helpEntry("Jitter", "Standard deviation of RTT. < 5 ms = stable · 5–20 ms = acceptable · > 20 ms = poor (inconsistent latency, often caused by queuing or congestion)")
                        helpEntry("Graph", "RTT sparkline for the last 60 rounds. Bar height = RTT value relative to the max. Red bars = timeouts. Color matches the RTT threshold: green / orange / red.")
                    }

                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Read Traceroute Results")
                            .font(.callout.bold())
                        Group {
                            bulletPoint("Loss or high RTT only at the *final destination* hop is a real problem. Loss at intermediate hops is usually ICMP rate limiting.")
                            bulletPoint("If RTT jumps significantly at a hop AND stays high for ALL subsequent hops, that hop is the bottleneck.")
                            bulletPoint("If RTT is high at one hop but drops back to normal at the next, the router is just slow at responding to ICMP — the actual path is fine.")
                            bulletPoint("Consecutive packet loss (3+) at any hop is a stronger signal of real congestion than intermittent loss.")
                        }
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(width: 520, height: 580)
    }

    private func helpEntry(_ term: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(term)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(.accentColor)
                .frame(width: 68, alignment: .trailing)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption).foregroundColor(.secondary)
            Text(text).font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func rttColorLocal(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

// MARK: - HopRow

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
                    Text(geo.shortLabel).help(geo.org)
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
            jitterCell
            Text(hop.lastSeen, format: .dateTime.hour().minute().second())
                .font(.system(.caption, design: .monospaced))
                .frame(width: 78, alignment: .trailing)
            sparkline

            copyButton
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
        HStack(spacing: 3) {
            if hop.consecutiveLoss >= 3 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .help("\(hop.consecutiveLoss) consecutive timeouts")
            }
            let text = hop.samples.isEmpty ? "—" : String(format: "%.1f%%", hop.loss)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(lossColor(hop.loss))
        }
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

    private var jitterCell: some View {
        Group {
            if let j = hop.jitter {
                Text(String(format: "%.1f", j))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(j < 5 ? .green : j < 20 ? .orange : .red)
            } else {
                Text("—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 68, alignment: .trailing)
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

    private var copyButton: some View {
        Button {
            var parts: [String] = ["Hop \(hop.hop): \(hop.displayHost)"]
            if let geo = hop.geo {
                parts.append("Location: \(geo.city), \(geo.country) — \(geo.org)")
            }
            if let avg = hop.avgRtt {
                parts.append(String(format: "Avg: %.1f ms · Loss: %.1f%%", avg, hop.loss))
            }
            if let j = hop.jitter {
                parts.append(String(format: "Jitter: %.1f ms", j))
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(parts.joined(separator: "\n"), forType: .string)
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .frame(width: 22)
        .help("Copy hop info to clipboard")
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

// MARK: - TimelineHopRow

private struct TimelineHopRow: View {
    let hop: TracerouteHop
    let globalMax: Double
    var rttWarn: Double = 20.0
    var rttCrit: Double = 100.0

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)")
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(hop.host ?? hop.ip ?? "*")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                if let ip = hop.ip, hop.host != nil, hop.host != hop.ip {
                    Text(ip)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 155, alignment: .leading)

            Canvas { ctx, size in
                let samples = Array(hop.samples.suffix(60))
                guard !samples.isEmpty else { return }
                let n = max(samples.count, 30)
                let slotW = size.width / CGFloat(n)
                let barW = max(1, slotW - 0.5)

                for (i, s) in samples.enumerated() {
                    let x = CGFloat(i) * slotW
                    if let rtt = s.rtt {
                        let ratio = CGFloat(min(rtt / max(globalMax, 1), 1))
                        let h = max(4, ratio * (size.height - 2))
                        let rect = CGRect(x: x, y: size.height - h, width: barW, height: h)
                        ctx.fill(Path(rect), with: .color(rttColor(rtt).opacity(0.8)))
                    } else {
                        let rect = CGRect(x: x, y: 0, width: barW, height: size.height)
                        ctx.fill(Path(rect), with: .color(Color.red.opacity(0.4)))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Color(.separatorColor).opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(.horizontal, 6)

            Group {
                if let avg = hop.avgRtt {
                    Text(String(format: "%.0f ms", avg))
                        .foregroundColor(rttColor(avg))
                } else {
                    Text("*").foregroundColor(.secondary)
                }
            }
            .font(.system(.caption2, design: .monospaced))
            .frame(width: 52, alignment: .trailing)

            Group {
                let text = hop.samples.isEmpty ? "—" : String(format: "%.0f%%", hop.loss)
                Text(text)
                    .foregroundColor(hop.loss == 0 ? .secondary : hop.loss < 10 ? .orange : .red)
            }
            .font(.system(.caption2, design: .monospaced))
            .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

// MARK: - HopDetailChart

private struct HopDetailChart: View {
    let hop: TracerouteHop
    var rttWarn: Double = 20.0
    var rttCrit: Double = 100.0

    private var validSamples: [RTTSample] { hop.samples.filter { $0.rtt != nil } }
    private var timeoutSamples: [RTTSample] { hop.samples.filter { $0.rtt == nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hop.displayHost).font(.caption.bold())
                    if let geo = hop.geo {
                        Text("\(geo.flag) \(geo.city.isEmpty ? geo.country : "\(geo.city), \(geo.country)") · \(geo.org)")
                            .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                }

                Text("Hop \(hop.hop)").font(.caption).foregroundColor(.secondary)
                Spacer()

                if let avg = hop.avgRtt {
                    statPill(String(format: "Avg %.1f ms", avg), .secondary)
                }
                if let j = hop.jitter {
                    statPill(String(format: "Jitter %.1f ms", j),
                             j < 5 ? .green : j < 20 ? .orange : .red)
                }
                statPill(String(format: "Loss %.1f%%", hop.loss),
                         hop.loss > 0 ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if hop.samples.isEmpty {
                Spacer()
                Text("No data yet").foregroundColor(.secondary).font(.caption).frame(maxWidth: .infinity)
                Spacer()
            } else {
                Chart {
                    if !validSamples.isEmpty {
                        ForEach(validSamples) { s in
                            AreaMark(x: .value("Time", s.timestamp), y: .value("RTT", s.rtt!))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [rttColor(s.rtt!).opacity(0.3), rttColor(s.rtt!).opacity(0.03)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                            LineMark(x: .value("Time", s.timestamp), y: .value("RTT", s.rtt!))
                                .foregroundStyle(rttColor(s.rtt!).opacity(0.9))
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            PointMark(x: .value("Time", s.timestamp), y: .value("RTT", s.rtt!))
                                .symbolSize(20)
                                .foregroundStyle(rttColor(s.rtt!))
                        }
                    }
                    ForEach(timeoutSamples) { s in
                        PointMark(x: .value("Time", s.timestamp), y: .value("RTT", 0))
                            .symbol(.cross).symbolSize(40)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                    RuleMark(y: .value("Warn", rttWarn))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.orange.opacity(0.5))
                    RuleMark(y: .value("Crit", rttCrit))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.red.opacity(0.5))
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor), lineWidth: 0.5))
    }

    private func statPill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
