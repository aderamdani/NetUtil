import SwiftUI

struct LookupCardsSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Infrastructure Lookup", icon: "magnifyingglass.circle.fill")

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

    private var whoisCard: some View {
        BentoCard(
            title: "WHOIS Lookup",
            icon: "magnifyingglass.circle",
            color: .gray,
            action: { selection = .whois },
            helpText: "Look up domain registration details: registrar, creation/expiry dates, name servers, and contact info."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if tools.whois.lastQuery.isEmpty {
                    Text("Domain Registry")
                        .font(.subheadline.bold())
                    Text("Enter a domain to see registration details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(tools.whois.lastQuery)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if let registrar = tools.whois.lines.first(where: { $0.label?.lowercased().contains("registrar") == true })?.value {
                        Label(registrar, systemImage: "building.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var subnetCard: some View {
        BentoCard(
            title: "Subnet Calculator",
            icon: "number.square",
            color: .green,
            action: { selection = .subnet },
            helpText: "Calculate network ranges, CIDR notation, usable hosts, broadcast address, and subnet masks."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CIDR Toolbox")
                    .font(.subheadline.bold())
                Text("Convert between CIDR, netmask, and host ranges")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var ipGeolocationCard: some View {
        BentoCard(
            title: "IP Geolocation",
            icon: "mappin.and.ellipse",
            color: .pink,
            action: { selection = .ipGeolocation },
            helpText: "Find the geographic location of any IP address: country, city, ISP, and coordinates."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                if let geo = tools.externalIPGeo {
                    HStack {
                        Text(geo.shortLabel)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.pink)
                    }
                    Text("\(geo.city), \(geo.country) — \(geo.ispName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Locate Any IP")
                        .font(.subheadline.bold())
                    Text("Your public IP: \(tools.externalIP)")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var dnsResolverCard: some View {
        let primary = tools.dnsResolver.primaryResolver
        let ns = primary?.nameservers.first
        let status: String = {
            guard let ns else { return "Checking DNS resolver…" }
            if let ms = primary?.latencyMs[ns] { return "\(ns) · \(Int(ms)) ms" }
            return ns
        }()
        let statusColor: Color = {
            guard let ns, let ms = primary?.latencyMs[ns] else { return .secondary }
            return ms < 30 ? .green : (ms < 80 ? .orange : .red)
        }()
        let resolverLabel = primary?.domain ?? "System Resolver"
        return BentoStatusCard(
            title: "DNS Resolver",
            icon: "server.rack",
            color: .indigo,
            status: status,
            action: { selection = .dnsResolver },
            helpText: "See which DNS resolver you're using and its response time. Compare multiple resolvers.",
            statusColor: statusColor,
            detail: resolverLabel
        )
    }
}