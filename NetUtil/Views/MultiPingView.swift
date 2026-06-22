import SwiftUI
import Charts
import Observation

struct MultiPingView: View {
    @Bindable var vm: MultiPingViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var newHost = ""
    @State private var expandedSlotID: UUID?
    @State private var showLearningGuide = false
    @State private var showImportSheet = false
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0

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
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(msg).font(.callout).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Multi-Ping Tool")
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Hostname or IP address", text: $newHost)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(addHost)
                    .accessibilityLabel("Host Input")
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
                            .accessibilityLabel("Host History")
                        }
                    }

                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { showImportSheet = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    
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
                        .accessibilityLabel("Sort Mode")
                    }

                    if !vm.slots.isEmpty {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveMultiPingPDF(slots: vm.slots) },
                            onExportCSV: {
                                let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: Exporter.csvString(from: vm.slots), defaultName: "NetUtil-MultiPing-\(date.string(from: Date())).csv", ext: "csv")
                            }
                        )
                    }

                    Button(action: addHost) {
                        Label("Add Host", systemImage: "plus")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add Host to Monitor")

                    if !newHost.trimmingCharacters(in: .whitespaces).isEmpty {
                        let h = newHost.trimmingCharacters(in: .whitespaces)
                        let isFav = tools.favorites.isFavorite(h)
                        Button { tools.favorites.toggle(host: h) } label: {
                            Image(systemName: isFav ? "star.fill" : "star").foregroundColor(isFav ? .orange : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                    }

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
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
        .background(.regularMaterial)
        .accessibilityElement(children: .ignore)
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
            Text("No Monitoring Targets")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add multiple hosts to monitor global latency performance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .accessibilityElement(children: .combine)
    }

    private func addHost() {
        let h = newHost.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        history.record(h); vm.add(host: h); newHost = ""
    }
}

