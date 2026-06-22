import Foundation
import Observation
import SwiftUI

struct FavoriteHost: Codable, Identifiable {
    let id: UUID
    var host: String
    var alias: String?
    var dateAdded: Date

    init(host: String, alias: String? = nil) {
        self.id = UUID()
        self.host = host
        self.alias = alias
        self.dateAdded = Date()
    }

    var displayName: String {
        if let a = alias, !a.isEmpty { return a }
        return host
    }
}

@Observable
@MainActor
final class FavoritesManager {
    var favorites: [FavoriteHost] = [] { didSet { save() } }
    private let key = "com.netutil.favorites"

    init() { load() }

    var canAdd: Bool { favorites.count < 20 }

    func add(host: String, alias: String? = nil) {
        guard canAdd, !isFavorite(host) else { return }
        favorites.append(FavoriteHost(host: host, alias: alias))
    }

    func remove(id: UUID) { favorites.removeAll { $0.id == id } }
    func remove(host: String) { favorites.removeAll { $0.host == host } }
    func isFavorite(_ host: String) -> Bool { favorites.contains { $0.host == host } }

    func toggle(host: String) {
        isFavorite(host) ? remove(host: host) : add(host: host)
    }

    func move(from: IndexSet, to: Int) { favorites.move(fromOffsets: from, toOffset: to) }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteHost].self, from: data) else { return }
        favorites = decoded
    }
}
