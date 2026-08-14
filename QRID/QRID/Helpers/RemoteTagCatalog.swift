import Combine
import Foundation

nonisolated struct RemoteTagCatalogDocument: Decodable, Sendable {
    let schemaVersion: Int
    let revision: String
    let entries: [RemoteTagEntry]
    let categories: [RemoteTagCategory]?
}

nonisolated struct RemoteTagEntry: Decodable, Identifiable, Sendable {
    nonisolated struct Names: Decodable, Sendable {
        let zhHans: String
        let zhHantHK: String
        let zhHantTW: String
        let en: String
        let ja: String

        var allValues: [String] { [zhHans, zhHantHK, zhHantTW, en, ja] }

        func value(for language: AppLanguage) -> String {
            switch language {
            case .system:
                return value(for: AppLanguage.preferredSystemLanguage())
            case .zhHans:
                return zhHans
            case .zhHantHK:
                return zhHantHK
            case .zhHantTW:
                return zhHantTW
            case .en:
                return en
            case .ja:
                return ja
            }
        }
    }

    let id: String
    let names: Names
    let aliases: [String]
    let colors: [String]
    let solidColor: String?

    var searchableValues: [String] { names.allValues + aliases }
}

nonisolated struct RemoteTagCategory: Decodable, Identifiable, Sendable {
    nonisolated struct EntryRange: Decodable, Sendable {
        let start: String
        let end: String

        func contains(_ entryID: String) -> Bool {
            entryID >= start && entryID <= end
        }
    }

    let id: String
    let names: RemoteTagEntry.Names
    let ranges: [EntryRange]

    func displayName(for language: AppLanguage) -> String {
        names.value(for: language)
    }
}

nonisolated struct RemoteTagSearchRecord: Sendable {
    let entry: RemoteTagEntry
    let displayKeys: [String]
    let aliasKeys: [String]
    let searchableKeys: [String]
}

nonisolated struct RemoteTagColorPreset: Sendable {
    let colors: [String]
    let solidColor: String?
}

nonisolated enum RemoteTagCatalogSnapshot {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [RemoteTagEntry] = []
    nonisolated(unsafe) private static var categories: [RemoteTagCategory] = []
    nonisolated(unsafe) private static var searchRecords: [RemoteTagSearchRecord] = []
    nonisolated(unsafe) private static var exactEntryByKey: [String: RemoteTagEntry] = [:]

    static func replace(with document: RemoteTagCatalogDocument) {
        let records = document.entries.map { entry in
            let displayKeys = Array(Set(entry.names.allValues.map(CardTagIndex.normalizedKey)))
            let aliasKeys = Array(Set(entry.aliases.map(CardTagIndex.normalizedKey)))
            return RemoteTagSearchRecord(
                entry: entry,
                displayKeys: displayKeys,
                aliasKeys: aliasKeys,
                searchableKeys: Array(Set(displayKeys + aliasKeys))
            )
        }
        var exactLookup: [String: RemoteTagEntry] = [:]
        for record in records {
            for key in record.searchableKeys where exactLookup[key] == nil {
                exactLookup[key] = record.entry
            }
        }

        lock.lock()
        entries = document.entries
        categories = document.categories ?? []
        searchRecords = records
        exactEntryByKey = exactLookup
        lock.unlock()
    }

    static func value() -> [RemoteTagEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static func categoryValue() -> [RemoteTagCategory] {
        lock.lock()
        defer { lock.unlock() }
        return categories
    }

    static func searchRecordValue() -> [RemoteTagSearchRecord] {
        lock.lock()
        defer { lock.unlock() }
        return searchRecords
    }

    static func entry(matchingNormalizedKey key: String) -> RemoteTagEntry? {
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return exactEntryByKey[key]
    }

    static func entries(in category: RemoteTagCategory) -> [RemoteTagEntry] {
        value().filter { entry in
            category.ranges.contains { $0.contains(entry.id) }
        }
    }

    static func colorPreset(for tag: String) -> RemoteTagColorPreset? {
        let key = CardTagIndex.normalizedKey(tag)
        guard let entry = entry(matchingNormalizedKey: key) else { return nil }
        let colors = entry.colors.compactMap(CardTagColorPalette.normalizedHex)
        guard !colors.isEmpty else { return nil }
        return RemoteTagColorPreset(
            colors: Array(colors.prefix(6)),
            solidColor: entry.solidColor.flatMap(CardTagColorPalette.normalizedHex)
        )
    }

    static func colors(for tag: String) -> [String]? {
        colorPreset(for: tag)?.colors
    }
}

@MainActor
final class RemoteTagCatalog: ObservableObject {
    static let shared = RemoteTagCatalog()
    private static let catalogURL = URL(string: "https://meqrcode.cn/config/tags-v1.json")!
    private static let cacheURL = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("meqr-tags-v1.json")

    @Published private(set) var revision = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var hasLoaded = false

    func refreshIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if !hasLoaded,
               let cachedDocument = try? await Self.loadDocument(from: Self.cacheURL) {
                install(cachedDocument)
            }

            var request = URLRequest(url: Self.catalogURL)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let document = try await Self.decode(data)
            install(document)
            try? data.write(to: Self.cacheURL, options: .atomic)
        } catch {
            if !hasLoaded {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func install(_ document: RemoteTagCatalogDocument) {
        RemoteTagCatalogSnapshot.replace(with: document)
        revision = document.revision
        hasLoaded = true
    }

    private nonisolated static func loadDocument(from url: URL) async throws -> RemoteTagCatalogDocument {
        let data = try Data(contentsOf: url)
        return try await decode(data)
    }

    private nonisolated static func decode(_ data: Data) async throws -> RemoteTagCatalogDocument {
        try await Task.detached(priority: .userInitiated) {
            let document = try JSONDecoder().decode(RemoteTagCatalogDocument.self, from: data)
            guard document.schemaVersion == 1, !document.entries.isEmpty else {
                throw URLError(.cannotParseResponse)
            }
            return document
        }.value
    }
}
