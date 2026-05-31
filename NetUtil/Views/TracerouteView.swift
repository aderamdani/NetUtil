import SwiftUI
import Observation
import CoreLocation

struct TracerouteView: View {
    var vm: TracerouteViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var host = ""
    @AppStorage("defaultMaxHops")       private var defaultMaxHops = 30
    @AppStorage("defaultTraceInterval")  private var defaultInterval = 5.0
    @AppStorage("rttWarnThreshold")      private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold")      private var rttCrit: Double = 100.0
    @State private var maxHops = 30
    @State private var traceInterval = 5.0
    @State private var viewMode: ViewMode = .hops
    @State private var selectedHopID: UUID?
    @State private var infoHop: TracerouteHop?
    @State private var showLearningGuide = false

    enum ViewMode: String, CaseIterable, Identifiable {
        case hops, timeline, map, raw
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            TracerouteControlBar(
                host: $host,
                isRunning: vm.isRunning,
                maxHops: $maxHops,
                traceInterval: $traceInterval,
                round: vm.round,
                onStart: startAction,
                onShowGuide: { showLearningGuide = true },
                history: history,
                hasHops: !vm.hops.isEmpty,
                onExportPDF: { Exporter.saveTraceroutePDF(hops: vm.hops, host: host, round: vm.round) },
                onExportCSV: {
                    let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                    Exporter.save(string: Exporter.csvString(from: vm.hops), defaultName: "NetUtil-Traceroute-\(host)-\(date.string(from: Date())).csv", ext: "csv")
                },
                isFavorite: tools.favorites.isFavorite(host),
                onToggleFavorite: { tools.favorites.toggle(host: host) }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if !vm.hops.isEmpty {
                        pathSummarySection
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                sectionHeader("Path Visualization", icon: "map.fill")
                                Spacer()
                                Picker("", selection: $viewMode) {
                                    ForEach(ViewMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue.capitalized).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                .accessibilityLabel("Visualization Mode")
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
        .onAppear {
            maxHops = defaultMaxHops
            traceInterval = defaultInterval
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Traceroute") }
        .onAppear {
            if let h = vm.quickLaunchHost { host = h; vm.quickLaunchHost = nil; startAction() }
        }
        .sheet(item: $infoHop) { hop in TracerouteIPInfoSheet(hop: hop) }
    }

    // MARK: - Components

    private var pathSummarySection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Path Depth", value: "\(vm.hops.count)", unit: "Hops", icon: "arrow.triangle.branch")
                .accessibilityElement(children: .combine)
            StatCard(title: "Path Loss", value: String(format: "%.1f%%", vm.pathLoss), icon: "exclamationmark.triangle", color: vm.pathLoss > 0 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent", vm.pathLoss))
            if let avg = vm.pathAvgRtt {
                StatCard(title: "Avg Latency", value: String(format: "%.1f", avg), unit: "ms", icon: "timer", color: avg < rttWarn ? .primary : .orange)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue("\(Int(avg)) milliseconds")
            }
            if let last = vm.hops.last?.displayHost {
                StatCard(title: "Target Host", value: last, icon: "target")
                    .accessibilityElement(children: .combine)
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
                    .accessibilityLabel("Close Detail")
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Host / IP").font(.caption2.bold()).foregroundColor(.secondary)
                    Text(hop.displayHost).font(.system(.subheadline, design: .monospaced).weight(.bold))
                }
                .accessibilityElement(children: .combine)
                
                if let geo = hop.geo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption2.bold()).foregroundColor(.secondary)
                        Text("\(geo.flag) \(geo.city), \(geo.country)")
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
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
                ForEach(vm.rawLines) { line in
                    Text(line.text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .accessibilityLabel("Raw traceroute output")
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
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
        .accessibilityLabel("Error: \(msg)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No Active Trace")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a target to map the layer 3 network path.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel("Discovering network hops, please wait")
    }

    private func startAction() {
        if vm.isRunning { vm.stop() }
        else { guard !host.isEmpty else { return }; history.record(host); vm.start(host: host, maxHops: maxHops, interval: traceInterval) }
    }
    
    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct StatCardMini: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                    .accessibilityLabel("Close IP info sheet")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                infoRow(label: "IP Address", value: hop.ip ?? "Unknown")
                if let geo = hop.geo {
                    infoRow(label: "Location", value: "\(geo.flag) \(geo.city), \(geo.country)")
                    if let coord = geo.coordinate {
                        let lat = coord.latitude
                        let lon = coord.longitude
                        infoRow(label: "Coordinates", value: String(format: "%.4f, %.4f", lat, lon))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
