import SwiftUI

struct PingResultsTable: View {
    let results: [PingResult]
    let resolvedIP: String?
    let rttWarn: Double
    let rttCrit: Double

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tHeader("Sequence", width: 80)
                tHeader("Status", width: 100)
                tHeader("Latency", width: 120)
                tHeader("Target IP", flexible: true)
                tHeader("Timestamp", width: 120)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(.regularMaterial)

            Divider()

            List {
                ForEach(results) { r in
                    HStack(spacing: 0) {
                        Text("\(r.sequence)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                            .foregroundColor(.secondary)

                        StatusBadge(isSuccess: r.status == .success)
                            .frame(width: 100, alignment: .leading)

                        let rttString = r.status == .success ? String(format: "%.2f ms", r.rtt) : "\u{2014}"
                        Text(rttString)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .frame(width: 120, alignment: .leading)
                            .foregroundColor(rttColor(r.rtt))

                        let ipString = r.ipAddress ?? resolvedIP ?? "\u{2014}"
                        Text(ipString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(r.timestamp, format: .dateTime.hour().minute().second())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.visible, edges: .bottom)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 400)
            .scrollContentBackground(.hidden)
            .scrollPosition(id: .constant(results.last?.id))
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func tHeader(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }

    private func rttColor(_ rtt: Double) -> Color {
        if rtt < rttWarn { return .primary }
        if rtt < rttCrit { return .orange }
        return .red
    }
}

private struct StatusBadge: View {
    let isSuccess: Bool
    var body: some View {
        Text(isSuccess ? "Success" : "Timeout")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(isSuccess ? .green : .red)
    }
}
