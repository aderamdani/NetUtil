import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var tools: ToolStore
    private var stats: TrafficStatistics { tools.statistics }
    private var bw: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    statsBar
                    realtimeSection
                    dailySection
                }
            }
        }
        .padding(32)
        .alert("Reset Statistics", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { stats.reset() }
        } message: {
            Text("This will clear all stored daily traffic totals. This cannot be undone.")
        }
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.accentColor)
                Text("Traffic Statistics").font(.headline)
            }.frame(width: 250, alignment: .leading)

            Spacer()

            Button(role: .destructive) { showResetConfirm = true } label: {
                HStack(spacing: 6) { Image(systemName: "trash"); Text("Reset") }
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .disabled(stats.dailyTotals.isEmpty)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.borderless)
        }
    }

    private var statsBar: some View {
        let todayKey = todayKey()
        let today = stats.dailyTotals.first { $0.dateKey == todayKey }
        let totalRx = stats.dailyTotals.map(\.rxBytes).reduce(0, &+)
        let totalTx = stats.dailyTotals.map(\.txBytes).reduce(0, &+)
        return HStack(spacing: 12) {
            StatCard(title: "Today Down",  value: formatBytes(today?.rxBytes ?? 0), icon: "arrow.down", color: .blue)
            StatCard(title: "Today Up",    value: formatBytes(today?.txBytes ?? 0), icon: "arrow.up",   color: .orange)
            StatCard(title: "Total Down",  value: formatBytes(totalRx), icon: "icloud.and.arrow.down")
            StatCard(title: "Total Up",    value: formatBytes(totalTx), icon: "icloud.and.arrow.up")
            Spacer()
        }
    }

    private var realtimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-Time (last 10 minutes)").font(.headline)
            if bw.totalHistory.count > 1 {
                Chart {
                    ForEach(bw.totalHistory) { s in
                        AreaMark(x: .value("t", s.timestamp), y: .value("Down", s.rxBps))
                            .foregroundStyle(.blue.opacity(0.15)).interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("Down", s.rxBps))
                            .foregroundStyle(.blue).interpolationMethod(.catmullRom)

                        AreaMark(x: .value("t", s.timestamp), y: .value("Up", s.txBps))
                            .foregroundStyle(.orange.opacity(0.15)).interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("Up", s.txBps))
                            .foregroundStyle(.orange).interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(formatRate(v)).font(.system(size: 10, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 180)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 16) {
                    legendDot(.blue, "Download")
                    legendDot(.orange, "Upload")
                    Spacer()
                    Text("Now: ↓ \(formatRate(bw.totalRxBps))  ↑ \(formatRate(bw.totalTxBps))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Collecting samples...").font(.subheadline).foregroundColor(.secondary)
            }
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Totals (last 30 days)").font(.headline)
            let recent = Array(stats.dailyTotals.suffix(30))
            if recent.isEmpty {
                Text("No data yet. Statistics accumulate as you use the network.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Chart {
                    ForEach(recent) { day in
                        BarMark(x: .value("Day", day.dateKey), y: .value("Down", Double(day.rxBytes)))
                            .foregroundStyle(.blue)
                            .position(by: .value("Direction", "Down"))
                        BarMark(x: .value("Day", day.dateKey), y: .value("Up", Double(day.txBytes)))
                            .foregroundStyle(.orange)
                            .position(by: .value("Direction", "Up"))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { val in
                        AxisValueLabel { if let s = val.as(String.self) { Text(shortDate(s)).font(.system(size: 9)) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(formatBytes(UInt64(v))).font(.system(size: 9, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }

    private func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func shortDate(_ key: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: key) else { return key }
        let out = DateFormatter(); out.dateFormat = "M/d"
        return out.string(from: d)
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f K/s", bps / 1024) }
        return String(format: "%.2f M/s", bps / 1_048_576)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Statistics Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                GuideSection(title: "How it works", icon: "chart.line.uptrend.xyaxis") {
                    Text("Aggregate bandwidth across all non-loopback interfaces is sampled every second. Daily totals are persisted in UserDefaults so they survive restarts.")
                }
                GuideSection(title: "Real-time vs Daily", icon: "calendar") {
                    Text("Real-Time shows the last 10 minutes of throughput. Daily Totals shows cumulative download and upload per calendar day for the last 30 days.")
                }
            }.padding(24) }
        }.frame(width: 500, height: 500)
    }
}
