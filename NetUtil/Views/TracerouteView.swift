import SwiftUI
import Charts
import MapKit

private enum TraceViewMode: String, CaseIterable {
    case hops     = "Table"
    case timeline = "Timeline"
    case map      = "Map"
    case raw      = "Console"
}

struct TracerouteView: View {
    @ObservedObject var vm: TracerouteViewModel
    @StateObject private var history = HostHistory.shared

    @State private var host = ""
    @State private var viewMode: TraceViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showLearningGuide = false

    @AppStorage("defaultMaxHops")       private var maxHops: Int = 30
    @AppStorage("defaultTraceInterval") private var traceInterval: Double = 5.0
    @AppStorage("rttWarnThreshold")     private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")     private var rttCrit: Double = 100.0

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if !vm.hops.isEmpty {
                        pathSummarySection
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Picker("", selection: $viewMode) {
                                    ForEach(TraceViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 350)
                                
                                Spacer()
                                
                                if vm.isRunning {
                                    HStack(spacing: 8) {
                                        ProgressView().controlSize(.small)
                                        Text("Round \(vm.round)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            contentArea
                                .frame(minHeight: 450)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                        }
                        
                        if let id = selectedHopID, let hop = vm.hops.first(where: { $0.id == id }) {
                            hopQuickDetail(hop)
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
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Traceroute") }
        .sheet(item: $infoHop) { hop in TracerouteIPInfoSheet(hop: hop) }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Traceroute")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
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

                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Hops")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.secondary)
                            TextField("", value: $maxHops, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 45)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Interval")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.secondary)
                            TextField("", value: $traceInterval, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 45)
                        }
                    }

                    if !vm.hops.isEmpty {
                        Menu {
                            Button("Export PDF Report") { Exporter.saveTraceroutePDF(hops: vm.hops, host: host, round: vm.round) }
                            Button("Export CSV Data") { Exporter.save(string: Exporter.csvString(from: vm.hops), defaultName: "trace-\(host).csv", ext: "csv") }
                        } label: {
                            Label("Report", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: startAction) {
                        Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
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

    private var pathSummarySection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Path Depth", value: "\(vm.hops.count)", unit: "Hops", icon: "arrow.triangle.branch")
            StatCard(title: "Path Loss", value: String(format: "%.1f%%", vm.pathLoss), icon: "exclamationmark.triangle", color: vm.pathLoss > 0 ? .red : .primary)
            if let avg = vm.pathAvgRtt {
                StatCard(title: "Avg Latency", value: String(format: "%.1f", avg), unit: "ms", icon: "timer", color: avg < rttWarn ? .primary : .orange)
            }
            if let last = vm.hops.last?.displayHost {
                StatCard(title: "Target Host", value: last, icon: "target")
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewMode {
        case .hops:
            TracerouteHopsTable(hops: vm.hops, selectedHopID: selectedHopID, rttWarn: rttWarn, rttCrit: rttCrit, onSelect: { selectedHopID = $0 }, onInfo: { infoHop = $0 })
        case .timeline:
            TracerouteTimelineView(hops: vm.hops, rttWarn: rttWarn, rttCrit: rttCrit, selectedHopID: selectedHopID, onSelect: { selectedHopID = $0 })
        case .map:
            TracerouteMapView(hops: vm.hops)
        case .raw:
            rawOutputView
        }
    }

    private func hopQuickDetail(_ hop: TracerouteHop) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hop \(hop.hop) Detail")
                    .font(.system(.caption, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button { selectedHopID = nil } label: { Image(systemName: "xmark").font(.system(size: 10)) }.buttonStyle(.plain).foregroundColor(.secondary)
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Host / IP").font(.caption2.bold()).foregroundColor(.secondary)
                    Text(hop.displayHost).font(.system(.subheadline, design: .monospaced).weight(.bold))
                }
                
                if let geo = hop.geo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption2.bold()).foregroundColor(.secondary)
                        Text("\(geo.flag) \(geo.city), \(geo.country)")
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    StatCardMini(label: "Min", value: hop.minRtt.map { String(format: "%.1f", $0) } ?? "—")
                    StatCardMini(label: "Max", value: hop.maxRtt.map { String(format: "%.1f", $0) } ?? "—")
                    StatCardMini(label: "Jitter", value: hop.jitter.map { String(format: "%.1f", $0) } ?? "—")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var rawOutputView: some View {
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Active Trace")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a target to map the layer 3 network path.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Discovering Network Hops...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, maxHops: maxHops, interval: traceInterval) }
    }
}

private struct StatCardMini: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1)).cornerRadius(6)
    }
}

private struct TracerouteIPInfoSheet: View {
    let hop: TracerouteHop
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hop \(hop.hop)").font(.headline)
                    Text(hop.displayHost).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                infoRow(label: "IP Address", value: hop.ip ?? "Unknown")
                if let geo = hop.geo {
                    infoRow(label: "Location", value: "\(geo.flag) \(geo.city), \(geo.country)")
                    if let coord = geo.coordinate {
                        infoRow(label: "Coordinates", value: String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                    }
                    infoRow(label: "Organization", value: geo.org)
                }
            }
            
            Spacer()
        }
        .padding(32)
        .frame(width: 400, height: 450)
        .background(Color(.windowBackgroundColor))
    }
    
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundColor(.secondary)
            Text(value).font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
        }
    }
}
