import SwiftUI

struct TopProcessesView: View {
    @ObservedObject var vm: TopProcessesViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)

            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.system(size: 12, weight: .medium)).padding(.bottom, 16)
            }

            statsBar.padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Active Processes")
                if vm.apps.isEmpty {
                    emptyState
                } else {
                    processTable
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(32)
        .onAppear { if !vm.isRunning { vm.start() } }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) { learningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle").foregroundColor(.accentColor)
                Text("Top Processes").font(.headline)
            }.frame(width: 250, alignment: .leading)

            Spacer()

            Button(action: { if vm.isRunning { vm.stop() } else { vm.start() } }) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                    Text(vm.isRunning ? "Stop" : "Start")
                }.font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.borderless)
        }
    }

    private var statsBar: some View {
        let totalRx = vm.apps.map(\.rxBps).reduce(0, +)
        let totalTx = vm.apps.map(\.txBps).reduce(0, +)
        return HStack(spacing: 12) {
            StatCard(title: "Active", value: "\(vm.apps.count)", icon: "circle.fill", color: vm.isRunning ? .green : .secondary)
            StatCard(title: "Download", value: formatRate(totalRx), icon: "arrow.down", color: .blue)
            StatCard(title: "Upload", value: formatRate(totalTx), icon: "arrow.up", color: .orange)
            Spacer()
        }
    }

    private var processTable: some View {
        let maxBps = max(vm.apps.map { max($0.rxBps, $0.txBps) }.max() ?? 1, 1024)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Process", flexible: true)
                tHeader("Download", width: 100)
                tHeader("Upload", width: 100)
                tHeader("Activity", width: 140)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.apps) { app in
                        HStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: "app.dashed").foregroundColor(.secondary).font(.system(size: 12))
                                Text(app.name).font(.system(size: 12)).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatRate(app.rxBps)).font(.system(size: 11, design: .monospaced)).foregroundColor(.blue).frame(width: 100, alignment: .leading)
                            Text(formatRate(app.txBps)).font(.system(size: 11, design: .monospaced)).foregroundColor(.orange).frame(width: 100, alignment: .leading)
                            activityBar(rx: app.rxBps, tx: app.txBps, maxBps: maxBps).frame(width: 140)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func activityBar(rx: Double, tx: Double, maxBps: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let rxFrac = CGFloat(rx / maxBps)
            let txFrac = CGFloat(tx / maxBps)
            VStack(spacing: 2) {
                Capsule().fill(Color.blue.opacity(0.75)).frame(width: w * rxFrac, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Capsule().fill(Color.orange.opacity(0.75)).frame(width: w * txFrac, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 12)
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            .frame(width: width, alignment: .leading).frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private var emptyState: some View {
        VStack { Spacer(); Text(vm.isRunning ? "Waiting for traffic..." : "Press Start to begin").font(.headline).foregroundColor(.secondary); Spacer() }
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f K/s", bps / 1024) }
        return String(format: "%.2f M/s", bps / 1_048_576)
    }

    private var learningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Top Processes Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) {
                GuideSection(title: "How it works", icon: "list.bullet.rectangle") {
                    Text("Reads /usr/bin/nettop in delta mode to report per-process upload and download rates in real-time. nettop is a built-in macOS tool — no additional privileges required.")
                }
                GuideSection(title: "Reading the table", icon: "chart.bar") {
                    Text("Download (blue) and Upload (orange) bars are normalised against the busiest process. Use this to identify which app is consuming your bandwidth.")
                }
            }.padding(24) }
        }.frame(width: 500, height: 500)
    }
}
