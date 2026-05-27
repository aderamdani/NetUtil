import SwiftUI
import Charts
import MapKit

private enum TraceViewMode: String, CaseIterable {
    case graph    = "Live Graph"
    case hops     = "Hops Table"
    case timeline = "Timeline"
    case map      = "Route Map"
    case raw      = "Raw Console"
}

private enum HopSortKey {
    case hop, host, location, sent, loss, avg, min, max, stddev
}

struct TracerouteView: View {
    @ObservedObject var vm: TracerouteViewModel
    @StateObject private var history = HostHistory.shared

    @State private var host = ""
    @State private var viewMode: TraceViewMode = .graph
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showGuide = false
    @State private var sortKey: HopSortKey = .hop
    @State private var sortAscending = true

    @AppStorage("defaultMaxHops")       private var maxHops: Int = 30
    @AppStorage("defaultTraceInterval") private var traceInterval: Double = 5.0
    @AppStorage("rttWarnThreshold")     private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")     private var rttCrit: Double = 100.0
    @AppStorage("geoEnabled")           private var geoEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let err = vm.error { errorBanner(err) }
                    modeBar
                    if !vm.hops.isEmpty {
                        pathSummaryRow
                        routeHealthBanner
                        contentArea
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                    } else if vm.isRunning {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(32)
            }
        }
        .sheet(isPresented: $showGuide) { guideSheet }
        .sheet(item: $infoHop) { hop in IPInfoCardView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit) }
        .onAppear { if !vm.currentHost.isEmpty { host = vm.currentHost } }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP (e.g. 103.4.0.42)", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 280)
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
                            Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                        .padding(.trailing, 4)
                    }
                }

            HStack(spacing: 4) {
                Text("Max Hops:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Stepper("\(maxHops)", value: $maxHops, in: 1...255)
                    .frame(width: 110).controlSize(.small)
            }

            HStack(spacing: 4) {
                Text("Interval:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Stepper(String(format: "%.0fs", traceInterval), value: $traceInterval, in: 1...60, step: 1)
                    .frame(width: 100).controlSize(.small)
            }

            Spacer()

            if !vm.hops.isEmpty {
                Menu {
                    Button("Export CSV") {
                        Exporter.save(
                            string: Exporter.csvString(from: vm.hops),
                            defaultName: "traceroute-\(host)-\(stamp()).csv", ext: "csv"
                        )
                    }
                    Button("Export JSON") {
                        if let data = try? Exporter.jsonData(from: vm.hops) {
                            Exporter.save(data: data, defaultName: "traceroute-\(host)-\(stamp()).json", ext: "json")
                        }
                    }
                    Button("Save PDF Report") {
                        Exporter.saveTraceroutePDF(hops: vm.hops, host: host, round: vm.round)
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(vm.isRunning ? "Stop" : "Trace")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)

            Button { showGuide = true } label: {
                Image(systemName: "book.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Traceroute Learning Guide")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else {
            guard !host.isEmpty else { return }
            history.record(host)
            vm.start(host: host, maxHops: maxHops, interval: traceInterval)
        }
    }

    private func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack {
            Picker("", selection: $viewMode) {
                ForEach(TraceViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 580)
            Spacer()
            if vm.isRunning {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Round \(vm.round)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Path Summary

    private var pathSummaryRow: some View {
        let bottlenecks = vm.hops.filter(\.isBottleneck).count
        let pathLoss    = vm.pathLoss
        return HStack(spacing: 8) {
            StatCard(title: "HOPS",         value: "\(vm.hops.count)",                    icon: "arrow.triangle.branch")
            StatCard(title: "BOTTLENECKS",  value: "\(bottlenecks)",                      icon: "bolt.fill",
                     color: bottlenecks > 0 ? .red : .green)
            StatCard(title: "PATH LOSS",    value: String(format: "%.1f%%", pathLoss),    icon: "exclamationmark.triangle",
                     color: pathLoss > 5 ? .red : pathLoss > 0 ? .orange : .green)
            if let avg = vm.pathAvgRtt {
                StatCard(title: "PATH AVG RTT", value: String(format: "%.1f", avg), unit: "ms", icon: "timer",
                         color: avg < rttWarn ? .green : avg < rttCrit ? .orange : .red)
            }
            StatCard(title: "ROUNDS", value: "\(vm.round)", icon: "arrow.clockwise")
            Spacer()
        }
    }

    // MARK: - Route Health Banner

    private var routeHealthBanner: some View {
        let maxLoss = vm.hops.map(\.loss).max() ?? 0
        let (label, color, icon, desc): (String, Color, String, String)
        if maxLoss >= 50 {
            (label, color, icon, desc) = ("CRITICAL", .red,    "xmark.circle.fill",            "Severe packet loss detected on path")
        } else if maxLoss >= 10 {
            (label, color, icon, desc) = ("DEGRADED", .orange, "exclamationmark.triangle.fill", "Elevated loss or latency on some hops")
        } else {
            (label, color, icon, desc) = ("HEALTHY",  .green,  "checkmark.circle.fill",         "All hops responding normally")
        }
        return HStack(spacing: 12) {
            Image(systemName: icon).font(.headline).foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("ROUTE: \(label)").font(.system(size: 11, weight: .black)).foregroundColor(color)
                Text(desc).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            if let last = vm.hops.last(where: { $0.ip != nil }) {
                Text("→ \(last.displayHost)").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch viewMode {
        case .graph:    graphView
        case .hops:     hopsView
        case .timeline: timelineView
        case .map:      routeMapView
        case .raw:      rawOutput
        }
    }

    // MARK: - Live Graph (PingPlotter-style heatmap)

    private var graphView: some View {
        VStack(spacing: 0) {
            // Legend strip
            HStack(spacing: 16) {
                legendChip(.green,  "Good  <\(Int(rttWarn)) ms")
                legendChip(.orange, "Warn  \(Int(rttWarn))–\(Int(rttCrit)) ms")
                legendChip(.red,    "Critical  >\(Int(rttCrit)) ms")
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(red:0.85,green:0.1,blue:0.1))
                        .frame(width: 12, height: 10)
                    Text("Loss").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Text("← Older · Newer →")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))

            Divider()

            HeatmapView(
                hops: sortedHops,
                rttWarn: rttWarn, rttCrit: rttCrit,
                selectedID: $selectedHopID,
                onInfo: { infoHop = $0 }
            )

            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                Divider()
                HopDetailChartView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
                    .frame(height: 180)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func legendChip(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.8)).frame(width: 12, height: 10)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }

    // MARK: - Hops Table

    private var sortedHops: [TracerouteHop] {
        vm.hops.sorted {
            let r: Bool
            switch sortKey {
            case .hop:      r = $0.hop < $1.hop
            case .host:     r = $0.displayHost < $1.displayHost
            case .location: r = ($0.geo?.shortLabel ?? "") < ($1.geo?.shortLabel ?? "")
            case .sent:     r = $0.sent < $1.sent
            case .loss:     r = $0.loss < $1.loss
            case .avg:      r = ($0.avgRtt ?? 9999) < ($1.avgRtt ?? 9999)
            case .min:      r = ($0.minRtt ?? 9999) < ($1.minRtt ?? 9999)
            case .max:      r = ($0.maxRtt ?? 9999) < ($1.maxRtt ?? 9999)
            case .stddev:   r = ($0.jitter ?? 9999) < ($1.jitter ?? 9999)
            }
            return sortAscending ? r : !r
        }
    }

    private var hopsView: some View {
        VSplitView {
            hopsTable.frame(minHeight: 160)
            hopDetailPanel.frame(minHeight: 180)
        }
    }

    private var hopsTable: some View {
        VStack(spacing: 0) {
            // Sortable header
            HStack(spacing: 0) {
                sortHeader("#",       key: .hop,      width: 36)
                plainHeader("",                       width: 18)
                sortHeader("Host / IP", key: .host,   flexible: true)
                sortHeader("Location",key: .location, width: 130)
                sortHeader("Sent",    key: .sent,     width: 50)
                sortHeader("Loss%",   key: .loss,     width: 60)
                sortHeader("Min",     key: .min,      width: 72)
                sortHeader("Avg",     key: .avg,      width: 72)
                sortHeader("Max",     key: .max,      width: 72)
                sortHeader("StdDev",  key: .stddev,   width: 72)
                plainHeader("History",                width: 120)
                plainHeader("",                       width: 52)
            }
            .padding(.vertical, 8).padding(.horizontal, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedHops) { hop in
                        HopRowView(hop: hop, isSelected: selectedHopID == hop.id,
                                   rttWarn: rttWarn, rttCrit: rttCrit,
                                   onInfo: { infoHop = hop },
                                   onCopy: { copyHop(hop) })
                            .onTapGesture { selectedHopID = selectedHopID == hop.id ? nil : hop.id }
                        Divider().opacity(0.2)
                    }
                }
            }
        }
    }

    private var hopDetailPanel: some View {
        Group {
            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                HopDetailChartView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click").font(.title2).foregroundColor(.secondary.opacity(0.4))
                    Text("Select a hop row to view RTT history chart")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func sortHeader(_ title: String, key: HopSortKey, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Button {
            if sortKey == key { sortAscending.toggle() }
            else { sortKey = key; sortAscending = true }
        } label: {
            HStack(spacing: 2) {
                Text(title.uppercased()).font(.system(size: 10, weight: .black))
                    .foregroundColor(sortKey == key ? .accentColor : .secondary)
                if sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold)).foregroundColor(.accentColor)
                }
            }
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func plainHeader(_ title: String, width: CGFloat? = nil) -> some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .black)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func copyHop(_ hop: TracerouteHop) {
        var parts = ["Hop \(hop.hop): \(hop.displayHost)"]
        if let geo = hop.geo { parts.append(geo.shortLabel) }
        parts.append(String(format: "Loss: %.1f%%", hop.loss))
        if let avg = hop.avgRtt { parts.append(String(format: "Avg: %.1f ms", avg)) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: " | "), forType: .string)
    }

    // MARK: - Timeline

    private var timelineView: some View {
        let globalMax = vm.hops.compactMap(\.maxRtt).max() ?? 100
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("").frame(width: 36)
                Text("HOST / IP").font(.system(size: 10, weight: .black)).foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                Text("RTT HISTORY — LAST 60 ROUNDS").font(.system(size: 10, weight: .black)).foregroundColor(.secondary)
                Spacer()
                Text("AVG    LOSS").font(.system(size: 10, weight: .black)).foregroundColor(.secondary).frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.hops) { hop in
                        TimelineHopRow(
                            hop: hop, globalMax: globalMax,
                            rttWarn: rttWarn, rttCrit: rttCrit,
                            isSelected: selectedHopID == hop.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedHopID = selectedHopID == hop.id ? nil : hop.id
                            }
                        }
                        if selectedHopID == hop.id {
                            HopDetailChartView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
                                .frame(height: 170)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Divider().opacity(0.2)
                    }
                }
            }
        }
    }

    // MARK: - Route Map

    private var routeMapView: some View {
        let geoHops: [(TracerouteHop, CLLocationCoordinate2D)] = vm.hops.compactMap { hop in
            guard let coord = hop.geo?.coordinate else { return nil }
            return (hop, coord)
        }
        return Group {
            if geoHops.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "map.fill").font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
                    Text(geoEnabled
                         ? "No geolocation data yet. Traceroute may still be running."
                         : "Geolocation disabled — enable it in Settings → Privacy.")
                        .foregroundColor(.secondary).multilineTextAlignment(.center).frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                Map {
                    ForEach(geoHops, id: \.0.id) { hop, coord in
                        Annotation("", coordinate: coord) {
                            ZStack {
                                Circle().fill(mapHopColor(hop))
                                    .frame(width: 26, height: 26)
                                    .shadow(color: mapHopColor(hop).opacity(0.5), radius: 4)
                                Text("\(hop.hop)").font(.system(size: 9, weight: .black)).foregroundColor(.white)
                            }
                            .onTapGesture { infoHop = hop }
                        }
                    }
                    if geoHops.count > 1 {
                        MapPolyline(coordinates: geoHops.map(\.1)).stroke(.blue.opacity(0.5), lineWidth: 2)
                    }
                }
                .frame(minHeight: 400)
            }
        }
    }

    private func mapHopColor(_ hop: TracerouteHop) -> Color {
        if hop.isBottleneck { return .red }
        guard let avg = hop.avgRtt else { return .gray }
        if avg < rttWarn { return .green }
        if avg < rttCrit { return .orange }
        return .red
    }

    // MARK: - Raw Output

    private var rawOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).id(i)
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.rawLines.count) {
                if let last = vm.rawLines.indices.last { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    // MARK: - Empty / Loading / Error

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 32)).foregroundColor(.accentColor)
            }
            VStack(spacing: 6) {
                Text("Discover Your Network Path").font(.headline)
                Text("Enter a hostname or IP address and press Trace. Try 103.4.0.42 to see a live example with multiple hops.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300).padding(.top, 40)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Discovering hops to \(vm.currentHost)…")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
            Text(msg).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.red).padding(10)
        .background(Color.red.opacity(0.1)).cornerRadius(8)
    }

    // MARK: - Guide Sheet

    private var guideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Traceroute Guide").font(.title2.bold())
                    Text("Every metric, every view mode explained.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "How Traceroute Works", icon: "point.3.connected.trianglepath.dotted") {
                        Text("Sends packets with increasing TTL values. Each router decrements TTL by 1; when it reaches zero, it returns an ICMP Time Exceeded message — revealing its IP and round-trip latency.")
                    }
                    GuideSection(title: "Live Graph (PingPlotter-Style)", icon: "chart.bar.doc.horizontal") {
                        VStack(alignment: .leading, spacing: 8) {
                            GuidePoint(title: "Heatmap Grid", desc: "Each row = one hop. Each column = one round. Color intensity shows RTT. Solid dark red = packet loss.")
                            GuidePoint(title: "Click a row", desc: "Select a hop row to expand its full RTT area chart at the bottom of the graph.")
                            GuidePoint(title: "Bottleneck outline", desc: "Hops flagged as bottlenecks get a red border around their heatmap row.")
                        }
                    }
                    GuideSection(title: "Hops Table Columns", icon: "tablecells") {
                        VStack(alignment: .leading, spacing: 8) {
                            GuidePoint(title: "Loss%", desc: "Percentage of probes that timed out. High intermediate loss often means ICMP rate-limiting — not true congestion.")
                            GuidePoint(title: "Min / Avg / Max", desc: "Minimum, average, and maximum RTT observed. A large Max–Avg gap means bursty latency spikes.")
                            GuidePoint(title: "StdDev", desc: "Standard deviation of RTT — measures jitter. Low StdDev = consistent, stable path.")
                            GuidePoint(title: "Bottleneck", desc: "RTT delta >30 ms AND avg >50 ms vs previous hop. True latency increase — not just probe noise.")
                        }
                    }
                    GuideSection(title: "View Modes", icon: "rectangle.3.group") {
                        VStack(alignment: .leading, spacing: 8) {
                            GuidePoint(title: "Live Graph", desc: "PingPlotter-style heatmap. Best for spotting recurring loss or latency patterns over time.")
                            GuidePoint(title: "Hops Table", desc: "Sortable stats table. Click columns to sort. Click rows to expand the detail RTT chart.")
                            GuidePoint(title: "Timeline", desc: "Per-hop stacked bar chart. Shows last 60 rounds side-by-side. Click to expand detail chart inline.")
                            GuidePoint(title: "Route Map", desc: "MapKit map with numbered pins per geo-resolved hop. Tap a pin to open the full IP Info Card.")
                        }
                    }
                    GuideSection(title: "Reading Results", icon: "checkmark.shield.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            GuidePoint(title: "* * *", desc: "Router silently drops ICMP probes. The path continues past it — doesn't mean the route is broken.")
                            GuidePoint(title: "CRITICAL route", desc: ">50% loss at any hop. Investigate that specific hop — it may be an infrastructure problem.")
                            GuidePoint(title: "Rising trend", desc: "RTT increasing across successive rounds = growing congestion, not just a momentary spike.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 560, height: 640)
    }
}

// MARK: - Heatmap View

private struct HeatmapView: View {
    let hops: [TracerouteHop]
    let rttWarn: Double
    let rttCrit: Double
    @Binding var selectedID: UUID?
    let onInfo: (TracerouteHop) -> Void

    private let rowH: CGFloat = 36
    private let labelW: CGFloat = 224
    private let cellW: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let availW = max(60, geo.size.width - labelW)
            let nCols  = max(1, Int(availW / cellW))

            VStack(spacing: 0) {
                ForEach(hops) { hop in
                    HStack(spacing: 0) {
                        // Label side
                        HStack(spacing: 6) {
                            Text("\(hop.hop)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .trailing)

                            Circle().fill(hopStatusColor(hop)).frame(width: 7, height: 7)

                            Text(hop.displayHost)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let flag = hop.geo?.flag { Text(flag).font(.system(size: 11)) }

                            Button { onInfo(hop) } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 9)).foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                        }
                        .padding(.horizontal, 8)
                        .frame(width: labelW, height: rowH)
                        .background(selectedID == hop.id ? Color.accentColor.opacity(0.08) : Color.clear)
                        .onTapGesture { selectedID = selectedID == hop.id ? nil : hop.id }

                        // Heatmap cells
                        Canvas { ctx, size in
                            let samples = Array(hop.samples.suffix(nCols))
                            let w = size.width / CGFloat(nCols)
                            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                                     with: .color(Color.secondary.opacity(0.04)))

                            let offset = nCols - samples.count
                            for (i, s) in samples.enumerated() {
                                let x = CGFloat(offset + i) * w
                                let rect = CGRect(x: x, y: 1.5, width: max(1, w - 0.5), height: size.height - 3)
                                if let rtt = s.rtt {
                                    ctx.fill(Path(rect), with: .color(cellColor(rtt)))
                                } else {
                                    ctx.fill(Path(rect), with: .color(Color(red: 0.85, green: 0.1, blue: 0.1)))
                                }
                            }
                            if hop.isBottleneck {
                                ctx.stroke(
                                    Path(CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)),
                                    with: .color(Color.red.opacity(0.7)), lineWidth: 1.5
                                )
                            }
                        }
                        .frame(width: availW, height: rowH)
                    }
                    Divider().opacity(0.12)
                }
            }
        }
        .frame(height: CGFloat(hops.count) * rowH + 1)
    }

    private func cellColor(_ rtt: Double) -> Color {
        if rtt < rttWarn {
            let t = rtt / rttWarn
            return Color(red: 0.05, green: 0.70 + t * 0.05, blue: 0.25, opacity: 0.35 + t * 0.55)
        } else if rtt < rttCrit {
            let t = (rtt - rttWarn) / (rttCrit - rttWarn)
            return Color(red: 1.0, green: 0.55 - t * 0.25, blue: 0.0, opacity: 0.72)
        } else {
            return Color(red: 0.88, green: 0.12, blue: 0.12, opacity: 0.90)
        }
    }

    private func hopStatusColor(_ hop: TracerouteHop) -> Color {
        if hop.loss > 50 { return .red }
        if hop.isBottleneck { return .orange }
        guard let avg = hop.avgRtt else { return .gray.opacity(0.4) }
        if avg < rttWarn { return .green }
        if avg < rttCrit { return .orange }
        return .red
    }
}

// MARK: - Hop Row (table)

private struct HopRowView: View {
    let hop: TracerouteHop
    let isSelected: Bool
    let rttWarn: Double
    let rttCrit: Double
    let onInfo: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)")
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 36, alignment: .leading)

            Circle().fill(statusColor).frame(width: 7, height: 7).frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(hop.displayHost).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                if hop.isBottleneck {
                    Text("BOTTLENECK")
                        .font(.system(size: 8, weight: .black)).foregroundColor(.red).kerning(0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(hop.geo?.shortLabel ?? (hop.isPrivateIP ? "Private" : "—"))
                .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text("\(hop.sent)")
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            lossText
                .frame(width: 60, alignment: .leading)

            rttText(hop.minRtt,  width: 72)
            rttText(hop.avgRtt,  width: 72)
            rttText(hop.maxRtt,  width: 72)
            jitterText(hop.jitter, width: 72)

            sparkline.frame(width: 120, height: 24)

            HStack(spacing: 6) {
                Button { onCopy() } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 9))
                }
                .buttonStyle(.borderless).help("Copy hop stats")

                Button { onInfo() } label: {
                    Image(systemName: "info.circle").font(.system(size: 10))
                }
                .buttonStyle(.borderless).help("IP Info Card")
            }
            .frame(width: 52)
        }
        .padding(.vertical, 7).padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var statusColor: Color {
        if hop.loss > 50 { return .red }
        if hop.isBottleneck { return .orange }
        guard let avg = hop.avgRtt else { return .gray.opacity(0.35) }
        return avg < rttWarn ? .green : avg < rttCrit ? .orange : .red
    }

    private var lossText: some View {
        let c: Color = hop.loss == 0 ? .secondary : hop.loss < 10 ? .orange : .red
        return Text(String(format: "%.0f%%", hop.loss))
            .font(.system(size: 11, design: .monospaced)).foregroundColor(c)
    }

    private func rttText(_ val: Double?, width: CGFloat) -> some View {
        Text(val.map { String(format: "%.1f", $0) } ?? "—")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(val.map { $0 < rttWarn ? .green : $0 < rttCrit ? .orange : .red } ?? .secondary)
            .frame(width: width, alignment: .leading)
    }

    private func jitterText(_ val: Double?, width: CGFloat) -> some View {
        Text(val.map { String(format: "±%.1f", $0) } ?? "—")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(val.map { $0 > 10 ? .orange : .secondary } ?? .secondary)
            .frame(width: width, alignment: .leading)
    }

    private var sparkline: some View {
        Canvas { ctx, size in
            let history = Array(hop.samples.suffix(40))
            guard !history.isEmpty else { return }
            let maxV = history.compactMap(\.rtt).max() ?? 100
            let sw = size.width / 40
            for (i, s) in history.enumerated() {
                let x = CGFloat(i) * sw
                if let rtt = s.rtt {
                    let h = CGFloat(rtt / maxV) * (size.height - 2)
                    let color: Color = rtt < rttWarn ? .green : rtt < rttCrit ? .orange : .red
                    ctx.fill(Path(CGRect(x: x, y: size.height - h - 1, width: max(1, sw - 0.5), height: h)),
                             with: .color(color.opacity(0.75)))
                } else {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: max(1, sw - 0.5), height: size.height)),
                             with: .color(.red.opacity(0.35)))
                }
            }
        }
    }
}

// MARK: - Timeline Hop Row

private struct TimelineHopRow: View {
    let hop: TracerouteHop
    let globalMax: Double
    let rttWarn: Double
    let rttCrit: Double
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text("\(hop.hop)")
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 22, alignment: .trailing)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(hop.displayHost).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                if let geo = hop.geo {
                    Text(geo.shortLabel).font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .frame(width: 160, alignment: .leading)

            Canvas { ctx, size in
                let samples = Array(hop.samples.suffix(60))
                let sw = size.width / 60
                for (i, s) in samples.enumerated() {
                    let x = CGFloat(i) * sw
                    if let rtt = s.rtt {
                        let h = CGFloat(min(rtt / globalMax, 1.0)) * size.height
                        let c: Color = rtt < rttWarn ? .green : rtt < rttCrit ? .orange : .red
                        ctx.fill(Path(CGRect(x: x, y: size.height - h, width: max(1, sw - 0.5), height: h)),
                                 with: .color(c.opacity(0.8)))
                    } else {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: max(1, sw - 0.5), height: size.height)),
                                 with: .color(.red.opacity(0.45)))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Color.secondary.opacity(0.04)).cornerRadius(4)

            VStack(alignment: .trailing, spacing: 1) {
                Text(hop.avgRtt.map { String(format: "%.0fms", $0) } ?? "*")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(hop.avgRtt.map { $0 < rttWarn ? .green : $0 < rttCrit ? .orange : .red } ?? .secondary)
                Text(String(format: "%.0f%%L", hop.loss))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(hop.loss > 0 ? .red : .secondary)
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var statusColor: Color {
        if hop.loss > 50 { return .red }
        if hop.isBottleneck { return .orange }
        guard let avg = hop.avgRtt else { return .gray.opacity(0.3) }
        return avg < rttWarn ? .green : avg < rttCrit ? .orange : .red
    }
}

// MARK: - Hop Detail Chart

private struct HopDetailChartView: View {
    let hop: TracerouteHop
    let rttWarn: Double
    let rttCrit: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RTT HISTORY — HOP \(hop.hop)")
                        .font(.system(size: 10, weight: .black)).foregroundColor(.secondary)
                    Text(hop.displayHost).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 12) {
                    statBadge("MIN",    hop.minRtt)
                    statBadge("AVG",    hop.avgRtt)
                    statBadge("MAX",    hop.maxRtt)
                    statBadge("STDDEV", hop.jitter)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.windowBackgroundColor))

            Divider()

            Chart {
                ForEach(hop.samples) { s in
                    if let rtt = s.rtt {
                        AreaMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                            .foregroundStyle(LinearGradient(
                                colors: [rttColor(rtt).opacity(0.22), .clear],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                            .foregroundStyle(rttColor(rtt))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        PointMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                            .symbolSize(12).foregroundStyle(rttColor(rtt))
                    } else {
                        RuleMark(x: .value("Time", s.timestamp))
                            .foregroundStyle(Color.red.opacity(0.18))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                }
                RuleMark(y: .value("Warn", rttWarn))
                    .foregroundStyle(Color.orange.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    .annotation(position: .trailing) {
                        Text("W").font(.system(size: 8)).foregroundColor(.orange.opacity(0.7))
                    }
                RuleMark(y: .value("Crit", rttCrit))
                    .foregroundStyle(Color.red.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    .annotation(position: .trailing) {
                        Text("C").font(.system(size: 8)).foregroundColor(.red.opacity(0.7))
                    }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let ms = v.as(Double.self) { Text("\(Int(ms))ms").font(.system(size: 9)) }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis(.hidden)
            .padding([.horizontal, .bottom], 12)
        }
    }

    private func statBadge(_ label: String, _ val: Double?) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
            Text(val.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(val.map { rttColor($0) } ?? .secondary)
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        rtt < rttWarn ? .green : rtt < rttCrit ? .orange : .red
    }
}

// MARK: - IP Info Card

private struct IPInfoCardView: View {
    let hop: TracerouteHop
    let rttWarn: Double
    let rttCrit: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("HOP \(hop.hop)")
                            .font(.system(size: 11, weight: .black)).foregroundColor(.secondary)
                        if hop.ip != nil {
                            Text(hop.isPrivateIP ? "PRIVATE" : "PUBLIC")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(hop.isPrivateIP
                                            ? Color.secondary.opacity(0.12)
                                            : Color.blue.opacity(0.12))
                                .foregroundColor(hop.isPrivateIP ? .secondary : .blue)
                                .cornerRadius(4)
                        }
                        if let ip = hop.ip {
                            Text(ip).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                    Text(hop.displayHost).font(.title3.bold()).lineLimit(2)
                    if hop.isBottleneck {
                        Label("Bottleneck Detected", systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.red)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Geolocation
                    if let geo = hop.geo {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("LOCATION", icon: "mappin.circle.fill")
                            HStack(alignment: .top, spacing: 14) {
                                Text(geo.flag).font(.system(size: 42))
                                VStack(alignment: .leading, spacing: 3) {
                                    if !geo.city.isEmpty    { infoRow("City",        geo.city) }
                                    if !geo.country.isEmpty { infoRow("Country",     geo.country) }
                                    if !geo.org.isEmpty     { infoRow("ISP / Org",   geo.org) }
                                    if let hn = geo.hostname { infoRow("Hostname",   hn) }
                                    if let tz = geo.timezone { infoRow("Timezone",   tz) }
                                    if let p  = geo.postal   { infoRow("Postal",     p) }
                                    if let c  = geo.coordinate {
                                        infoRow("Coordinates",
                                                String(format: "%.4f, %.4f", c.latitude, c.longitude))
                                    }
                                }
                            }
                        }
                        Divider()
                    }

                    // Performance
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("PERFORMANCE", icon: "chart.xyaxis.line")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            perfCell("SENT",   "\(hop.sent)",                          .secondary)
                            perfCell("RECV",   "\(hop.recv)",                          .secondary)
                            perfCell("LOSS",   String(format: "%.1f%%", hop.loss),
                                     hop.loss > 0 ? .red : .green)
                            perfCell("MIN",    hop.minRtt.map { fmtMs($0) } ?? "—",    .primary)
                            perfCell("AVG",    hop.avgRtt.map { fmtMs($0) } ?? "—",    avgColor)
                            perfCell("MAX",    hop.maxRtt.map { fmtMs($0) } ?? "—",    .primary)
                            if let j = hop.jitter {
                                perfCell("STDDEV", String(format: "±%.1f ms", j),
                                         j > 10 ? .orange : .secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 480)
        .background(Color(.windowBackgroundColor))
    }

    private var avgColor: Color {
        guard let avg = hop.avgRtt else { return .secondary }
        return avg < rttWarn ? .green : avg < rttCrit ? .orange : .red
    }

    private func fmtMs(_ v: Double) -> String { String(format: "%.1f ms", v) }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .black)).foregroundColor(.secondary).kerning(0.5)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption.bold()).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.caption).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func perfCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .black)).foregroundColor(.secondary)
            Text(value).font(.system(size: 13, design: .monospaced).bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }
}
