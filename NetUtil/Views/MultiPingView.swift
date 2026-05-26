import SwiftUI

struct MultiPingView: View {
    @StateObject private var vm = MultiPingViewModel()
    @StateObject private var history = HostHistory.shared
    @State private var newHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addBar
            if vm.slots.isEmpty {
                emptyState
            } else {
                slotsTable
            }
        }
        .padding()
        .onDisappear { vm.stopAll() }
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Add host or IP", text: $newHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit { addHost() }
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
                }
            }

            Button("Add") { addHost() }
                .disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return)

            Spacer()

            if !vm.slots.isEmpty {
                Button("Stop All") { vm.stopAll() }
                    .buttonStyle(.borderless)
                Button("Start All") { vm.startAll() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var slotsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("Host", flexible: true)
                headerCell("Snt", width: 50)
                headerCell("Loss%", width: 65)
                headerCell("Last (ms)", width: 80)
                headerCell("Avg (ms)", width: 80)
                headerCell("Graph", width: 140)
                headerCell("", width: 30)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.slots) { slot in
                        SlotRow(slot: slot) {
                            vm.remove(slot)
                        }
                        Divider().opacity(0.5)
                    }
                }
            }
            .background(Color(.textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Add hosts to ping simultaneously")
                .foregroundColor(.secondary)
                .font(.callout)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(.secondary)
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

private struct SlotRow: View {
    @ObservedObject var slot: PingSlot
    let onRemove: () -> Void
    @AppStorage("rttWarnThreshold") private var rttWarn: Double = 20.0
    @AppStorage("rttCritThreshold") private var rttCrit: Double = 100.0

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(slot.host)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(slot.sent)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 50, alignment: .trailing)

            lossCell

            rttCell(slot.lastRtt, width: 80)
            rttCell(slot.avgRtt, width: 80)

            sparkline

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 30)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(rowBackground)
    }

    private var statusColor: Color {
        guard slot.sent > 0 else { return .secondary }
        if slot.loss >= 50 { return .red }
        if slot.loss > 0 { return .orange }
        return .green
    }

    private var rowBackground: Color {
        if slot.loss >= 50 { return Color.red.opacity(0.06) }
        if slot.loss > 0 { return Color.orange.opacity(0.04) }
        return Color.clear
    }

    private var lossCell: some View {
        let text = slot.sent == 0 ? "—" : String(format: "%.1f%%", slot.loss)
        let color: Color = slot.loss == 0 ? .secondary : slot.loss < 10 ? .orange : .red
        return Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(color)
            .frame(width: 65, alignment: .trailing)
    }

    @ViewBuilder
    private func rttCell(_ rtt: Double?, width: CGFloat) -> some View {
        if let rtt {
            Text(String(format: "%.1f", rtt))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(rttColor(rtt))
                .frame(width: width, alignment: .trailing)
        } else {
            Text("—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: width, alignment: .trailing)
        }
    }

    private var sparkline: some View {
        let history = Array(slot.samples.suffix(60))
        let maxVal = history.compactMap { $0.rtt }.max() ?? 1

        return Canvas { ctx, size in
            let slotW = size.width / CGFloat(max(history.count, 30))
            let barW = max(1, slotW - 1)
            for (i, sample) in history.enumerated() {
                let x = CGFloat(i) * slotW
                if let v = sample.rtt {
                    let ratio = CGFloat(v / maxVal)
                    let h = max(3, ratio * (size.height - 4)) + 4
                    let rect = CGRect(x: x, y: size.height - h, width: barW, height: h)
                    ctx.fill(Path(rect), with: .color(rttColor(v).opacity(0.75)))
                } else {
                    let rect = CGRect(x: x, y: size.height - 5, width: barW, height: 5)
                    ctx.fill(Path(rect), with: .color(Color.red.opacity(0.7)))
                }
            }
        }
        .frame(width: 132, height: 26)
        .background(Color(.separatorColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.leading, 8)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .green }
        if rtt < rttCrit { return .orange }
        return .red
    }
}
