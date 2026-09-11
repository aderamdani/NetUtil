import SwiftUI
import Charts
import Observation

struct MultiPingView: View {
    @Bindable var vm: MultiPingViewModel
    @State private var history = HostHistory.shared
    @State private var newHost = ""
    @State private var expandedSlotID: UUID?
    @State private var showLearningGuide = false
    @State private var showImportSheet = false
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0
    @AppStorage("multiPingAlerts") private var alertsEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            multiPingMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if vm.slots.isEmpty {
                        emptyState
                    } else {
                        statsBarSection

                        slotsOptionsRow

                        VStack(spacing: 0) {
                            slotsTableHeader
                            Divider()
                            LazyVStack(spacing: 0) {
                                ForEach(vm.slots) { slot in
                                    MultiPingSlotRow(slot: slot, isExpanded: expandedSlotID == slot.id, rttWarn: rttWarn, rttCrit: rttCrit, onToggleExpand: {
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
        .sheet(isPresented: $showImportSheet) {
            ImportHostsSheet { hosts in
                for host in hosts {
                    vm.add(host: host)
                }
            }
        }
    }

    private var multiPingMoodBar: some View {
        let active = vm.slots.filter { $0.isRunning }.count
        let total  = vm.slots.count
        let avgLoss = total > 0 ? vm.slots.map { $0.loss }.reduce(0, +) / Double(total) : 0
        let (icon, color, msg): (String, Color, String) = {
            if total == 0 { return ("dot.radiowaves.left.and.right", .secondary, "No hosts added") }
            if active == 0 { return ("pause.circle", .secondary, "Monitoring stopped — \(total) host\(total == 1 ? "" : "s") configured") }
            if avgLoss > 10 { return ("exclamationmark.triangle.fill", .red, "Active: \(active)/\(total)  —  Avg loss: \(String(format: "%.1f", avgLoss))%") }
            if avgLoss > 0  { return ("exclamationmark.triangle.fill", .orange, "Active: \(active)/\(total)  —  Avg loss: \(String(format: "%.1f", avgLoss))%") }
            return ("checkmark.circle.fill", .green, "Active: \(active)/\(total)  —  All hosts reachable")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    private var controlBar: some View {
        MultiPingControlBar(
            host: $newHost,
            history: history,
            vm: vm,
            onAddHost: addHost,
            onShowGuide: { showLearningGuide = true },
            onExportPDF: { Exporter.saveMultiPingPDF(slots: vm.slots) },
            onExportCSV: {
                let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                Exporter.save(string: Exporter.csvString(from: vm.slots), defaultName: "NetUtil-MultiPing-\(date.string(from: Date())).csv", ext: "csv")
            }
        )
    }

    /// Secondary controls near the slots table: sort mode plus import and
    /// alert toggles. Kept out of the primary toolbar so it never wraps.
    private var slotsOptionsRow: some View {
        HStack {
            Picker("", selection: $vm.sortMode) {
                ForEach(MultiPingSort.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            .accessibilityLabel("Sort Mode")

            Spacer()

            Button(action: { showImportSheet = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)

            Toggle(isOn: $alertsEnabled) {
                Image(systemName: alertsEnabled ? "bell.fill" : "bell.slash")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .help("Notify when a host's packet loss or average RTT crosses the thresholds set in Settings > Thresholds (at most one alert per host every 5 minutes).")
            .accessibilityLabel("Latency Alerts")
        }
    }

    private var statsBarSection: some View {
        let running = vm.slots.filter { $0.isRunning }.count
        let avgLoss = vm.slots.isEmpty ? 0.0 : vm.slots.map { $0.loss }.reduce(0, +) / Double(vm.slots.count)
        return HStack(spacing: 12) {
            StatCard(title: "Active Hosts", value: "\(vm.slots.count)", icon: "server.rack")
                .accessibilityElement(children: .combine)
            StatCard(title: "Monitoring", value: "\(running)", icon: "play.fill", color: running > 0 ? .green : .primary)
                .accessibilityElement(children: .combine)
            StatCard(title: "Average Loss", value: String(format: "%.1f%%", avgLoss), icon: "exclamationmark.triangle", color: avgLoss > 10 ? .red : .primary)
                .accessibilityElement(children: .combine)
                .accessibilityValue(String(format: "%.1f percent", avgLoss))
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
                .accessibilityLabel("Clear All Monitoring Targets")
            }
        }
    }

    private var slotsTableHeader: some View {
        HStack(spacing: 0) {
            TableHeader("Alias", width: 140)
            TableHeader("Endpoint", flexible: true)
            TableHeader("Sent", width: 60)
            TableHeader("Loss", width: 70)
            TableHeader("Last", width: 80)
            TableHeader("Average", width: 80)
            TableHeader("Health (60s)", width: 140)
            TableHeader("", width: 60)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(.regularMaterial)
        .accessibilityElement(children: .ignore)
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Monitoring Targets",
                            subtitle: "Add multiple hosts to monitor global latency performance.")
        .accessibilityElement(children: .combine)
    }

    private func addHost() {
        let h = newHost.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        history.record(h); vm.add(host: h); newHost = ""
    }
}

