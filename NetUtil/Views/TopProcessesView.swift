import SwiftUI

struct TopProcessesView: View {
    var vm: TopProcessesViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            VStack(spacing: 24) {
                if let err = vm.error {
                    errorBanner(err)
                }
                
                interpretationSection
                
                statsBarSection
                
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Real-time App Traffic", icon: "app.dashed")
                    
                    if vm.apps.isEmpty {
                        emptyState
                    } else {
                        processTable
                    }
                }
            }
            .padding(24)
        }
        .onAppear { if !vm.isRunning { vm.start() } }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Top Processes") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Top Processes")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Top Processes Tool")
                
                Spacer()
                
                HStack(spacing: 16) {
                    if vm.isRunning {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Monitoring").font(.system(size: 11, weight: .bold)).foregroundColor(.green)
                        }
                        .accessibilityLabel("Monitoring active")
                    }
                    
                    Divider().frame(height: 16)

                    ReportMenuButton(
                        onExportPDF: {},
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: Exporter.csvString(from: vm.apps),
                                          defaultName: "NetUtil-TopProcesses-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )

                    Button(action: { if vm.isRunning { vm.stop() } else { vm.start() } }) {
                        Label(vm.isRunning ? "Stop" : "Start", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .accessibilityLabel(vm.isRunning ? "Stop Monitoring" : "Start Monitoring")

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
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var interpretationSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill((vm.isRunning ? Color.green : Color.secondary).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "cpu")
                    .foregroundColor(vm.isRunning ? .green : .secondary)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.isRunning ? "Activity Monitor Active" : "Process Monitor Idle")
                    .font(.headline)
                Text("Analyzing per-application network utilization via nettop.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(vm.isRunning ? "Activity Monitor Active" : "Process Monitor Idle")
            
            Spacer()
        }
    }

    private var statsBarSection: some View {
        let totalRx = vm.apps.map(\.rxBps).reduce(0, +)
        let totalTx = vm.apps.map(\.txBps).reduce(0, +)
        return HStack(spacing: 12) {
            StatCard(title: "Active Apps", value: "\(vm.apps.count)", icon: "app.badge.fill")
                .accessibilityElement(children: .combine)
            StatCard(title: "Total Download", value: NetworkMath.formatRate(totalRx), icon: "arrow.down", color: .blue)
                .accessibilityElement(children: .combine)
                .accessibilityValue(NetworkMath.formatRate(totalRx))
            StatCard(title: "Total Upload", value: NetworkMath.formatRate(totalTx), icon: "arrow.up", color: .orange)
                .accessibilityElement(children: .combine)
                .accessibilityValue(NetworkMath.formatRate(totalTx))
        }
    }

    private var processTable: some View {
        let maxBps = max(vm.apps.map { max($0.rxBps, $0.txBps) }.max() ?? 1, 1024)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Process Name", flexible: true)
                tHeader("Download", width: 100)
                tHeader("Upload", width: 100)
                tHeader("Load Intensity", width: 140)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(.regularMaterial)
            .accessibilityElement(children: .ignore)
            
            Divider()
            
            List {
                ForEach(vm.apps) { app in
                    HStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Text(app.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(NetworkMath.formatRate(app.rxBps))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                            .frame(width: 100, alignment: .leading)
                        
                        Text(NetworkMath.formatRate(app.txBps))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 100, alignment: .leading)
                        
                        activityIntensityBar(rx: app.rxBps, tx: app.txBps, maxBps: maxBps)
                            .frame(width: 140)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.visible, edges: .bottom)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Process \(app.name). Download: \(NetworkMath.formatRate(app.rxBps)), Upload: \(NetworkMath.formatRate(app.txBps))")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func activityIntensityBar(rx: Double, tx: Double, maxBps: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let rxFrac = CGFloat(rx / maxBps)
            let txFrac = CGFloat(tx / maxBps)
            VStack(spacing: 3) {
                Capsule().fill(Color.blue.opacity(0.6)).frame(width: w * rxFrac, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Capsule().fill(Color.orange.opacity(0.6)).frame(width: w * txFrac, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 14)
        .accessibilityLabel("Activity intensity bar")
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
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
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        .accessibilityLabel("Error: \(msg)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(vm.isRunning ? "No Active Traffic" : "Monitoring Paused")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(vm.isRunning ? "No processes are currently transmitting data." : "Start monitoring to see per-process network load.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .accessibilityElement(children: .combine)
    }
}
