import SwiftUI
import Charts
import Darwin
import Combine
import Observation

struct BandwidthView: View {
    @Environment(ToolStore.self) private var tools
    private var vm: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            ScrollView {
                VStack(spacing: 24) {
                    Text("Placeholder content").padding()
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Bandwidth Monitor") }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Bandwidth Monitor")
                        .font(.headline)
                }
                Spacer()
                HStack(spacing: 16) {
                    ReportMenuButton(onExportPDF: {}, onExportCSV: {
                        let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                        Exporter.save(string: exportBandwidthCSV(), defaultName: "NetUtil-Bandwidth-\(date.string(from: Date())).csv", ext: "csv")
                    })
                    Button(action: {}) { Label("Pause", systemImage: "pause.fill") }.buttonStyle(.borderless)
                    Button(action: {}) { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            Divider()
        }
    }
    
    private func exportBandwidthCSV() -> String {
        return "timestamp,interface,rx_bps,tx_bps"
    }
}
