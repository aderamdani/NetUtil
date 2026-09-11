import SwiftUI
import Charts
import Accessibility

/// Analytical throughput monitor: time-series line chart plus a
/// Name / Mean / Max / Last summary table, computed from the visible window.
struct ThroughputStatisticsView: View {
    @Bindable var viewModel: ThroughputStatisticsViewModel
    @State private var selectedTime: Date? = nil

    init(viewModel: ThroughputStatisticsViewModel) {
        self.viewModel = viewModel
    }

    init(samples: [ThroughputSample], range: ThroughputRange = .fiveMinutes) {
        let vm = ThroughputStatisticsViewModel(samples: samples)
        vm.range = range
        self.viewModel = vm
    }

    private var selectedSample: ThroughputSample? {
        guard let selectedTime else { return nil }
        return viewModel.samples.min(by: {
            abs($0.time.timeIntervalSince(selectedTime)) < abs($1.time.timeIntervalSince(selectedTime))
        })
    }

    private var yTop: Double {
        ThroughputStatisticsViewModel.axisTop(
            for: viewModel.samples.map { max($0.download, $0.upload) }.max() ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            moodBar
            ScrollView {
                if viewModel.isLoading && viewModel.samples.isEmpty {
                    ToolStateView.loading(message: "Loading samples…")
                } else if viewModel.samples.isEmpty {
                    ToolStateView.empty(
                        title: "No Samples",
                        subtitle: "No throughput data in this range yet.")
                } else {
                    statsCard
                }
            }
        }
        .task(id: viewModel.range) {
            await viewModel.reload()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Throughput Statistics")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Throughput Statistics")

                Spacer()

                Picker("Range", selection: $viewModel.range) {
                    ForEach(ThroughputRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .accessibilityLabel("Time range")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
        }
    }

    private var moodBar: some View {
        let samples = viewModel.samples
        let (icon, color, msg): (String, Color, String) = {
            if samples.isEmpty {
                return ("chart.line.uptrend.xyaxis", .secondary, "No throughput data in this range")
            }
            let down = samples.map(\.download)
            let peak = NetworkMath.formatRate(down.max() ?? 0)
            let avg = NetworkMath.formatRate(down.reduce(0, +) / Double(samples.count))
            return ("chart.line.uptrend.xyaxis", .accentColor,
                    "Download avg \(avg) · peak \(peak) — \(samples.count) samples")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            throughputChart
                .frame(height: 240)
            Divider().opacity(0.5)
            summaryTable
        }
        .padding(Metrics.spacingXL)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .padding(24)
    }

    private var throughputChart: some View {
        Chart {
            ForEach(viewModel.samples, id: \.time) { s in
                LineMark(
                    x: .value("Time", s.time),
                    y: .value("Throughput", s.download)
                )
                .foregroundStyle(by: .value("Series", "Download"))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                LineMark(
                    x: .value("Time", s.time),
                    y: .value("Throughput", s.upload)
                )
                .foregroundStyle(by: .value("Series", "Upload"))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
            }
            if let selected = selectedSample {
                RuleMark(x: .value("Cursor", selected.time))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        tooltip(sample: selected)
                    }
            }
        }
        .chartForegroundStyleScale([
            "Download": Color.blue,
            "Upload": Color.orange
        ])
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: viewModel.range.stride.component, count: viewModel.range.stride.count)) {
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, yTop / 2, yTop]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(verbatim: NetworkMath.formatRate(v))
                            .font(.caption2.monospaced())
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .chartYScale(domain: 0...yTop)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            select(at: location, proxy: proxy, geo: geo)
                        case .ended:
                            selectedTime = nil
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                select(at: value.location, proxy: proxy, geo: geo)
                            }
                            .onEnded { _ in selectedTime = nil }
                    )
            }
        }
        .drawingGroup()
        .accessibilityChartDescriptor(ThroughputChartDescriptor(
            samples: viewModel.samples,
            yTop: yTop,
            summary: summaryDescription
        ))
        .accessibilityLabel("Line chart of throughput over time for download and upload")
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
        guard let date: Date = proxy.value(atX: location.x - plotOriginX) else { return }
        selectedTime = viewModel.samples.min(by: {
            abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date))
        })?.time
    }

    private func tooltip(sample: ThroughputSample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sample.time, format: .dateTime.hour().minute())
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("↓").font(.caption.bold()).foregroundColor(.blue)
                    Text(NetworkMath.formatRate(sample.download))
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.blue)
                }
                HStack(spacing: 4) {
                    Text("↑").font(.caption.bold()).foregroundColor(.orange)
                    Text(NetworkMath.formatRate(sample.upload))
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summaryTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Mean").frame(width: 110, alignment: .trailing)
                Text("Max").frame(width: 110, alignment: .trailing)
                Text("Last").frame(width: 110, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)

            Divider().opacity(0.5)

            SummaryRow(color: .blue, square: false, name: "Download", stats: stats(for: \.download))
            Divider().opacity(0.5).padding(.leading, 20)
            SummaryRow(color: .orange, square: true, name: "Upload", stats: stats(for: \.upload))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Summary. \(summaryDescription)")
    }

    private func stats(for keyPath: KeyPath<ThroughputSample, Double>) -> (mean: String, max: String, last: String) {
        let samples = viewModel.samples
        guard !samples.isEmpty else { return ("—", "—", "—") }
        let values = samples.map { $0[keyPath: keyPath] }
        return (
            NetworkMath.formatRate(values.reduce(0, +) / Double(values.count)),
            NetworkMath.formatRate(values.max() ?? 0),
            NetworkMath.formatRate(values.last ?? 0)
        )
    }

    private var summaryDescription: String {
        let down = stats(for: \.download)
        let up = stats(for: \.upload)
        return "Time on the X axis, throughput on the Y axis from 0 to \(NetworkMath.formatRate(yTop)). Download mean \(down.mean), max \(down.max), last \(down.last). Upload mean \(up.mean), max \(up.max), last \(up.last)."
    }
}

/// One summary-table row. The swatch shape differs per series so color is
/// never the only differentiator.
private struct SummaryRow: View {
    let color: Color
    let square: Bool
    let name: String
    let stats: (mean: String, max: String, last: String)

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Group {
                    if square {
                        RoundedRectangle(cornerRadius: 2).fill(color)
                    } else {
                        Circle().fill(color)
                    }
                }
                .frame(width: 8, height: 8)
                Text(name).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(stats.mean).frame(width: 110, alignment: .trailing)
            Text(stats.max).frame(width: 110, alignment: .trailing)
            Text(stats.last).frame(width: 110, alignment: .trailing)
        }
        .font(.caption.monospaced())
        .padding(.vertical, 8)
    }
}

/// VoiceOver descriptor. Points are downsampled and each carries a spoken
/// label ("Download at 14:05, 34 megabits per second") — never colors,
///
/// and never subjective words.
private struct ThroughputChartDescriptor: AXChartDescriptorRepresentable {
    let samples: [ThroughputSample]
    let yTop: Double
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()
        let stride = max(1, samples.count / 60)
        let points = samples.enumerated().compactMap { index, sample in
            index % stride == 0 ? sample : nil
        }
        return AXChartDescriptor(
            title: "Throughput statistics",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Time",
                categoryOrder: points.map { timeFormatter.string(from: $0.time) }
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: "Throughput",
                range: 0...yTop,
                gridlinePositions: [0, yTop / 2, yTop],
                valueDescriptionProvider: { NetworkMath.spokenRate($0) }
            ),
            series: [
                AXDataSeriesDescriptor(
                    name: "Download",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(
                            x: timeFormatter.string(from: $0.time),
                            y: $0.download,
                            label: "Download at \(timeFormatter.string(from: $0.time)), \(NetworkMath.spokenRate($0.download))")
                    }
                ),
                AXDataSeriesDescriptor(
                    name: "Upload",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(
                            x: timeFormatter.string(from: $0.time),
                            y: $0.upload,
                            label: "Upload at \(timeFormatter.string(from: $0.time)), \(NetworkMath.spokenRate($0.upload))")
                    }
                )
            ]
        )
    }
}

// MARK: - Preview Data

extension ThroughputSample {
    /// 12 hours of deterministic samples: quiet download base with
    /// ~30–34 Mb spikes, upload always under ~2 Mb.
    static func previewData(now: Date = Date()) -> [ThroughputSample] {
        let step: TimeInterval = 60
        let count = 12 * 60
        let spikeIndices: Set<Int> = [120, 300, 520, 660]
        let mib = 1_048_576.0
        return (0..<count).map { i in
            let time = now.addingTimeInterval(-Double(count - 1 - i) * step)
            let f = Double(i)
            var download = 800_000
                + 900_000 * (0.5 + 0.5 * sin(f * 0.05))
                + 400_000 * (0.5 + 0.5 * sin(f * 0.13 + 2))
            if spikeIndices.contains(i) {
                download = (30 + Double((i * 13) % 5)) * mib
            }
            let upload = 400_000
                + 700_000 * (0.5 + 0.5 * sin(f * 0.07 + 0.5))
                + 300_000 * (0.5 + 0.5 * sin(f * 0.19))
            return ThroughputSample(
                time: time,
                download: max(download, 100_000),
                upload: max(upload, 100_000)
            )
        }
    }
}

#Preview("5 Minutes") {
    ThroughputStatisticsView(samples: ThroughputSample.previewData())
        .padding(24)
        .frame(width: 700, height: 560)
}

#Preview("12 Hours") {
    ThroughputStatisticsView(samples: ThroughputSample.previewData(), range: .twelveHours)
        .padding(24)
        .frame(width: 700, height: 560)
}
