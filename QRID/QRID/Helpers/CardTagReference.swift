import Foundation

// A local combination keeps catalog identities and offline snapshots; it is not a catalog entry.
struct CardTagPair: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable { case cp = "CP", cb = "CB" }
    struct Member: Codable, Equatable {
        let catalogID: String
        let names: RemoteTagEntry.Names
        let color: String

        var displayName: String {
            let language = AppSettings.shared.resolvedLanguage
            let current = RemoteTagCatalogSnapshot.entry(id: catalogID)?.names ?? names
            let full = current.value(for: language)
            if language == .en { return full.components(separatedBy: " ").first ?? full }
            let surnameLength = CardTagPair.surnameLengths[catalogID] ?? 2
            return String(full.dropFirst(surnameLength))
        }

        nonisolated var currentColor: String {
            RemoteTagCatalogSnapshot.entry(id: catalogID)?.solidColor ?? color
        }
    }
    var kind: Kind
    let members: [Member]
    var displayName: String { members.map(\.displayName).joined(separator: "&") }
    var snapshot: Self {
        Self(kind: kind, members: members.map { member in
            guard let entry = RemoteTagCatalogSnapshot.entry(id: member.catalogID) else { return member }
            return Member(catalogID: entry.id, names: entry.names, color: entry.solidColor ?? member.color)
        })
    }
    nonisolated var identity: String { "pair:" + members.map(\.catalogID).joined(separator: ":") }
    nonisolated var colors: [String] { members.map(\.currentColor) }

    private nonisolated static let surnameLengths: [String: Int] = [
        "tag-0008": 2, "tag-0009": 2, "tag-0010": 2, "tag-0011": 3,
        "tag-0012": 2, "tag-0013": 2, "tag-0014": 2, "tag-0015": 3,
        "tag-0016": 3, "tag-0017": 2, "tag-0018": 2, "tag-0019": 2,
        "tag-0020": 2, "tag-0021": 1, "tag-0022": 2, "tag-0023": 2,
        "tag-0024": 2, "tag-0025": 3, "tag-0026": 2, "tag-0027": 2,
    ]

    static func character(_ tag: String) -> RemoteTagEntry? {
        guard let entry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey(tag)),
              entry.kind == "character", surnameLengths[entry.id] != nil,
              let category = RemoteTagCatalogSnapshot.categoryValue().first(where: { $0.id == "ip-project-sekai" }),
              category.ranges.contains(where: { $0.contains(entry.id) }) else { return nil }
        return entry
    }

    static func make(_ first: String, _ second: String, kind: Kind) -> Self? {
        guard let a = character(first), let b = character(second), a.id != b.id else { return nil }
        return Self(kind: kind, members: [a, b].map {
            Member(catalogID: $0.id, names: $0.names, color: $0.solidColor ?? $0.colors.first ?? CardTagColorPalette.fallbackHex)
        })
    }

    static func combine(tags: [String], overrides: [String: CardTagColorOverride],
                        first: String, second: String, kind: Kind) -> (tags: [String], overrides: [String: CardTagColorOverride])? {
        guard let a = tags.firstIndex(of: first), let b = tags.firstIndex(of: second), a != b else { return nil }
        let left = min(a, b), right = max(a, b)
        guard let pair = make(first, second, kind: kind) else { return nil }
        let name = pair.displayName
        let key = CardTagColorPalette.normalized(name)
        guard !tags.contains(where: { CardTagColorPalette.normalized($0) == key }) else { return nil }
        var next = tags
        next.remove(at: right)
        next[left] = name
        var nextOverrides = overrides
        nextOverrides[key] = CardTagColorOverride(mode: .preset, hexes: [], pairing: pair)
        return (next, nextOverrides)
    }

    static func swapSides(tags: [String], overrides: [String: CardTagColorOverride],
                          tag: String) -> (tags: [String], overrides: [String: CardTagColorOverride])? {
        let oldKey = CardTagColorPalette.normalized(tag)
        guard let index = tags.firstIndex(of: tag), var value = overrides[oldKey],
              let pair = value.pairing, pair.isValid else { return nil }
        let reversed = Self(kind: pair.kind, members: Array(pair.members.reversed())).snapshot
        let name = reversed.displayName
        let key = CardTagColorPalette.normalized(name)
        guard !tags.enumerated().contains(where: { $0.offset != index && CardTagColorPalette.normalized($0.element) == key }) else { return nil }
        var next = tags
        next[index] = name
        value.pairing = reversed
        value.referenceColors = reversed.colors
        value.referenceSolid = reversed.colors.first
        var nextOverrides = overrides
        nextOverrides.removeValue(forKey: oldKey)
        nextOverrides[key] = value
        return (next, nextOverrides)
    }

    // Treat malformed or unsupported pairs as ordinary custom tags.
    nonisolated var isValid: Bool {
        members.count == 2 && members[0].catalogID != members[1].catalogID
            && members.allSatisfy { Self.surnameLengths[$0.catalogID] != nil }
    }
}

struct CardTagReference: Codable {
    var catalogID: String?
    var localID = UUID().uuidString
    var fallbackName: String
    var colors: [String]
    var solidColor: String
    var override: CardTagColorOverride?
    var catalogKind: String? = nil

    var displayName: String {
        if let pair = override?.pairing, pair.isValid { return pair.displayName }
        return catalogID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0) }?.names.value(for: AppSettings.shared.resolvedLanguage) ?? fallbackName
    }

    var displayOverride: CardTagColorOverride {
        if let pair = override?.pairing, pair.isValid {
            var value = override!
            value.referenceColors = pair.colors
            value.referenceSolid = pair.colors.first
            return value
        }
        let entry = catalogID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0) }
        let palette = entry?.colors ?? colors
        var value = override ?? CardTagColorOverride(mode: palette.count > 1 ? .preset : .solid, hexes: [])
        value.referenceKind = entry?.kind ?? catalogKind
        value.referenceColors = palette
        value.referenceSolid = entry.map { $0.solidColor ?? $0.colors.first ?? solidColor } ?? solidColor
        return value
    }

    var snapshot: Self {
        var value = self
        if let pair = override?.pairing, pair.isValid {
            value.override?.pairing = pair.snapshot
            value.fallbackName = pair.displayName
            value.colors = pair.colors
            value.solidColor = pair.colors[0]
            return value
        }
        if let entry = catalogID.flatMap({ RemoteTagCatalogSnapshot.entry(id: $0) }) {
            value.catalogKind = entry.kind
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
                                   solidColor: CardTagColorPalette.presetSolidHex(for: name), catalogKind: entry?.kind)).snapshot
            let pair = overrides[key]?.pairing ?? old?.override?.pairing
            let identity = pair?.isValid == true ? pair!.identity : value.catalogID.map { "catalog:" + $0 } ?? "custom:" + CardTagIndex.normalizedKey(value.fallbackName)
            guard seen.insert(identity).inserted else { continue }
            // Legacy overrides may use another spelling of the same catalog tag.
            let aliasOverride = value.catalogID.flatMap { id in
                overrides.sorted { $0.key < $1.key }.first {
                    RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey($0.key))?.id == id
                }?.value
            }
            value.override = overrides[key] ?? aliasOverride ?? old?.override
            if let pair = value.override?.pairing, pair.isValid {
                value.fallbackName = pair.displayName
                value.colors = pair.colors
                value.solidColor = pair.colors[0]
            }
            value.override?.referenceColors = nil
            value.override?.referenceSolid = nil
            value.override?.referenceKind = nil
            result.append(value)
            if result.count == CardTagLimiter.maxTags { break }
        }
        return result
    }
}
