import SwiftUI
import Charts

struct MultiPingView: View {
    @ObservedObject var vm: MultiPingViewModel
    @StateObject private var history = HostHistory.shared
    @State private var newHost = ""
    @State private var expandedSlotID: UUID?
    @State private var showLearningGuide = false
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            addBar
            
            if vm.slots.isEmpty {
                emptyState
            } else {
                summaryBar
                
                VStack(spacing: 0) {
                    slotsTableHeader
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.slots) { slot in
                                MultiPingRow(
                                    slot: slot,
                                    isExpanded: expandedSlotID == slot.id,
                                    rttWarn: rttWarn,
                                    rttCrit: rttCrit,
                                    onToggleExpand: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            expandedSlotID = expandedSlotID == slot.id ? nil : slot.id
                                        }
                                    },
                                    onRemove: { vm.remove(slot) },
                                    onCommitRename: { vm.sortSlots() }
                                )
                                Divider().opacity(0.15)
                            }
                        }
                    }
                }
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            multiPingLearningGuideSheet
        }
    }

    private var summaryBar: some View {
        let running = vm.slots.filter { $0.isRunning }.count
        let responding = vm.slots.filter { $0.loss < 100 && $0.sent > 0 }.count
        let avgLoss = vm.slots.isEmpty ? 0.0 : vm.slots.map { $0.loss }.reduce(0, +) / Double(vm.slots.count)
        
        return HStack(spacing: 12) {
            StatCard(title: "TOTAL HOSTS", value: "\(vm.slots.count)", icon: "server.rack")
            StatCard(title: "ACTIVE", value: "\(running)", icon: "play.fill", color: running > 0 ? .green : .secondary)
            StatCard(title: "RESPONDING", value: "\(responding)", icon: "checkmark.shield.fill", color: responding == vm.slots.count ? .blue : .orange)
            StatCard(title: "AVG LOSS", value: String(format: "%.1f%%", avgLoss), icon: "exclamationmark.triangle.fill", color: avgLoss > 10 ? .red : .secondary)
            
            Spacer()
            
            if !vm.slots.isEmpty {
                Menu {
                    Button("Export as PDF Report...") {
                        Exporter.saveMultiPingPDF(slots: vm.slots)
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
            }
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .help("Multi-Ping Learning Guide")
        }
    }

    private var multiPingLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Multi-Ping Learning Guide").font(.title2.bold())
                    Text("Understand how to monitor infrastructure at scale.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "Multi-Host Strategy", icon: "server.rack") {
                        Text("Multi-Ping allows you to monitor the health of your entire infrastructure in one glance. Use it to compare performance between different server locations or gateways.")
                    }
                    
                    GuideSection(title: "Health Strips", icon: "square.grid.3x1.below.line.grid.1x2") {
                        Text("The 'Stability Bar' shows 60 individual packet results per host. A solid green bar means 100% uptime, while red segments reveal intermittent disconnects.")
                    }
                    
                    GuideSection(title: "Interpreting Status", icon: "brain.head.profile") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "Healthy", desc: "Target is responding quickly with no packet loss.")
                            GuidePoint(title: "Degraded", desc: "Target is reachable but experiencing minor packet loss or latency.")
                            GuidePoint(title: "Critical", desc: "Major issues detected, such as >20% packet loss or very high latency.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }

    private var addBar: some View {
        HStack(spacing: 12) {
            TextField("Enter hostname or IP address", text: $newHost)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 300)
                .onSubmit(addHost)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in
                                Button(h) { newHost = h; addHost() }
                            }
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                        .padding(.trailing, 4)
                    }
                }

            Button(action: addHost) {
                Label("Add Target", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)

            Divider().frame(height: 24).padding(.horizontal, 8)
            
            HStack(spacing: 8) {
                Text("Sort:").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                Picker("", selection: $vm.sortMode) {
                    ForEach(MultiPingSort.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            Spacer()

            if !vm.slots.isEmpty {
                HStack(spacing: 8) {
                    Button(action: { vm.stopAll() }) {
                        Label("Stop All", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { vm.startAll() }) {
                        Label("Start All", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var slotsTableHeader: some View {
        HStack(spacing: 0) {
            headerCell("Alias Name", width: 160)
            headerCell("Host / Endpoint", flexible: true)
            headerCell("Snt", width: 60)
            headerCell("Loss%", width: 70)
            headerCell("Last", width: 80)
            headerCell("Avg RTT", width: 80)
            headerCell("Stability Bar (Last 60)", width: 150)
            headerCell("", width: 40)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color(.windowBackgroundColor))
        .overlay(VStack { Spacer(); Divider() })
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
            VStack(spacing: 4) {
                Text("Multi-Host Monitoring")
                    .font(.title2.bold())
                Text("Enter a hostname above to start monitoring multiple endpoints simultaneously.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.secondary)
            .kerning(1)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func addHost() {
        let h = newHost.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        history.record(h)
        vm.add(host: h)
        newHost = ""
    }
}

// MARK: - MultiPingRow

private struct MultiPingRow: View {
    @ObservedObject var slot: PingSlot
    let isExpanded: Bool
    var rttWarn: Double
    var rttCrit: Double
    let onToggleExpand: () -> Void
    let onRemove: () -> Void
    let onCommitRename: () -> Void
    
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 1. Alias Name Column (Renamable, Positioned Left)
                TextField("Alias Name", text: $slot.customName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 160, alignment: .leading)
                    .focused($isNameFocused)
                    .onSubmit {
                        isNameFocused = false // Release focus
                        onCommitRename()
                    }
                    .help("Click to rename this host alias. Press Enter to apply and sort.")
                
                // 2. Host & Status Interpretation
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(statusColor.opacity(0.3), lineWidth: 3).scaleEffect(slot.isRunning ? 1.5 : 1.0).opacity(slot.isRunning ? 0 : 1))
                        Text(slot.host)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    Text(interpretStatus().description)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }

                Text("\(slot.sent)")
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 60, alignment: .leading)
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", slot.loss))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(slot.loss > 0 ? .red : .secondary)
                    .frame(width: 70, alignment: .leading)

                Text(slot.lastRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(slot.lastRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)

                Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(slot.avgRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)

                // Health Strip
                healthStrip
                    .frame(width: 150)
                    .onTapGesture { onToggleExpand() }

                HStack(spacing: 4) {
                    Button(action: { if slot.isRunning { slot.stop() } else { slot.start() } }) {
                        Image(systemName: slot.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(slot.isRunning ? .orange : .green)
                            .frame(width: 20, height: 20)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(width: 20, height: 20)
                            .background(Color.red.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 40)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(rowBackground)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("RTT HISTORY (ms)").font(.system(size: 9, weight: .black)).foregroundColor(.secondary)
                        Spacer()
                        if let avg = slot.avgRtt {
                            Text("Avg: \(String(format: "%.2f", avg))").font(.system(size: 9, weight: .bold))
                        }
                    }
                    
                    Chart {
                        ForEach(slot.samples) { s in
                            if let rtt = s.rtt {
                                AreaMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                                    .foregroundStyle(LinearGradient(colors: [rttColor(rtt).opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Time", s.timestamp), y: .value("RTT", rtt))
                                    .foregroundStyle(rttColor(rtt))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                            } else {
                                RuleMark(x: .value("Time", s.timestamp))
                                    .foregroundStyle(Color.red.opacity(0.2))
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { val in
                            AxisValueLabel { if let ms = val.as(Double.self) { Text("\(Int(ms))").font(.system(size: 8)) } }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 100)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.03))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var healthStrip: some View {
        let history = Array(slot.samples.suffix(60))
        return HStack(spacing: 1.5) {
            ForEach(0..<60) { i in
                let sample = i < history.count ? history[i] : nil
                RoundedRectangle(cornerRadius: 1)
                    .fill(healthColor(sample))
                    .frame(width: 2, height: 16)
            }
        }
        .help("Stability over last 60 packets. Red = Timeout, Orange = High Latency, Green = Healthy.")
    }

    private func healthColor(_ sample: RTTSample?) -> Color {
        guard let s = sample else { return Color.secondary.opacity(0.1) }
        guard let rtt = s.rtt else { return .red }
        if rtt > rttCrit { return .red }
        if rtt > rttWarn { return .orange }
        return .green
    }

    private var statusColor: Color {
        guard slot.sent > 0 else { return .secondary }
        if slot.loss >= 50 { return .red }
        if slot.loss > 0 { return .orange }
        return .green
    }

    private var rowBackground: Color {
        if isExpanded { return Color.accentColor.opacity(0.03) }
        if slot.loss >= 50 { return Color.red.opacity(0.05) }
        if slot.loss > 0 { return Color.orange.opacity(0.03) }
        return Color.clear
    }

    private func interpretStatus() -> (status: String, description: String) {
        guard slot.sent > 0 else { return ("Idle", "Waiting to start") }
        if slot.loss > 20 { return ("Critical", "Severe packet loss") }
        if slot.loss > 0 { return ("Degraded", "Minor instability") }
        if let avg = slot.avgRtt, avg > rttWarn { return ("Lagging", "Higher latency") }
        return ("Healthy", "Stable connection")
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
