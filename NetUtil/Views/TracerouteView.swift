import SwiftUI
import Charts
import MapKit

private enum TraceViewMode { case hops, timeline, map, raw }

struct TracerouteView: View {
    @ObservedObject var vm: TracerouteViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var maxHopsText = "30"
    @State private var intervalText = "5"
    @State private var viewMode: TraceViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showColumnHelp = false
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0
    @AppStorage("geoEnabled") private var geoEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            controlBar
                .onAppear {
                    if host.isEmpty, !vm.currentHost.isEmpty {
                        host = vm.currentHost
                    }
                }
            
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
            
            modeBar
            
            if !vm.hops.isEmpty {
                pathSummary
                routeHealthBanner
            }

            VStack(spacing: 0) {
                switch viewMode {
                case .hops:
                    VSplitView {
                        hopsTable.frame(minHeight: 120)
                        detailPanel.frame(minHeight: 180)
                    }
                case .timeline:
                    timelineView
                case .map:
                    routeMapView
                case .raw:
                    rawOutput
                }
            }
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
        }
        .padding(32)
        .sheet(isPresented: $showColumnHelp) {
            columnHelpSheet
        }
        .sheet(item: $infoHop) { hop in
            IPInfoCardView(hop: hop)
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("Target host to ping.")
                .onSubmit {
                    guard !host.isEmpty, !vm.isRunning else { return }
                    history.record(host)
                    vm.start(host: host,
                             maxHops: Int(maxHopsText) ?? 30,
                             interval: Double(intervalText) ?? 5)
                }
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in
                                Button(h) { host = h }
                            }
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                        .padding(.trailing, 4)
                    }
                }

            HStack(spacing: 4) {
                Text("Max Hops:").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                TextField("", text: $maxHopsText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
            }
            .help("Max router hops to probe.")

            HStack(spacing: 4) {
                Text("Interval:").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 45)
                Text("s").font(.caption).foregroundColor(.secondary)
            }
            .help("Seconds between trace rounds.")

            Spacer()

            if !vm.hops.isEmpty {
                Menu {
                    Button("Export CSV") {
                        Exporter.save(string: Exporter.csvString(from: vm.hops), defaultName: "traceroute-\(host).csv", ext: "csv")
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            Button(action: {
                if vm.isRunning { vm.stop() }
                else {
                    history.record(host)
                    vm.start(host: host, maxHops: Int(maxHopsText) ?? 30, interval: Double(intervalText) ?? 5)
                }
            }) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Start Trace")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
        }
    }

    // MARK: - Mode bar

    private var modeBar: some View {
        HStack {
            Picker("", selection: $viewMode) {
                Text("Hops Table").tag(TraceViewMode.hops)
                Text("Timeline View").tag(TraceViewMode.timeline)
                Text("Route Map").tag(TraceViewMode.map)
                Text("Raw Console").tag(TraceViewMode.raw)
            }
            .pickerStyle(.segmented)
            .frame(width: 450)
            
            Spacer()
            
            Button { showColumnHelp = true } label: {
                Label("Learning Guide", systemImage: "book.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)
        }
    }

    // MARK: - Path Summary

    private var pathSummary: some View {
        let bottleneckCount = vm.hops.filter(\.isBottleneck).count
        return HStack(spacing: 12) {
            StatCard(title: "HOPS", value: "\(vm.hops.count)", icon: "arrow.triangle.branch")
            if let last = vm.hops.last(where: { $0.ip != nil }) {
                StatCard(title: "LAST SEEN", value: last.displayHost, icon: "target", color: .accentColor)
            }
            StatCard(title: "BOTTLENECKS", value: "\(bottleneckCount)", icon: "bolt.fill", color: bottleneckCount > 0 ? .red : .secondary)
            Spacer()
        }
    }

    // MARK: - Route Health Banner

    private var routeHealthBanner: some View {
        let maxLoss = vm.hops.map(\.loss).max() ?? 0
        let (label, color, icon): (String, Color, String)
        if maxLoss >= 50 { (label, color, icon) = ("CRITICAL", .red, "xmark.circle.fill") }
        else if maxLoss >= 10 { (label, color, icon) = ("DEGRADED", .orange, "exclamationmark.triangle.fill") }
        else { (label, color, icon) = ("HEALTHY", .green, "checkmark.circle.fill") }

        return HStack(spacing: 12) {
            Image(systemName: icon).font(.headline).foregroundColor(color)
            Text("ROUTE STATUS: \(label)")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(color)
            Spacer()
            Text("Round \(vm.round)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Hops Table

    private var hopsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("#", width: 40)
                headerCell("Host / IP Address", flexible: true)
                headerCell("Location", width: 140)
                headerCell("Loss%", width: 60)
                headerCell("Avg RTT", width: 80)
                headerCell("Jitter", width: 80)
                headerCell("Graph", width: 120)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.hops) { hop in
                        HopRowView(hop: hop, isSelected: selectedHopID == hop.id,
                               rttWarn: rttWarn, rttCrit: rttCrit,
                               onInfo: { infoHop = hop })
                            .onTapGesture { selectedHopID = selectedHopID == hop.id ? nil : hop.id }
                        Divider().opacity(0.2)
                    }
                }
            }
        }
    }

    private var detailPanel: some View {
        Group {
            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                HopDetailChartView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click").font(.title).foregroundColor(.secondary)
                    Text("Select a hop row to view latency history")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    // MARK: - Route Map View
    private var routeMapView: some View {
        let geoHops: [(TracerouteHop, CLLocationCoordinate2D)] = vm.hops.compactMap { hop in
            guard let coord = hop.geo?.coordinate else { return nil }
            return (hop, coord)
        }
        return Group {
            if geoHops.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map.fill").font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
                    Text("Geolocation data unavailable or disabled.").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Map {
                    ForEach(geoHops, id: \.0.id) { hop, coord in
                        Annotation("Hop \(hop.hop)", coordinate: coord) {
                            Circle().fill(hopMapColor(hop)).frame(width: 12, height: 12)
                                .shadow(radius: 2)
                        }
                    }
                    if geoHops.count > 1 {
                        MapPolyline(coordinates: geoHops.map(\.1)).stroke(.blue.opacity(0.5), lineWidth: 3)
                    }
                }
            }
        }
    }

    private func hopMapColor(_ hop: TracerouteHop) -> Color {
        if hop.isBottleneck { return .red }
        guard let avg = hop.avgRtt else { return .gray }
        if avg < rttWarn { return .green }
        return .orange
    }

    // MARK: - Timeline View
    private var timelineView: some View {
        let globalMax = vm.hops.compactMap(\.maxRtt).max() ?? 100
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.hops) { hop in
                    TimelineHopRowView(hop: hop, globalMax: globalMax, rttWarn: rttWarn, rttCrit: rttCrit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedHopID = selectedHopID == hop.id ? nil : hop.id
                            }
                        }
                        .background(selectedHopID == hop.id ? Color.accentColor.opacity(0.08) : Color.clear)
                    Divider().opacity(0.2)
                }
            }
        }
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

    // MARK: - Column Help Sheet
    private var columnHelpSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Traceroute Learning Guide").font(.title2.bold())
                Spacer()
                Button("Done") { showColumnHelp = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Understanding Hops").font(.headline)
                    Text("Every time your data travels across the internet, it jumps through multiple routers called 'Hops'. NetUtil measures how long each jump takes.").font(.subheadline).foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        helpRow("Seq (#)", "The order of the router in the path.")
                        helpRow("Bottleneck", "A red bolt indicates a hop where delay increases significantly.")
                        helpRow("Loss %", "Packets that never came back. High loss at the last hop is a real issue.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func helpRow(_ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).font(.system(size: 11, weight: .black)).frame(width: 80, alignment: .trailing)
            Text(desc).font(.subheadline).foregroundColor(.secondary)
        }
    }
}

// MARK: - Sub-Views

private struct HopRowView: View {
    let hop: TracerouteHop
    let isSelected: Bool
    var rttWarn: Double
    var rttCrit: Double
    var onInfo: (() -> Void)

    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)").font(.system(size: 11, design: .monospaced)).frame(width: 40, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(hop.displayHost).font(.system(size: 11, weight: .bold)).lineLimit(1)
                if hop.isBottleneck {
                    Text("BOTTLENECK").font(.system(size: 8, weight: .black)).foregroundColor(.red).kerning(0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(hop.geo?.shortLabel ?? "—").font(.system(size: 11)).foregroundColor(.secondary).frame(width: 140, alignment: .leading)
            
            Text(String(format: "%.0f%%", hop.loss)).font(.system(size: 11, design: .monospaced)).foregroundColor(hop.loss > 0 ? .red : .secondary).frame(width: 60, alignment: .leading)
            
            Text(hop.avgRtt.map { String(format: "%.1f ms", $0) } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(hop.avgRtt.map { rttColor($0) } ?? .secondary).frame(width: 80, alignment: .leading)
            
            Text(hop.jitter.map { String(format: "%.1f ms", $0) } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            
            sparkline
            
            Button { onInfo() } label: {
                Image(systemName: "info.circle").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var sparkline: some View {
        Canvas { ctx, size in
            let history = Array(hop.samples.suffix(40))
            let maxVal = history.compactMap { $0.rtt }.max() ?? 100
            let slotW = size.width / 40
            for (i, s) in history.enumerated() {
                let x = CGFloat(i) * slotW
                if let rtt = s.rtt {
                    let h = CGFloat(rtt / maxVal) * size.height
                    ctx.fill(Path(CGRect(x: x, y: size.height - h, width: slotW - 1, height: h)), with: .color(rttColor(rtt).opacity(0.7)))
                } else {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: slotW - 1, height: size.height)), with: .color(.red.opacity(0.3)))
                }
            }
        }
        .frame(width: 120, height: 24)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct TimelineHopRowView: View {
    let hop: TracerouteHop
    let globalMax: Double
    let rttWarn: Double
    let rttCrit: Double

    var body: some View {
        HStack(spacing: 12) {
            Text("\(hop.hop)")
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 30, alignment: .leading)
            
            Text(hop.displayHost)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            Canvas { ctx, size in
                let samples = Array(hop.samples.suffix(60))
                let slotW = size.width / 60
                for (i, s) in samples.enumerated() {
                    let x = CGFloat(i) * slotW
                    if let rtt = s.rtt {
                        let h = CGFloat(min(rtt / globalMax, 1.0)) * size.height
                        ctx.fill(Path(CGRect(x: x, y: size.height - h, width: slotW - 0.5, height: h)), with: .color(rttColor(rtt).opacity(0.8)))
                    } else {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: slotW - 0.5, height: size.height)), with: .color(.red.opacity(0.4)))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(Color.secondary.opacity(0.05))
            
            Text(hop.avgRtt.map { String(format: "%.0f ms", $0) } ?? "*")
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct HopDetailChartView: View {
    let hop: TracerouteHop
    let rttWarn: Double
    let rttCrit: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RTT HISTORY: \(hop.displayHost)").font(.system(size: 11, weight: .black))
                Spacer()
                if let avg = hop.avgRtt {
                    Text("AVG: \(String(format: "%.1f ms", avg))").font(.system(size: 10, weight: .bold))
                }
            }
            .padding([.horizontal, .top], 16)
            
            Chart {
                ForEach(hop.samples) { s in
                    if let rtt = s.rtt {
                        AreaMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                            .foregroundStyle(LinearGradient(colors: [rttColor(rtt).opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                            .foregroundStyle(rttColor(rtt))
                    } else {
                        RuleMark(x: .value("Time", s.timestamp))
                            .foregroundStyle(Color.red.opacity(0.2))
                    }
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let ms = val.as(Double.self) { Text("\(Int(ms))ms").font(.system(size: 9)) }
                    }
                }
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct IPInfoCardView: View {
    let hop: TracerouteHop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hop \(hop.hop)").font(.headline)
                    Text(hop.displayHost).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if let ip = hop.ip { infoRow("IP Address", ip) }
                if let geo = hop.geo {
                    infoRow("Location", "\(geo.flag) \(geo.city), \(geo.country)")
                    infoRow("ISP / Org", geo.org)
                }
                infoRow("Avg Latency", hop.avgRtt.map { String(format: "%.2f ms", $0) } ?? "—")
                infoRow("Packet Loss", String(format: "%.1f%%", hop.loss))
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 350, height: 400)
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption.bold()).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundColor(.primary)
        }
    }
}
