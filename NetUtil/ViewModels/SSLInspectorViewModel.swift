import Foundation
import Security
import CryptoKit
import Combine
import Observation

private final class TLSDelegate: NSObject, URLSessionDelegate {
    var certResult: CertResult?
    var host: String = ""
    var port: Int = 443

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var chain: [CertInfo] = []
        if let certChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            for (i, cert) in certChain.enumerated() {
                chain.append(Self.parse(cert: cert, isLeaf: i == 0))
            }
        }

        certResult = CertResult(host: host, port: port, chain: chain,
                                tlsVersion: nil, cipherSuite: nil, timestamp: Date())
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private static func parse(cert: SecCertificate, isLeaf: Bool) -> CertInfo {
        let subject = SecCertificateCopySubjectSummary(cert) as String? ?? "—"

        // Pre-cast all CFString OID/property keys to String
        let oidNotBefore: String = kSecOIDX509V1ValidityNotBefore as String
        let oidNotAfter:  String = kSecOIDX509V1ValidityNotAfter as String
        let oidIssuer:    String = kSecOIDX509V1IssuerName as String
        let oidSAN:       String = kSecOIDSubjectAltName as String
        let propLabel:    String = kSecPropertyKeyLabel as String
        let propValue:    String = kSecPropertyKeyValue as String

        var notBefore: Date?
        var notAfter: Date?
        var issuer = "—"
        var sans: [String] = []

        let oids = [kSecOIDX509V1ValidityNotBefore, kSecOIDX509V1ValidityNotAfter,
                    kSecOIDX509V1IssuerName, kSecOIDSubjectAltName] as CFArray

        var cfErr: Unmanaged<CFError>?
        if let vals = SecCertificateCopyValues(cert, oids, &cfErr) as? [String: Any] {
            if let nb = vals[oidNotBefore] as? [String: Any],
               let v = nb[propValue] as? Double {
                notBefore = Date(timeIntervalSinceReferenceDate: v)
            }
            if let na = vals[oidNotAfter] as? [String: Any],
               let v = na[propValue] as? Double {
                notAfter = Date(timeIntervalSinceReferenceDate: v)
            }
            if let iss = vals[oidIssuer] as? [String: Any],
               let props = iss[propValue] as? [[String: Any]] {
                let cn = props.first { ($0[propLabel] as? String) == "Common Name" }
                issuer = cn?[propValue] as? String ?? "—"
            }
            if let sanEntry = vals[oidSAN] as? [String: Any],
               let sanList = sanEntry[propValue] as? [[String: Any]] {
                sans = sanList.compactMap { $0[propValue] as? String }
            }
        }

        let keyTypeStr = Self.keyTypeString(cert)

        return CertInfo(subject: subject, issuer: issuer,
                        notBefore: notBefore, notAfter: notAfter,
                        serialNumber: Self.serialNumber(cert),
                        sans: sans, keyType: keyTypeStr,
                        sha256: Self.sha256Fingerprint(cert), isLeaf: isLeaf)
    }

    private static func keyTypeString(_ cert: SecCertificate) -> String {
        guard let key = SecCertificateCopyKey(cert),
              let attrs = SecKeyCopyAttributes(key) as? [String: Any] else { return "—" }
        let rsaKey: String = kSecAttrKeyTypeRSA as String
        let ecKey:  String = kSecAttrKeyTypeECSECPrimeRandom as String
        let sizeKey: String = kSecAttrKeySizeInBits as String
        let typeKey: String = kSecAttrKeyType as String
        guard let type = attrs[typeKey] as? String,
              let size = attrs[sizeKey] as? Int else { return "—" }
        let typeName = type == rsaKey ? "RSA" : type == ecKey ? "EC" : type
        return "\(typeName)-\(size)"
    }

    private static func sha256Fingerprint(_ cert: SecCertificate) -> String {
        let data = SecCertificateCopyData(cert) as Data
        return SHA256.hash(data: data).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    private static func serialNumber(_ cert: SecCertificate) -> String {
        guard let data = SecCertificateCopySerialNumberData(cert, nil) as Data? else { return "—" }
        return data.map { String(format: "%02X", $0) }.joined()
    }
}

@Observable
@MainActor
final class SSLInspectorViewModel {
    var result: CertResult?
    var isRunning = false
    var error: String?

    private var task: Task<Void, Never>?

    func inspect(host: String, port: Int) {
        task?.cancel()
        error = nil
        result = nil
        isRunning = true

        task = Task {
            do {
                result = try await Self.fetch(host: host, port: port)
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            isRunning = false
        }
    }

    func cancel() {
        task?.cancel()
        isRunning = false
    }

    private static func fetch(host: String, port: Int) async throws -> CertResult {
        var h = host.trimmingCharacters(in: .whitespaces)
        if h.lowercased().hasPrefix("https://") { h = String(h.dropFirst(8)) }
        if h.lowercased().hasPrefix("http://")  { h = String(h.dropFirst(7)) }
        h = h.components(separatedBy: "/").first ?? h

        guard let url = URL(string: "https://\(h):\(port)") else { throw URLError(.badURL) }

        let delegate = TLSDelegate()
        delegate.host = h
        delegate.port = port

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        _ = try? await session.data(for: req)

        guard let r = delegate.certResult, !r.chain.isEmpty else {
            throw URLError(.serverCertificateUntrusted)
        }
        return r
    }
}
