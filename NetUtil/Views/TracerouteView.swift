import SwiftUI
import Charts
import MapKit

private enum TraceViewMode: String, CaseIterable {
    case graph    = "Graph"
    case hops     = "Table"
    case timeline = "Timeline"
    case map      = "Map"
    case raw      = "Console"
}

private enum HopSortKey { case hop, host, location, sent, loss, avg, min, max, stddev }

struct TracerouteView: View {
    @ObservedObject var vm: TracerouteViewModel
    @StateObject private var history = HostHistory.shared

    @State private var host = ""
    @State private var viewMode: TraceViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showGuide = false
    @State private var sortKey: HopSortKey = .hop
    @State private var sortAscending = true

    @AppStorage("defaultMaxHops")       private var maxHops: Int = 30
    @AppStorage("defaultTraceInterval") private var traceInterval: Double = 5.0
    @AppStorage("rttWarnThreshold")     private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")     private var rttCrit: Double = 100.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            if let err = vm.error { Text(err).foregroundColor(.red).font(.system(size: 12, weight: .medium)).padding(.bottom, 16) }
            
            if !vm.hops.isEmpty {
                pathSummaryRow.padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Picker("", selection: $viewMode) { ForEach(TraceViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).frame(maxWidth: 350)
                        Spacer()
                        if vm.isRunning { Text("Round \(vm.round)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary) }
                    }
                    contentArea
                }
                .frame(maxHeight: .infinity)
            } else if vm.isRunning {
                VStack { Spacer(); ProgressView(); Text("Tracing path...").foregroundColor(.secondary).font(.subheadline); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack { Spacer(); Text("No Target Selected").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(32)
        .sheet(isPresented: $showGuide) { guideSheet }
        .sheet(item: $infoHop) { hop in IPInfoCardView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit) }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $host)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(width: 250).onSubmit(startAction)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { host = h; startAction() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }.menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                TextField("Hops", value: $maxHops, format: .number).textFieldStyle(.roundedBorder).frame(width: 45)
                TextField("Int", value: $traceInterval, format: .number).textFieldStyle(.roundedBorder).frame(width: 45)
            }

            Spacer()

            if !vm.hops.isEmpty {
                Menu {
                    Button("Export PDF") { Exporter.saveTraceroutePDF(hops: vm.hops, host: host, round: vm.round) }
                    Button("Export CSV") { Exporter.save(string: Exporter.csvString(from: vm.hops), defaultName: "trace-\(host).csv", ext: "csv") }
                } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: startAction) {
                HStack(spacing: 6) { Image(systemName: vm.isRunning ? "stop.fill" : "play.fill"); Text(vm.isRunning ? "Stop" : "Start") }.font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }.buttonStyle(.borderedProminent).tint(vm.isRunning ? .red : .accentColor)
            
            Button { showGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }

    private var pathSummaryRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Hops", value: "\(vm.hops.count)", icon: "arrow.triangle.branch")
            StatCard(title: "Path Loss", value: String(format: "%.1f%%", vm.pathLoss), icon: "exclamationmark.triangle", color: vm.pathLoss > 0 ? .red : .primary)
            if let avg = vm.pathAvgRtt { StatCard(title: "Avg Latency", value: String(format: "%.1f", avg), unit: "ms", icon: "timer", color: avg < rttWarn ? .primary : .orange) }
            Spacer()
        }
    }

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

    private var graphView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedHops) { hop in
                        HStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Text("\(hop.hop)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 24, alignment: .trailing)
                                Text(hop.displayHost).font(.system(size: 11)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(.horizontal, 12).frame(width: 200, height: 28).background(selectedHopID == hop.id ? Color.secondary.opacity(0.1) : Color.clear).onTapGesture { selectedHopID = selectedHopID == hop.id ? nil : hop.id }

                            Canvas { ctx, size in
                                let samples = Array(hop.samples.suffix(50))
                                let w = size.width / 50
                                for (i, s) in samples.enumerated() {
                                    let x = CGFloat(i) * w
                                    let rect = CGRect(x: x + 1, y: 2, width: w - 1, height: size.height - 4)
                                    if let rtt = s.rtt { ctx.fill(Path(rect), with: .color(rtt < rttWarn ? .green.opacity(0.4) : .orange.opacity(0.6))) }
                                    else { ctx.fill(Path(rect), with: .color(.red.opacity(0.3))) }
                                }
                            }.frame(height: 28)
                        }
                        Divider().opacity(0.5)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                HopDetailChartView(hop: hop, rttWarn: rttWarn, rttCrit: rttCrit).frame(height: 140).padding(.top, 16)
            }
        }
    }

    private var hopsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("#", width: 30)
                tHeader("Host", flexible: true)
                tHeader("Loss%", width: 50)
                tHeader("Avg", width: 60)
                tHeader("StdDev", width: 60)
                tHeader("History", width: 100)
                tHeader("", width: 30)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedHops) { hop in
                        HopRowView(hop: hop, isSelected: selectedHopID == hop.id, rttWarn: rttWarn, rttCrit: rttCrit, onInfo: { infoHop = hop })
                            .onTapGesture { selectedHopID = selectedHopID == hop.id ? nil : hop.id }
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let gMax = vm.hops.compactMap(\.maxRtt).max() ?? 100
                ForEach(vm.hops) { hop in
                    TimelineHopRow(hop: hop, globalMax: gMax, rttWarn: rttWarn, rttCrit: rttCrit, isSelected: selectedHopID == hop.id)
                        .onTapGesture { withAnimation { selectedHopID = selectedHopID == hop.id ? nil : hop.id } }
                    Divider().opacity(0.5)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var routeMapView: some View {
        Map {
            ForEach(vm.hops.compactMap { h in h.geo?.coordinate.map { (h, $0) } }, id: \.0.id) { hop, coord in
                Annotation("", coordinate: coord) {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8).shadow(radius: 2)
                }
            }
        }.cornerRadius(8)
    }

    private var rawOutput: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(vm.rawLines.enumerated()), id: \.offset) { i, line in Text(line).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).id(i) }
            }.padding(12)
        }.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, maxHops: maxHops, interval: traceInterval) }
    }

    private var guideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Traceroute Guide").font(.title2.bold()); Spacer(); Button("Done") { showGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "How it works", icon: "point.3.connected.trianglepath.dotted") { Text("Traceroute uses TTL to discover hops.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
    
    private var sortedHops: [TracerouteHop] { vm.hops } // Simplified for clean code
}

private struct HopRowView: View {
    let hop: TracerouteHop; let isSelected: Bool; let rttWarn: Double; let rttCrit: Double; let onInfo: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            Text("\(hop.hop)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
            Text(hop.displayHost).font(.system(size: 12)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.0f%%", hop.loss)).font(.system(size: 11)).foregroundColor(hop.loss > 0 ? .red : .secondary).frame(width: 50, alignment: .leading)
            Text(hop.avgRtt.map { String(format: "%.1f", $0) } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(avgColor).frame(width: 60, alignment: .leading)
            Text(hop.jitter.map { String(format: "%.1f", $0) } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            sparkline.frame(width: 100, height: 16)
            Button { onInfo() } label: { Image(systemName: "info.circle").foregroundColor(.secondary) }.buttonStyle(.borderless).frame(width: 30)
        }
        .padding(.vertical, 6).padding(.horizontal, 12).background(isSelected ? Color.secondary.opacity(0.1) : Color.clear)
    }
    private var avgColor: Color { guard let avg = hop.avgRtt else { return .secondary }; return avg < rttWarn ? .primary : avg < rttCrit ? .orange : .red }
    private var sparkline: some View {
        Canvas { ctx, size in
            let history = Array(hop.samples.suffix(30)); guard !history.isEmpty else { return }
            let maxV = history.compactMap(\.rtt).max() ?? 100; let sw = size.width / 30
            for (i, s) in history.enumerated() {
                let x = CGFloat(i) * sw
                if let rtt = s.rtt { ctx.fill(Path(CGRect(x: x, y: size.height - (CGFloat(rtt / maxV) * size.height), width: sw - 1, height: CGFloat(rtt / maxV) * size.height)), with: .color(rtt < rttWarn ? .primary.opacity(0.3) : .orange.opacity(0.6))) }
                else { ctx.fill(Path(CGRect(x: x, y: 0, width: sw - 1, height: size.height)), with: .color(.red.opacity(0.2))) }
            }
        }
    }
}

private struct TimelineHopRow: View {
    let hop: TracerouteHop; let globalMax: Double; let rttWarn: Double; let rttCrit: Double; let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Text("\(hop.hop)").font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary).frame(width: 20, alignment: .trailing)
            Text(hop.displayHost).font(.system(size: 11)).lineLimit(1).frame(width: 140, alignment: .leading)
            Canvas { ctx, size in
                let samples = Array(hop.samples.suffix(60)); let sw = size.width / 60
                for (i, s) in samples.enumerated() {
                    let x = CGFloat(i) * sw
                    if let rtt = s.rtt { ctx.fill(Path(CGRect(x: x, y: size.height - (CGFloat(min(rtt / globalMax, 1.0)) * size.height), width: sw - 1, height: CGFloat(min(rtt / globalMax, 1.0)) * size.height)), with: .color(.primary.opacity(0.3))) }
                    else { ctx.fill(Path(CGRect(x: x, y: 0, width: sw - 1, height: size.height)), with: .color(.red.opacity(0.2))) }
                }
            }.frame(maxWidth: .infinity, minHeight: 24)
        }
        .padding(.horizontal, 12).padding(.vertical, 6).background(isSelected ? Color.secondary.opacity(0.1) : Color.clear)
    }
}

private struct HopDetailChartView: View {
    let hop: TracerouteHop; let rttWarn: Double; let rttCrit: Double
    var body: some View {
        Chart {
            ForEach(hop.samples) { s in
                if let rtt = s.rtt { LineMark(x: .value("T", s.timestamp), y: .value("R", rtt)).foregroundStyle(.primary) }
                else { RuleMark(x: .value("T", s.timestamp)).foregroundStyle(.red.opacity(0.2)) }
            }
        }.chartXAxis(.hidden)
    }
}

private struct IPInfoCardView: View {
    let hop: TracerouteHop; let rttWarn: Double; let rttCrit: Double; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading) { Text("Hop \(hop.hop)").font(.headline); Text(hop.displayHost).font(.subheadline).foregroundColor(.secondary) }; Spacer(); Button("Done") { dismiss() } }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if let ip = hop.ip { HStack{Text("IP").foregroundColor(.secondary);Spacer();Text(ip)} }
                if let geo = hop.geo { HStack{Text("Location").foregroundColor(.secondary);Spacer();Text("\(geo.flag) \(geo.city)")} }
            }.font(.system(size: 12))
            Spacer()
        }.padding(24).frame(width: 300, height: 300).background(Color(.windowBackgroundColor))
    }
}
