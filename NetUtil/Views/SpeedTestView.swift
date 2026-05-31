import SwiftUI
import Observation

struct SpeedTestView: View {
    @Bindable var vm: SpeedTestViewModel
    @Environment(ToolStore.self) private var tools
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            ScrollView {
                Text("Speed Test Content").padding()
            }
        }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Speed Test")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Speed Test Tool")

                Spacer()

                HStack(spacing: 12) {
                    if !vm.history.isEmpty {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveSpeedTestPDF(history: vm.history) },
                            onExportCSV: {
                                let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: Exporter.csvString(from: vm.history),
                                              defaultName: "NetUtil-SpeedTest-\(ts.string(from: Date())).csv",
                                              ext: "csv")
                            }
                        )
                    }

                    Button(action: { if vm.isTesting { vm.cancel() } else { vm.start() } }) {
                        Label(vm.isTesting ? "Stop" : "Start", systemImage: vm.isTesting ? "stop.fill" : "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isTesting ? .red : .accentColor)
                    .accessibilityLabel(vm.isTesting ? "Stop Speed Test" : "Start Speed Test")

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
}
