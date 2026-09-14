import XCTest
import SwiftUI
@testable import NetUtil

@MainActor
final class ToolSmokeTests: XCTestCase {

    func testEveryViewModelInstantiatesAndResets() {
        let dnsResolver = DNSResolverViewModel()
        dnsResolver.clearError(); dnsResolver.stop()
        XCTAssertFalse(dnsResolver.isRunning)

        let dns = DNSViewModel()
        dns.clearError(); dns.stop()
        XCTAssertFalse(dns.isRunning)

        let http = HTTPLatencyViewModel()
        http.clearError(); http.stop()
        XCTAssertFalse(http.isRunning)

        let geo = IPGeolocationViewModel()
        geo.clearError(); geo.stop()
        XCTAssertFalse(geo.isRunning)

        let multiPing = MultiPingViewModel()
        multiPing.stopAll()

        let neighbors = NeighborsViewModel()
        neighbors.stop()

        let netQuality = NetQualityViewModel()
        netQuality.clearError(); netQuality.stop()
        XCTAssertFalse(netQuality.isRunning)

        let doctor = NetworkDoctorViewModel()
        doctor.stop()
        XCTAssertFalse(doctor.isRunning)

        let interfaces = NetworkInterfaceViewModel()
        interfaces.stop()

        let pathMTU = PathMTUViewModel()
        pathMTU.clearError(); pathMTU.stop()
        XCTAssertFalse(pathMTU.isRunning)

        let ping = PingViewModel()
        ping.clearError(); ping.stop()
        XCTAssertFalse(ping.isRunning)

        let listener = PortListenerViewModel()
        listener.clearError(); listener.stop()
        XCTAssertFalse(listener.isRunning)

        let portScan = PortScanViewModel()
        portScan.clearError(); portScan.stop()
        XCTAssertFalse(portScan.isRunning)

        let ssl = SSLInspectorViewModel()
        ssl.clearError(); ssl.cancel()
        XCTAssertFalse(ssl.isRunning)

        let speed = SpeedTestViewModel()
        speed.clearError(); speed.cancel()
        XCTAssertFalse(speed.isRunning)

        let subnetScan = SubnetScanViewModel()
        subnetScan.clearError(); subnetScan.stop()
        XCTAssertFalse(subnetScan.isRunning)

        let traceroute = TracerouteViewModel()
        traceroute.clearError(); traceroute.stop()
        XCTAssertFalse(traceroute.isRunning)

        let wol = WakeOnLanViewModel()
        wol.clearError()

        let whois = WhoisViewModel()
        whois.clearError(); whois.stop()
        XCTAssertFalse(whois.isRunning)

        let wifi = WiFiInspectorViewModel()
        wifi.stop()

        _ = ConnectionsViewModel()
        _ = SubnetViewModel()
        _ = ThroughputStatisticsViewModel(samples: [])
    }

    func testToolEnumSurface() {
        XCTAssertEqual(Tool.allCases.count, 28)
        for tool in Tool.allCases {
            XCTAssertFalse(tool.icon.isEmpty)
            XCTAssertFalse(tool.displayName.isEmpty)
            XCTAssertFalse(tool.persistenceKey.isEmpty)
            XCTAssertNotNil(Tool(persistenceKey: tool.persistenceKey))
        }
    }

    func testEveryToolViewConstructs() {
        let doctor = NetworkDoctorViewModel()
        let subnetScan = SubnetScanViewModel()
        let selection: Binding<Tool?> = .constant(.dashboard)

        _ = DashboardView(selection: selection)
        _ = NetworkDoctorView(vm: doctor, selection: selection)
        _ = PingView(vm: PingViewModel())
        _ = TracerouteView(vm: TracerouteViewModel())
        _ = DNSView(vm: DNSViewModel())
        _ = PortScanView(vm: PortScanViewModel())
        _ = NetworkInterfaceView(vm: NetworkInterfaceViewModel())
        _ = HTTPLatencyView(vm: HTTPLatencyViewModel())
        _ = PathMTUView(vm: PathMTUViewModel())
        _ = MultiPingView(vm: MultiPingViewModel())
        _ = WiFiInspectorView(vm: WiFiInspectorViewModel())
        _ = RouteTableView()
        _ = NeighborsView(vm: NeighborsViewModel())
        _ = ConnectionsView(vm: ConnectionsViewModel())
        _ = SSLInspectorView(vm: SSLInspectorViewModel())
        _ = WhoisView(vm: WhoisViewModel())
        _ = BandwidthView()
        _ = SubnetCalculatorView(vm: SubnetViewModel())
        _ = SubnetScanView(viewModel: subnetScan, selection: selection)
        _ = StatisticsView()
        _ = SpeedTestView(vm: SpeedTestViewModel())
        _ = NetQualityView(vm: NetQualityViewModel())
        _ = WakeOnLanView(vm: WakeOnLanViewModel())
        _ = PortListenerView(vm: PortListenerViewModel())
        _ = IPGeolocationView(vm: IPGeolocationViewModel())
        _ = DNSResolverView(vm: DNSResolverViewModel())
        _ = SessionHistoryView(selection: selection)
        _ = CompareView()
    }

    func testEmptyAndLoadingStatesRender() {
        _ = ToolStateView.empty(title: "No Result", subtitle: "Run the tool to see data.")
        _ = ToolStateView.loading(message: "Working...")
        _ = MoodBar(icon: "checkmark.circle.fill", color: .green, message: "Ready")
        _ = SectionHeader(title: "Section", icon: "list.bullet")
        _ = PulsingIndicator(color: .green)
    }
}
