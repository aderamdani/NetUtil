import SwiftUI
import CoreWLAN
import Combine
import Charts
import Observation

struct WiFiInspectorView: View {
    var vm: WiFiInspectorViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let info = vm.info {
                        interpretationSection(info)
                        
                        statsBarSection(info)
                        
                        if vm.rssiSamples.count > 1 {
                            signalStabilitySection
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Infrastructure Details", icon: "antenna.radiowaves.left.and.right")
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
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text(vm.info?.ssid ?? "Searching...")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Wi-Fi Inspector Tool")
                
                Spacer()
                
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Interface").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        Text(vm.info?.interfaceName ?? "en0")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Network Interface: \(vm.info?.interfaceName ?? "en0")")
                    
                    Divider().frame(height: 16)
                    
                    if let info = vm.info {
                        ReportMenuButton(
                            onExportPDF: {},
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
            .padding(.vertical, 14)
            
            Divider()
        }
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func interpretationSection(_ info: WiFiInfo) -> some View {
        HStack(alignment: .center, spacing: 16) {
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
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Last Polled").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard))
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last polled at \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
        }
    }

    private func statsBarSection(_ info: WiFiInfo) -> some View {
        HStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Signal Stability (RSSI)", icon: "chart.line.uptrend.xyaxis")
            
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
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in plotArea.padding(.top, 10).padding(.bottom, 10) }
            .drawingGroup()
            .frame(height: 120)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .accessibilityLabel("Signal stability chart showing RSSI in dBm")
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

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon in
                if let value {
                    WiFiDetailCard(label: label, value: value, icon: icon)
                }
            }
        }
    }

    private var noWiFiState: some View {
        VStack(spacing: 12) {
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
}

struct WiFiDetailCard: View {
    let label: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
