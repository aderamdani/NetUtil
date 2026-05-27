import SwiftUI
import Charts

struct HTTPLatencyView: View {
    @ObservedObject var vm: HTTPLatencyViewModel
    @StateObject private var history = HostHistory.shared
    @State private var urlString = ""
    @State private var method = "GET"
    @State private var followRedirects = true
    @State private var showLearningGuide = false

    private let methods = ["GET", "HEAD", "POST", "PUT", "OPTIONS"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar
                .padding(.bottom, 24)
            
            if let err = vm.error {
                errorBanner(err).padding(.bottom, 16)
            }
            
            if let result = vm.result {
                statsBar(result).padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        sectionHeader("Latency Waterfall")
                        Spacer()
                        httpHealthStrip
                    }
                    
                    waterfallChart(result)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.bottom, 32)
                
                if !vm.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionHeader("Analysis History")
                            Spacer()
                            Button(role: .destructive) { withAnimation { vm.history.removeAll() } } label: {
                                Image(systemName: "trash").foregroundColor(.secondary)
                            }.buttonStyle(.borderless)
                        }
                        historyTable
                    }
                    .frame(maxHeight: .infinity)
                }
            } else if vm.isRunning {
                loadingState
            } else {
                emptyState
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("https://example.com", text: $urlString)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(minWidth: 300).onSubmit(startAction)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { urlString = h.contains("://") ? h : "https://\(h)"; startAction() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }
                        .menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Picker("", selection: $method) { ForEach(methods, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).frame(width: 90)
                Toggle("Redirects", isOn: $followRedirects).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }

            Spacer()

            if let res = vm.result {
                Button { Exporter.saveHTTPLatencyPDF(result: res, history: vm.history) } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: startAction) {
                HStack(spacing: 6) { Image(systemName: vm.isRunning ? "stop.fill" : "play.fill"); Text(vm.isRunning ? "Stop" : "Send") }.font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }.buttonStyle(.borderedProminent).tint(vm.isRunning ? .red : .accentColor).disabled(!vm.isRunning && urlString.isEmpty)
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func statsBar(_ r: HTTPLatencyResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Status", value: "\(r.statusCode ?? 0)", icon: "network", color: statusColor(r.statusCode))
            StatCard(title: "Latency", value: String(format: "%.0f", r.totalMs), unit: "ms", icon: "stopwatch.fill", color: totalColor(r.totalMs))
            if let bytes = r.bodyBytes {
                let fmt = formatBytes(bytes)
                StatCard(title: "Size", value: fmt.value, unit: fmt.unit, icon: "shippingbox.fill")
            }
            Spacer()
        }
    }

    private var httpHealthStrip: some View {
        let items = vm.history.prefix(20).reversed()
        return HStack(spacing: 1.5) {
            ForEach(items) { r in RoundedRectangle(cornerRadius: 1).fill(statusColor(r.statusCode)).frame(width: 3, height: 12) }
        }
    }

    private func waterfallChart(_ r: HTTPLatencyResult) -> some View {
        VStack(spacing: 10) {
            let maxMs = r.phases.map(\.endMs).max() ?? r.totalMs
            ForEach(r.phases) { phase in
                HStack(spacing: 12) {
                    Text(phase.phase.rawValue.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).frame(width: 70, alignment: .trailing)
                    GeometryReader { geo in
                        let x = geo.size.width * CGFloat(phase.startMs / max(maxMs, 1))
                        let w = max(4, geo.size.width * CGFloat(phase.durationMs / max(maxMs, 1)))
                        RoundedRectangle(cornerRadius: 4).fill(phaseColor(phase.phase)).frame(width: w).offset(x: x)
                    }.frame(height: 14)
                    Text(String(format: "%.1f ms", phase.durationMs)).font(.system(size: 10, design: .monospaced)).frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Time", width: 80); tHeader("Status", width: 60); tHeader("Total", width: 80); tHeader("URL / Endpoint", flexible: true)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.history) { r in
                        HStack(spacing: 0) {
                            Text(r.timestamp.formatted(date: .omitted, time: .standard)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                            Text("\(r.statusCode ?? 0)").font(.system(size: 11)).foregroundColor(statusColor(r.statusCode)).frame(width: 60, alignment: .leading)
                            Text(String(format: "%.0f ms", r.totalMs)).font(.system(size: 11, design: .monospaced)).foregroundColor(totalColor(r.totalMs)).frame(width: 80, alignment: .leading)
                            Text(r.url).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 12).contentShape(Rectangle())
                        .onTapGesture { urlString = r.url; method = r.method }
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }
    
    private func errorBanner(_ msg: String) -> some View { Text(msg).foregroundColor(.red).font(.system(size: 12, weight: .medium)) }

    private var emptyState: some View {
        VStack { Spacer(); Text("No Target Selected").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack { Spacer(); ProgressView(); Text("Analyzing network phases...").font(.subheadline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startAction() {
        if vm.isRunning { vm.cancel() }
        else { guard !urlString.isEmpty else { return }; history.record(urlString); vm.run(urlString: urlString, method: method, followRedirects: followRedirects) }
    }

    private func statusColor(_ code: Int?) -> Color { guard let c = code else { return .secondary }; return c < 300 ? .green : c < 400 ? .orange : .red }
    private func totalColor(_ ms: Double) -> Color { ms < 200 ? .primary : ms < 1000 ? .orange : .red }
    private func phaseColor(_ p: HTTPPhase) -> Color { switch p { case .dns: .teal; case .tcp: .blue; case .tls: .purple; case .request: .orange; case .ttfb: .yellow; case .download: .green } }

    private func formatBytes(_ b: Int64) -> (value: String, unit: String) {
        let kb = Double(b) / 1024
        if kb < 1024 { return (String(format: "%.1f", kb), "KB") }
        return (String(format: "%.2f", kb / 1024), "MB")
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("HTTP Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is TTFB?", icon: "stopwatch") { Text("Time to First Byte measures the responsiveness of a web server.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}
