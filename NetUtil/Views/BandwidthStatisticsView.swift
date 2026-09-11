import SwiftUI
import Charts
import Accessibility

// MARK: - Model

/// One throughput sample. Values are in bits per second.
struct ThroughputSample: Identifiable, Sendable {
    let id = UUID()
    let time: Date
    let download: Double
    let upload: Double
}

/// Selectable time window for the chart.
enum ThroughputRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case fiveMinutes = "5 min"
    case oneHour = "1 hour"
    case twelveHours = "12 hours"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .oneHour: return 60 * 60
        case .twelveHours: return 12 * 60 * 60
        }
    }

    /// X-axis tick density per range — keeps labels from crowding.
    var stride: (component: Calendar.Component, count: Int) {
        switch self {
        case .fiveMinutes: return (.minute, 1)
        case .oneHour: return (.minute, 15)
        case .twelveHours: return (.hour, 2)
        }
    }
}

/// Data source contract — the view only ever sees filtered arrays.
protocol ThroughputDataProvider: Sendable {
    func samples(for range: ThroughputRange) async -> [ThroughputSample]
}

/// In-memory provider that filters a fixed sample set by recency.
struct StaticThroughputProvider: ThroughputDataProvider {
    let samples: [ThroughputSample]

    func samples(for range: ThroughputRange) async -> [ThroughputSample] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return samples.filter { $0.time >= cutoff }
    }
}

/// Bit-rate formatting (bits, not bytes — ByteCountFormatter doesn't fit).
enum BitRateFormat {
    static func string(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f Mbps", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f Kbps", bps / 1_000) }
        if bps > 0 { return String(format: "%.0f bps", bps) }
        return "0 bps"
    }

    /// Adaptive unit picked from the data maximum.
    static func unit(for maxBps: Double) -> (divisor: Double, suffix: String) {
        if maxBps >= 1_000_000 { return (1_000_000, "Mbps") }
        if maxBps >= 1_000 { return (1_000, "Kbps") }
        return (1, "bps")
    }

    /// Round integer label in the adaptive unit, e.g. "20 Mbps".
    static func axisString(_ bps: Double, divisor: Double, suffix: String) -> String {
        String(format: "%.0f %@", bps / divisor, suffix)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class BandwidthStatisticsViewModel {
    var range: ThroughputRange = .fiveMinutes
    private(set) var samples: [ThroughputSample] = []

    private let provider: any ThroughputDataProvider

    init(provider: any ThroughputDataProvider) {
        self.provider = provider
    }

    func reload() async {
        samples = await provider.samples(for: range)
    }
}

// MARK: - View

/// Grafana-style analytical throughput monitor — separate from the
/// glanceable dashboard hero. Line chart + hover inspection + summary table.
struct BandwidthStatisticsView: View {
    @Bindable var viewModel: BandwidthStatisticsViewModel
    @State private var selectedTime: Date? = nil

    init(viewModel: BandwidthStatisticsViewModel) {
        self.viewModel = viewModel
    }

    /// Convenience init straight from an array (e.g. previews, tests).
    init(samples: [ThroughputSample]) {
        self.viewModel = BandwidthStatisticsViewModel(
            provider: StaticThroughputProvider(samples: samples))
    }

    private var selectedSample: ThroughputSample? {
        guard let selectedTime else { return nil }
        return viewModel.samples.min(by: {
            abs($0.time.timeIntervalSince(selectedTime)) < abs($1.time.timeIntervalSince(selectedTime))
        })
    }

    /// Nice-round Y domain locked so live updates never rescale the chart.
    private var yTop: Double {
        let peak = viewModel.samples.map { max($0.download, $0.upload) }.max() ?? 0
        return peak <= 0 ? 1000 : Metrics.niceCeiling(peak * 1.1)
    }

    private var yUnit: (divisor: Double, suffix: String) {
        BitRateFormat.unit(for: yTop)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.samples.isEmpty {
                Text("No data in this range.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chart
                Divider().opacity(0.5)
                summaryTable
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .task(id: viewModel.range) {
            await viewModel.reload()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bandwidth Statistics")
                    .font(.headline)
                Text("Throughput over time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    }

    private var chart: some View {
        Chart {
            ForEach(viewModel.samples) { s in
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
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartXSelection(value: $selectedTime)
        .chartYAxis {
            AxisMarks(values: [0, yTop / 2, yTop]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text(verbatim: BitRateFormat.axisString(value.as(Double.self) ?? 0, divisor: yUnit.divisor, suffix: yUnit.suffix))
                        .font(.caption2.monospaced())
                }
            }
        }
        .chartYScale(domain: 0...yTop)
        .frame(height: 220)
        .accessibilityChartDescriptor(ThroughputChartDescriptor(
            samples: viewModel.samples,
            yTop: yTop,
            summary: summaryDescription
        ))
        .accessibilityLabel("Throughput over time for download and upload")
    }

    private func tooltip(sample: ThroughputSample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sample.time, format: .dateTime.hour().minute())
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("↓").font(.caption.bold()).foregroundColor(.blue)
                    Text(BitRateFormat.string(sample.download))
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.blue)
                }
                HStack(spacing: 4) {
                    Text("↑").font(.caption.bold()).foregroundColor(.orange)
                    Text(BitRateFormat.string(sample.upload))
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

            SummaryRow(color: .blue, name: "Download", stats: stats(for: \.download))
            Divider().opacity(0.5).padding(.leading, 20)
            SummaryRow(color: .orange, name: "Upload", stats: stats(for: \.upload))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Summary. \(summaryDescription)")
    }

    private func stats(for keyPath: KeyPath<ThroughputSample, Double>) -> (mean: String, max: String, last: String) {
        let samples = viewModel.samples
        guard !samples.isEmpty else { return ("—", "—", "—") }
        let values = samples.map { $0[keyPath: keyPath] }
        let mean = values.reduce(0, +) / Double(values.count)
        return (
            BitRateFormat.string(mean),
            BitRateFormat.string(values.max() ?? 0),
            BitRateFormat.string(values.last ?? 0)
        )
    }

    private var summaryDescription: String {
        let down = stats(for: \.download)
        let up = stats(for: \.upload)
        return "Download mean \(down.mean), max \(down.max), last \(down.last). Upload mean \(up.mean), max \(up.max), last \(up.last)."
    }

}

/// VoiceOver descriptor. Points are downsampled — a screen reader needs
/// the shape of the data, not all 700+ samples.
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
        let labels = points.map { timeFormatter.string(from: $0.time) }
        return AXChartDescriptor(
            title: "Bandwidth statistics",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Time",
                categoryOrder: labels
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: "Throughput",
                range: 0...yTop,
                gridlinePositions: [0, yTop / 2, yTop],
                valueDescriptionProvider: { BitRateFormat.string($0) }
            ),
            series: [
                AXDataSeriesDescriptor(
                    name: "Download",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(x: timeFormatter.string(from: $0.time), y: $0.download)
                    }
                ),
                AXDataSeriesDescriptor(
                    name: "Upload",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(x: timeFormatter.string(from: $0.time), y: $0.upload)
                    }
                )
            ]
        )
    }
}

/// One summary-table row: color dot + series name, then Mean / Max / Last.
private struct SummaryRow: View {
    let color: Color
    let name: String
    let stats: (mean: String, max: String, last: String)

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
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

// MARK: - Preview Data

extension ThroughputSample {
    /// 12 hours of deterministic, realistic samples: quiet download base
    /// with a few ~30–34 Mbps spikes, upload always under ~2 Mbps.
    static func previewData(now: Date = Date()) -> [ThroughputSample] {
        let step: TimeInterval = 60
        let count = 12 * 60
        let spikeIndices: Set<Int> = [120, 300, 520, 660]
        return (0..<count).map { i in
            let time = now.addingTimeInterval(-Double(count - 1 - i) * step)
            let f = Double(i)
            var download = 800_000
                + 900_000 * (0.5 + 0.5 * sin(f * 0.05))
                + 400_000 * (0.5 + 0.5 * sin(f * 0.13 + 2))
            if spikeIndices.contains(i) {
                download = 30_000_000 + Double((i * 13) % 5) * 1_000_000
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

#Preview {
    BandwidthStatisticsView(samples: ThroughputSample.previewData())
        .padding(24)
        .frame(width: 640, height: 480)
}
