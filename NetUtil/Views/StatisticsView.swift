import SwiftUI
import Charts
import UniformTypeIdentifiers

struct StatisticsView: View {
    @EnvironmentObject private var tools: ToolStore
    private var stats: TrafficStatistics { tools.statistics }
    private var bw: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false
    @State private var showResetConfirm = false
    @State private var selectedPoint: Date? = nil
    @State private var selectedDayKey: String? = nil
    @State private var timeRange: TimeRange = .last30
    
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
            
            ScrollView {
                VStack(spacing: 24) {
                    summaryStats
                    
                    realtimeSection
                    
                    dailySection
                    
                    if !stats.dailyTotals.isEmpty {
                        historyTable
                    }
                }
                .padding(24)
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

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Traffic Statistics")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Data", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(stats.dailyTotals.isEmpty)
                    
                    Divider().frame(height: 16)
                    
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(stats.dailyTotals.isEmpty)
                    
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

    private var summaryStats: some View {
        HStack(spacing: 12) {
            StatCard(title: "Today Download", value: NetworkMath.formatBytes(stats.todayRx), icon: "arrow.down.circle.fill", color: .blue)
            StatCard(title: "Today Upload", value: NetworkMath.formatBytes(stats.todayTx), icon: "arrow.up.circle.fill", color: .orange)
            StatCard(title: "Total Download", value: NetworkMath.formatBytes(stats.totalRx), icon: "icloud.and.arrow.down")
            StatCard(title: "Total Upload", value: NetworkMath.formatBytes(stats.totalTx), icon: "icloud.and.arrow.up")
        }
    }

    private var realtimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Throughput")
                        .font(.headline)
                    Text("Last 10 minutes of aggregate traffic")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let s = bw.totalHistory.last {
                    Text("Current: ↓ \(NetworkMath.formatRate(s.rxBps)) · ↑ \(NetworkMath.formatRate(s.txBps))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                Chart {
                    ForEach(bw.totalHistory) { s in
                        AreaMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                        AreaMark(x: .value("Time", s.timestamp), y: .value("Upload", s.txBps))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .orange.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Upload", s.txBps))
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(NetworkMath.formatRate(v))
                                    .font(.system(size: 10, design: .monospaced))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Totals")
                        .font(.headline)
                    Text("Cumulative traffic per calendar day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Picker("", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    
                    if !stats.dailyTotals.isEmpty {
                        Text("Avg: ↓ \(NetworkMath.formatBytes(stats.averageDailyRx)) · ↑ \(NetworkMath.formatBytes(stats.averageDailyTx))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            let recent = filteredDailyTotals
            if recent.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    Chart {
                        ForEach(recent) { day in
                            BarMark(x: .value("Day", day.dateKey), y: .value("Bytes", Double(day.rxBytes)))
                                .foregroundStyle(by: .value("Direction", "Download"))
                                .position(by: .value("Direction", "Download"))
                            
                            BarMark(x: .value("Day", day.dateKey), y: .value("Bytes", Double(day.txBytes)))
                                .foregroundStyle(by: .value("Direction", "Upload"))
                                .position(by: .value("Direction", "Upload"))
                            
                            if let selectedDayKey, selectedDayKey == day.dateKey {
                                RuleMark(x: .value("Selected", day.dateKey))
                                    .foregroundStyle(.clear)
                                    .offset(y: 0)
                                    .annotation(position: .top, alignment: .center) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(day.dateKey).font(.caption2.bold())
                                            Text("↓ \(NetworkMath.formatBytes(day.rxBytes))").foregroundColor(.blue)
                                            Text("↑ \(NetworkMath.formatBytes(day.txBytes))").foregroundColor(.orange)
                                        }
                                        .padding(8)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                                    }
                            }
                        }
                    }
                    .chartForegroundStyleScale(["Download": .blue, "Upload": .orange])
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 8)) { val in
                            AxisValueLabel {
                                if let s = val.as(String.self) {
                                    Text(shortDate(s))
                                        .font(.system(size: 10))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(NetworkMath.formatBytes(UInt64(v)))
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        selectedDayKey = proxy.value(atX: location.x)
                                    case .ended:
                                        selectedDayKey = nil
                                    }
                                }
                        }
                    }
                    .frame(height: 180)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed History")
                .font(.headline)
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tableHeader("Date", width: 120)
                    tableHeader("Download", width: 140)
                    tableHeader("Upload", width: 140)
                    tableHeader("Total Activity", width: nil)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                
                Divider()
                
                let filtered = filteredDailyTotals
                ForEach(filtered.reversed()) { day in
                    HStack(spacing: 0) {
                        Text(day.dateKey)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 120, alignment: .leading)
                        
                        Text(NetworkMath.formatBytes(day.rxBytes))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                            .frame(width: 140, alignment: .leading)
                        
                        Text(NetworkMath.formatBytes(day.txBytes))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 140, alignment: .leading)
                        
                        activityBar(rx: day.rxBytes, tx: day.txBytes)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    if day.id != stats.dailyTotals.first?.id {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func tableHeader(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func activityBar(rx: UInt64, tx: UInt64) -> some View {
        let total = Double(rx + tx)
        let rxWidth = total > 0 ? Double(rx) / total : 0
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Color.blue).frame(width: geo.size.width * rxWidth)
                Rectangle().fill(Color.orange)
            }
            .cornerRadius(2)
        }
        .frame(height: 4)
        .frame(maxWidth: 200)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No Historical Data")
                .font(.headline)
            Text("Statistics are collected automatically while the app is running.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func shortDate(_ key: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: key) else { return key }
        let out = DateFormatter(); out.dateFormat = "MMM d"
        return out.string(from: d)
    }

    private func exportCSV() {
        let header = "Date,Download_Bytes,Upload_Bytes\n"
        let rows = stats.dailyTotals.map { "\($0.dateKey),\($0.rxBytes),\($0.txBytes)" }.joined(separator: "\n")
        let csv = header + rows
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "NetUtil_Traffic_Stats_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
