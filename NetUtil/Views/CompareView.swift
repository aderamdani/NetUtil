import SwiftUI

struct CompareView: View {
    @Environment(ToolStore.self) private var tools
    @State private var toolFilter = "ping"
    @State private var sessionA: SessionRecord? = nil
    @State private var sessionB: SessionRecord? = nil
    @State private var showLearningGuide = false

    private var history: SessionHistory { tools.sessionHistory }

    private let comparableTools = ["ping", "portScan", "traceroute"]

    private var availableSessions: [SessionRecord] {
        history.records.filter { record in
            record.tool == toolFilter &&
            (record.pingStats != nil || record.portResults != nil || record.tracerouteHops != nil)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            compareMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if sessionA == nil || sessionB == nil {
                        emptyCompareState
                    } else if let a = sessionA, let b = sessionB {
                        compareContent(a: a, b: b)
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Compare") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Compare Sessions")
                        .font(.headline)
                }

                Divider().frame(height: 16).padding(.horizontal, 4)

                Picker("Tool", selection: $toolFilter) {
                    ForEach(comparableTools, id: \.self) { Text(toolLabel($0)).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChange(of: toolFilter) { _, _ in sessionA = nil; sessionB = nil }

                Divider().frame(height: 16)

                // Session A picker
                Menu {
                    ForEach(availableSessions.prefix(20)) { record in
                        Button {
                            sessionA = record
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(record.target)
                                    Text(record.summary).font(.caption)
                                }
                            } icon: {
                                Image(systemName: sessionA?.id == record.id ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                    if availableSessions.isEmpty {
                        Text("No sessions with detail data").foregroundColor(.secondary)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "a.circle").foregroundColor(.accentColor)
                        Text(sessionA.map { truncate($0.target, 18) } ?? "Session A")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(sessionA == nil ? .secondary : .primary)
                        Image(systemName: "chevron.down").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Image(systemName: "arrow.left.arrow.right").foregroundColor(.secondary).font(.caption2)

                // Session B picker
                Menu {
                    ForEach(availableSessions.prefix(20)) { record in
                        Button {
                            sessionB = record
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(record.target)
                                    Text(record.summary).font(.caption)
                                }
                            } icon: {
                                Image(systemName: sessionB?.id == record.id ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                    if availableSessions.isEmpty {
                        Text("No sessions with detail data").foregroundColor(.secondary)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "b.circle").foregroundColor(.accentColor)
                        Text(sessionB.map { truncate($0.target, 18) } ?? "Session B")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(sessionB == nil ? .secondary : .primary)
                        Image(systemName: "chevron.down").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(.separatorColor).opacity(0.2), lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            Divider()
        }
    }

    private var compareMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if availableSessions.count < 2 {
                let need = max(0, 2 - availableSessions.count)
                return ("arrow.left.arrow.right", .secondary,
                        "Need \(need) more \(toolLabel(toolFilter)) session\(need == 1 ? "" : "s") with detail data")
            }
            if sessionA == nil || sessionB == nil {
                return ("arrow.left.arrow.right", .secondary, "Select Session A and Session B to compare")
            }
            return ("checkmark.circle.fill", .green, "Comparing \(toolLabel(toolFilter)) — \(sessionA!.target) vs \(sessionB!.target)")
        }()
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(.callout, weight: .semibold))
            Text(msg).font(.callout).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private var emptyCompareState: some View {
        VStack(spacing: 8) {
            Text("Select Two Sessions").font(.headline).foregroundColor(.secondary)
            Text("Use the Session A and Session B menus above.").font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func truncate(_ s: String, _ n: Int) -> String {
        s.count > n ? String(s.prefix(n - 1)) + "…" : s
    }

    // MARK: - Compare Content

    private func sessionHeaders(a: SessionRecord, b: SessionRecord) -> some View {
        HStack(spacing: 12) {
            sessionHeaderCard(record: a, label: "Session A")
            sessionHeaderCard(record: b, label: "Session B")
        }
    }

    private func sessionHeaderCard(record: SessionRecord, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(record.target).font(.system(.headline, design: .monospaced))
            Text(record.summary).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
            Text(record.timestamp, style: .relative).font(.caption2).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    @ViewBuilder
    private func compareContent(a: SessionRecord, b: SessionRecord) -> some View {
        sessionHeaders(a: a, b: b)
        switch toolFilter {
        case "ping":
            if let sa = a.pingStats, let sb = b.pingStats {
                pingCompare(a: sa, labelA: a.target, b: sb, labelB: b.target)
            }
        case "portScan":
            if let pa = a.portResults, let pb = b.portResults {
                portCompare(a: pa, labelA: a.target, b: pb, labelB: b.target)
            }
        case "traceroute":
            if let ha = a.tracerouteHops, let hb = b.tracerouteHops {
                traceCompare(a: ha, labelA: a.target, b: hb, labelB: b.target)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Ping Compare

    private func pingCompare(a: PingStatsSnapshot, labelA: String, b: PingStatsSnapshot, labelB: String) -> some View {
        let metrics: [(String, String, String, Color?)] = [
            ("Avg RTT", String(format: "%.2f ms", a.avgRtt), String(format: "%.2f ms", b.avgRtt), rttDiffColor(a.avgRtt, b.avgRtt)),
            ("Min RTT", String(format: "%.2f ms", a.minRtt), String(format: "%.2f ms", b.minRtt), nil),
            ("Max RTT", String(format: "%.2f ms", a.maxRtt), String(format: "%.2f ms", b.maxRtt), nil),
            ("Jitter",  String(format: "%.2f ms", a.jitter),  String(format: "%.2f ms", b.jitter),  nil),
            ("Packet Loss", String(format: "%.1f%%", a.lossPercent), String(format: "%.1f%%", b.lossPercent), lossDiffColor(a.lossPercent, b.lossPercent)),
            ("Transmitted", "\(a.transmitted)", "\(b.transmitted)", nil),
        ]
        let improved  = metrics.compactMap { $0.3 }.filter { $0 == .green }.count
        let degraded  = metrics.compactMap { $0.3 }.filter { $0 == .red }.count

        return compareTable(
            title: "Ping Statistics",
            headers: (labelA, labelB),
            rows: metrics,
            summary: "B vs A: \(improved) better, \(degraded) worse"
        )
    }

    // MARK: - Port Scan Compare

    private func portCompare(a: [PortResultSnapshot], labelA: String, b: [PortResultSnapshot], labelB: String) -> some View {
        let openA = Set(a.filter { $0.isOpen }.map { $0.port })
        let openB = Set(b.filter { $0.isOpen }.map { $0.port })
        let allPorts = openA.union(openB).sorted()
        let rows: [(String, String, String, Color?)] = allPorts.map { port in
            let inA = openA.contains(port)
            let inB = openB.contains(port)
            let service = a.first(where: { $0.port == port })?.service ?? b.first(where: { $0.port == port })?.service
            let label = service.map { "\(port) (\($0))" } ?? "\(port)"
            let color: Color? = inA && !inB ? .red : !inA && inB ? .green : nil
            return (label, inA ? "Open" : "—", inB ? "Open" : "—", color)
        }
        let newPorts     = openB.subtracting(openA).count
        let closedPorts  = openA.subtracting(openB).count
        let unchanged    = openA.intersection(openB).count
        return compareTable(
            title: "Open Ports",
            headers: (labelA, labelB),
            rows: rows,
            summary: "\(newPorts) new, \(closedPorts) closed, \(unchanged) unchanged"
        )
    }

    // MARK: - Traceroute Compare

    private func traceCompare(a: [HopSnapshot], labelA: String, b: [HopSnapshot], labelB: String) -> some View {
        let maxHop = max(a.map(\.hop).max() ?? 0, b.map(\.hop).max() ?? 0)
        let rows: [(String, String, String, Color?)] = (1...maxHop).map { hop in
            let ha = a.first(where: { $0.hop == hop })
            let hb = b.first(where: { $0.hop == hop })
            let valA = ha?.avgRttMs.map { String(format: "%.1f ms", $0) } ?? (ha != nil ? "*" : "—")
            let valB = hb?.avgRttMs.map { String(format: "%.1f ms", $0) } ?? (hb != nil ? "*" : "—")
            let color: Color? = rttDiffColor(ha?.avgRttMs ?? 0, hb?.avgRttMs ?? 0)
            return ("Hop \(hop)", valA, valB, color)
        }
        return compareTable(
            title: "Hop-by-Hop RTT",
            headers: (labelA, labelB),
            rows: rows,
            summary: "\(a.count) hops A, \(b.count) hops B"
        )
    }

    // MARK: - Shared Table

    private func compareTable(title: String, headers: (String, String), rows: [(String, String, String, Color?)], summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Metric").font(.caption2.weight(.bold)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text(headers.0).font(.caption2.weight(.bold)).foregroundColor(.secondary).frame(width: 160, alignment: .leading).lineLimit(1)
                    Text(headers.1).font(.caption2.weight(.bold)).foregroundColor(.secondary).frame(width: 160, alignment: .leading).lineLimit(1)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial)

                Divider()

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 0) {
                        Text(row.0).font(.system(size: 11, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.1).font(.system(size: 11, design: .monospaced)).foregroundColor(row.3 == .red ? .primary : .primary).frame(width: 160, alignment: .leading)
                        Text(row.2).font(.system(size: 11, design: .monospaced)).foregroundColor(row.3 ?? .primary).frame(width: 160, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.03))

                    if idx < rows.count - 1 { Divider().padding(.horizontal, 16).opacity(0.4) }
                }

                Divider()

                HStack {
                    Text(summary).font(.system(.caption2, design: .monospaced)).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.regularMaterial)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    // MARK: - Helpers

    private func rttDiffColor(_ a: Double, _ b: Double) -> Color? {
        guard a > 0, b > 0 else { return nil }
        return b < a * 0.95 ? .green : b > a * 1.05 ? .red : nil
    }

    private func lossDiffColor(_ a: Double, _ b: Double) -> Color? {
        if b < a { return .green }
        if b > a { return .red }
        return nil
    }

    private func toolLabel(_ key: String) -> String {
        switch key {
        case "ping":       return "Ping"
        case "portScan":   return "Port Scanner"
        case "traceroute": return "Traceroute"
        default:           return key
        }
    }
}
