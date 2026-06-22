import SwiftUI
import Charts
import Observation

struct HTTPLatencyView: View {
    var vm: HTTPLatencyViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var urlString = ""
    @State private var method = "GET"
    @State private var followRedirects = true
    @State private var showLearningGuide = false

    private let methods = ["GET", "HEAD", "POST", "PUT", "OPTIONS"]

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            httpMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }

                    if let result = vm.result {
                        statsBarSection(result)
                        
                        latencyWaterfallSection(result)
                        
                        if !vm.history.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Analysis History")
                                            .font(.headline)
                                        Text("Previous request performance benchmarks")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        withAnimation { vm.history.removeAll() }
                                    } label: {
                                        Label("Clear History", systemImage: "trash")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                
                                historyTable
                            }
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
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "HTTP Latency") }
    }

    // MARK: - Components

    private var httpMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            guard let r = vm.result else {
                return ("stopwatch", .secondary, vm.isRunning ? "Request in progress..." : "Enter a URL to measure latency")
            }
            let ttfb = r.phases.first(where: { $0.phase == .ttfb })?.durationMs ?? r.totalMs
            let code  = r.statusCode ?? 0
            if code >= 500 { return ("xmark.circle.fill", .red, "HTTP \(code)  —  Total: \(String(format: "%.0f", r.totalMs)) ms") }
            if code >= 400 { return ("exclamationmark.triangle.fill", .orange, "HTTP \(code)  —  Total: \(String(format: "%.0f", r.totalMs)) ms") }
            if ttfb > 500  { return ("exclamationmark.triangle.fill", .orange, "Slow TTFB: \(String(format: "%.0f", ttfb)) ms  —  Total: \(String(format: "%.0f", r.totalMs)) ms") }
            return ("checkmark.circle.fill", .green, "HTTP \(code)  —  TTFB: \(String(format: "%.0f", ttfb)) ms  —  Total: \(String(format: "%.0f", r.totalMs)) ms")
        }()
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(msg).font(.callout).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("HTTP Latency")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 280)
                    .onSubmit(startAction)
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { urlString = h.contains("://") ? h : "https://\(h)"; startAction() }
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
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        
                        Toggle("Redirects", isOn: $followRedirects)
                            .toggleStyle(.checkbox)
                            .font(.subheadline)
                    }

                    if let res = vm.result {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveHTTPLatencyPDF(result: res, history: vm.history) },
                            onExportCSV: {
                                let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: exportCSV(vm.history), defaultName: "NetUtil-HTTPLatency-\(date.string(from: Date())).csv", ext: "csv")
                            }
                        )
                    }

                    Button(action: startAction) {
                        Label(vm.isRunning ? "Stop" : "Send", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && urlString.isEmpty)

                    let favHost = URL(string: urlString)?.host ?? urlString
                    if !favHost.isEmpty {
                        let isFav = tools.favorites.isFavorite(favHost)
                        Button { tools.favorites.toggle(host: favHost) } label: {
                            Image(systemName: isFav ? "star.fill" : "star").foregroundColor(isFav ? .orange : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                    }

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

    private func statsBarSection(_ r: HTTPLatencyResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Status Code", value: "\(r.statusCode ?? 0)", icon: "network", color: statusColor(r.statusCode))
            StatCard(title: "Total Latency", value: String(format: "%.0f", r.totalMs), unit: "ms", icon: "stopwatch.fill", color: totalColor(r.totalMs))
            if let bytes = r.bodyBytes {
                let fmt = formatBytes(bytes)
                StatCard(title: "Payload Size", value: fmt.value, unit: fmt.unit, icon: "shippingbox.fill")
            }
        }
    }

    private var httpHealthStrip: some View {
        let items = vm.history.prefix(20).reversed()
        return HStack(spacing: 2) {
            ForEach(items) { r in
                RoundedRectangle(cornerRadius: 1)
                    .fill(statusColor(r.statusCode))
                    .frame(width: 3, height: 12)
            }
        }
        .drawingGroup() // PERFORMANCE: Optimized for mini health strip
    }

    private func latencyWaterfallSection(_ r: HTTPLatencyResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latency Waterfall")
                        .font(.headline)
                    Text("Step-by-step connection timing breakdown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                httpHealthStrip
            }

            VStack(spacing: 14) {
                let maxMs = r.phases.map(\.endMs).max() ?? r.totalMs
                ForEach(r.phases) { phase in
                    HStack(spacing: 12) {
                        Text(phase.phase.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        
                        GeometryReader { geo in
                            let x = geo.size.width * CGFloat(phase.startMs / max(maxMs, 1))
                            let w = max(4, geo.size.width * CGFloat(phase.durationMs / max(maxMs, 1)))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(phaseColor(phase.phase))
                                .frame(width: w)
                                .offset(x: x)
                        }
                        .frame(height: 12)
                        
                        Text(String(format: "%.1f ms", phase.durationMs))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(phase.phase.rawValue) Phase: \(Int(phase.durationMs)) milliseconds")
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Timestamp", width: 100)
                tHeader("Status", width: 80)
                tHeader("Latency", width: 100)
                tHeader("URL / Endpoint", flexible: true)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(.regularMaterial)
            
            Divider()
            
            LazyVStack(spacing: 0) {
                ForEach(vm.history) { r in
                    HStack(spacing: 0) {
                        Text(r.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)
                        
                        HTTPStatusBadge(code: r.statusCode)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(String(format: "%.0f ms", r.totalMs))
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundColor(totalColor(r.totalMs))
                            .frame(width: 100, alignment: .leading)
                        
                        Text(r.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { urlString = r.url; method = r.method }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Request to \(r.url) at \(r.timestamp.formatted(date: .omitted, time: .standard)). Status: \(r.statusCode ?? 0). Latency: \(Int(r.totalMs)) ms.")
                    .accessibilityHint("Tap to restore this request")
                    
                    if r.id != vm.history.last?.id {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
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
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No Request Sent")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a URL to analyze connection phases and TTFB latency.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing Network Phases...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func startAction() {
        if vm.isRunning { vm.cancel() }
        else { guard !urlString.isEmpty else { return }; history.record(urlString); vm.run(urlString: urlString, method: method, followRedirects: followRedirects) }
    }

    private func exportCSV(_ history: [HTTPLatencyResult]) -> String {
        var lines = ["timestamp,method,url,status,latency_ms"]
        let fmt = ISO8601DateFormatter()
        for r in history {
            lines.append("\(fmt.string(from: r.timestamp)),\(r.method),\"\(r.url)\",\(r.statusCode ?? 0),\(r.totalMs)")
        }
        return lines.joined(separator: "\n")
    }

    private func statusColor(_ code: Int?) -> Color { guard let c = code else { return .secondary }; return c < 300 ? .green : c < 400 ? .orange : .red }
    private func totalColor(_ ms: Double) -> Color { ms < 200 ? .primary : ms < 1000 ? .orange : .red }
    private func phaseColor(_ p: HTTPPhase) -> Color { switch p { case .dns: .teal; case .tcp: .blue; case .tls: .purple; case .request: .orange; case .ttfb: .yellow; case .download: .green } }

    private func formatBytes(_ b: Int64) -> (value: String, unit: String) {
        let kb = Double(b) / 1024
        if kb < 1024 { return (String(format: "%.1f", kb), "KB") }
        return (String(format: "%.2f", kb / 1024), "MB")
    }
}

private struct HTTPStatusBadge: View {
    let code: Int?
    var body: some View {
        Text("\(code ?? 0)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(color)
    }
    
    private var color: Color {
        guard let c = code else { return .secondary }
        if c < 300 { return .green }
        if c < 400 { return .orange }
        return .red
    }
}
