import SwiftUI

struct NetworkDoctorView: View {
    @Bindable var vm: NetworkDoctorViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if vm.lastRun == nil && !vm.isRunning {
                        ToolStateView.empty(title: "No Diagnosis Yet",
                                            subtitle: "Run a check to test each network layer — router, DNS, internet, and encrypted web — and find where a problem sits.",
                                            minHeight: 200)
                    }
                    stepList
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Connectivity Doctor") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Connectivity Doctor")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connectivity Doctor Tool")

                Spacer()

                Button(action: { vm.isRunning ? vm.stop() : vm.start() }) {
                    Label(vm.isRunning ? "Stop" : "Diagnose", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 90)
                }
                .buttonStyle(.glassProminent)
                .tint(vm.isRunning ? .red : .accentColor)
                .accessibilityLabel(vm.isRunning ? "Stop Diagnosis" : "Start Diagnosis")

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
            if vm.isRunning { return ("hourglass", .accentColor, "Checking each network layer...") }
            guard vm.lastRun != nil else {
                return ("stethoscope", .secondary, "Finds which layer is broken when \"the internet doesn't work\"")
            }
            let v = NetworkDoctorViewModel.verdict(for: vm.checks, captivePortal: vm.captivePortal)
            let c: Color = v.color == "green" ? .green : v.color == "orange" ? .orange : .red
            return (v.icon, c, v.message)
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Steps

    private var stepList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.checks.enumerated()), id: \.element.id) { idx, check in
                stepRow(check)
                if idx < vm.checks.count - 1 {
                    Divider().opacity(0.5).padding(.leading, 52)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func stepRow(_ check: DoctorCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.id.icon)
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(check.id.rawValue).font(.headline)
                Text(detailText(for: check))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            statusBadge(check.state)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.id.rawValue) check")
        .accessibilityValue(detailText(for: check))
    }

    private func detailText(for check: DoctorCheck) -> String {
        switch check.state {
        case .pending:            check.id.explanation
        case .running:            "Checking..."
        case .passed(let detail): detail
        case .failed(let detail): detail
        }
    }

    @ViewBuilder
    private func statusBadge(_ state: DoctorStepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle.dashed").foregroundColor(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .passed:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }
}
