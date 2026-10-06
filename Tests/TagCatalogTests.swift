import Foundation

// Compile with RemoteTagCatalog.swift; only UI and color helpers are replaced by fixtures.
enum AppLanguage: Sendable {
    case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum CardTagIndex {
    static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "！", with: "!")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: " ", with: "").lowercased()
    }
}
enum CardTagColorPalette {
    static func normalizedHex(_ value: String) -> String? { value }
}
enum L {
    static let tagKindWork = "Work", tagKindGroup = "Group", tagKindRating = "Rating", tagKindCharacter = "Character"
    static let tagCatalogSource = "bundled"
    static let tagCatalogCache = "cached"
    static let tagCatalogRemote = "online"
    static let tagCatalogMaintenance = "maintenance"
    static let tagCatalogFallback = "offline"
}

final class CatalogResponse: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var data = Data()
    nonisolated(unsafe) static var error: Error?
    nonisolated(unsafe) static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        if let error = Self.error { client?.urlProtocol(self, didFailWithError: error); return }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct TagCatalogTests {
    @MainActor static func main() async throws {
        let bundledURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let original = try Data(contentsOf: bundledURL)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appendingPathComponent("tags.json")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CatalogResponse.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        func catalog(_ online: Bool) -> RemoteTagCatalog {
            RemoteTagCatalog(onlineMode: online, bundledURL: bundledURL,
                             endpoint: URL(string: "https://catalog.test/tags.json")!, storedURL: cache, session: session)
        }
        let local = catalog(false)
        await local.refresh()
        assert(local.source == .bundled && CatalogResponse.requests == 0)
        let originalDocument = try JSONDecoder().decode(RemoteTagCatalogDocument.self, from: original)
        assert(RemoteTagCatalogSnapshot.value().count == originalDocument.entries.count)
        assert(RemoteTagCatalogSnapshot.colors(for: "pjsk") == ["#39C5BB", "#00A0E9", "#88DD44", "#FF9900", "#EE1166", "#884499"])
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Project Sekai")?.solidColor == "#00A0E9")
        for entry in RemoteTagCatalogSnapshot.value() {
            assert(!entry.colors.isEmpty && entry.colors.count <= 6)
            for name in entry.names.allValues {
                let key = CardTagIndex.normalizedKey(name)
                assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: key)?.id == entry.id, "Display name identity: \(name)")
                assert(RemoteTagCatalogSnapshot.colors(for: name) == entry.colors, "Localized colors: \(name)")
            }
        }
        assert(RemoteTagCatalogSnapshot.colors(for: "LoveLive!") == ["#E4007F"])
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "MEIKO")?.solidColor == "#D80000")
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Kagamine Rin")?.solidColor == "#FFB000")
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Kagamine Len")?.solidColor == "#FFE211")
        assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: "frieren")?.id == "tag-0146")
        assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: "saki") == nil)
        assert(RemoteTagCatalogSnapshot.colors(for: "Saki") == ["#6F7582"])
        assert(RemoteTagCatalogSnapshot.searchRecordValue().filter { $0.aliasKeys.contains("saki") }.count == 2)
        assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: "胡桃")?.names.en == "Hu Tao")
        assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: "妮可")?.names.en == "Nico Yazawa")
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Yukina Minato")?.solidColor == "#881188")
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Misaki Okusawa")?.solidColor == "#006699")
        assert(RemoteTagCatalogSnapshot.colorPreset(for: "Michelle")?.solidColor == "#DD33CC")
        assert(RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: "wsmix")?.id == "tag-0005")
        assert(!RemoteTagCatalogSnapshot.value().contains { $0.id == "tag-0006" })

        var document = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        document["revision"] = "maintenance-2026.09.06"
        let maintenance = try JSONSerialization.data(withJSONObject: document)
        CatalogResponse.data = maintenance
        let maintaining = catalog(true)
        await maintaining.refresh()
        assert(maintaining.source == .bundled && maintaining.revision == local.revision)
        assert(maintaining.statusMessage == L.tagCatalogMaintenance)
        assert(!FileManager.default.fileExists(atPath: cache.path), "Maintenance response must not enter cache")

        document["revision"] = "2099.10.02.10"
        document.removeValue(forKey: "changelog")
        CatalogResponse.data = try JSONSerialization.data(withJSONObject: document)
        await maintaining.refresh()
        assert(maintaining.source == .online && maintaining.sourceName == "online")
        assert(maintaining.revision == "2099.10.02.10" && maintaining.changelog.isEmpty)
        let cachedData = try Data(contentsOf: cache)
        assert(cachedData == CatalogResponse.data)

        CatalogResponse.error = URLError(.notConnectedToInternet)
        let offline = catalog(true)
        await offline.refresh()
        assert(offline.source == .cached && offline.sourceName == "cached")
        assert(offline.revision == "2099.10.02.10" && offline.statusMessage == L.tagCatalogFallback)

        CatalogResponse.error = nil
        CatalogResponse.data = Data("{}".utf8)
        await offline.refresh()
        assert(offline.revision == "2099.10.02.10" && offline.source == .cached)

        // Downgrade and malformed responses must leave both the live directory and cache intact.
        var older = document
        older["revision"] = "2099.10.02.9"
        var incomplete = document
        incomplete["revision"] = "2099.10.02.11"
        incomplete["categories"] = []
        var brokenColor = document
        var brokenEntries = document["entries"] as! [[String: Any]]
        brokenEntries[0]["colors"] = ["not-a-color"]
        brokenColor["entries"] = brokenEntries
        var duplicate = document
        let validEntries = document["entries"] as! [[String: Any]]
        duplicate["entries"] = validEntries + [validEntries[0]]
        var cycle = document
        var cyclicEntries = document["entries"] as! [[String: Any]]
        cyclicEntries[0]["parentID"] = cyclicEntries[0]["id"]
        cycle["entries"] = cyclicEntries
        for invalid in [older, incomplete, brokenColor, duplicate, cycle] {
            CatalogResponse.data = try JSONSerialization.data(withJSONObject: invalid)
            await offline.refresh()
            assert(offline.revision == "2099.10.02.10")
            assert(offline.statusMessage == L.tagCatalogFallback)
            assert(RemoteTagCatalogSnapshot.value().count == originalDocument.entries.count)
            let preserved = try Data(contentsOf: cache)
            assert(preserved == cachedData)
        }

        let records = RemoteTagCatalogSnapshot.searchRecordValue()
        let chihaya = records.first { $0.entry.id == "tag-0423" }!
        let haruka = records.first { $0.entry.id == "tag-0422" }!
        assert(!chihaya.contextKeys.contains { $0.contains("灰姑娘") })
        assert(!haruka.contextKeys.contains { $0.contains("闪耀") })
        let imbibitor = records.first { $0.entry.id == "tag-0376" }!
        assert(imbibitor.contextKeys.contains(CardTagIndex.normalizedKey("Dan Heng")))
        assert(imbibitor.contextKeys.contains(CardTagIndex.normalizedKey("Honkai: Star Rail")))

        var staleCacheDocument = document
        staleCacheDocument["revision"] = "2000.01.01.1"
        try JSONSerialization.data(withJSONObject: staleCacheDocument).write(to: cache)
        CatalogResponse.error = URLError(.notConnectedToInternet)
        let oldCache = catalog(true)
        await oldCache.refresh()
        assert(oldCache.revision == local.revision && oldCache.source == .bundled)

        try maintenance.write(to: cache)
        CatalogResponse.error = URLError(.notConnectedToInternet)
        let staleMaintenance = catalog(true)
        await staleMaintenance.refresh()
        assert(staleMaintenance.source == .bundled && staleMaintenance.revision == local.revision)
        print("Tag catalog: identity, ancestors, local/online/cache, maintenance, downgrade and invalid response preservation passed")
    }
}
