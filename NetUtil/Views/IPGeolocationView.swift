import SwiftUI
import MapKit

struct IPGeolocationView: View {
    @Bindable var vm: IPGeolocationViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var showLearningGuide = false
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    if let result = vm.result {
                        summarySection(result)
                        statsGrid(result)
                        if let coordinate = result.coordinate {
                            mapSection(coordinate: coordinate, result: result)
                        }
                    } else if !vm.isRunning && vm.error == nil {
                        ToolStateView.empty(title: "No Lookup Yet",
                                            subtitle: "Leave the field blank and press Return to locate your own public IP, or enter any IP/hostname to locate it.")
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            if vm.result == nil, vm.query.isEmpty, let cached = tools.externalIPGeo {
                vm.seed(cached)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "IP Geolocation") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        ToolControlBar(icon: "mappin.and.ellipse", title: "IP Geolocation",
                       host: $vm.query, placeholder: "IP or hostname (blank = my IP)",
                       textFieldAccessibilityLabel: "IP Address or Hostname Input",
                       history: history, onSubmit: startAction,
                       onSelectHistory: { h in vm.query = h; startAction() }) {
            if let result = vm.result {
                ReportMenuButton(
                    onExportPDF: { Exporter.saveIPGeolocationPDF(result: result) },
                    onExportCSV: {
                        let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                        Exporter.save(string: Exporter.csvString(from: result),
                                      defaultName: "NetUtil-IPGeo-\(result.ip)-\(ts.string(from: Date())).csv",
                                      ext: "csv")
                    }
                )
            }

            Button(action: startAction) {
                Label(vm.isRunning ? "Locating..." : "Locate", systemImage: "location.magnifyingglass")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.glassProminent)
            .disabled(vm.isRunning)
            .accessibilityLabel("Locate IP Address")

            Button { showLearningGuide = true } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Show Help Guide")
        }
    }

    private func startAction() {
        if !vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
            history.record(vm.query)
        }
        vm.start()
    }

    private var moodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .accentColor, "Looking up \(vm.lastQuery ?? "IP")...") }
            guard let result = vm.result else {
                return ("mappin.and.ellipse", .secondary, "Resolves the country, city, and network operator behind any public IP address")
            }
            return ("checkmark.circle.fill", .green, "\(result.ip) resolves to \(result.shortLabel)")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Result

    private func summarySection(_ r: IPGeoResult) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(r.flag)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(r.ip)
                    .font(.headline)
                    .textSelection(.enabled)
                Text([r.city, r.region, r.country].filter { !$0.isEmpty }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                let summary = "IP: \(r.ip)\nLocation: \(r.city), \(r.region), \(r.country)\nISP: \(r.ispName)\nHostname: \(r.hostname ?? "—")"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(summary, forType: .string)
            } label: {
                Label("Copy Info", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy result summary to clipboard")
        }
    }

    private func statsGrid(_ r: IPGeoResult) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SubnetDetailCard(label: "ISP / Org", value: r.ispName, icon: "building.2")
            SubnetDetailCard(label: "ASN", value: r.asn ?? "—", icon: "number")
            SubnetDetailCard(label: "Hostname", value: r.hostname ?? "—", icon: "textformat")
            SubnetDetailCard(label: "Postal Code", value: r.postal ?? "—", icon: "envelope")
            SubnetDetailCard(label: "Timezone", value: r.timezone ?? "—", icon: "clock")
            SubnetDetailCard(label: "Region", value: r.region.isEmpty ? "—" : r.region, icon: "map")
        }
    }

    private func mapSection(coordinate: CLLocationCoordinate2D, result: IPGeoResult) -> some View {
        Map(position: $position) {
            Annotation(result.shortLabel, coordinate: coordinate) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 2)
                    Image(systemName: "mappin")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .onAppear {
            position = .region(MKCoordinateRegion(center: coordinate,
                                                   span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)))
        }
        .onChange(of: result.ip) {
            position = .region(MKCoordinateRegion(center: coordinate,
                                                   span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)))
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg).font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
