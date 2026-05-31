import SwiftUI
import UserNotifications

struct SSLWatchlistView: View {
    @Bindable var watchlist: SSLWatchlist
    
    var body: some View {
        List {
            ForEach(watchlist.items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.domain)
                            .font(.system(.subheadline, design: .monospaced))
                            .bold()
                        Spacer()
                        statusBadge(item.status)
                    }
                    
                    if let expiry = item.expiryDate {
                        Text("Expires: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Unknown status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { watchlist.items.remove(atOffsets: $0) }
        }
        .navigationTitle("SSL Watchlist")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await watchlist.checkAll() } }) {
                    Label("Check All", systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    @ViewBuilder
    private func statusBadge(_ status: ExpiryStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(status.color).opacity(0.2))
            .foregroundColor(Color(status.color))
            .cornerRadius(4)
    }
}
