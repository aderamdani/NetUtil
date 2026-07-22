import SwiftUI

struct NetQualityView: View {
    @Bindable var vm: NetQualityViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    if let r = vm.result {
                        resultCards(r)
                        detailCard(r)
                    } else if vm.isRunning {
                        ToolStateView.loading(message: "Measuring against Apple's test servers — about 20 seconds...")
                    } else {
                        ToolStateView.empty(title: "No Measurement Yet",
                                            subtitle: "Run a test to measure throughput and responsiveness (bufferbloat) under working load.")
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Network Quality") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Network Quality")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Network Quality Tool")

                Spacer()

                Button(action: { vm.isRunning ? vm.stop() : vm.start() }) {
                    Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.glassProminent)
                .tint(vm.isRunning ? .red : .accentColor)
                .accessibilityLabel(vm.isRunning ? "Stop Test" : "Start Test")

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()
        }
    }

    private var moodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .accentColor, "Measuring network quality...") }
            guard let r = vm.result else {
                return ("gauge.with.dots.needle.67percent", .secondary, "Responsiveness (RPM) shows how usable the connection stays under load")
            }
            let grade = r.rpmGrade
            let gradeColor: Color = grade.color == "green" ? .green : grade.color == "orange" ? .orange : .red
            return (grade.color == "green" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    gradeColor,
                    "Responsiveness: \(grade.label) (\(r.responsivenessRPM) RPM)  —  ↓ \(String(format: "%.0f", r.downloadMbps)) / ↑ \(String(format: "%.0f", r.uploadMbps)) Mbps")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Results

    private func resultCards(_ r: NetQualityResult) -> some View {
        let gradeColor: Color = r.rpmGrade.color == "green" ? .green : r.rpmGrade.color == "orange" ? .orange : .red
        return HStack(spacing: 12) {
            StatCard(title: "Download", value: String(format: "%.0f", r.downloadMbps), unit: "Mbps", icon: "arrow.down.circle")
            StatCard(title: "Upload", value: String(format: "%.0f", r.uploadMbps), unit: "Mbps", icon: "arrow.up.circle")
            StatCard(title: "Responsiveness", value: "\(r.responsivenessRPM)", unit: "RPM", icon: "gauge.with.dots.needle.67percent", color: gradeColor)
            StatCard(title: "Base RTT", value: r.baseRttMs.map { String(format: "%.0f", $0) } ?? "—", unit: "ms", icon: "clock")
        }
    }

    private func detailCard(_ r: NetQualityResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Interface", r.interfaceName ?? "—")
            Divider().opacity(0.5)
            detailRow("Test Server", r.endpoint ?? "—")
            Divider().opacity(0.5)
            detailRow("Measured", r.timestamp.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced))
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg).font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
