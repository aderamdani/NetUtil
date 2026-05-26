import Foundation
import Security

struct CertInfo: Identifiable {
    let id = UUID()
    let subject: String
    let issuer: String
    let notBefore: Date?
    let notAfter: Date?
    let serialNumber: String
    let sans: [String]
    let keyType: String
    let sha256: String
    let isLeaf: Bool

    var daysRemaining: Int? {
        guard let exp = notAfter else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }

    var expiryColor: String {
        guard let d = daysRemaining else { return "secondary" }
        if d > 30 { return "green" }
        if d > 7  { return "orange" }
        return "red"
    }
}

struct CertResult {
    let host: String
    let port: Int
    let chain: [CertInfo]
    let tlsVersion: String?
    let cipherSuite: String?
    let timestamp: Date
}
