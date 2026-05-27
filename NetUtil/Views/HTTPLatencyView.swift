import SwiftUI
import Charts

struct HTTPLatencyView: View {
    @ObservedObject var vm: HTTPLatencyViewModel
    @StateObject private var history = HostHistory.shared
    @State private var urlString = ""
    @State private var method = "GET"
    @State private var followRedirects = true
    @State private var historySelection: HTTPLatencyResult.ID?
    @State private var showLearningGuide = false

    private let methods = ["GET", "HEAD", "POST", "PUT", "OPTIONS"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // FIXED HEADER (Control Bar)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                    
                    if let result = vm.result {
                        VStack(alignment: .leading, spacing: 20) {
                            // Smart Interpretation & Health Strip
                            HStack(alignment: .center, spacing: 12) {
                                let interpretation = interpretHTTPStatus(result)
                                Image(systemName: interpretation.icon)
                                    .font(.title2)
                                    .foregroundColor(interpretation.color)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(interpretation.status)
                                        .font(.headline)
                                    Text(interpretation.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Health Strip (Last 20 requests)
                                httpHealthStrip
                            }
                            .padding(.bottom, 8)
                            
                            statsBar(result)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("LATENCY WATERFALL", systemImage: "chart.bar.xaxis")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.secondary)
                                        .kerning(1)
                                    Spacer()
                                    Text(result.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                waterfallChart(result)
                                    .padding(20)
                                    .background(Color(.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                            }
                        }
                    } else if !vm.isRunning {
                        emptyState
                    }
                    
                    if vm.isRunning {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Analyzing network phases...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    
                    if !vm.history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ANALYSIS HISTORY")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                Spacer()
                                Button(role: .destructive) {
                                    withAnimation {
                                        vm.history.removeAll()
                                    }
                                } label: {
                                    Label("Clear History", systemImage: "trash")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                            
                            historyTable
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            learningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("https://example.com", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(minWidth: 300)
                .help("URL to analyze.")
                .onSubmit(startAction)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in
                                Button(h) { 
                                    urlString = h.contains("://") ? h : "https://\(h)"
                                    startAction() 
                                }
                            }
                            Divider()
                            Button("Clear History", role: .destructive) { 
                                history.clear()
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

            Picker("", selection: $method) {
                ForEach(methods, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Toggle("Follow Redirects", isOn: $followRedirects)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            if let result = vm.result {
                Menu {
                    Button("Export as PDF Report...") {
                        Exporter.saveHTTPLatencyPDF(result: result, history: vm.history)
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            Button(action: startAction) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Send Request")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && urlString.isEmpty)
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .help("HTTP Latency Learning Guide")
        }
    }
    
    private func startAction() {
        if vm.isRunning {
            vm.cancel()
        } else {
            guard !urlString.isEmpty else { return }
            history.record(urlString)
            vm.run(urlString: urlString, method: method, followRedirects: followRedirects)
        }
    }

    private func statsBar(_ r: HTTPLatencyResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "STATUS", value: statusText(r.statusCode), icon: "network", color: statusColor(r.statusCode))
            StatCard(title: "TOTAL LATENCY", value: String(format: "%.0f", r.totalMs), unit: "ms", icon: "stopwatch.fill", color: totalColor(r.totalMs))
            if let bytes = r.bodyBytes {
                let formatted = formatBytes(bytes)
                StatCard(title: "BODY SIZE", value: formatted.value, unit: formatted.unit, icon: "shippingbox.fill")
            }
            if r.redirectCount > 0 {
                StatCard(title: "REDIRECTS", value: "\(r.redirectCount)", icon: "arrow.right.circle.fill", color: .orange)
            }
            Spacer()
        }
    }

    private var httpHealthStrip: some View {
        let items = vm.history.prefix(20).reversed()
        return HStack(spacing: 3) {
            ForEach(items) { r in
                RoundedRectangle(cornerRadius: 1)
                    .fill(statusColor(r.statusCode))
                    .frame(width: 6, height: 16)
            }
        }
        .help("HTTP Health Strip: Last 20 requests. Green = 2xx, Orange = 3xx, Red = 4xx/5xx.")
    }

    private func interpretHTTPStatus(_ r: HTTPLatencyResult) -> (status: String, description: String, icon: String, color: Color) {
        guard let code = r.statusCode else {
            return ("Connection Failed", "Unable to establish a connection to the server.", "xmark.shield.fill", .red)
        }
        
        let latency = r.totalMs
        
        switch code {
        case 200..<300:
            if latency < 200 {
                return ("Excellent", "Ultra-fast response with successful status.", "checkmark.seal.fill", .green)
            } else if latency < 1000 {
                return ("Responsive", "Good response time for a web resource.", "hand.thumbsup.fill", .green)
            } else {
                return ("High Latency", "Request successful but server response is slow.", "clock.fill", .orange)
            }
        case 300..<400:
            return ("Redirected (\(code))", "Request was redirected to another location.", "arrow.right.circle.fill", .orange)
        case 400..<500:
            return ("Client Error (\(code))", "The server couldn't process your request (Bad URL/Unauthorized).", "person.fill.questionmark", .red)
        case 500..<600:
            return ("Server Error (\(code))", "The remote server encountered an internal error.", "exclamationmark.shield.fill", .red)
        default:
            return ("Status \(code)", "Received an unusual HTTP status code.", "questionmark.circle.fill", .secondary)
        }
    }

    private func waterfallChart(_ r: HTTPLatencyResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if r.phases.isEmpty {
                Text("Detailed metrics unavailable. Ensure the server supports timing metrics.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                let maxMs = r.phases.map(\.endMs).max() ?? r.totalMs

                VStack(spacing: 8) {
                    ForEach(r.phases) { phase in
                        waterfallRow(phase: phase, maxMs: maxMs)
                    }
                }

                HStack(spacing: 16) {
                    phaseLegendItem(.teal,   "DNS")
                    phaseLegendItem(.blue,   "TCP")
                    phaseLegendItem(.purple, "TLS")
                    phaseLegendItem(.orange, "Request")
                    phaseLegendItem(.yellow, "TTFB")
                    phaseLegendItem(.green,  "Download")
                }
                .padding(.top, 12)
            }
        }
    }

    private func waterfallRow(phase: HTTPPhaseTiming, maxMs: Double) -> some View {
        HStack(spacing: 12) {
            Text(phase.phase.rawValue.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            GeometryReader { geo in
                let total = max(maxMs, 1)
                let x = geo.size.width * CGFloat(phase.startMs / total)
                let w = max(4, geo.size.width * CGFloat(phase.durationMs / total))
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.05))
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phaseColor(phase.phase))
                        .shadow(color: phaseColor(phase.phase).opacity(0.3), radius: 2)
                        .frame(width: w)
                        .offset(x: x)
                }
            }
            .frame(height: 16)

            Text(String(format: "%.1f ms", phase.durationMs))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 75, alignment: .trailing)
        }
    }

    private func phaseColor(_ phase: HTTPPhase) -> Color {
        switch phase {
        case .dns:      return .teal
        case .tcp:      return .blue
        case .tls:      return .purple
        case .request:  return .orange
        case .ttfb:     return .yellow
        case .download: return .green
        }
    }

    private func phaseLegendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
        }
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("Time", width: 80)
                headerCell("Method", width: 60)
                headerCell("Status", width: 60)
                headerCell("Total", width: 80)
                headerCell("URL / Endpoint", flexible: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(.windowBackgroundColor))
            
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.history) { r in
                        HStack(spacing: 0) {
                            Text(r.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 80, alignment: .leading)
                            
                            Text(r.method)
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 60, alignment: .leading)
                            
                            Text(statusText(r.statusCode))
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(statusColor(r.statusCode))
                                .frame(width: 60, alignment: .leading)
                            
                            Text(String(format: "%.0f ms", r.totalMs))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(totalColor(r.totalMs))
                                .frame(width: 80, alignment: .leading)
                            
                            Text(r.url)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            urlString = r.url
                            method = r.method
                        }
                        
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .frame(maxHeight: 250)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "stopwatch").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Enter a URL to analyze high-precision HTTP/HTTPS latency phases.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HTTP Latency Learning Guide").font(.title2.bold())
                    Text("Learn how to analyze web request performance.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is HTTP Latency?", icon: "stopwatch.fill") {
                        Text("HTTP Latency is the time it takes for a web request to travel from your computer to a server and for the response to come back. NetUtil breaks this down into six distinct phases.")
                    }
                    
                    GuideSection(title: "Understanding Phases", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "DNS (Domain Name System)", desc: "Time spent resolving the hostname (e.g., google.com) to an IP address.")
                            GuidePoint(title: "TCP (Transmission Control Protocol)", desc: "Time spent establishing a connection between your device and the server.")
                            GuidePoint(title: "TLS (Handshake)", desc: "Time spent negotiating a secure encrypted connection (HTTPS).")
                            GuidePoint(title: "TTFB (Time to First Byte)", desc: "The time spent waiting for the server to process the request and send the first byte of response. A key indicator of server speed.")
                        }
                    }
                    
                    GuideSection(title: "What to Look For?", icon: "lightbulb.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• **Long DNS**: Indicates issues with your DNS provider or local cache.")
                            Text("• **Long TTFB**: The server itself is likely overloaded or the code is slow.")
                            Text("• **TLS Spikes**: May indicate issues with SSL certificate validation or remote security settings.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.secondary)
            .kerning(1)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func statusText(_ code: Int?) -> String {
        guard let code else { return "—" }
        return "\(code)"
    }

    private func statusColor(_ code: Int?) -> Color {
        guard let code else { return .secondary }
        switch code {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<500: return .red
        default:        return .red
        }
    }

    private func totalColor(_ ms: Double) -> Color {
        if ms < 200 { return .green }
        if ms < 1000 { return .orange }
        return .red
    }

    private func formatBytes(_ bytes: Int64) -> (value: String, unit: String) {
        let kb = Double(bytes) / 1024
        if kb < 1 { return ("\(bytes)", "B") }
        if kb < 1024 { return (String(format: "%.1f", kb), "KB") }
        return (String(format: "%.2f", kb / 1024), "MB")
    }
}
