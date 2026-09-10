import Foundation

// Compile with CardTagUsageStore.swift. Catalog fixtures isolate storage from SwiftUI/SwiftData.
enum AppSettings {
    static let shared = Settings()
    final class Settings { var resolvedLanguage = "en" }
}
enum CardTagIndex {
    static func selectionKey(_ tag: String) -> String {
        RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: normalizedKey(tag)).map { "catalog:" + $0.id } ?? "custom:" + normalizedKey(tag)
    }
    static func normalizedKey(_ tag: String) -> String { tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
}
enum RemoteTagCatalogSnapshot {
    struct Names {
        func value(for language: String) -> String { language == "ja" ? "ミク" : "Miku" }
    }
    struct Entry { let id = "tag-0002"; let names = Names() }
    static func entry(matchingNormalizedKey key: String) -> Entry? {
        ["miku", "ミク"].contains(key) ? Entry() : nil
    }
    static func value() -> [Entry] { [Entry()] }
}

@main
struct TagUsageTests {
    @MainActor static func main() {
        let suite = "MeQR.TagUsage.Tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CardTagUsageStore(defaults: defaults)
        store.toggleFavorite("Miku")
        assert(store.isFavorite("ミク"))
        assert(CardTagUsageStore(defaults: defaults).favorites.count == 1)
        assert(store.records.isEmpty)
        store.record("Miku")
        store.record("ミク")
        store.record("Photography")
        assert(store.records.count == 2, "Aliases must share history identity")
        assert(store.sorted(frequent: true).first?.count == 2)
        assert(store.sorted(frequent: false).first?.name == "Photography")
        AppSettings.shared.resolvedLanguage = "ja"
        assert(store.displayName(for: store.sorted(frequent: true)[0]) == "ミク")
        let reloaded = CardTagUsageStore(defaults: defaults)
        assert(reloaded.records.count == 2, "History must survive relaunch")
        assert(reloaded.sorted(frequent: true).first?.count == 2)
        reloaded.record("   ")
        assert(reloaded.records.count == 2)
        for i in 0..<110 { reloaded.record("Custom \(i)") }
        assert(reloaded.records.count == 100, "Storage must be bounded")
        assert(reloaded.sorted(frequent: false).count == 20)
        reloaded.clear()
        assert(CardTagUsageStore(defaults: defaults).records.isEmpty)
        assert(CardTagUsageStore(defaults: defaults).favorites.count == 1, "Clearing history must preserve favorites")
        reloaded.toggleFavorite("ミク")
        assert(CardTagUsageStore(defaults: defaults).favorites.isEmpty)
        defaults.set(Data("bad JSON".utf8), forKey: "meqr.tagUsage.v1")
        assert(CardTagUsageStore(defaults: defaults).records.isEmpty)
        print("Tag usage: 12 assertions passed")
    }
}
