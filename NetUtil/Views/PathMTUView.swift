import SwiftUI

struct PathMTUView: View {
    @Bindable var vm: PathMTUViewModel
    @State private var host = ""
    @State private var history = HostHistory.shared
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            ToolControlBar(icon: "ruler", title: "Path MTU",
                           host: $host, history: history, onSubmit: startAction) {
                Button(action: { vm.isRunning ? vm.stop() : startAction() }) {
                    Label(vm.isRunning ? "Stop" : "Measure", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.glassProminent)
                .tint(vm.isRunning ? .red : .accentColor)
                .disabled(!vm.isRunning && host.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(vm.isRunning ? "Stop Measurement" : "Start Measurement")

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }
                    if let mtu = vm.mtu {
                        resultCard(mtu)
                    }
                    if !vm.probes.isEmpty {
                        probeLog
                    }
                    if vm.probes.isEmpty && vm.error == nil && !vm.isRunning {
                        ToolStateView.empty(title: "No Measurement Yet",
                                            subtitle: "Enter a host to find the largest packet that travels the path unfragmented.")
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Path MTU") }
    }

    private func startAction() {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        history.record(host)
        vm.start(host: host)
    }

    private var moodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .accentColor, "Probing \(vm.currentHost) with don't-fragment pings...") }
            guard let mtu = vm.mtu else {
                return ("ruler", .secondary, "Finds the largest packet size a path can carry without fragmenting")
            }
            let healthy = mtu >= 1500
            return (healthy ? "checkmark.circle.fill" : "info.circle.fill",
                    healthy ? .green : .orange,
                    "Path MTU to \(vm.currentHost): \(mtu) bytes — \(PathMTUViewModel.interpretation(mtu: mtu))")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private func resultCard(_ mtu: Int) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Path MTU", value: "\(mtu)", unit: "bytes", icon: "ruler",
                     color: mtu >= 1500 ? .green : .orange)
            StatCard(title: "Max Payload", value: "\(mtu - PathMTUViewModel.headerOverhead)", unit: "bytes", icon: "shippingbox")
            StatCard(title: "Probes", value: "\(vm.probes.count)", icon: "target")
        }
    }

    private var probeLog: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.probes.enumerated()), id: \.element.id) { idx, probe in
                HStack(spacing: 12) {
                    Image(systemName: probe.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(probe.passed ? .green : .red)
                    Text("\(probe.packetSize) bytes")
                        .font(.system(.subheadline, design: .monospaced))
                    Text(probe.passed ? "delivered unfragmented" : "too large for the path")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                if idx < vm.probes.count - 1 {
                    Divider().opacity(0.5).padding(.leading, 44)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}
