import Foundation
import Network
import Observation

@MainActor
@Observable
final class BonjourBrowserViewModel {
    var discoveredServices: [BonjourService] = []
    var isScanning: Bool = false
    var selectedServiceType: String = "_http._tcp"
    var searchFilter: String = ""
    
    private var browser: NWBrowser?
    
    struct ServiceTypePreset: Identifiable {
        let id: String
        let name: String
    }
    
    let availableServiceTypes: [ServiceTypePreset] = [
        ServiceTypePreset(id: "_http._tcp", name: "Web Servers"),
        ServiceTypePreset(id: "_ssh._tcp", name: "SSH"),
        ServiceTypePreset(id: "_printer._tcp", name: "Printers"),
        ServiceTypePreset(id: "_ipp._tcp", name: "IPP Printers"),
        ServiceTypePreset(id: "_airplay._tcp", name: "AirPlay"),
        ServiceTypePreset(id: "_raop._tcp", name: "AirPlay Audio"),
        ServiceTypePreset(id: "_smb._tcp", name: "SMB File Sharing"),
        ServiceTypePreset(id: "_afpovertcp._tcp", name: "AFP File Sharing"),
        ServiceTypePreset(id: "_googlecast._tcp", name: "Chromecast"),
        ServiceTypePreset(id: "_spotify-connect._tcp", name: "Spotify Connect"),
        ServiceTypePreset(id: "_companion-link._tcp", name: "HomeKit"),
        ServiceTypePreset(id: "_sleep-proxy._udp", name: "Sleep Proxy")
    ]
    
    func startBrowsing() {
        stopBrowsing()
        isScanning = true
        discoveredServices.removeAll()
        
        let parameters = NWParameters.tcp
        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: selectedServiceType, domain: "local.")
        let browser = NWBrowser(for: browserDescriptor, using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleBrowserResults(results)
            }
        }
        
        browser.start(queue: .main)
        self.browser = browser
    }
    
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
    
    private func handleBrowserResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case let .service(name: serviceName, type: serviceType, domain: domain, interface: _) = result.endpoint {
                let newService = BonjourService(
                    name: serviceName,
                    type: serviceType,
                    domain: domain
                )
                if !discoveredServices.contains(where: { $0.name == newService.name }) {
                    discoveredServices.append(newService)
                }
            }
        }
    }
}
