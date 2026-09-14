import XCTest
import SwiftUI
@testable import NetUtil

@MainActor
final class ToolSmokeTests: XCTestCase {

    // MARK: - ToolStore

    func testToolStoreInitializesWithSaneDefaults() {
        // autoStart: false keeps construction inert — no pollers, network,
        // timers, or observers — so this test requires no teardown.
        let store = ToolStore(autoStart: false)

        XCTAssertFalse(store.healthIcon.isEmpty)
        XCTAssertFalse(store.healthColor.isEmpty)
        XCTAssertFalse(store.healthMessage.isEmpty)
        XCTAssertFalse(store.externalIP.isEmpty)
        XCTAssertFalse(store.currentConnectionName.isEmpty)
        XCTAssertFalse(store.primaryLocalIP.isEmpty)
        XCTAssertNil(store.externalIPGeo)
    }

    // MARK: - Initial contract

    func testEveryViewModelStartsIdle() {
        let ping = PingViewModel()
        XCTAssertFalse(ping.isRunning)
        XCTAssertNil(ping.error)
        XCTAssertTrue(ping.results.isEmpty)
        XCTAssertTrue(ping.chartResults.isEmpty)
        XCTAssertTrue(ping.rawLines.isEmpty)
        XCTAssertEqual(ping.stats.transmitted, 0)
        XCTAssertNil(ping.resolvedIP)
        XCTAssertEqual(ping.currentHost, "")

        let traceroute = TracerouteViewModel()
        XCTAssertFalse(traceroute.isRunning)
        XCTAssertNil(traceroute.error)
        XCTAssertTrue(traceroute.hops.isEmpty)
        XCTAssertTrue(traceroute.routeChanges.isEmpty)
        XCTAssertEqual(traceroute.round, 0)
        XCTAssertEqual(traceroute.currentHost, "")
        XCTAssertNil(traceroute.startTime)

        let multiPing = MultiPingViewModel()
        XCTAssertTrue(multiPing.slots.isEmpty)
        XCTAssertEqual(multiPing.sortMode, .alias)

        let slot = PingSlot(host: "1.1.1.1")
        XCTAssertFalse(slot.isRunning)
        XCTAssertTrue(slot.samples.isEmpty)
        XCTAssertEqual(slot.sent, 0)
        XCTAssertEqual(slot.loss, 0)
        XCTAssertNil(slot.lastRtt)
        XCTAssertNil(slot.avgRtt)
        XCTAssertEqual(slot.customName, "1.1.1.1")

        let portScan = PortScanViewModel()
        XCTAssertFalse(portScan.isRunning)
        XCTAssertNil(portScan.error)
        XCTAssertTrue(portScan.results.isEmpty)
        XCTAssertEqual(portScan.scanned, 0)
        XCTAssertEqual(portScan.total, 0)
        XCTAssertEqual(portScan.openCount, 0)

        let dns = DNSViewModel()
        XCTAssertFalse(dns.isRunning)
        XCTAssertNil(dns.error)
        XCTAssertNil(dns.result)
        XCTAssertEqual(dns.rawOutput, "")
        XCTAssertEqual(dns.lastQuery, "")

        let http = HTTPLatencyViewModel()
        XCTAssertFalse(http.isRunning)
        XCTAssertNil(http.error)
        XCTAssertNil(http.result)
        XCTAssertTrue(http.history.isEmpty)

        let ssl = SSLInspectorViewModel()
        XCTAssertFalse(ssl.isRunning)
        XCTAssertNil(ssl.error)
        XCTAssertNil(ssl.result)

        let whois = WhoisViewModel()
        XCTAssertFalse(whois.isRunning)
        XCTAssertNil(whois.error)
        XCTAssertTrue(whois.lines.isEmpty)
        XCTAssertEqual(whois.lastQuery, "")

        let doctor = NetworkDoctorViewModel()
        XCTAssertFalse(doctor.isRunning)
        XCTAssertFalse(doctor.captivePortal)
        XCTAssertNil(doctor.gatewayIP)
        XCTAssertNil(doctor.lastRun)
        XCTAssertEqual(doctor.checks.count, DoctorStepID.allCases.count)
        XCTAssertTrue(doctor.checks.allSatisfy { $0.state == .pending })

        let pathMTU = PathMTUViewModel { _, _ in true }
        XCTAssertFalse(pathMTU.isRunning)
        XCTAssertNil(pathMTU.error)
        XCTAssertTrue(pathMTU.probes.isEmpty)
        XCTAssertNil(pathMTU.mtu)
        XCTAssertEqual(pathMTU.currentHost, "")

        let subnetScan = SubnetScanViewModel()
        XCTAssertFalse(subnetScan.isRunning)
        XCTAssertNil(subnetScan.error)
        XCTAssertTrue(subnetScan.results.isEmpty)
        XCTAssertEqual(subnetScan.progress, 0)

        let subnet = SubnetViewModel()
        XCTAssertNotNil(subnet.result)
        XCTAssertEqual(subnet.ipAddress, "192.168.1.1")
        XCTAssertEqual(subnet.prefix, 24)

        let wifi = WiFiInspectorViewModel()
        XCTAssertFalse(wifi.isRunning)
        XCTAssertNil(wifi.info)
        XCTAssertTrue(wifi.rssiSamples.isEmpty)

        let neighbors = NeighborsViewModel()
        XCTAssertTrue(neighbors.entries.isEmpty)
        XCTAssertNil(neighbors.lastUpdated)
        XCTAssertTrue(neighbors.hostnames.isEmpty)
        XCTAssertTrue(neighbors.resolving.isEmpty)

        let connections = ConnectionsViewModel()
        XCTAssertTrue(connections.connections.isEmpty)
        XCTAssertNil(connections.lastUpdated)

        let portListener = PortListenerViewModel()
        XCTAssertFalse(portListener.isRunning)
        XCTAssertNil(portListener.error)
        XCTAssertTrue(portListener.events.isEmpty)
        XCTAssertEqual(portListener.port, 8080)
        XCTAssertEqual(portListener.proto, .tcp)

        let wol = WakeOnLanViewModel()
        XCTAssertNil(wol.error)
        XCTAssertNil(wol.lastSent)
        XCTAssertEqual(wol.macAddress, "")
        XCTAssertEqual(wol.broadcastAddress, "255.255.255.255")
        XCTAssertEqual(wol.port, 9)

        let ipGeo = IPGeolocationViewModel()
        XCTAssertFalse(ipGeo.isRunning)
        XCTAssertNil(ipGeo.error)
        XCTAssertNil(ipGeo.result)

        let dnsResolver = DNSResolverViewModel()
        XCTAssertFalse(dnsResolver.isRunning)
        XCTAssertNil(dnsResolver.error)
        XCTAssertTrue(dnsResolver.resolvers.isEmpty)
        XCTAssertNil(dnsResolver.lastUpdated)

        let speed = SpeedTestViewModel()
        XCTAssertFalse(speed.isRunning)
        XCTAssertNil(speed.error)
        XCTAssertNil(speed.lastResult)
        XCTAssertEqual(speed.progress, 0)
    }

    // MARK: - Lifecycle

    func testStopIsIdempotentAndSafeBeforeStart() {
        let ping = PingViewModel()
        ping.stop(); ping.stop()
        XCTAssertFalse(ping.isRunning)

        let traceroute = TracerouteViewModel()
        traceroute.stop(); traceroute.stop()
        XCTAssertFalse(traceroute.isRunning)

        let multiPing = MultiPingViewModel()
        multiPing.stopAll(); multiPing.stopAll()

        let portScan = PortScanViewModel()
        portScan.stop(); portScan.stop()
        XCTAssertFalse(portScan.isRunning)

        let dns = DNSViewModel()
        dns.stop(); dns.stop()
        XCTAssertFalse(dns.isRunning)

        let http = HTTPLatencyViewModel()
        http.stop(); http.stop()
        XCTAssertFalse(http.isRunning)

        let ssl = SSLInspectorViewModel()
        ssl.cancel(); ssl.cancel()
        XCTAssertFalse(ssl.isRunning)

        let whois = WhoisViewModel()
        whois.stop(); whois.stop()
        XCTAssertFalse(whois.isRunning)

        let doctor = NetworkDoctorViewModel()
        doctor.stop(); doctor.stop()
        XCTAssertFalse(doctor.isRunning)

        let pathMTU = PathMTUViewModel { _, _ in true }
        pathMTU.stop(); pathMTU.stop()
        XCTAssertFalse(pathMTU.isRunning)

        let subnetScan = SubnetScanViewModel()
        subnetScan.stop(); subnetScan.stop()
        XCTAssertFalse(subnetScan.isRunning)

        let interfaces = NetworkInterfaceViewModel()
        interfaces.stop(); interfaces.stop()

        let wifi = WiFiInspectorViewModel()
        wifi.stop(); wifi.stop()
        XCTAssertFalse(wifi.isRunning)

        let neighbors = NeighborsViewModel()
        neighbors.stop(); neighbors.stop()

        let connections = ConnectionsViewModel()
        connections.stop(); connections.stop()

        let portListener = PortListenerViewModel()
        portListener.stop(); portListener.stop()
        XCTAssertFalse(portListener.isRunning)

        let ipGeo = IPGeolocationViewModel()
        ipGeo.stop(); ipGeo.stop()
        XCTAssertFalse(ipGeo.isRunning)

        let dnsResolver = DNSResolverViewModel()
        dnsResolver.stop(); dnsResolver.stop()
        XCTAssertFalse(dnsResolver.isRunning)

        let speed = SpeedTestViewModel()
        speed.cancel(); speed.cancel()
        XCTAssertFalse(speed.isRunning)
    }

    func testClearErrorResetsSurfacedErrors() async {
        // Invalid port fails its range guard before touching NWListener.
        let listener = PortListenerViewModel()
        listener.port = 0
        listener.start()
        XCTAssertNotNil(listener.error)
        XCTAssertFalse(listener.isRunning)
        listener.clearError()
        XCTAssertNil(listener.error)

        // Invalid MAC fails validation before the UDP socket is opened.
        let wol = WakeOnLanViewModel()
        wol.macAddress = "not-a-mac"
        wol.send()
        XCTAssertNotNil(wol.error)
        wol.clearError()
        XCTAssertNil(wol.error)

        // Malformed CIDR fails validation before any ping sweep starts.
        let subnetScan = SubnetScanViewModel()
        subnetScan.cidrInput = "not-a-cidr"
        await subnetScan.start()
        XCTAssertNotNil(subnetScan.error)
        XCTAssertTrue(subnetScan.results.isEmpty)
        subnetScan.clearError()
        XCTAssertNil(subnetScan.error)
    }

    // MARK: - Tool surface

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
        _ = NetworkInterfaceView(vm: NetworkInterfaceViewModel(), selection: .constant(.dashboard))
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

/// Feeds representative and malformed CLI/API output through every reachable
/// parser so a crash or trap surfaces in CI before release.
@MainActor
final class ToolParserSmokeTests: XCTestCase {

    // MARK: - Ping

    private let pingHeader = "PING google.com (142.250.4.100): 56 data bytes"
    private let pingLine = "64 bytes from 142.250.4.100: icmp_seq=0 ttl=116 time=12.3 ms"
    private let pingLine6 = "64 bytes from 2607:f8b0::1: icmp6_seq=3 hlim=58 time=20.1 ms"

    func testPingParser() {
        XCTAssertEqual(PingViewModel.parseHeader(pingHeader), "142.250.4.100")
        XCTAssertNil(PingViewModel.parseHeader(""))
        XCTAssertNil(PingViewModel.parseHeader("round-trip min/avg/max = 1/2/3 ms"))

        let v4 = PingViewModel.parseLine(pingLine, ip: "142.250.4.100")
        XCTAssertEqual(v4?.rtt, 12.3)
        XCTAssertEqual(v4?.sequence, 0)
        XCTAssertEqual(v4?.status, .success)

        XCTAssertNotNil(PingViewModel.parseLine(pingLine6, ip: nil))
        XCTAssertNil(PingViewModel.parseLine("", ip: nil))
        XCTAssertNil(PingViewModel.parseLine(pingHeader, ip: nil))

        XCTAssertEqual(PingViewModel.parseTimeout("Request timeout for icmp_seq 5"), 5)
        XCTAssertEqual(PingViewModel.parseTimeout("Request timeout for icmp6_seq 9"), 9)
        XCTAssertNil(PingViewModel.parseTimeout(""))
        XCTAssertNil(PingViewModel.parseTimeout(pingLine))
    }

    // MARK: - Traceroute

    func testTracerouteParser() {
        let hop = TracerouteViewModel.parseLine("1  192.168.1.1 (192.168.1.1)  0.345 ms  0.211 ms  0.198 ms")
        XCTAssertEqual(hop?.hop, 1)
        XCTAssertEqual(hop?.ip, "192.168.1.1")
        XCTAssertEqual(hop?.rtts.compactMap { $0 }, [0.345, 0.211, 0.198])

        XCTAssertEqual(TracerouteViewModel.parseLine("2  * * *")?.rtts.count, 3)
        XCTAssertNil(TracerouteViewModel.parseLine(""))
        XCTAssertNil(TracerouteViewModel.parseLine("traceroute to google.com (1.2.3.4), 30 hops max"))

        let changed = TracerouteViewModel.changedHopNumbers(previous: ["1.1.1.1", "2.2.2.2"],
                                                            current: ["1.1.1.1", "3.3.3.3"])
        XCTAssertEqual(changed?.changed, [2])
        XCTAssertNil(TracerouteViewModel.changedHopNumbers(previous: [], current: [nil]))
        XCTAssertNil(TracerouteViewModel.changedHopNumbers(previous: [], current: []))
    }

    // MARK: - Multi-Ping

    func testMultiPingParser() {
        guard case .some(.some(let rtt)) = PingSlot.parseLine("64 bytes from 1.1.1.1: icmp_seq=0 ttl=55 time=12.3 ms") else {
            return XCTFail("expected rtt")
        }
        XCTAssertEqual(rtt, 12.3)

        guard case .some(.none) = PingSlot.parseLine("Request timeout for icmp_seq 3") else {
            return XCTFail("expected timeout sentinel")
        }
        guard case .some(.none) = PingSlot.parseLine("ping: sendto: No route to host") else {
            return XCTFail("expected loss sentinel")
        }
        if case .some = PingSlot.parseLine("") { XCTFail("empty line should not parse") }
        if case .some = PingSlot.parseLine("PING 1.1.1.1 (1.1.1.1): 56 data bytes") {
            XCTFail("header line should not parse")
        }
    }

    // MARK: - DNS (dig)

    private let digSample = """
    ; <<>> DiG 9.10 <<>> example.com A
    ;; global options: +cmd
    ;; Got answer:
    ;; ANSWER SECTION:
    example.com.\t\t3600\tIN\tA\t93.184.216.34
    example.com.\t\t3600\tIN\tA\t93.184.216.35

    ;; Query time: 23 msec
    ;; SERVER: 8.8.8.8#53(8.8.8.8)
    """

    func testDNSParser() {
        let result = DNSViewModel.parse(output: digSample, serverAddress: "8.8.8.8")
        XCTAssertEqual(result.records.count, 2)
        XCTAssertEqual(result.queryTimeMs, 23)
        XCTAssertEqual(result.server, "8.8.8.8")

        let empty = DNSViewModel.parse(output: "", serverAddress: nil)
        XCTAssertTrue(empty.records.isEmpty)
        XCTAssertEqual(empty.server, "system")

        let garbage = DNSViewModel.parse(output: "not dig output\nrandom text", serverAddress: "1.1.1.1")
        XCTAssertTrue(garbage.records.isEmpty)
    }

    // MARK: - WHOIS

    func testWhoisParser() {
        let parsed = WhoisViewModel.parse("Domain Name: example.com\nNo colon here\nRegistrar: Example Inc")
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].label, "Domain Name")
        XCTAssertEqual(parsed[0].value, "example.com")
        XCTAssertNil(parsed[1].label)
        XCTAssertEqual(parsed[2].label, "Registrar")

        // Empty input yields no labelled fields (it does not trap).
        XCTAssertTrue(WhoisViewModel.parse("").allSatisfy { $0.label == nil })
    }

    // MARK: - networkQuality

    private let netQualitySample = """
    {"base_rtt": 66.29, "dl_throughput": 363052160, "ul_throughput": 371732064,
     "responsiveness": 423.99, "interface_name": "en4",
     "test_endpoint": "sgsin4-edge-fx-023.aaplimg.com"}
    """

    func testNetQualityParser() {
        let result = NetQualityViewModel.parse(netQualitySample)
        XCTAssertEqual(result?.responsivenessRPM, 424)
        XCTAssertEqual(result?.interfaceName, "en4")
        XCTAssertEqual(result?.rpmGrade.label, "Medium")

        XCTAssertNil(NetQualityViewModel.parse(""))
        XCTAssertNil(NetQualityViewModel.parse("not json"))
        XCTAssertNil(NetQualityViewModel.parse(#"{"dl_throughput": 1000000}"#))
    }

    // MARK: - ARP

    private let arpSample = """
    ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
    ? (192.168.1.50) at (incomplete) on en0 ifscope [ethernet]
    garbage line without structure
    """

    func testARPParser() {
        let entries = ARPEntry.parse(arpSample)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].kind, .host)
        XCTAssertNil(entries[1].mac)

        XCTAssertTrue(ARPEntry.parse("").isEmpty)
        XCTAssertTrue(ARPEntry.parse("garbage line without structure").isEmpty)
    }

    // MARK: - lsof

    private let lsofSample = """
    COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    Safari     1234 aderamdani   45u  IPv4 0xabc      0t0  TCP 192.168.1.5:52034->17.253.144.10:443 (ESTABLISHED)
    node       5678 aderamdani   23u  IPv6 0xdef      0t0  TCP *:8080 (LISTEN)
    weird       999 aderamdani    3u  IPv4 0x456      0t0  ICMP *:*
    """

    func testNetConnectionParser() {
        let connections = NetConnection.parse(lsofSample)
        XCTAssertEqual(connections.count, 2)
        XCTAssertEqual(connections.first { $0.command == "Safari" }?.remote, "17.253.144.10:443")
        XCTAssertTrue(connections.first { $0.command == "node" }?.isListening ?? false)

        XCTAssertTrue(NetConnection.parse("").isEmpty)
        XCTAssertTrue(NetConnection.parse("COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME").isEmpty)
    }

    // MARK: - scutil --dns

    private let scutilSample = """
    DNS configuration

    resolver #1
      nameserver[0] : 1.1.1.1
      reach    : 0x00000002 (Reachable)

    DNS configuration (for scoped queries)

    resolver #1
      nameserver[0] : 192.168.1.1
      if_index : 21 (en4)
      reach    : 0x00020002 (Reachable)
    """

    func testDNSResolverEntryParser() {
        let entries = DNSResolverEntry.parse(scutilSample)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { !$0.isScoped }?.nameservers, ["1.1.1.1"])
        XCTAssertEqual(entries.first { $0.isScoped }?.interface, "en4")

        XCTAssertTrue(DNSResolverEntry.parse("").isEmpty)
        XCTAssertTrue(DNSResolverEntry.parse("not scutil output").isEmpty)
    }

    // MARK: - IP geolocation

    func testIPGeoParser() {
        let json = """
        {"ip":"8.8.8.8","hostname":"dns.google","city":"Mountain View","region":"California",
         "country":"US","org":"AS15169 Google LLC","postal":"94043",
         "timezone":"America/Los_Angeles","loc":"37.4056,-122.0775"}
        """
        guard let data = json.data(using: .utf8) else { return XCTFail("bad fixture") }
        let result = IPGeoResult.parse(data)
        XCTAssertEqual(result?.ip, "8.8.8.8")
        XCTAssertEqual(result?.asn, "AS15169")
        XCTAssertEqual(result?.ispName, "Google LLC")

        XCTAssertNil(IPGeoResult.parse("not json".data(using: .utf8) ?? Data()))
        XCTAssertNil(IPGeoResult.parse(#"{"city":"Nowhere"}"#.data(using: .utf8) ?? Data()))
    }

    // MARK: - Non-string models (Port / HTTP / Route / cert / subnet)

    func testModelParsersHandleRepresentativeAndMalformedInput() {
        XCTAssertEqual(PortStatus(rawValue: "open")?.label, "Open")
        XCTAssertNil(PortStatus(rawValue: "bogus"))
        let port = PortResult(port: 443, status: .open, service: wellKnownPorts[443], responseMs: 1.2)
        XCTAssertEqual(port.service, "HTTPS")

        let timing = HTTPPhaseTiming(phase: .tcp, startMs: 10, durationMs: 5)
        XCTAssertEqual(timing.endMs, 15)

        XCTAssertTrue(RouteEntry(destination: "default", gateway: "g", flags: "UG", netif: "en0", isIPv6: false).isDefault)
        XCTAssertFalse(RouteEntry(destination: "10.0.0.0/8", gateway: "g", flags: "UG", netif: "en0", isIPv6: false).isDefault)

        let unknownExpiry = CertInfo(subject: "cn", issuer: "ca", notBefore: nil, notAfter: nil,
                                     serialNumber: "00", sans: [], keyType: "RSA-2048", sha256: "ab", isLeaf: true)
        XCTAssertNil(unknownExpiry.daysRemaining)
        XCTAssertEqual(unknownExpiry.expiryColor, "secondary")
        let expired = CertInfo(subject: "cn", issuer: "ca", notBefore: nil,
                               notAfter: Date().addingTimeInterval(-86_400), serialNumber: "00",
                               sans: [], keyType: "RSA-2048", sha256: "ab", isLeaf: true)
        XCTAssertEqual(expired.expiryColor, "red")

        let subnet = NetworkMath.calculateSubnet(ip: "192.168.1.50", prefix: 24)
        XCTAssertEqual(subnet?.networkAddress, "192.168.1.0")
        XCTAssertEqual(subnet?.usableHosts, 254)
        XCTAssertNil(NetworkMath.calculateSubnet(ip: "999.1.1.1", prefix: 24))
        XCTAssertNotNil(NetworkMath.calculateSubnet(ip: "10.0.0.0", prefix: 0))
    }

    // MARK: - Wake on LAN

    func testWakeOnLanMACParser() {
        XCTAssertEqual(WakeOnLan.parseMAC("AA:BB:CC:DD:EE:FF")?.count, 6)
        XCTAssertNil(WakeOnLan.parseMAC(""))
        XCTAssertNil(WakeOnLan.parseMAC("GG:BB:CC:DD:EE:FF"))
    }
}
