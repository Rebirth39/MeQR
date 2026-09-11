import Combine
import Foundation

nonisolated struct RemoteTagCatalogDocument: Decodable, Sendable {
    let schemaVersion: Int
    let revision: String
    let entries: [RemoteTagEntry]
    let categories: [RemoteTagCategory]?
    let changelog: [RemoteTagCatalogChange]?
}

nonisolated struct RemoteTagCatalogChange: Decodable, Identifiable, Sendable {
    let revision: String
    let date: String
    let summary: RemoteTagEntry.Names
    var id: String { revision }
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
    let kind: String?
    let parentID: String?

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
    let contextKeys: [String]
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
    nonisolated(unsafe) private static var ambiguousKeys: Set<String> = []

    static func replace(with document: RemoteTagCatalogDocument) {
        let records = document.entries.map { entry in
            let displayKeys = Array(Set(entry.names.allValues.map(CardTagIndex.normalizedKey)))
            let aliasKeys = Array(Set(entry.aliases.map(CardTagIndex.normalizedKey)))
            let categories = (document.categories ?? []).filter { category in category.ranges.contains { $0.contains(entry.id) } }
            let works = document.entries.filter { candidate in
                candidate.kind == "work" && categories.contains { category in category.ranges.contains { $0.contains(candidate.id) } }
            }
            let parent = document.entries.first { $0.id == entry.parentID }
            let context = categories.flatMap { $0.names.allValues } + works.flatMap(\.searchableValues) + (parent?.searchableValues ?? [])
            return RemoteTagSearchRecord(
                entry: entry,
                displayKeys: displayKeys,
                aliasKeys: aliasKeys,
                searchableKeys: Array(Set(displayKeys + aliasKeys)),
                contextKeys: Array(Set(context.map(CardTagIndex.normalizedKey)))
            )
        }
        var exactLookup: [String: RemoteTagEntry] = [:]
        var ambiguous: Set<String> = []
        func add(_ key: String, entry: RemoteTagEntry) {
            guard !key.isEmpty, !ambiguous.contains(key) else { return }
            if let previous = exactLookup[key], previous.id != entry.id {
                exactLookup.removeValue(forKey: key)
                ambiguous.insert(key)
            } else {
                exactLookup[key] = entry
            }
        }
        // Full names take priority; shared nicknames remain search-only.
        for record in records {
            for key in record.displayKeys { add(key, entry: record.entry) }
        }
        let displayKeys = Set(records.flatMap(\.displayKeys))
        for record in records {
            for key in record.aliasKeys where !displayKeys.contains(key) {
                add(key, entry: record.entry)
            }
        }

        lock.lock()
        entries = document.entries
        categories = document.categories ?? []
        searchRecords = records
        exactEntryByKey = exactLookup
        ambiguousKeys = ambiguous
        lock.unlock()
    }

    static func value() -> [RemoteTagEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static func entry(id: String) -> RemoteTagEntry? {
        value().first { $0.id == id }
    }

    @MainActor static func subtitle(for entry: RemoteTagEntry, language: AppLanguage) -> String {
        let category = categoryValue().first { $0.ranges.contains { $0.contains(entry.id) } }
        if let parentID = entry.parentID, let parent = self.entry(id: parentID) {
            return [category?.displayName(for: language), parent.names.value(for: language)].compactMap { $0 }.joined(separator: " · ")
        }
        let label: String
        switch entry.kind {
        case "work": label = L.tagKindWork
        case "group": label = L.tagKindGroup
        case "rating": label = L.tagKindRating
        default: label = L.tagKindCharacter
        }
        return entry.kind == "work" ? label : [category?.displayName(for: language), label].compactMap { $0 }.joined(separator: " · ")
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
        lock.lock()
        let ambiguous = ambiguousKeys.contains(key)
        let matchedEntry = exactEntryByKey[key]
        lock.unlock()
        if ambiguous {
            return RemoteTagColorPreset(colors: ["#6F7582"], solidColor: "#6F7582")
        }
        guard let entry = matchedEntry else { return nil }
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
    // Enable in the September 12 release after the online catalog maintenance is complete.
    nonisolated static let onlineEnabled = true
    private nonisolated static let catalogURL = URL(string: "https://meqrcode.cn/config/tags-v1.json")!
    private nonisolated static let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("meqr-tags-v1.json")

    enum Source { case bundled, cached, online }

    @Published private(set) var revision = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var changelog: [RemoteTagCatalogChange] = []
    @Published private(set) var source: Source = .bundled
    @Published private(set) var statusMessage: String?

    var sourceName: String {
        switch source {
        case .bundled: L.tagCatalogSource
        case .cached: L.tagCatalogCache
        case .online: L.tagCatalogRemote
        }
    }

    private var hasLoaded = false
    private var lastAttempt: Date?
    private let onlineMode: Bool
    private let bundledURL: URL?
    private let endpoint: URL
    private let storedURL: URL
    private let session: URLSession

    init(onlineMode: Bool = RemoteTagCatalog.onlineEnabled,
         bundledURL: URL? = Bundle.main.url(forResource: "tags-v1", withExtension: "json"),
         endpoint: URL = RemoteTagCatalog.catalogURL,
         storedURL: URL = RemoteTagCatalog.cacheURL,
         session: URLSession = .shared) {
        self.onlineMode = onlineMode
        self.bundledURL = bundledURL
        self.endpoint = endpoint
        self.storedURL = storedURL
        self.session = session
    }

    func refreshIfNeeded() async {
        guard !isLoading else { return }
        if hasLoaded, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 900 { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        lastAttempt = Date()
        defer { isLoading = false }

        if !hasLoaded {
            do {
                guard let url = bundledURL else {
                    throw URLError(.fileDoesNotExist)
                }
                install(try await Self.loadDocument(from: url), source: .bundled)
            } catch {
                errorMessage = error.localizedDescription
            }
            if onlineMode, let cached = try? await Self.loadDocument(from: storedURL),
               !Self.isMaintenance(cached) {
                install(cached, source: .cached)
            }
        }
        guard onlineMode else { return }

        do {
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count <= 2 * 1024 * 1024 else { throw URLError(.badServerResponse) }
            let document = try await Self.decode(data)
            guard !Self.isMaintenance(document) else {
                statusMessage = L.tagCatalogMaintenance
                return
            }
            install(document, source: .online)
            try? data.write(to: storedURL, options: .atomic)
        } catch {
            if hasLoaded { statusMessage = L.tagCatalogFallback }
            else { errorMessage = error.localizedDescription }
        }
    }

    private nonisolated static func isMaintenance(_ document: RemoteTagCatalogDocument) -> Bool {
        document.revision.lowercased().hasPrefix("maintenance")
    }

    private func install(_ document: RemoteTagCatalogDocument, source: Source) {
        RemoteTagCatalogSnapshot.replace(with: document)
        revision = document.revision
        changelog = document.changelog ?? []
        self.source = source
        errorMessage = nil
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
