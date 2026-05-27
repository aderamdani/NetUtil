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
        VStack(alignment: .leading, spacing: 0) {
            controlBar
                .padding(.bottom, 24)
            
            if vm.slots.isEmpty {
                emptyState
            } else {
                statsBar.padding(.bottom, 24)
                
                VStack(spacing: 0) {
                    slotsTableHeader
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.slots) { slot in
                                MultiPingRow(slot: slot, isExpanded: expandedSlotID == slot.id, rttWarn: rttWarn, rttCrit: rttCrit, onToggleExpand: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expandedSlotID = expandedSlotID == slot.id ? nil : slot.id }
                                }, onRemove: { vm.remove(slot) }, onCommitRename: { vm.sortSlots() })
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { multiPingLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Hostname or IP address", text: $newHost)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(width: 250).onSubmit(addHost)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { newHost = h; addHost() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }.menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Text("Sort:").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Picker("", selection: $vm.sortMode) { ForEach(MultiPingSort.allCases) { mode in Text(mode.rawValue).tag(mode) } }
                .pickerStyle(.menu).frame(width: 110)
            }

            Spacer()

            if !vm.slots.isEmpty {
                Button { Exporter.saveMultiPingPDF(slots: vm.slots) } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
                Button(action: { vm.stopAll() }) { Text("Stop All").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
                Button(action: { vm.startAll() }) { Text("Start All").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: addHost) {
                HStack(spacing: 6) { Image(systemName: "plus"); Text("Add") }.font(.system(size: 13, weight: .medium))
            }.buttonStyle(.borderedProminent).disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }

    private var statsBar: some View {
        let running = vm.slots.filter { $0.isRunning }.count
        let avgLoss = vm.slots.isEmpty ? 0.0 : vm.slots.map { $0.loss }.reduce(0, +) / Double(vm.slots.count)
        return HStack(spacing: 12) {
            StatCard(title: "Hosts", value: "\(vm.slots.count)", icon: "server.rack")
            StatCard(title: "Active", value: "\(running)", icon: "play.fill", color: running > 0 ? .green : .primary)
            StatCard(title: "Avg Loss", value: String(format: "%.1f%%", avgLoss), icon: "exclamationmark.triangle", color: avgLoss > 10 ? .red : .primary)
            Spacer()
            if !vm.slots.isEmpty {
                Button(role: .destructive) { withAnimation { vm.slots.forEach { $0.stop() }; vm.slots.removeAll() } } label: { Image(systemName: "trash").foregroundColor(.secondary) }.buttonStyle(.borderless)
            }
        }
    }

    private var slotsTableHeader: some View {
        HStack(spacing: 0) {
            tHeader("Alias", width: 140)
            tHeader("Endpoint", flexible: true)
            tHeader("Snt", width: 50)
            tHeader("Loss%", width: 60)
            tHeader("Last", width: 70)
            tHeader("Avg RTT", width: 70)
            tHeader("Health", width: 130)
            tHeader("", width: 40)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No Targets Selected").font(.headline).foregroundColor(.secondary)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addHost() {
        let h = newHost.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        history.record(h); vm.add(host: h); newHost = ""
    }

    private var multiPingLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Multi-Ping Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "Multi-Host Audit", icon: "server.rack") { Text("Monitor multiple endpoints simultaneously.") } }.padding(24) }
        }.frame(width: 500, height: 600)
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
                    .textFieldStyle(.plain).font(.system(size: 12, weight: .medium))
                    .frame(width: 140, alignment: .leading).focused($isNameFocused)
                    .onSubmit { isNameFocused = false; onCommitRename() }
                
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 6, height: 6).opacity(slot.isRunning ? 1 : 0.3)
                    Text(slot.host).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(.secondary).rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).onTapGesture { onToggleExpand() }

                Text("\(slot.sent)").font(.system(size: 11, design: .monospaced)).frame(width: 50, alignment: .leading).foregroundColor(.secondary)
                Text(String(format: "%.0f%%", slot.loss)).font(.system(size: 11, design: .monospaced)).foregroundColor(slot.loss > 0 ? .red : .primary).frame(width: 60, alignment: .leading)
                Text(slot.lastRtt.map { String(format: "%.1f", $0) } ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(slot.lastRtt.map { rttColor($0) } ?? .secondary).frame(width: 70, alignment: .leading)
                Text(slot.avgRtt.map { String(format: "%.1f", $0) } ?? "—").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(slot.avgRtt.map { rttColor($0) } ?? .secondary).frame(width: 70, alignment: .leading)

                healthStrip.frame(width: 130).onTapGesture { onToggleExpand() }

                HStack(spacing: 8) {
                    Button(action: { if slot.isRunning { slot.stop() } else { slot.start() } }) {
                        Image(systemName: slot.isRunning ? "pause.fill" : "play.fill").foregroundColor(slot.isRunning ? .secondary : .primary)
                    }.buttonStyle(.borderless)
                    Button(action: onRemove) { Image(systemName: "xmark").foregroundColor(.secondary) }.buttonStyle(.borderless)
                }.frame(width: 40)
            }
            .padding(.vertical, 8).padding(.horizontal, 12).background(isExpanded ? Color.secondary.opacity(0.05) : Color.clear)
            
            if isExpanded {
                Chart {
                    ForEach(slot.samples) { s in
                        if let rtt = s.rtt {
                            LineMark(x: .value("T", s.timestamp), y: .value("R", rtt)).foregroundStyle(rttColor(rtt)).lineStyle(StrokeStyle(lineWidth: 1))
                        } else { RuleMark(x: .value("T", s.timestamp)).foregroundStyle(Color.red.opacity(0.2)) }
                    }
                }
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 2)) { val in AxisValueLabel { if let ms = val.as(Double.self) { Text("\(Int(ms))").font(.system(size: 8)) } } } }
                .chartXAxis(.hidden).frame(height: 60).padding(.horizontal, 40).padding(.vertical, 12).background(Color.black.opacity(0.02))
            }
        }
    }

    private var healthStrip: some View {
        let history = Array(slot.samples.suffix(40))
        return HStack(spacing: 1.5) {
            ForEach(0..<40) { i in
                RoundedRectangle(cornerRadius: 1).fill(i < history.count ? hColor(history[i]) : Color.secondary.opacity(0.1)).frame(width: 2, height: 12)
            }
        }
    }

    private func hColor(_ sample: RTTSample?) -> Color {
        guard let s = sample, let rtt = s.rtt else { return .red }
        if rtt > rttCrit { return .red }
        if rtt > rttWarn { return .orange }
        return .green
    }

    private var statusColor: Color { slot.loss > 0 ? .orange : .green }
    private func rttColor(_ rtt: Double) -> Color { rtt < rttWarn ? .primary : rtt < rttCrit ? .orange : .red }
}
