import SwiftUI
import Charts
import UniformTypeIdentifiers
import Observation
import Accessibility

struct StatisticsView: View {
    @Environment(ToolStore.self) private var tools
    private var stats: TrafficStatistics { tools.statistics }
    private var bw: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false
    @State private var showResetConfirm = false
    @State private var selectedDate: Date? = nil
    @State private var selectedLiveTime: Date? = nil
    @State private var timeRange: TimeRange = .last30

    /// Parses DayTotal.dateKey ("yyyy-MM-dd"). Static so every row reuses one instance.
    private static let dayKeyParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let csvTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case last7 = "7D"
        case last14 = "14D"
        case last30 = "30D"
        case all = "All"
        var id: String { rawValue }
        
        var days: Int? {
            switch self {
            case .last7: return 7
            case .last14: return 14
            case .last30: return 30
            case .all: return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            statisticsMoodBar

            ScrollView {
                VStack(spacing: Metrics.spacingXL) {
                    summaryStats

                    realtimeSection

                    dailySection

                    if !stats.dailyTotals.isEmpty {
                        historyTable
                    }
                }
                .padding(Metrics.spacingXL)
            }
        }
        .alert("Reset Statistics", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { stats.reset() }
        } message: {
            Text("This will clear all stored daily traffic totals. This cannot be undone.")
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Traffic Statistics") }
    }

    // MARK: - Components

    private var statisticsMoodBar: some View {
        let totalToday = stats.todayRx + stats.todayTx
        let days = stats.dailyTotals.count
        let (icon, color, msg): (String, Color, String) = {
            if days == 0 { return ("chart.line.uptrend.xyaxis", .secondary, "No historical data yet — collecting...") }
            let todayStr = NetworkMath.formatBytes(totalToday)
            return ("chart.line.uptrend.xyaxis", .accentColor, Self.moodBarMessage(todayBytes: todayStr, days: days))
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Traffic Statistics")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Traffic Statistics Tool")
                
                Spacer()

                HStack(spacing: Metrics.spacingLG) {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Data", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(stats.dailyTotals.isEmpty)
                    .accessibilityLabel("Reset traffic statistics data")
                    
                    Divider().frame(height: Metrics.spacingLG)

                    ReportMenuButton(
                        onExportPDF: { Exporter.saveStatisticsPDF(stats: stats) },
                        onExportCSV: { exportCSV() }
                    )
                    
                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, Metrics.spacingXL)
            .padding(.vertical, Metrics.spacingLG)

            Divider()
        }
    }

    private var summaryStats: some View {
        HStack(spacing: Metrics.spacingMD) {
            StatCard(title: "Today Download", value: NetworkMath.formatBytes(stats.todayRx), icon: "arrow.down.circle.fill", color: .blue)
            StatCard(title: "Today Upload", value: NetworkMath.formatBytes(stats.todayTx), icon: "arrow.up.circle.fill", color: .orange)
            StatCard(title: "Total Download", value: NetworkMath.formatBytes(stats.totalRx), icon: "icloud.and.arrow.down")
            StatCard(title: "Total Upload", value: NetworkMath.formatBytes(stats.totalTx), icon: "icloud.and.arrow.up")
        }
    }

    private var liveSelectedSample: BandwidthSample? {
        guard let selectedLiveTime else { return nil }
        return bw.totalHistory.min(by: {
            abs($0.timestamp.timeIntervalSince(selectedLiveTime)) < abs($1.timestamp.timeIntervalSince(selectedLiveTime))
        })
    }

    private var liveDomainTop: Double {
        ThroughputStatisticsViewModel.axisTop(
            for: bw.totalHistory.map { max($0.rxBps, $0.txBps) }.max() ?? 0)
    }

    private var realtimeSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            HStack {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Live Throughput")
                        .font(.headline)
                    Text("Last 10 minutes of aggregate traffic")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let s = bw.totalHistory.last {
                    Text("Current: ↓ \(NetworkMath.formatRate(s.rxBps)) · ↑ \(NetworkMath.formatRate(s.txBps))")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                Chart {
                    ForEach(bw.totalHistory) { s in
                        AreaMark(x: .value("Time", s.timestamp), y: .value("Rate", s.rxBps))
                            .foregroundStyle(by: .value("Direction", "Download"))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Rate", s.rxBps))
                            .foregroundStyle(by: .value("Direction", "Download"))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))

                        AreaMark(x: .value("Time", s.timestamp), y: .value("Rate", s.txBps))
                            .foregroundStyle(by: .value("Direction", "Upload"))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Rate", s.txBps))
                            .foregroundStyle(by: .value("Direction", "Upload"))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                    if let selected = liveSelectedSample {
                        RuleMark(x: .value("Cursor", selected.timestamp))
                            .foregroundStyle(Color.secondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(
                                position: .top,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                valueTooltip(
                                    title: selected.timestamp.formatted(.dateTime.hour().minute()),
                                    rx: NetworkMath.formatRate(selected.rxBps),
                                    tx: NetworkMath.formatRate(selected.txBps))
                            }
                    }
                }
                .chartForegroundStyleScale(ThroughputStyle.scale)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, liveDomainTop / 2, liveDomainTop]) { value in
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
                .chartYScale(domain: 0...liveDomainTop)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    selectLive(at: location, proxy: proxy, geo: geo)
                                case .ended:
                                    selectedLiveTime = nil
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        selectLive(at: value.location, proxy: proxy, geo: geo)
                                    }
                                    .onEnded { _ in selectedLiveTime = nil }
                            )
                    }
                }
                .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
                .drawingGroup()
                .frame(height: 160)
                .accessibilityChartDescriptor(LiveThroughputDescriptor(
                    samples: Array(bw.totalHistory),
                    yTop: liveDomainTop,
                    summary: liveDescriptorSummary
                ))
                .accessibilityLabel("Line chart of live throughput over the last 10 minutes")
            }
            .padding(Metrics.spacingXL)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func selectLive(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
        guard let date: Date = proxy.value(atX: location.x - plotOriginX) else { return }
        selectedLiveTime = bw.totalHistory.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })?.timestamp
    }

    private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
        guard let date: Date = proxy.value(atX: location.x - plotOriginX) else { return }
        selectedDate = datedTotals.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })?.date
    }

    private var liveDescriptorSummary: String {
        let peak = bw.totalHistory.map { max($0.rxBps, $0.txBps) }.max() ?? 0
        return Self.liveSummary(peak: NetworkMath.formatRate(peak),
                                top: NetworkMath.formatRate(liveDomainTop),
                                sampleCount: bw.totalHistory.count)
    }

    private func valueTooltip(title: String, rx: String, tx: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            HStack(spacing: Metrics.spacingSM) {
                HStack(spacing: Metrics.spacingXS) {
                    Text("↓").font(.caption.bold()).foregroundColor(.blue)
                    Text(rx)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.blue)
                }
                HStack(spacing: Metrics.spacingXS) {
                    Text("↑").font(.caption.bold()).foregroundColor(.orange)
                    Text(tx)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(Metrics.spacingSM)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            HStack {
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Daily Totals")
                        .font(.headline)
                    Text("Cumulative traffic per calendar day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: Metrics.spacingMD) {
                    Picker("", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    
                    if !stats.dailyTotals.isEmpty {
                        Text("Avg: ↓ \(NetworkMath.formatBytes(stats.averageDailyRx)) · ↑ \(NetworkMath.formatBytes(stats.averageDailyTx))")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }

            let dated = datedTotals
            if dated.isEmpty {
                emptyState
            } else {
                let peak = dated.map { Double($0.day.rxBytes + $0.day.txBytes) }.max() ?? 0
                let top = ThroughputStatisticsViewModel.axisTop(for: peak)
                VStack(spacing: 0) {
                    Chart {
                        ForEach(dated, id: \.day.id) { item in
                            BarMark(
                                x: .value("Day", item.date),
                                y: .value("Bytes", Double(item.day.rxBytes)),
                                stacking: .standard
                            )
                            .foregroundStyle(by: .value("Direction", "Download"))

                            BarMark(
                                x: .value("Day", item.date),
                                y: .value("Bytes", Double(item.day.txBytes)),
                                stacking: .standard
                            )
                            .foregroundStyle(by: .value("Direction", "Upload"))

                            if let selected = selectedDate,
                               Calendar.current.isDate(selected, inSameDayAs: item.date) {
                                RuleMark(x: .value("Selected", item.date))
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                        valueTooltip(
                                            title: item.date.formatted(.dateTime.month(.wide).day()),
                                            rx: NetworkMath.formatBytes(item.day.rxBytes),
                                            tx: NetworkMath.formatBytes(item.day.txBytes))
                                    }
                            }
                        }
                    }
                    .chartForegroundStyleScale(["Download": .blue, "Upload": .orange])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: max(1, dated.count / 6))) {
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: [0, top / 2, top]) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(verbatim: NetworkMath.formatBytes(UInt64(v)))
                                        .font(.caption2.monospaced())
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...top)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        selectDay(at: location, proxy: proxy, geo: geo)
                                    case .ended:
                                        selectedDate = nil
                                    }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            selectDay(at: value.location, proxy: proxy, geo: geo)
                                        }
                                        .onEnded { _ in selectedDate = nil }
                                )
                        }
                    }
                    .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
                    .drawingGroup()
                    .frame(height: 180)
                    .accessibilityChartDescriptor(DailyTotalsDescriptor(
                        days: dated.map { ($0.date, $0.day.rxBytes, $0.day.txBytes) },
                        yTop: top,
                        summary: Self.dailySummary(top: NetworkMath.formatBytes(UInt64(top)), dayCount: dated.count)
                    ))
                    .accessibilityLabel("Stacked bar chart of traffic per day for download and upload")
                }
                .padding(Metrics.spacingXL)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            }
        }
    }

    private var filteredDailyTotals: [TrafficStatistics.DayTotal] {
        if let limit = timeRange.days {
            return Array(stats.dailyTotals.suffix(limit))
        }
        return stats.dailyTotals
    }

    private var historyTable: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            Text("Detailed History")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TableHeader("Date", width: 120)
                    TableHeader("Download", width: 140)
                    TableHeader("Upload", width: 140)
                    TableHeader("Total Activity", flexible: true)
                }
                .padding(.horizontal, Metrics.spacingLG)
                .padding(.vertical, Metrics.spacingSM)
                .background(.regularMaterial)

                Divider()

                let filtered = filteredDailyTotals
                ForEach(filtered.reversed()) { day in
                    HStack(spacing: 0) {
                        Text(day.dateKey)
                            .font(.callout.monospaced())
                            .frame(width: 120, alignment: .leading)

                        Text(NetworkMath.formatBytes(day.rxBytes))
                            .font(.callout.monospaced().weight(.medium))
                            .foregroundColor(.blue)
                            .frame(width: 140, alignment: .leading)

                        Text(NetworkMath.formatBytes(day.txBytes))
                            .font(.callout.monospaced().weight(.medium))
                            .foregroundColor(.orange)
                            .frame(width: 140, alignment: .leading)

                        ActivityBar(rx: day.rxBytes, tx: day.txBytes)

                        Spacer()
                    }
                    .padding(.horizontal, Metrics.spacingLG)
                    .padding(.vertical, Metrics.spacingSM)

                    if day.id != stats.dailyTotals.first?.id {
                        Divider().padding(.horizontal, Metrics.spacingLG).opacity(0.5)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var emptyState: some View {
        ToolStateView.empty(
            title: "No Historical Data",
            subtitle: "Statistics are collected automatically while the app is running.",
            minHeight: 180)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
    }

    // MARK: - Helpers

    /// Pure builders for spoken/displayed summary strings — testable
    /// without rendering the view. Inputs are pre-formatted values.
    static func moodBarMessage(todayBytes: String, days: Int) -> String {
        "Today: \(todayBytes) total — \(days) day\(days == 1 ? "" : "s") of history"
    }

    static func liveSummary(peak: String, top: String, sampleCount: Int) -> String {
        "Line chart. Time on the X axis, throughput on the Y axis from 0 to \(top). Peak \(peak) over \(sampleCount) samples."
    }

    static func dailySummary(top: String, dayCount: Int) -> String {
        "Stacked bar chart. Date on the X axis, bytes on the Y axis from 0 to \(top). \(dayCount) days."
    }

    /// Days with parsed dates, so the X axis uses real positions and
    /// missing days render as gaps instead of collapsing together.
    private var datedTotals: [(date: Date, day: TrafficStatistics.DayTotal)] {
        filteredDailyTotals.compactMap { day in
            Self.dayKeyParser.date(from: day.dateKey).map { ($0, day) }
        }
    }

    private func exportCSV() {
        let header = "date,download_bytes,upload_bytes"
        let rows = stats.dailyTotals.map { "\($0.dateKey),\($0.rxBytes),\($0.txBytes)" }
        Exporter.save(string: ([header] + rows).joined(separator: "\n"),
                      defaultName: "NetUtil-Statistics-\(Self.csvTimestamp.string(from: Date())).csv",
                      ext: "csv")
    }
}

/// VoiceOver descriptor for the live throughput line chart. Points are
/// downsampled and each carries a spoken label — never colors, never
/// subjective words, time (X) always first.
private struct LiveThroughputDescriptor: AXChartDescriptorRepresentable {
    let samples: [BandwidthSample]
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
            title: "Live throughput",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Time",
                categoryOrder: points.map { timeFormatter.string(from: $0.timestamp) }
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
                            x: timeFormatter.string(from: $0.timestamp),
                            y: $0.rxBps,
                            label: "Download at \(timeFormatter.string(from: $0.timestamp)), \(NetworkMath.spokenRate($0.rxBps))")
                    }
                ),
                AXDataSeriesDescriptor(
                    name: "Upload",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(
                            x: timeFormatter.string(from: $0.timestamp),
                            y: $0.txBps,
                            label: "Upload at \(timeFormatter.string(from: $0.timestamp)), \(NetworkMath.spokenRate($0.txBps))")
                    }
                )
            ]
        )
    }
}

/// VoiceOver descriptor for the daily stacked bar chart. Dates read as
/// "June 6" with spoken byte units.
private struct DailyTotalsDescriptor: AXChartDescriptorRepresentable {
    let days: [(date: Date, rx: UInt64, tx: UInt64)]
    let yTop: Double
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter
        }()
        return AXChartDescriptor(
            title: "Daily totals",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Date",
                categoryOrder: days.map { dayFormatter.string(from: $0.date) }
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: "Bytes",
                range: 0...yTop,
                gridlinePositions: [0, yTop / 2, yTop],
                valueDescriptionProvider: { NetworkMath.spokenBytes(UInt64($0)) }
            ),
            series: [
                AXDataSeriesDescriptor(
                    name: "Download",
                    isContinuous: false,
                    dataPoints: days.map {
                        AXDataPoint(
                            x: dayFormatter.string(from: $0.date),
                            y: Double($0.rx),
                            label: "\(dayFormatter.string(from: $0.date)), download \(NetworkMath.spokenBytes($0.rx))")
                    }
                ),
                AXDataSeriesDescriptor(
                    name: "Upload",
                    isContinuous: false,
                    dataPoints: days.map {
                        AXDataPoint(
                            x: dayFormatter.string(from: $0.date),
                            y: Double($0.tx),
                            label: "\(dayFormatter.string(from: $0.date)), upload \(NetworkMath.spokenBytes($0.tx))")
                    }
                )
            ]
        )
    }
}

/// Proportional download/upload bar for one table row. The GeometryReader
/// stays isolated here — a flex ratio needs the measured width.
private struct ActivityBar: View {
    let rx: UInt64
    let tx: UInt64

    var body: some View {
        let total = Double(rx + tx)
        let rxWidth = total > 0 ? Double(rx) / total : 0
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Color.blue).frame(width: geo.size.width * rxWidth)
                Rectangle().fill(Color.orange)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(height: 4)
        .frame(maxWidth: 200)
        .accessibilityHidden(true)
    }
}
