import SwiftUI
import Combine

struct MenuBarView: View {
    @EnvironmentObject private var vm: MenuBarViewModel
    @EnvironmentObject private var tools: ToolStore
    @EnvironmentObject private var networkInterfaces: NetworkInterfaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
            Divider()
            pingSection
            Divider()
            footerSection
        }
        .frame(width: 280)
        .onAppear {
            if tools.externalIP == "Checking..." || tools.externalIP == "Unknown" {
                tools.refreshGlobalStatus()
            }
        }
    }

    // MARK: - Helpers

    private var primaryInterface: NetworkInterface? {
        networkInterfaces.interfaces.first {
            $0.isUp && !$0.isLoopback && !$0.ipv4.isEmpty &&
            !$0.name.hasPrefix("utun") && !$0.name.hasPrefix("ipsec") &&
            !$0.name.hasPrefix("awdl") && !$0.name.hasPrefix("llw") &&
            !$0.name.hasPrefix("bridge")
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ipRow(label: "External", value: tools.externalIP,
                      faded: tools.externalIP == "Checking..." || tools.externalIP == "Unknown")
                ipRow(label: "Local",
                      value: primaryInterface?.ipv4.first ?? "—",
                      faded: primaryInterface == nil)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if tools.isVPNActive {
                    Label("VPN", systemImage: "lock.shield.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                }
                if let iface = primaryInterface {
                    HStack(spacing: 4) {
                        Image(systemName: iface.typeIcon).font(.caption2)
                        Text(iface.typeName).font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func ipRow(label: String, value: String, faded: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(faded ? .secondary : .primary)
        }
    }

    // MARK: - Ping Section

    private var pingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ping").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Spacer()
                TextField("", text: Binding(get: { vm.pingHost }, set: { vm.pingHost = $0 }),
                          prompt: Text("8.8.8.8"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 110)
                    .onSubmit { vm.startPing() }
            }

            HStack(spacing: 8) {
                Circle().fill(vm.pingStatusColor).frame(width: 7, height: 7)
                if let rtt = vm.lastRtt {
                    Text(String(format: "%.1f ms", rtt))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(vm.pingStatusColor)
                } else {
                    Text(vm.pingHost.isEmpty ? "—" : "Pinging...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if vm.sent > 0 {
                    Text(String(format: "Loss %.0f%%", vm.loss))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(vm.loss > 0 ? .orange : .secondary)
                }
            }

            if !vm.rttHistory.isEmpty {
                DashboardSparkline(data: vm.rttHistory, color: vm.pingStatusColor)
                    .frame(height: 22)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 0) {
            Button {
                NSApp.activate()
                NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Open NetUtil")

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")

            Divider().frame(height: 12).padding(.horizontal, 10)

            Button {
                Updater.shared.checkForUpdates(interactive: true)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Check for Updates")

            Divider().frame(height: 12).padding(.horizontal, 10)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Quit NetUtil")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - ViewModel

@MainActor
class MenuBarViewModel: ObservableObject {
    @Published var lastRtt: Double?
    @Published var loss: Double = 0
    @Published var sent: Int = 0
    @Published var rttHistory: [Double] = []
    @Published var pingHost: String = UserDefaults.standard.string(forKey: "menuBarPingHost") ?? "8.8.8.8" {
        didSet { UserDefaults.standard.set(pingHost, forKey: "menuBarPingHost") }
    }

    private var process: Process?
    private var pipe: Pipe?
    private var samples: [Double?] = []

    init() {
        Task { @MainActor in self.startPing() }
    }

    var pingStatusColor: Color {
        guard let rtt = lastRtt else { return .secondary }
        let warn = UserDefaults.standard.object(forKey: "rttWarnThreshold") as? Double ?? 20.0
        let crit = UserDefaults.standard.object(forKey: "rttCritThreshold") as? Double ?? 100.0
        if rtt < warn { return .green }
        if rtt < crit { return .orange }
        return .red
    }

    func startPing() {
        stop()
        guard !pingHost.isEmpty else { return }
        samples = []
        sent = 0
        loss = 0
        rttHistory = []

        let interval = UserDefaults.standard.object(forKey: "menuBarPingInterval") as? Double ?? 2.0
        let intervalArg = String(format: "%.1f", max(1.0, interval))

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        p.arguments = ["-i", intervalArg, pingHost]
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines {
                let rtt = Self.parseRTT(line)
                guard rtt != nil || line.contains("timeout") || line.contains("no route") else { continue }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.sent += 1
                    self.samples.append(rtt)
                    if self.samples.count > 30 { self.samples.removeFirst() }
                    self.lastRtt = rtt ?? self.lastRtt
                    if let rtt {
                        self.rttHistory.append(rtt)
                        if self.rttHistory.count > 30 { self.rttHistory.removeFirst() }
                        UserDefaults.standard.set(rtt, forKey: "menuBarCurrentRTT")
                    }
                    let timeouts = self.samples.filter { $0 == nil }.count
                    self.loss = Double(timeouts) / Double(self.samples.count) * 100
                }
            }
        }

        self.process = p
        self.pipe = pipe
        try? p.run()
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
        UserDefaults.standard.set(-1.0, forKey: "menuBarCurrentRTT")
    }

    private nonisolated static func parseRTT(_ line: String) -> Double? {
        guard let r = line.range(of: #"time[=<]([\d.]+)"#, options: .regularExpression) else { return nil }
        let sub = String(line[r])
        let value = sub.components(separatedBy: CharacterSet(charactersIn: "=<")).last ?? ""
        return Double(value)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @AppStorage("menuBarDisplayMode") private var displayMode = "icon"
    @AppStorage("menuBarShowTraffic") private var showTraffic = false
    @AppStorage("menuBarCurrentRTT")  private var currentRTT  = -1.0
    @AppStorage("menuBarCurrentRxBps") private var currentRx  = 0.0
    @AppStorage("menuBarCurrentTxBps") private var currentTx  = 0.0
    @AppStorage("rttWarnThreshold")   private var rttWarn     = 20.0
    @AppStorage("rttCritThreshold")   private var rttCrit     = 100.0

    private var hasResult: Bool { currentRTT >= 0 }

    private var pingColor: Color {
        guard hasResult else { return .secondary }
        if currentRTT < rttWarn { return .green }
        if currentRTT < rttCrit { return .orange }
        return .red
    }

    private var rttString: String {
        hasResult ? String(format: "%dms", Int(currentRTT)) : "—ms"
    }

    private var trafficString: String {
        "↓\(Self.formatRate(currentRx)) ↑\(Self.formatRate(currentTx))"
    }

    var body: some View {
        switch displayMode {
        case "rtt":
            Text(rttString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundColor(hasResult ? pingColor : .secondary)
        case "traffic":
            Text(trafficString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
        case "rtt_traffic":
            Text("\(rttString)  \(trafficString)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundColor(hasResult ? pingColor : .secondary)
        default:
            if showTraffic {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg").imageScale(.medium)
                    Text(trafficString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                }
            } else {
                Image(systemName: "waveform.path.ecg").imageScale(.medium)
            }
        }
    }

    static func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0fB", bps) }
        if bps < 1_048_576 { return String(format: "%.0fK", bps / 1024) }
        return String(format: "%.1fM", bps / 1_048_576)
    }
}
