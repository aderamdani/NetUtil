import SwiftUI
import Combine

struct MenuBarView: View {
    @StateObject private var vm = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pingSection
            Divider()
            interfaceSection
            Divider()
            HStack {
                Button("Check for Updates...") {
                    Updater.shared.checkForUpdates(interactive: true)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            Divider()
            HStack {
                Button("Open NetUtil") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
        .onAppear { vm.startPing() }
        .onDisappear { vm.stop() }
    }

    private var pingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Quick Ping")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", text: Binding(get: { vm.pingHost }, set: { vm.pingHost = $0 }),
                          prompt: Text("8.8.8.8"))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospacedDigit())
                    .frame(width: 110)
                    .onSubmit { vm.startPing() }
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(vm.pingStatusColor)
                    .frame(width: 8, height: 8)
                if let rtt = vm.lastRtt {
                    Text(String(format: "%.1f ms", rtt))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(vm.pingStatusColor)
                } else {
                    Text(vm.pingHost.isEmpty ? "—" : "Pinging…")
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Interfaces")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(vm.interfaces.filter { $0.isUp && !$0.isLoopback }.prefix(4)) { iface in
                HStack(spacing: 8) {
                    Image(systemName: iface.typeIcon)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .frame(width: 16)
                    Text(iface.name)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .leading)
                    Text(iface.ipv4.first ?? iface.ipv6.first ?? "—")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }

            if vm.interfaces.filter({ $0.isUp && !$0.isLoopback }).isEmpty {
                Text("No active interfaces")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
}

@MainActor
private class MenuBarViewModel: ObservableObject {
    @Published var lastRtt: Double?
    @Published var loss: Double = 0
    @Published var sent: Int = 0
    @Published var interfaces: [NetworkInterface] = []
    @Published var pingHost: String = UserDefaults.standard.string(forKey: "menuBarPingHost") ?? "8.8.8.8" {
        didSet { UserDefaults.standard.set(pingHost, forKey: "menuBarPingHost") }
    }

    private var process: Process?
    private var pipe: Pipe?
    private var samples: [Double?] = []
    private var ifaceTimer: Timer?

    init() {
        interfaces = NetworkInterfaceFetcher.fetch()
        ifaceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.interfaces = NetworkInterfaceFetcher.fetch()
            }
        }
    }

    deinit {
        process?.terminate()
        ifaceTimer?.invalidate()
    }

    var pingStatusColor: Color {
        guard let rtt = lastRtt else { return .secondary }
        if rtt < 20 { return .green }
        if rtt < 100 { return .orange }
        return .red
    }

    func startPing() {
        stop()
        guard !pingHost.isEmpty else { return }
        samples = []
        sent = 0
        loss = 0

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        p.arguments = ["-i", "2", pingHost]
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
                    self.samples.append(rtt ?? nil)
                    if self.samples.count > 30 { self.samples.removeFirst() }
                    self.lastRtt = rtt ?? self.lastRtt
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
    }

    private nonisolated static func parseRTT(_ line: String) -> Double? {
        guard let r = line.range(of: #"time[=<]([\d.]+)"#, options: .regularExpression) else { return nil }
        let sub = String(line[r])
        let value = sub.components(separatedBy: CharacterSet(charactersIn: "=<")).last ?? ""
        return Double(value)
    }
}
