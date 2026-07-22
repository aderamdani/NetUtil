import SwiftUI

struct LookupCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Infrastructure Lookup", icon: "magnifyingglass.circle.fill")

            GlassEffectContainer {
                HStack(spacing: 12) {
                    whoisCard
                    subnetCard
                    ipGeolocationCard
                    dnsResolverCard
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var whoisCard: some View {
        BentoStatusCard(
            title: "WHOIS",
            icon: "magnifyingglass.circle",
            color: .gray,
            status: tools.whois.lastQuery.isEmpty ? "Domain Registry" : tools.whois.lastQuery,
            action: { selection = .whois }
        )
    }

    private var subnetCard: some View {
        BentoStatusCard(
            title: "Subnet Calc",
            icon: "number.square",
            color: .green,
            status: "CIDR Toolbox",
            action: { selection = .subnet }
        )
    }

    private var ipGeolocationCard: some View {
        BentoStatusCard(
            title: "IP Geolocation",
            icon: "mappin.and.ellipse",
            color: .pink,
            status: tools.externalIPGeo.map { "\($0.shortLabel)" } ?? "Locate Any IP",
            action: { selection = .ipGeolocation }
        )
    }

    private var dnsResolverCard: some View {
        let primary = tools.dnsResolver.primaryResolver
        let ns = primary?.nameservers.first
        let status: String = {
            guard let ns else { return "Checking..." }
            if let ms = primary?.latencyMs[ns] { return "\(ns) · \(Int(ms))ms" }
            return ns
        }()
        return BentoStatusCard(
            title: "DNS Resolver",
            icon: "server.rack",
            color: .indigo,
            status: status,
            action: { selection = .dnsResolver }
        )
    }
}
