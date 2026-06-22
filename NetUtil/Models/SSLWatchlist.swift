import Foundation

enum ExpiryStatus: String, Codable, CaseIterable {
    case safe
    case warning
    case critical
    case expired
    case unknown
    
    var color: String {
        switch self {
        case .safe: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        case .expired: return "red"
        case .unknown: return "secondary"
        }
    }
}

struct SSLWatchItem: Codable, Identifiable {
    let id: UUID
    var domain: String
    var lastChecked: Date?
    var expiryDate: Date?
    var issuer: String?
    var status: ExpiryStatus
    
    init(domain: String) {
        self.id = UUID()
        self.domain = domain
        self.status = .unknown
    }
}

@Observable
final class SSLWatchlist {
    var items: [SSLWatchItem] = [] {
        didSet { save() }
    }
    
    private let storageKey = "com.netutil.sslWatchlist"
    
    init() {
        load()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SSLWatchItem].self, from: data) {
            items = decoded
        }
    }
    
    func add(domain: String) {
        guard !items.contains(where: { $0.domain == domain }) else { return }
        items.append(SSLWatchItem(domain: domain))
    }
    
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }
    

    func calculateStatus(expiryDate: Date) -> ExpiryStatus {
        let now = Date()
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: now, to: expiryDate).day ?? 0
        
        if daysUntilExpiry < 0 { return .expired }
        if daysUntilExpiry < 7 { return .critical }
        if daysUntilExpiry < 30 { return .warning }
        return .safe
    }
}
