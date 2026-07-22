import SwiftUI

struct ConnectionsView: View {
    @Bindable var vm: ConnectionsViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if vm.visibleConnections.isEmpty {
                        ToolStateView.empty(title: "No Connections Shown",
                                            subtitle: vm.connections.isEmpty
                                                ? "Reading open sockets..."
                                                : "No connections match the current filter.")
                    } else {
                        connectionTable
                    }
                }
                .padding(24)
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Connections") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "app.connected.to.app.below.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Connections")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connections Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                TextField("Filter by process or address", text: $vm.filterText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 220)
                    .accessibilityLabel("Connection Filter")

                Picker("", selection: $vm.stateFilter) {
                    ForEach(ConnectionsViewModel.StateFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .accessibilityLabel("State Filter")

                Spacer()

                if !vm.visibleConnections.isEmpty {
                    ReportMenuButton(
                        onExportPDF: { Exporter.saveConnectionsPDF(connections: vm.visibleConnections) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: Exporter.csvString(from: vm.visibleConnections),
                                          defaultName: "NetUtil-Connections-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )
                }

                Button { vm.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now (the list auto-refreshes every 5 seconds).")
                .accessibilityLabel("Refresh Connections")

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
        let total = vm.connections.count
        let listening = vm.connections.filter(\.isListening).count
        let processes = Set(vm.connections.map(\.pid)).count
        let msg = total == 0
            ? "Which apps are talking to which hosts right now"
            : "\(total) socket\(total == 1 ? "" : "s") across \(processes) process\(processes == 1 ? "" : "es")  —  \(listening) listening"
        return MoodBar(icon: "app.connected.to.app.below.fill",
                       color: total == 0 ? .secondary : .accentColor,
                       message: msg)
    }

    // MARK: - Table

    private var connectionTable: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().opacity(0.5)
            ForEach(Array(vm.visibleConnections.enumerated()), id: \.element.id) { idx, conn in
                connectionRow(conn)
                if idx < vm.visibleConnections.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var headerRow: some View {
        HStack {
            Text("Process").frame(width: 140, alignment: .leading)
            Text("PID").frame(width: 60, alignment: .leading)
            Text("Proto").frame(width: 50, alignment: .leading)
            Text("Local").frame(width: 180, alignment: .leading)
            Text("Remote").frame(width: 180, alignment: .leading)
            Text("State").frame(width: 110, alignment: .leading)
            Spacer()
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func connectionRow(_ conn: NetConnection) -> some View {
        HStack {
            Text(conn.command)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            Text("\(conn.pid)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(conn.proto)
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 50, alignment: .leading)
            Text(conn.local)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)
                .textSelection(.enabled)
            Text(conn.remote ?? "—")
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)
                .textSelection(.enabled)
            Text(conn.state ?? "—")
                .font(.subheadline)
                .foregroundColor(conn.isListening ? .blue : conn.state == "ESTABLISHED" ? .green : .secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conn.command) connection")
        .accessibilityValue("\(conn.proto) \(conn.local) to \(conn.remote ?? "none"), \(conn.state ?? "stateless")")
    }
}
