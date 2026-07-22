import SwiftUI

struct SubnetScanView: View {
    @Bindable var viewModel: SubnetScanViewModel
    @Binding var selection: Tool?
    @Environment(ToolStore.self) private var tools
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            statusMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = viewModel.error {
                        errorBanner(err)
                    }

                    if viewModel.scanStats.total > 0 {
                        statsHeader

                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredResults) { result in
                                resultRow(result)
                                Divider().opacity(0.5)
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                    } else if viewModel.isRunning {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Subnet Scanner") }
        .onAppear { viewModel.applyDetectedDefault(from: tools.primaryInterface) }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Subnet Scanner")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Subnet Scanner Tool")
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("192.168.1.0/24", text: $viewModel.cidrInput)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 200)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Picker("", selection: $viewModel.batchSize) {
                        Text("Normal").tag(8)
                        Text("Fast").tag(16)
                        Text("Aggressive").tag(32)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    
                    if !viewModel.filteredResults.isEmpty {
                        ReportMenuButton(
                            onExportPDF: {
                                Exporter.saveSubnetScanPDF(results: viewModel.filteredResults, cidr: viewModel.cidrInput)
                            },
                            onExportCSV: {
                                let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                                let safe = viewModel.cidrInput.replacingOccurrences(of: "/", with: "_")
                                Exporter.save(string: Exporter.csvString(from: viewModel.filteredResults),
                                              defaultName: "NetUtil-SubnetScan-\(safe)-\(ts.string(from: Date())).csv",
                                              ext: "csv")
                            }
                        )
                    }

                    Button {
                        if viewModel.isRunning { viewModel.stop() }
                        else { Task { await viewModel.start() } }
                    } label: {
                        Label(viewModel.isRunning ? "Stop" : "Scan", systemImage: viewModel.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(viewModel.isRunning ? .red : .accentColor)
                    .accessibilityLabel(viewModel.isRunning ? "Stop Scan" : "Start Scan")

                    if !viewModel.cidrInput.isEmpty {
                        let isFav = tools.favorites.isFavorite(viewModel.cidrInput)
                        Button { tools.favorites.toggle(host: viewModel.cidrInput) } label: {
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
    
    private var statusMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if viewModel.isRunning {
                return ("hourglass", .secondary, "Scanning \(viewModel.cidrInput)...  \(Int(viewModel.progress * 100))%")
            }
            guard viewModel.scanStats.total > 0 else {
                return ("network", .secondary, "Enter a CIDR block to sweep for live hosts")
            }
            let alive = viewModel.scanStats.alive
            if alive > 0 {
                return ("checkmark.circle.fill", .green, "\(alive) host\(alive == 1 ? "" : "s") responding  —  \(viewModel.scanDuration)")
            }
            return ("exclamationmark.triangle.fill", .orange, "No hosts found — check CIDR")
        }()
        return MoodBar(icon: icon, color: color, message: msg) {
            if viewModel.isRunning {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                    .accessibilityLabel("Scan progress: \(Int(viewModel.progress * 100)) percent")
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private var statsHeader: some View {
        HStack {
            StatCard(title: "Total IPs", value: "\(viewModel.scanStats.total)", icon: "list.number")
            StatCard(title: "Alive", value: "\(viewModel.scanStats.alive)", icon: "checkmark.circle")
            StatCard(title: "Unreachable", value: "\(viewModel.scanStats.unreachable)", icon: "xmark.circle")
            StatCard(title: "Duration", value: viewModel.scanDuration, icon: "timer")
        }
    }
    
    private func resultRow(_ result: SubnetScanResult) -> some View {
        HStack {
            Text(result.ip).font(.system(.caption, design: .monospaced))
            Spacer()
            Text(result.hostname ?? "—").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
            if let mac = result.macAddress {
                Text(mac).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            }
            Text(result.status.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(result.status == .alive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            Text(result.rtt.map { String(format: "%.2f ms", $0) } ?? "—")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contextMenu {
            if result.status == .alive {
                Button {
                    tools.ping.start(host: result.ip, count: 20, interval: 1.0)
                    selection = .ping
                } label: {
                    Label("Ping", systemImage: "antenna.radiowaves.left.and.right")
                }

                Button {
                    tools.portScan.scan(host: result.ip,
                                        ports: PortPreset.common.ports ?? [],
                                        concurrency: 50, timeout: 1.5)
                    selection = .portScan
                } label: {
                    Label("Port Scan", systemImage: "checklist")
                }

                Button {
                    tools.traceroute.start(host: result.ip, maxHops: 30, interval: 5.0)
                    selection = .traceroute
                } label: {
                    Label("Traceroute", systemImage: "point.3.connected.trianglepath.dotted")
                }

                Divider()
                Button("Copy IP") { copy(result.ip) }
                if let mac = result.macAddress { Button("Copy MAC") { copy(mac) } }
            }
        }
    }
    
    private var loadingState: some View {
        ToolStateView.loading(message: "Scanning \(viewModel.cidrInput)...")
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Scan Performed",
                            subtitle: "Enter a CIDR block (e.g. 192.168.1.0/24) to discover live hosts on your network.")
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
