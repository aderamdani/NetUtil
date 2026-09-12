import SwiftUI
import AppKit

struct NetworkDoctorView: View {
    @Bindable var vm: NetworkDoctorViewModel
    @Binding var selection: Tool?
    @Environment(ToolStore.self) private var tools
    @State private var showLearningGuide = false
    @State private var expandedSteps: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: Metrics.spacingLG) {
                    if vm.lastRun == nil && !vm.isRunning {
                        ToolStateView.empty(title: "No Diagnosis Yet",
                                            subtitle: "Run a check to test each network layer — router, DNS, internet, and encrypted web — and find where a problem sits.",
                                            minHeight: 200)
                    }
                    if vm.lastRun != nil && !vm.isRunning {
                        verdictCard
                    }
                    pathDiagram
                    stepListSection
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Connectivity Doctor") }
        .onChange(of: vm.isRunning) { _, running in
            if running {
                expandedSteps = []
            } else if vm.lastRun != nil {
                // Auto-reveal the broken layers so the problem is visible immediately.
                expandedSteps = Set(vm.checks.filter {
                    if case .failed = $0.state { return true }
                    return false
                }.map { $0.id.rawValue })
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    Image(systemName: "stethoscope")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Connectivity Doctor")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connectivity Doctor Tool")

                Spacer()

                if vm.lastRun != nil {
                    ReportMenuButton(
                        onExportPDF: { Exporter.saveDoctorPDF(checks: vm.checks, captivePortal: vm.captivePortal) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            var lines = ["layer,result"]
                            for check in vm.checks {
                                let stateStr: String
                                switch check.state {
                                case .pending:  stateStr = "Pending"
                                case .running:  stateStr = "Running"
                                case .passed(let why):  stateStr = "Passed — \(why)"
                                case .failed(let why):  stateStr = "Failed — \(why)"
                                }
                                lines.append("\(check.id.rawValue),\(Exporter.csvField(stateStr))")
                            }
                            Exporter.save(string: lines.joined(separator: "\n"),
                                          defaultName: "NetUtil-Doctor-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        },
                        onCopySummary: {
                            let v = NetworkDoctorViewModel.verdict(for: vm.checks, captivePortal: vm.captivePortal)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(v.message, forType: .string)
                        }
                    )
                }

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
            .padding(.vertical, 16)

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

    // MARK: - Verdict

    /// Plain-language summary card: what the outcome means and the single
    /// next step when something is broken.
    private var verdictCard: some View {
        let v = NetworkDoctorViewModel.verdict(for: vm.checks, captivePortal: vm.captivePortal)
        let color: Color = v.color == "green" ? .green : (v.color == "orange" ? .orange : .red)
        let title: String = {
            if v.color == "green" { return "You're Connected" }
            if v.color == "orange" { return "Action Needed" }
            return "Problem Found"
        }()
        let failedCheck = vm.checks.first(where: { check in
            if case .failed = check.state { return true }
            return false
        })
        return HStack(spacing: Metrics.spacingMD) {
            Image(systemName: v.icon)
                .font(.title.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(v.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let failed = failedCheck, let action = failureAction(for: failed) {
                Button(action: action.perform) {
                    Label(action.label, systemImage: action.icon)
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel(action.label)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Connection Path

    /// Visual chain Mac → Router → DNS → Internet → Secure Web. Green means
    /// the step works; the chain breaks at the first red step.
    private var pathDiagram: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingMD) {
            HStack {
                Text("Connection Path")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(progressText)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .top, spacing: Metrics.spacingXS) {
                pathNode(icon: "desktopcomputer", label: "This Mac", state: nil)
                pathConnector(state: state(for: .gateway))
                pathNode(icon: DoctorStepID.gateway.icon, label: DoctorStepID.gateway.rawValue, state: state(for: .gateway))
                pathConnector(state: state(for: .dns))
                pathNode(icon: DoctorStepID.dns.icon, label: DoctorStepID.dns.rawValue, state: state(for: .dns))
                pathConnector(state: state(for: .http))
                pathNode(icon: DoctorStepID.http.icon, label: DoctorStepID.http.rawValue, state: state(for: .http))
                pathConnector(state: state(for: .tls))
                pathNode(icon: DoctorStepID.tls.icon, label: DoctorStepID.tls.rawValue, state: state(for: .tls))
            }
            Text("Green means that step works. The chain breaks at the first red step.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection path diagram. \(progressText)")
    }

    private func pathNode(icon: String, label: String, state: DoctorStepState?) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(nodeColor(state).opacity(0.12))
                    .frame(width: 36, height: 36)
                if isRunningState(state) {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(nodeColor(state))
                }
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 64)
        .accessibilityLabel("\(label): \(stateDescription(state))")
    }

    private func pathConnector(state: DoctorStepState?) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 17)
            RoundedRectangle(cornerRadius: 1)
                .fill(connectorColor(state))
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func state(for id: DoctorStepID) -> DoctorStepState? {
        vm.checks.first(where: { $0.id == id })?.state
    }

    private var progressText: String {
        let done = vm.checks.filter { check in
            switch check.state {
            case .passed, .failed: return true
            case .pending, .running: return false
            }
        }.count
        if vm.isRunning { return "Checking \(min(done + 1, 4)) of 4…" }
        if vm.lastRun != nil { return "\(done) of 4 checked" }
        return "Not started"
    }

    private func nodeColor(_ state: DoctorStepState?) -> Color {
        guard let state else { return .accentColor }
        switch state {
        case .pending: return .secondary
        case .running: return .accentColor
        case .passed: return .green
        case .failed: return .red
        }
    }

    private func connectorColor(_ state: DoctorStepState?) -> Color {
        guard let state else { return Color.secondary.opacity(0.3) }
        switch state {
        case .passed: return .green
        case .failed: return .red
        case .running: return .accentColor
        case .pending: return Color.secondary.opacity(0.3)
        }
    }

    private func isPendingState(_ state: DoctorStepState) -> Bool {
        if case .pending = state { return true }
        return false
    }

    private func isRunningState(_ state: DoctorStepState?) -> Bool {
        guard let state else { return false }
        if case .running = state { return true }
        return false
    }

    private func stateDescription(_ state: DoctorStepState?) -> String {
        guard let state else { return "Starting point" }
        switch state {
        case .pending: return "Waiting"
        case .running: return "Checking now"
        case .passed: return "Working"
        case .failed: return "Problem found"
        }
    }

    // MARK: - Steps

    private var stepListSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSM) {
            SectionHeader(title: "Layer Details", icon: "list.bullet.rectangle")
                .padding(.leading, 4)
            stepList
        }
    }

    private var stepList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.checks.enumerated()), id: \.element.id) { idx, check in
                stepRow(check)
                if idx < vm.checks.count - 1 {
                    Divider().opacity(0.5).padding(.leading, 56)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func stepRow(_ check: DoctorCheck) -> some View {
        let expanded = expandedSteps.contains(check.id.rawValue)
        let showExplanation = !isPendingState(check.state)
        let action = failureAction(for: check)
        return VStack(spacing: 0) {
            Button {
                if expanded { expandedSteps.remove(check.id.rawValue) }
                else { expandedSteps.insert(check.id.rawValue) }
            } label: {
                HStack(alignment: .top, spacing: Metrics.spacingMD) {
                    Image(systemName: check.id.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(check.id.rawValue).font(.headline)
                        Text(detailText(for: check))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    statusBadge(check.state)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .padding(.top, 4)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(check.id.rawValue) check, \(detailText(for: check))")
            .accessibilityHint(expanded ? "Tap to collapse details" : "Tap to expand details")

            if expanded && (showExplanation || action != nil) {
                VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                    Divider().opacity(0.5)
                    if showExplanation {
                        Text(check.id.explanation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let action {
                        Button(action: action.perform) {
                            Label(action.label, systemImage: action.icon)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private struct FailureAction {
        let label: String
        let icon: String
        let perform: () -> Void
    }

    /// One-click follow-up per failed layer — turns the advice text into
    /// an action instead of leaving the user to act on it manually.
    private func failureAction(for check: DoctorCheck) -> FailureAction? {
        guard case .failed = check.state else { return nil }
        switch check.id {
        case .gateway:
            guard let gateway = vm.gatewayIP else { return nil }
            return FailureAction(label: "Ping Router", icon: "antenna.radiowaves.left.and.right") {
                tools.ping.quickLaunchHost = gateway
                selection = .ping
            }
        case .dns:
            return FailureAction(label: "Open DNS Resolver", icon: "server.rack") {
                selection = .dnsResolver
            }
        case .http:
            guard vm.captivePortal, let url = URL(string: "http://captive.apple.com/hotspot-detect.html") else { return nil }
            return FailureAction(label: "Open in Browser", icon: "safari") {
                NSWorkspace.shared.open(url)
            }
        case .tls:
            return nil
        }
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
