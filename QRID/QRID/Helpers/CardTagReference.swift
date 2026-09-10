import Foundation

struct CardTagReference: Codable {
    var catalogID: String?
    var localID = UUID().uuidString
    var fallbackName: String
    var colors: [String]
    var solidColor: String
    var override: CardTagColorOverride?

    var displayName: String {
        catalogID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0) }?.names.value(for: AppSettings.shared.resolvedLanguage) ?? fallbackName
    }

    var displayOverride: CardTagColorOverride {
        let entry = catalogID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0) }
        let palette = entry?.colors ?? colors
        var value = override ?? CardTagColorOverride(mode: palette.count > 1 ? .preset : .solid, hexes: [])
        value.referenceColors = palette
        value.referenceSolid = entry.map { $0.solidColor ?? $0.colors.first ?? solidColor } ?? solidColor
        return value
    }

    var snapshot: Self {
        var value = self
        if let entry = catalogID.flatMap({ RemoteTagCatalogSnapshot.entry(id: $0) }) {
            value.fallbackName = entry.names.value(for: AppSettings.shared.resolvedLanguage)
            value.colors = entry.colors
            value.solidColor = entry.solidColor ?? entry.colors.first ?? CardTagColorPalette.fallbackHex
        }
        return value
    }

    static func decode(_ raw: String?) -> [Self]? {
        guard let data = raw?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Self].self, from: data)
    }

    static func encode(_ values: [Self]) -> String? {
        guard let data = try? JSONEncoder().encode(values) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func reconcile(names: [String], overrides: [String: CardTagColorOverride], previous: [Self]) -> [Self] {
        var result: [Self] = []
        var seen: Set<String> = []
        for rawName in names {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = CardTagIndex.normalizedKey(name)
            let matchedEntry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: key)
            let old = previous.first { CardTagIndex.normalizedKey($0.displayName) == key || CardTagIndex.normalizedKey($0.fallbackName) == key }
                ?? previous.first { $0.catalogID != nil && $0.catalogID == matchedEntry?.id }
            let entry = old == nil ? matchedEntry : old?.catalogID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0) }
            var value = (old ?? Self(catalogID: entry?.id, fallbackName: CardTagLimiter.normalizedTag(name),
                                   colors: CardTagColorPalette.colorStyle(for: name).segmentHexes,
                                   solidColor: CardTagColorPalette.presetSolidHex(for: name))).snapshot
            let identity = value.catalogID.map { "catalog:" + $0 } ?? "custom:" + CardTagIndex.normalizedKey(value.fallbackName)
            guard seen.insert(identity).inserted else { continue }
            // Legacy overrides may use another spelling of the same catalog tag.
            let aliasOverride = value.catalogID.flatMap { id in
                overrides.sorted { $0.key < $1.key }.first {
                    RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey($0.key))?.id == id
                }?.value
            }
            value.override = overrides[key] ?? aliasOverride ?? old?.override
            value.override?.referenceColors = nil
            value.override?.referenceSolid = nil
            result.append(value)
            if result.count == CardTagLimiter.maxTags { break }
        }
        return result
    }
}
