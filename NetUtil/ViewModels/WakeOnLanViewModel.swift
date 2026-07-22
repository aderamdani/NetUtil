import Foundation
import Observation

@Observable
@MainActor
final class WakeOnLanViewModel {
    var macAddress: String = ""
    var broadcastAddress: String = "255.255.255.255"
    var port: Int = 9

    private(set) var lastSent: (mac: String, at: Date)?
    private(set) var error: String?

    func send() {
        error = nil
        do {
            try WakeOnLan.send(mac: macAddress,
                               broadcast: broadcastAddress.trimmingCharacters(in: .whitespaces),
                               port: UInt16(clamping: port))
            lastSent = (macAddress, Date())
        } catch {
            self.error = error.localizedDescription
        }
    }
}
