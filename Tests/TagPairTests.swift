import Foundation
import SwiftData

@main struct TagPairTests {
    @MainActor static func main() throws {
        let document = try JSONDecoder().decode(RemoteTagCatalogDocument.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        RemoteTagCatalogSnapshot.replace(with: document)
        let characters = document.entries.filter { CardTagPair.character($0.names.value(for: .zhHans)) != nil }
        assert(characters.count == 20)
        for a in characters {
            for b in characters where a.id != b.id {
                for kind in CardTagPair.Kind.allCases {
                    let pair = CardTagPair.make(a.names.zhHans, b.names.en, kind: kind)!
                    assert(pair.isValid && pair.members.map(\.catalogID) == [a.id, b.id])
                    assert(pair.colors == [a.solidColor!, b.solidColor!])
                    assert(CardTagLimiter.normalizedTag(pair.displayName) == pair.displayName)
                    let source = ["Before", b.names.zhHans, "Middle", a.names.zhHans, "After"]
                    let result = CardTagPair.combine(tags: source, overrides: [:], first: a.names.zhHans, second: b.names.zhHans, kind: kind)!
                    assert(result.tags == ["Before", pair.displayName, "Middle", "After"])
                    let swapped = CardTagPair.swapSides(tags: result.tags, overrides: result.overrides, tag: pair.displayName)!
                    let opposite = CardTagPair.make(b.names.zhHans, a.names.zhHans, kind: kind)!
                    assert(swapped.tags == ["Before", opposite.displayName, "Middle", "After"])
                    assert(swapped.overrides[CardTagColorPalette.normalized(opposite.displayName)]!.pairing == opposite)
                    let restored = CardTagPair.swapSides(tags: swapped.tags, overrides: swapped.overrides, tag: opposite.displayName)!
                    assert(restored.tags == result.tags)
                    assert(restored.overrides[CardTagColorPalette.normalized(pair.displayName)]!.pairing == pair)
                }
            }
        }
        assert(CardTagPair.make("星乃一歌", "Ichika Hoshino", kind: .cp) == nil)
        assert(CardTagPair.make("星乃一歌", "高松灯", kind: .cp) == nil)
        assert(CardTagPair.make("世界计划", "天马咲希", kind: .cp) == nil)
        assert(CardTagPair.make("Leo/need", "天马咲希", kind: .cp) == nil)
        assert(CardTagPair.make("Unknown", "天马咲希", kind: .cp) == nil)
        // White appearance changes rendering only; CP/CB retain their fixed semantics.
        for entry in document.entries {
            for mode in [CardTagColorOverride.Mode.solid, .preset, .custom] {
                let name = entry.names.zhHans
                let key = CardTagColorPalette.normalized(name)
                let value = CardTagColorOverride(mode: mode, hexes: ["#FFFFFF", "#FFEE99", "#AA22BB"], textWeight: .bold, appearance: .white)
                let style = CardTagColorPalette.colorStyle(for: name, overrides: [key: value])
                assert(style.isWhiteBackground)
                if entry.kind == "work" || entry.kind == "group" {
                    assert(style.whiteTextUsesFirstColor)
                    if let expected = style.segmentHexes.first(where: { CardTagColorPalette.normalizedHex($0) != "#FFFFFF" }) {
                        assert(style.whiteTextHex == expected)
                    } else {
                        assert(style.whiteTextHex != "#FFFFFF")
                        assert(1.05 / (CardTagInk.luminance(style.whiteTextHex) + 0.05) >= 4.5)
                    }
                } else {
                    assert(!style.whiteTextUsesFirstColor)
                    assert(1.05 / (CardTagInk.luminance(style.whiteTextHex) + 0.05) >= 4.5)
                }
                assert(style.whiteOutlineHexes.allSatisfy { 1.05 / (CardTagInk.luminance($0) + 0.05) >= 1.5 })
                let decoded = CardTagColorPalette.overrides(from: CardTagColorPalette.rawValue(from: [key: value], tags: [name]))
                assert(decoded[key]?.appearance == .white && decoded[key]?.mode == mode && decoded[key]?.textWeight == .bold)
                assert(CardTagColorPalette.colorStyle(for: name, overrides: decoded).segmentHexes == style.segmentHexes)
            }
        }
        for kind in CardTagPair.Kind.allCases {
            let pair = CardTagPair.make("星乃一歌", "天马咲希", kind: kind)!
            for appearance in CardTagColorOverride.Appearance.allCases {
                let value = CardTagColorOverride(mode: .preset, hexes: [], pairing: pair, appearance: appearance)
                let style = CardTagColorPalette.colorStyle(for: pair.displayName, overrides: [CardTagColorPalette.normalized(pair.displayName): value])
                assert(style.isWhiteBackground == (kind == .cb))
            }
        }
        let legacyStyle = try JSONDecoder().decode(CardTagColorOverride.self, from: Data(#"{"mode":"solid","hexes":[]}"#.utf8))
        assert(legacyStyle.appearance == nil)
        assert(!CardTagColorPalette.colorStyle(for: "Legacy", overrides: ["legacy": legacyStyle]).isWhiteBackground)
        for name in ["世界计划", "Project Sekai", "プロセカ", "pjsk"] {
            let style = CardTagColorPalette.colorStyle(for: name, overrides: [CardTagColorPalette.normalized(name): .init(mode: .preset, hexes: [], appearance: .white)])
            assert(style.whiteTextHex == "#39C5BB")
        }
        for name in ["Wonderlands x Showtime", "WxS", "ワンダショ"] {
            let style = CardTagColorPalette.colorStyle(for: name, overrides: [CardTagColorPalette.normalized(name): .init(mode: .preset, hexes: [], appearance: .white)])
            assert(style.whiteTextHex == "#FF9900")
        }
        for (colors, expected) in [
            (["#FFFFFF", "#32C5FF", "#FFFFFF"], "#32C5FF"),
            (["#FFFFFF", "#ffffff", "#FFFFFF", "#FF9900"], "#FF9900"),
            (["#FF9900", "#FFFFFF", "#32C5FF"], "#FF9900"),
            (["#FFFFFF", "#FFFFFE", "#32C5FF"], "#FFFFFE")
        ] {
            var style = CardTagColorStyle(segmentHexes: colors)
            style.whiteTextUsesFirstColor = true
            assert(style.whiteTextHex == expected)
        }
        for colors in [["#FFFFFF"], ["#FFFFFF", "#ffffff", "#FFFFFF"]] {
            var style = CardTagColorStyle(segmentHexes: colors)
            style.whiteTextUsesFirstColor = true
            assert(CardTagColorPalette.normalizedHex(style.whiteTextHex) != "#FFFFFF")
            assert(1.05 / (CardTagInk.luminance(style.whiteTextHex) + 0.05) >= 4.5)
        }
        let maimai = CardTagColorPalette.colorStyle(for: "maimai", overrides: ["maimai": .init(mode: .preset, hexes: [], appearance: .white)])
        assert(maimai.whiteTextHex == "#32C5FF")
        let groupRefs = CardTagReference.reconcile(names: ["世界计划", "Wonderlands x Showtime", "maimai"], overrides: [
            "世界计划": .init(mode: .preset, hexes: [], appearance: .white),
            "wonderlandsxshowtime": .init(mode: .preset, hexes: [], appearance: .white),
            "maimai": .init(mode: .preset, hexes: [], appearance: .white)
        ], previous: [])
        let groupSnapshots = CardTagReference.decode(CardTagReference.encode(groupRefs.map(\.snapshot)))!
        assert(groupSnapshots.map(\.catalogKind) == ["work", "group", "work"])
        let ordinaryNames = ["星乃一歌", "世界计划", "White Custom"]
        let ordinaryOverrides: [String: CardTagColorOverride] = [
            "星乃一歌": .init(mode: .solid, hexes: [], textWeight: .bold, appearance: .white),
            "世界计划": .init(mode: .preset, hexes: [], appearance: .white),
            "whitecustom": .init(mode: .custom, hexes: ["#FFFFFF", "#FFEE99"], appearance: .white)
        ]
        let ordinaryURL = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("white.store")
        do {
            let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: ordinaryURL))
            let context = ModelContext(container)
            let c = QRCluster(name: "White ordinary fixture")
            c.setTags(ordinaryNames, overrides: ordinaryOverrides)
            context.insert(c); try context.save()
        }
        let whiteContainer = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: ordinaryURL))
        let ordinary = try ModelContext(whiteContainer).fetch(FetchDescriptor<QRCluster>())[0]
        assert(ordinary.tags == ordinaryNames)
        assert(ordinary.tags.allSatisfy { ordinary.tagColorStyle(for: $0).isWhiteBackground })
        assert(ordinary.tagColorOverrides["星乃一歌"]?.textWeight == .bold)
        assert(ordinary.tagColorStyle(for: "世界计划").segmentHexes.count == 6)
        assert(ordinary.tagColorStyle(for: "White Custom").segmentHexes == ["#FFFFFF", "#FFEE99"])
        let ordinarySnapshots = CardTagReference.decode(ordinary.tagReferencesRawValue)!.map(\.snapshot)
        let whiteSync = SyncDocument.Tag(name: "White", catalogID: "", mode: "custom", colors: ["#FFFFFF"], presetColors: ["#FFFFFF"], solidColor: "#FFFFFF", weight: 400, appearance: .white, catalogKind: "work")
        let restoredWhiteSync = try JSONDecoder().decode(SyncDocument.Tag.self, from: JSONEncoder().encode(whiteSync))
        assert(restoredWhiteSync == whiteSync)
        let originals = ["世界计划", "星乃一歌", "高松灯", "天马咲希"]
        let combined = CardTagPair.combine(tags: originals, overrides: [:], first: "星乃一歌", second: "天马咲希", kind: .cb)!
        let reverse = CardTagPair.combine(tags: originals, overrides: [:], first: "天马咲希", second: "星乃一歌", kind: .cp)!
        assert(reverse.tags == ["世界计划", "咲希&一歌", "高松灯"])
        assert(reverse.overrides["咲希&一歌"]!.pairing!.members.map(\.catalogID) == ["tag-0009", "tag-0008"])
        assert(reverse.overrides["咲希&一歌"]!.pairing!.colors == ["#FFDD44", "#33AAEE"])
        assert(CardTagPair.swapSides(tags: originals, overrides: [:], tag: "星乃一歌") == nil)
        assert(CardTagPair.swapSides(tags: combined.tags + ["咲希&一歌"], overrides: combined.overrides, tag: "一歌&咲希") == nil)
        assert(combined.tags == ["世界计划", "一歌&咲希", "高松灯"])
        assert(combined.overrides["一歌&咲希"]!.pairing!.members.map(\.catalogID) == ["tag-0008", "tag-0009"])
        assert(CardTagPair.combine(tags: originals + ["一歌&咲希"], overrides: [:], first: "星乃一歌", second: "天马咲希", kind: .cp) == nil)
        let full = originals + (0..<11).map { "Custom \($0)" }
        assert(CardTagPair.combine(tags: full, overrides: [:], first: "星乃一歌", second: "天马咲希", kind: .cp)!.tags.count == 14)

        let raw = CardTagColorPalette.rawValue(from: combined.overrides, tags: combined.tags)!
        let restored = CardTagColorPalette.overrides(from: raw)
        assert(restored["一歌&咲希"]!.pairing!.kind == .cb)
        assert(CardTagColorPalette.colorStyle(for: "一歌&咲希", overrides: restored).pairing?.kind == .cb)
        let refs = CardTagReference.reconcile(names: combined.tags, overrides: restored, previous: [])
        assert(refs[1].colors == ["#33AAEE", "#FFDD44"])
        assert(CardTagReference.decode(CardTagReference.encode(refs))![1].displayName == "一歌&咲希")
        let tag = SyncDocument.Tag(name: "一歌&咲希", catalogID: "", mode: "preset", colors: refs[1].colors,
                                   presetColors: refs[1].colors, solidColor: refs[1].solidColor, weight: 400, pairing: refs[1].override?.pairing)
        let synced = try JSONDecoder().decode(SyncDocument.Tag.self, from: JSONEncoder().encode(tag))
        assert(synced == tag)
        let legacy = Data(##"{"name":"Legacy","catalogID":"","mode":"solid","colors":["#112233"],"presetColors":["#112233"],"solidColor":"#112233","weight":400}"##.utf8)
        let legacyTag = try JSONDecoder().decode(SyncDocument.Tag.self, from: legacy)
        assert(legacyTag.pairing == nil && legacyTag.appearance == nil)

        let url = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("pairs.store")
        do {
            let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let cluster = QRCluster(name: "Pair fixture", tagListRawValue: combined.tags.joined(separator: "\n"), tagColorOverridesRawValue: raw)
            context.insert(cluster); try context.save()
            assert(cluster.tags == combined.tags)
            var overrides = cluster.tagColorOverrides
            overrides["一歌&咲希"]!.pairing!.kind = .cp
            overrides["一歌&咲希"]!.textWeight = .bold
            let swapped = CardTagPair.swapSides(tags: cluster.tags, overrides: overrides, tag: "一歌&咲希")!
            assert(swapped.overrides["一歌&咲希"] == nil)
            assert(swapped.overrides["咲希&一歌"]!.textWeight == .bold)
            cluster.setTags(swapped.tags, overrides: swapped.overrides)
            try context.save()
            assert(cluster.tagColorStyle(for: "咲希&一歌").pairing?.kind == .cp)
        }
        let reopened = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: url))
        let cluster = try ModelContext(reopened).fetch(FetchDescriptor<QRCluster>())[0]
        assert(cluster.tags == ["世界计划", "咲希&一歌", "高松灯"])
        assert(cluster.tagColorStyle(for: "咲希&一歌").pairing?.kind == .cp)
        for language in [AppLanguage.en, .ja, .zhHantHK, .zhHantTW, .zhHans] {
            AppSettings.shared.resolvedLanguage = language
            let pair = cluster.tagColorOverrides.values.compactMap(\.pairing).first!
            assert(cluster.tags.contains(pair.displayName))
            assert(CardTagLimiter.normalizedTag(pair.displayName) == pair.displayName)
            assert(cluster.tagColorStyle(for: pair.displayName).pairing?.kind == .cp)
        }
        AppSettings.shared.resolvedLanguage = .zhHans
        let snapshot = CardTagReference.decode(cluster.tagReferencesRawValue)!.map(\.snapshot)
        let empty = try JSONDecoder().decode(RemoteTagCatalogDocument.self, from: Data(#"{"schemaVersion":1,"revision":"empty","entries":[],"categories":[]}"#.utf8))
        RemoteTagCatalogSnapshot.replace(with: empty)
        for (ref, color) in zip(groupSnapshots, ["#39C5BB", "#FF9900", "#32C5FF"]) {
            let style = CardTagColorPalette.colorStyle(for: ref.displayName, overrides: [CardTagColorPalette.normalized(ref.displayName): ref.displayOverride])
            assert(style.whiteTextHex == color)
        }
        assert(ordinarySnapshots.allSatisfy {
            CardTagColorPalette.colorStyle(for: $0.displayName, overrides: [CardTagColorPalette.normalized($0.displayName): $0.displayOverride]).isWhiteBackground
        })
        assert(snapshot[1].displayName == "咲希&一歌")
        assert(snapshot[1].displayOverride.pairing?.colors == ["#FFDD44", "#33AAEE"])
        assert(CardTagPair.make("星乃一歌", "天马咲希", kind: .cb) == nil)
        print("PASS: maimai #32C5FF, consecutive white skipping, exact-white-only matching, all-white readable fallback, IP/group first-color ink, multilingual aliases and offline kind snapshots, ordinary white appearance across 530 catalog entries/3 color modes, contrast/legacy/sync/offline/SwiftData, fixed CP/CB appearance, 760 eligible pair cases, cross-IP/work/group/self guards, drag-direction order, swap/double-swap/collision, CP/CB palette and override round trips, sync DTO compatibility, SwiftData save/reopen/type/side change, five-language display, offline snapshots")
    }
}
