import SwiftUI
import Charts

struct HTTPLatencyView: View {
    @ObservedObject var vm: HTTPLatencyViewModel
    @State private var urlString = ""
    @State private var method = "GET"
    @State private var followRedirects = true
    @State private var historySelection: HTTPLatencyResult.ID?

    private let methods = ["GET", "HEAD", "POST", "PUT", "OPTIONS"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if let result = vm.result {
                summaryBar(result)
                Divider()
                waterfallChart(result)
            } else if !vm.isRunning {
                emptyState
            }
            if vm.isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Measuring…").font(.caption).foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            if !vm.history.isEmpty {
                Divider()
                historyTable
            }
        }
        .padding()
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            TextField("https://example.com", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)
                .onSubmit {
                    guard !urlString.isEmpty, !vm.isRunning else { return }
                    vm.run(urlString: urlString, method: method, followRedirects: followRedirects)
                }

            Picker("", selection: $method) {
                ForEach(methods, id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 90)

            Toggle("Follow Redirects", isOn: $followRedirects)
                .toggleStyle(.checkbox)
                .font(.caption)

            Spacer()

            Button(vm.isRunning ? "Cancel" : "Send") {
                if vm.isRunning {
                    vm.cancel()
                } else {
                    guard !urlString.isEmpty else { return }
                    vm.run(urlString: urlString, method: method, followRedirects: followRedirects)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .keyboardShortcut(.return)
        }
    }

    private func summaryBar(_ r: HTTPLatencyResult) -> some View {
        HStack(spacing: 14) {
            chip("Status", statusText(r.statusCode), statusColor(r.statusCode))
            chip("Total", String(format: "%.0f ms", r.totalMs), totalColor(r.totalMs))
            if let bytes = r.bodyBytes {
                chip("Size", formatBytes(bytes), .primary)
            }
            if r.redirectCount > 0 {
                chip("Redirects", "\(r.redirectCount)", .orange)
            }
            Spacer()
            Text(r.timestamp.formatted(date: .omitted, time: .standard))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Button {
                guard !urlString.isEmpty else { return }
                vm.run(urlString: urlString, method: method, followRedirects: followRedirects)
            } label: {
                Label("Run Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.isRunning || urlString.isEmpty)
        }
    }

    private func chip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func waterfallChart(_ r: HTTPLatencyResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waterfall")
                .font(.caption)
                .foregroundColor(.secondary)

            if r.phases.isEmpty {
                Text("Detailed phase metrics unavailable for this request.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                let maxMs = r.phases.map(\.endMs).max() ?? r.totalMs

                VStack(spacing: 6) {
                    ForEach(r.phases) { phase in
                        waterfallRow(phase: phase, maxMs: maxMs)
                    }
                }

                phaseLegend(r.phases)
            }
        }
    }

    private func waterfallRow(phase: HTTPPhaseTiming, maxMs: Double) -> some View {
        HStack(spacing: 8) {
            Text(phase.phase.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 68, alignment: .trailing)

            GeometryReader { geo in
                let total = max(maxMs, 1)
                let x = geo.size.width * CGFloat(phase.startMs / total)
                let w = max(2, geo.size.width * CGFloat(phase.durationMs / total))
                RoundedRectangle(cornerRadius: 3)
                    .fill(phaseColor(phase.phase))
                    .frame(width: w, height: 14)
                    .offset(x: x)
            }
            .frame(height: 14)

            Text(String(format: "%.1f ms", phase.durationMs))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 70, alignment: .trailing)
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

    private func phaseLegend(_ phases: [HTTPPhaseTiming]) -> some View {
        let present = phases.map(\.phase)
        return HStack(spacing: 12) {
            ForEach(present, id: \.rawValue) { p in
                HStack(spacing: 4) {
                    Circle().fill(phaseColor(p)).frame(width: 7, height: 7)
                    Text(p.rawValue).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private var historyTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("History")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Click row to restore URL")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Table(vm.history, selection: $historySelection) {
                TableColumn("Time") { r in
                    Text(r.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(75)

                TableColumn("Method") { r in
                    Text(r.method)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(55)

                TableColumn("Status") { r in
                    Text(statusText(r.statusCode))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(statusColor(r.statusCode))
                }
                .width(55)

                TableColumn("Total") { r in
                    Text(String(format: "%.0f ms", r.totalMs))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(totalColor(r.totalMs))
                }
                .width(75)

                TableColumn("URL") { r in
                    Text(r.url)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(height: min(CGFloat(vm.history.count) * 28 + 30, 220))
            .onChange(of: historySelection) { _, newValue in
                if let id = newValue,
                   let result = vm.history.first(where: { $0.id == id }) {
                    urlString = result.url
                    method = result.method
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Enter a URL and press Send")
                .foregroundColor(.secondary)
                .font(.callout)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
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

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1 { return "\(bytes) B" }
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.2f MB", kb / 1024)
    }
}
