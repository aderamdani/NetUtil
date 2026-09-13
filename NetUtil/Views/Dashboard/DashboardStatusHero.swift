import SwiftUI


/// Status-first dashboard hero: answers "is my connection healthy?" at a glance,
/// with a primary call-to-action to run a full connectivity check. Live throughput
/// stays visible as a compact secondary readout.
struct DashboardStatusHero: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?


    private var statusColor: Color {
        switch tools.healthColor {
        case "red": return .red
        case "orange": return .orange
        default: return .green
        }
    }


    private var doctorSummary: String {
        if tools.doctor.isRunning { return "Running checks…" }
        let total = tools.doctor.checks.count
        if total == 0 { return "Not checked yet" }
        let failed = tools.doctor.checks.filter { if case .failed = $0.state { return true } else { return false } }.count
        return failed > 0 ? "\(failed) of \(total) checks failed" : "All \(total) checks passed"
    }


    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            HStack(alignment: .top, spacing: Metrics.spacingMD) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: tools.healthIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(statusColor)
                }
                .accessibilityHidden(true)


                VStack(alignment: .leading, spacing: 2) {
                    Text(tools.healthMessage)
                        .font(.title3.weight(.bold))
                        .foregroundColor(statusColor == .green ? .primary : statusColor)
                    Text(tools.currentConnectionName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }


                Spacer()


                HStack(spacing: Metrics.spacingLG) {
                    rateMetric(label: "Download", value: tools.bandwidth.totalRxBps, color: .blue)
                    rateMetric(label: "Upload", value: tools.bandwidth.totalTxBps, color: .orange)
                }
            }


            HStack(spacing: Metrics.spacingMD) {
                Button {
                    selection = .doctor
                } label: {
                    Label("Run a full check", systemImage: "stethoscope")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)


                Text(doctorSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)


                Spacer()
            }
        }
        .padding(Metrics.spacingXL)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG)
                .stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(tools.healthMessage). \(doctorSummary). Download \(NetworkMath.formatRate(tools.bandwidth.totalRxBps)), upload \(NetworkMath.formatRate(tools.bandwidth.totalTxBps)).")
    }


    private func rateMetric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: Metrics.spacingXS) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            }
            Text(NetworkMath.formatRate(value))
                .font(.title3.monospaced().weight(.bold))
                .foregroundColor(color)
        }
    }
}
