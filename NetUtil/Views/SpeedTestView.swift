import SwiftUI

struct SpeedTestView: View {
    @ObservedObject var vm: SpeedTestViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)

            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.system(size: 12, weight: .medium)).padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 24) {
                gaugeRow
                progressSection
                if !vm.history.isEmpty {
                    historySection
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "speedometer").foregroundColor(.accentColor)
                Text("Speed Test").font(.headline)
            }.frame(width: 250, alignment: .leading)

            HStack(spacing: 8) {
                Text("Provider:").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Text("Cloudflare").font(.system(size: 12, design: .monospaced))
            }

            Spacer()

            Button(action: { if vm.isTesting { vm.cancel() } else { vm.start() } }) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isTesting ? "stop.fill" : "play.fill")
                    Text(vm.isTesting ? "Cancel" : "Start Test")
                }.font(.system(size: 13, weight: .medium)).frame(minWidth: 90)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isTesting ? .red : .accentColor)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.borderless)
        }
    }

    private var gaugeRow: some View {
        HStack(spacing: 16) {
            metricCard(title: "Download", value: vm.downloadMbps, unit: "Mbps", icon: "arrow.down", color: .blue, highlight: vm.phase == .download)
            metricCard(title: "Upload",   value: vm.uploadMbps,   unit: "Mbps", icon: "arrow.up",   color: .orange, highlight: vm.phase == .upload)
            metricCard(title: "Latency",  value: vm.pingMs,       unit: "ms",   icon: "timer",      color: .green,  highlight: vm.phase == .latency)
            metricCard(title: "Jitter",   value: vm.jitterMs,     unit: "ms",   icon: "waveform.path.ecg", color: .purple, highlight: false)
        }
    }

    private func metricCard(title: String, value: Double, unit: String, icon: String, color: Color, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.subheadline).foregroundColor(color)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                if highlight { PulsingIndicator(color: color).scaleEffect(0.7) }
                Spacer()
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text(unit).font(.caption.weight(.medium)).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(highlight ? color.opacity(0.5) : Color(.separatorColor).opacity(0.1), lineWidth: highlight ? 1.5 : 0.5))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status").font(.caption.weight(.medium)).foregroundColor(.secondary)
                Spacer()
                Text(vm.phase.rawValue).font(.caption.weight(.semibold))
                    .foregroundColor(phaseColor)
            }
            ProgressView(value: vm.progress).progressViewStyle(.linear).tint(phaseColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var phaseColor: Color {
        switch vm.phase {
        case .idle:     return .secondary
        case .latency:  return .green
        case .download: return .blue
        case .upload:   return .orange
        case .done:     return .green
        case .failed:   return .red
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(.headline)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tHeader("Time",     width: 100)
                    tHeader("Download", width: 110)
                    tHeader("Upload",   width: 110)
                    tHeader("Ping",     width: 80)
                    tHeader("Jitter",   width: 80)
                }.padding(.vertical, 8).padding(.horizontal, 12)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.history) { r in
                            HStack(spacing: 0) {
                                Text(r.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(width: 100, alignment: .leading)
                                Text(String(format: "%.1f Mbps", r.downloadMbps))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.blue).frame(width: 110, alignment: .leading)
                                Text(String(format: "%.1f Mbps", r.uploadMbps))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.orange).frame(width: 110, alignment: .leading)
                                Text(String(format: "%.0f ms", r.pingMs))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.green).frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f ms", r.jitterMs))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.purple).frame(width: 80, alignment: .leading)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func tHeader(_ title: String, width: CGFloat) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Speed Test Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                GuideSection(title: "How it works", icon: "speedometer") {
                    Text("Uses Cloudflare's open speed test endpoints. Downloads 100 MB then uploads chunks for 10 seconds each. Latency is measured with 5 round-trips to compute median ping and jitter.")
                }
                GuideSection(title: "Reading results", icon: "chart.bar") {
                    Text("Download/Upload are sustained throughput in Mbps. Ping is the median round-trip latency. Jitter is the standard deviation of pings — high jitter means inconsistent latency.")
                }
            }.padding(24) }
        }.frame(width: 500, height: 500)
    }
}
