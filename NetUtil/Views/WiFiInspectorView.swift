import SwiftUI
import CoreWLAN
import Charts
import Accessibility
import Observation

struct WiFiInspectorView: View {
    var vm: WiFiInspectorViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar

            ScrollView {
                VStack(spacing: Metrics.spacingXL) {
                    if let info = vm.info {
                        interpretationSection(info)
                        recommendationSection(info)
                        
                        statsBarSection(info)
                        
                        if vm.rssiSamples.count > 1 {
                            signalStabilitySection
                        }
                        
                        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
                            SectionHeader(title: "Infrastructure Details", icon: "antenna.radiowaves.left.and.right")
                            detailGrid(info)
                        }
                    } else {
                        noWiFiState
                    }
                }
                .padding(24)
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Wi-Fi Inspector") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    Image(systemName: "wifi")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Wi-Fi")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Wi-Fi Inspector Tool")
                
                Spacer()
                
                HStack(spacing: Metrics.spacingLG) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Interface").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                        Text(vm.info?.interfaceName ?? "en0")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Network Interface: \(vm.info?.interfaceName ?? "en0")")
                    
                    Divider().frame(height: 16)
                    
                    if let info = vm.info {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveWiFiPDF(info: info) },
                            onExportCSV: {
                                let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: Exporter.csvString(from: info),
                                              defaultName: "NetUtil-WiFi-\(ts.string(from: Date())).csv",
                                              ext: "csv")
                            }
                        )
                    }

                    Button { vm.refresh() } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Rescan Wi-Fi Network")

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, Metrics.spacingLG)
            
            Divider()
        }
    }
    
    private var moodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            guard let info = vm.info else {
                return ("wifi.slash", .secondary, "No Wi-Fi connection detected")
            }
            let rssi = info.rssi ?? 0
            if rssi >= -60 { return ("wifi", .green, "\(info.ssid ?? "Connected") — excellent signal (\(rssi) dBm)") }
            if rssi >= -75 { return ("wifi", .orange, "\(info.ssid ?? "Connected") — acceptable signal (\(rssi) dBm)") }
            return ("wifi.exclamationmark", .red, "\(info.ssid ?? "Connected") — weak signal (\(rssi) dBm)")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private func interpretationSection(_ info: WiFiInfo) -> some View {
        HStack(alignment: .center, spacing: Metrics.spacingLG) {
            let rssi = info.rssi ?? -100
            let (status, desc, icon, color): (String, String, String, Color) = {
                if rssi >= -60 { return ("Excellent Association", "High signal-to-noise ratio with minimal interference.", "wifi", .green) }
                if rssi >= -75 { return ("Good Connectivity", "Stable connection suitable for high-bandwidth tasks.", "wifi", .orange) }
                return ("Weak Signal", "Marginal connection; performance may be inconsistent.", "wifi.exclamationmark", .red)
            }()
            
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(status). \(desc)")
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Metrics.spacingXS) {
                Text("Last Polled").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard))
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last polled at \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
        }
    }

    private func recommendationSection(_ info: WiFiInfo) -> some View {
        let rssi = info.rssi ?? -100
        let (grade, advice): (String, String) = {
            if rssi >= -60 {
                return ("A", "Sinyal sangat kuat — cocok untuk streaming 4K, video call, atau gaming. Pertahankan jarak dekat dengan router.")
            } else if rssi >= -75 {
                return ("B", "Sinyal cukup baik untuk Zoom atau pekerjaan sehari-hari. Coba pindah ke channel yang lebih sepi jika sering putus.")
            } else {
                return ("C", "Sinyal lemah — pertimbangkan pindah lebih dekat ke router atau ganti ke band 5/6 GHz.")
            }
        }()
        
        return VStack(alignment: .leading, spacing: Metrics.spacingMD) {
            SectionHeader(title: "Penilaian & Saran", icon: "lightbulb")
            HStack(alignment: .top, spacing: Metrics.spacingMD) {
                ZStack {
                    Circle().fill(.green.opacity(0.1)).frame(width: 44, height: 44)
                    Text(grade)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text("Rating Sinyal Wi-Fi")
                        .font(.headline)
                    Text(advice)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    if let ch = info.channel {
                        Text("Saran channel: gunakan channel \(ch) saat ini — jika sering terganggu, coba pindah ke channel 1, 6, atau 11 (2.4 GHz) atau 36/40 (5 GHz).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusMD).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func statsBarSection(_ info: WiFiInfo) -> some View {
        HStack(spacing: Metrics.spacingMD) {
            if let rssi = info.rssi {
                StatCard(title: "Signal (RSSI)", value: "\(rssi)", unit: "dBm", icon: "waveform", color: signalColor(rssi))
            }
            if let noise = info.noise, let rssi = info.rssi {
                StatCard(title: "SNR Quality", value: "\(rssi - noise)", unit: "dB", icon: "shield.checkerboard", color: snrColor(rssi - noise))
            }
            StatCard(title: "Radio Band", value: info.band ?? "Unknown", icon: "antenna.radiowaves.left.and.right")
            StatCard(title: "Channel", value: info.channel.map { "\($0)" } ?? "—", icon: "number.square")
        }
    }

    private var signalStabilitySection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            SectionHeader(title: "Signal Stability (RSSI)", icon: "chart.line.uptrend.xyaxis")
            
            Chart {
                ForEach(vm.rssiSamples) { sample in
                    LineMark(x: .value("Sample", sample.timestamp), y: .value("RSSI", Double(sample.rssi)))
                        .foregroundStyle(signalColor(sample.rssi))
                        .interpolationMethod(.catmullRom)
                    
                    AreaMark(x: .value("Sample", sample.timestamp), y: .value("RSSI", Double(sample.rssi)))
                        .foregroundStyle(LinearGradient(colors: [signalColor(sample.rssi).opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v)) dBm")
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
            .drawingGroup()
            .frame(height: 120)
            .padding(Metrics.spacingXL)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .accessibilityLabel("Signal stability chart showing RSSI in dBm")
            .accessibilityChartDescriptor(RSSIStabilityDescriptor(
                samples: vm.rssiSamples.map { (timestamp: $0.timestamp, rssi: $0.rssi) },
                summary: Self.rssiChartSummary(
                    count: vm.rssiSamples.count,
                    minRssi: vm.rssiSamples.map { $0.rssi }.min() ?? 0,
                    maxRssi: vm.rssiSamples.map { $0.rssi }.max() ?? 0,
                    avgRssi: vm.rssiSamples.isEmpty ? 0 : vm.rssiSamples.map { $0.rssi }.reduce(0, +) / vm.rssiSamples.count)
            ))
        }
    }

    private func detailGrid(_ info: WiFiInfo) -> some View {
        let items: [(String, String?, String)] = [
            ("Security Mode",  info.security, "lock.shield"),
            ("Transmit Rate",  info.transmitRate.map { String(format: "%.1f Mbps", $0) }, "bolt.horizontal"),
            ("Country Code",   info.countryCode, "globe"),
            ("BSSID (Base)",   info.bssid, "macwindow"),
            ("MAC Address",    info.hardwareAddress, "barcode"),
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Metrics.spacingMD) {
            ForEach(items, id: \.0) { label, value, icon in
                if let value {
                    DetailCard(label: label, value: value, icon: icon)
                }
            }
        }
    }

    private var noWiFiState: some View {
        VStack(spacing: Metrics.spacingMD) {
            Text("No Wi-Fi Connection")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Ensure Wi-Fi is enabled and connected to an access point.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func signalColor(_ rssi: Int?) -> Color {
        guard let r = rssi else { return .secondary }
        if r >= -60 { return .green }
        if r >= -75 { return .orange }
        return .red
    }

    private func snrColor(_ snr: Int) -> Color {
        if snr >= 25 { return .green }
        if snr >= 15 { return .orange }
        return .red
    }

    /// Pure spoken-summary builder for the RSSI chart — testable without
    /// rendering. Time (X) first, describes data not colors.
    nonisolated static func rssiChartSummary(count: Int, minRssi: Int, maxRssi: Int, avgRssi: Int) -> String {
        guard count > 0 else { return "Line chart. No signal samples yet." }
        return "Line chart. Time on the X axis, signal strength in dBm on the Y axis. \(count) samples, ranging from \(minRssi) to \(maxRssi) dBm, average \(avgRssi) dBm."
    }
}

/// VoiceOver descriptor for the Wi-Fi signal-stability chart. Points are
/// downsampled and each carries a spoken label — never colors, time (X)
/// always first.
private struct RSSIStabilityDescriptor: AXChartDescriptorRepresentable {
    let samples: [(timestamp: Date, rssi: Int)]
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
        let stride = max(1, samples.count / 60)
        let points = samples.enumerated().compactMap { index, sample in
            index % stride == 0 ? sample : nil
        }
        let values = points.map { Double($0.rssi) }
        let lower = values.min() ?? -100
        let upper = values.max() ?? -30
        let yRange = lower == upper ? (lower - 1)...(upper + 1) : lower...upper
        return AXChartDescriptor(
            title: "Signal stability",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: "Time",
                categoryOrder: points.map { timeFormatter.string(from: $0.timestamp) }
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: "Signal strength",
                range: yRange,
                gridlinePositions: [yRange.lowerBound, (yRange.lowerBound + yRange.upperBound) / 2, yRange.upperBound],
                valueDescriptionProvider: { "\(Int($0)) dBm" }
            ),
            series: [
                AXDataSeriesDescriptor(
                    name: "RSSI",
                    isContinuous: true,
                    dataPoints: points.map {
                        AXDataPoint(
                            x: timeFormatter.string(from: $0.timestamp),
                            y: Double($0.rssi),
                            label: "\(timeFormatter.string(from: $0.timestamp)), \($0.rssi) dBm")
                    }
                )
            ]
        )
    }
}

