import Combine
import Foundation

@MainActor
final class CardTagUsageStore: ObservableObject {
    struct Record: Codable, Identifiable {
        let id: String
        let name: String
        var count: Int
        var lastUsed: Date
    }

    static let shared = CardTagUsageStore()
    @Published private(set) var records: [Record]
    @Published private(set) var favorites: [Record]
    private let defaults: UserDefaults
    private let storageKey = "meqr.tagUsage.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([Record].self, from: $0) } ?? []
        favorites = defaults.data(forKey: "meqr.tagFavorites.v1")
            .flatMap { try? JSONDecoder().decode([Record].self, from: $0) } ?? []
    }

    private func matches(_ record: Record, tag: String) -> Bool {
        if record.id == CardTagIndex.selectionKey(tag) { return true }
        return record.id.hasPrefix("catalog:") && !RemoteTagCatalogSnapshot.value().contains(where: { "catalog:" + $0.id == record.id })
            && CardTagIndex.normalizedKey(record.name) == CardTagIndex.normalizedKey(tag)
    }

    func isFavorite(_ tag: String) -> Bool { favorites.contains { matches($0, tag: tag) } }

    func toggleFavorite(_ tag: String) {
        let id = CardTagIndex.selectionKey(tag)
        if favorites.contains(where: { matches($0, tag: tag) }) { favorites.removeAll { matches($0, tag: tag) } }
        else { favorites.append(Record(id: id, name: tag, count: 0, lastUsed: Date())) }
        if let data = try? JSONEncoder().encode(favorites) { defaults.set(data, forKey: "meqr.tagFavorites.v1") }
    }

    func record(_ tag: String) {
        let key = CardTagIndex.normalizedKey(tag)
        guard !key.isEmpty else { return }
        let entry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: key)
        let id = entry.map { "catalog:" + $0.id } ?? "custom:" + key
        var next = records
        if let index = next.firstIndex(where: { $0.id == id }) {
            next[index].count = min(next[index].count, 999_999) + 1
            next[index].lastUsed = Date()
        } else {
            next.append(Record(id: id, name: tag, count: 1, lastUsed: Date()))
        }
        records = Array(next.sorted { $0.lastUsed > $1.lastUsed }.prefix(100))
        persist()
    }

    func sorted(frequent: Bool) -> [Record] {
        Array(records.sorted {
            if frequent && $0.count != $1.count { return $0.count > $1.count }
            if $0.lastUsed != $1.lastUsed { return $0.lastUsed > $1.lastUsed }
            return $0.id < $1.id
        }.prefix(20))
    }

    func displayName(for record: Record) -> String {
        guard record.id.hasPrefix("catalog:"),
              let entry = RemoteTagCatalogSnapshot.value().first(where: { "catalog:" + $0.id == record.id })
        else { return record.name }
        return entry.names.value(for: AppSettings.shared.resolvedLanguage)
    }

    func clear() {
        records = []
        defaults.removeObject(forKey: storageKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: storageKey) }
    }
}
