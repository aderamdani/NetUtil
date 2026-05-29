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
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if vm.slots.isEmpty {
                        emptyState
                    } else {
                        statsBarSection
                        
                        VStack(spacing: 0) {
                            slotsTableHeader
                            Divider()
                            LazyVStack(spacing: 0) {
                                ForEach(vm.slots) { slot in
                                    MultiPingRow(slot: slot, isExpanded: expandedSlotID == slot.id, rttWarn: rttWarn, rttCrit: rttCrit, onToggleExpand: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            expandedSlotID = expandedSlotID == slot.id ? nil : slot.id
                                        }
                                    }, onRemove: { vm.remove(slot) }, onCommitRename: { vm.sortSlots() })
                                    
                                    if slot.id != vm.slots.last?.id {
                                        Divider().padding(.horizontal, 16).opacity(0.5)
                                    }
                                }
                            }
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Multi-Ping") }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Multi-Ping")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Hostname or IP address", text: $newHost)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(addHost)
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { newHost = h; addHost() }
                                }
                                Divider()
                                Button("Clear History", role: .destructive) { history.clear() }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28)
                            .padding(.trailing, 4)
                        }
                    }

                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Sort")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $vm.sortMode) {
                            ForEach(MultiPingSort.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }

                    if !vm.slots.isEmpty {
                        Menu {
                            Button("Export PDF Report") { Exporter.saveMultiPingPDF(slots: vm.slots) }
                            Divider()
                            Button("Stop All Sessions") { vm.stopAll() }
                            Button("Start All Sessions") { vm.startAll() }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: addHost) {
                        Label("Add Host", systemImage: "plus")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
    }

    private var statsBarSection: some View {
        let running = vm.slots.filter { $0.isRunning }.count
        let avgLoss = vm.slots.isEmpty ? 0.0 : vm.slots.map { $0.loss }.reduce(0, +) / Double(vm.slots.count)
        return HStack(spacing: 12) {
            StatCard(title: "Active Hosts", value: "\(vm.slots.count)", icon: "server.rack")
            StatCard(title: "Monitoring", value: "\(running)", icon: "play.fill", color: running > 0 ? .green : .primary)
            StatCard(title: "Average Loss", value: String(format: "%.1f%%", avgLoss), icon: "exclamationmark.triangle", color: avgLoss > 10 ? .red : .primary)
            Spacer()
            if !vm.slots.isEmpty {
                Button(role: .destructive) {
                    withAnimation {
                        vm.slots.forEach { $0.stop() }
                        vm.slots.removeAll()
                    }
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var slotsTableHeader: some View {
        HStack(spacing: 0) {
            tHeader("Alias", width: 140)
            tHeader("Endpoint", flexible: true)
            tHeader("Sent", width: 60)
            tHeader("Loss", width: 70)
            tHeader("Last", width: 80)
            tHeader("Average", width: 80)
            tHeader("Health (60s)", width: 140)
            tHeader("", width: 60)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(Color.secondary.opacity(0.05))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Monitoring Targets")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add multiple hosts to monitor global latency performance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func addHost() {
        let h = newHost.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        history.record(h); vm.add(host: h); newHost = ""
    }
}

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
                TextField("Alias", text: $slot.customName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 140, alignment: .leading)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false; onCommitRename() }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .opacity(slot.isRunning ? 1 : 0.3)
                    
                    Text(slot.host)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }

                Text("\(slot.sent)")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60, alignment: .leading)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.0f%%", slot.loss))
                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                    .foregroundColor(slot.loss > 0 ? .red : .primary)
                    .frame(width: 70, alignment: .leading)
                
                Text(slot.lastRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(slot.lastRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)
                
                Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(slot.avgRtt.map { rttColor($0) } ?? .secondary)
                    .frame(width: 80, alignment: .leading)

                healthStrip.frame(width: 140).onTapGesture { onToggleExpand() }

                HStack(spacing: 12) {
                    Button(action: { if slot.isRunning { slot.stop() } else { slot.start() } }) {
                        Image(systemName: slot.isRunning ? "pause.fill" : "play.fill")
                            .foregroundColor(slot.isRunning ? .secondary : .accentColor)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.borderless)
                }
                .frame(width: 60)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
            
            if isExpanded {
                VStack(spacing: 0) {
                    Chart {
                        ForEach(slot.samples) { s in
                            if let rtt = s.rtt {
                                AreaMark(x: .value("T", s.timestamp), y: .value("R", rtt))
                                    .foregroundStyle(LinearGradient(colors: [rttColor(rtt).opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.monotone)
                                
                                LineMark(x: .value("T", s.timestamp), y: .value("R", rtt))
                                    .foregroundStyle(rttColor(rtt))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    .interpolationMethod(.monotone)
                            } else {
                                RuleMark(x: .value("T", s.timestamp))
                                    .foregroundStyle(Color.red.opacity(0.2))
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { val in
                            AxisValueLabel {
                                if let ms = val.as(Double.self) {
                                    Text("\(Int(ms)) ms").font(.system(size: 9, design: .monospaced))
                                }
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    
                    Divider().padding(.horizontal, 16).opacity(0.3)
                }
                .background(.regularMaterial)
            }
        }
    }

    private var healthStrip: some View {
        let history = Array(slot.samples.suffix(40))
        return HStack(spacing: 1.5) {
            ForEach(0..<40) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < history.count ? hColor(history[i]) : Color.secondary.opacity(0.1))
                    .frame(width: 2.5, height: 14)
            }
        }
    }

    private func hColor(_ sample: RTTSample?) -> Color {
        guard let s = sample, let rtt = s.rtt else { return .red }
        if rtt > rttCrit { return .red }
        if rtt > rttWarn { return .orange }
        return .green
    }

    private var statusColor: Color {
        if !slot.isRunning { return .secondary }
        return slot.loss > 10 ? .red : (slot.loss > 0 ? .orange : .green)
    }
    
    private func rttColor(_ rtt: Double) -> Color {
        rtt < rttWarn ? .primary : (rtt < rttCrit ? .orange : .red)
    }
}
