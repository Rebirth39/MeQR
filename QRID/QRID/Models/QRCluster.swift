import Foundation
import SwiftData
import SwiftUI

enum ClusterTemplateStyle: String, CaseIterable, Identifiable {
    case standard
    case conventionPass
    case rhodesPass

    var id: String { rawValue }

    static var selectableCases: [ClusterTemplateStyle] {
        [.standard, .rhodesPass]
    }

    var displayName: String {
        switch self {
        case .standard:
            return L.templateStandard
        case .conventionPass:
            return L.templateConventionPass
        case .rhodesPass:
            return L.templateRhodesPass
        }
    }

    var iconName: String {
        switch self {
        case .standard:
            return "rectangle.inset.filled"
        case .conventionPass:
            return "lanyardcard"
        case .rhodesPass:
            return "lanyardcard.fill"
        }
    }
}

@Model
final class QRCluster {
    var id: UUID
    var name: String
    var subtitle: String
    var avatarImageData: Data?
    var backgroundImageData: Data?
    var backgroundColorHex: String
    var borderColorHex: String
    var textColorHex: String?
    var qrColorHex: String?
    var templateStyleRawValue: String?
    var rhodesBannerImageData: Data?
    var passSubtitle: String?
    var tagListRawValue: String?
    var tagColorOverridesRawValue: String?
    var cornerRadius: Double
    var cardOpacity: Double?
    var createdAt: Date
    var sortOrder: Int
    var widgetProfileIndex: Int?
    var widgetUseClusterBackground: Bool?
    var widgetBackgroundImageData: Data?
    var widgetOpacity: Double?
    var widgetTextColorHex: String?
    var widgetSmallOffsetX: Double?
    var widgetSmallOffsetY: Double?
    var widgetMediumOffsetX: Double?
    var widgetMediumOffsetY: Double?
    var widgetLargeOffsetX: Double?
    var widgetLargeOffsetY: Double?

    @Relationship(deleteRule: .cascade, inverse: \QRProfile.cluster)
    var profiles: [QRProfile] = []

    init(
        name: String,
        subtitle: String = "",
        avatarImageData: Data? = nil,
        backgroundImageData: Data? = nil,
        backgroundColorHex: String = "#FFFFFF",
        borderColorHex: String = "#000000",
        textColorHex: String? = nil,
        qrColorHex: String? = nil,
        templateStyleRawValue: String? = nil,
        rhodesBannerImageData: Data? = nil,
        passSubtitle: String? = nil,
        tagListRawValue: String? = nil,
        tagColorOverridesRawValue: String? = nil,
        cornerRadius: Double = 16,
        cardOpacity: Double? = nil,
        sortOrder: Int = 0,
        widgetProfileIndex: Int? = nil,
        widgetUseClusterBackground: Bool? = nil,
        widgetBackgroundImageData: Data? = nil,
        widgetOpacity: Double? = nil,
        widgetTextColorHex: String? = nil,
        widgetSmallOffsetX: Double? = nil,
        widgetSmallOffsetY: Double? = nil,
        widgetMediumOffsetX: Double? = nil,
        widgetMediumOffsetY: Double? = nil,
        widgetLargeOffsetX: Double? = nil,
        widgetLargeOffsetY: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.subtitle = subtitle
        self.avatarImageData = avatarImageData
        self.backgroundImageData = backgroundImageData
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.textColorHex = textColorHex
        self.qrColorHex = qrColorHex
        self.templateStyleRawValue = templateStyleRawValue
        self.rhodesBannerImageData = rhodesBannerImageData
        self.passSubtitle = passSubtitle
        self.tagListRawValue = tagListRawValue
        self.tagColorOverridesRawValue = tagColorOverridesRawValue
        self.cornerRadius = cornerRadius
        self.cardOpacity = cardOpacity
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.widgetProfileIndex = widgetProfileIndex
        self.widgetUseClusterBackground = widgetUseClusterBackground
        self.widgetBackgroundImageData = widgetBackgroundImageData
        self.widgetOpacity = widgetOpacity
        self.widgetTextColorHex = widgetTextColorHex
        self.widgetSmallOffsetX = widgetSmallOffsetX
        self.widgetSmallOffsetY = widgetSmallOffsetY
        self.widgetMediumOffsetX = widgetMediumOffsetX
        self.widgetMediumOffsetY = widgetMediumOffsetY
        self.widgetLargeOffsetX = widgetLargeOffsetX
        self.widgetLargeOffsetY = widgetLargeOffsetY
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var borderColor: Color {
        Color(hex: borderColorHex)
    }

    var textColor: Color {
        Color(hex: textColorHex ?? "#000000")
    }

    var qrColor: Color {
        Color(hex: qrColorHex ?? "#000000")
    }

    var templateStyle: ClusterTemplateStyle {
        get {
            ClusterTemplateStyle(rawValue: templateStyleRawValue ?? "") ?? .standard
        }
        set { templateStyleRawValue = newValue.rawValue }
    }

    var passSubtitleText: String {
        let trimmed = passSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L.passLabel : trimmed
    }

    var tags: [String] {
        CardTagLimiter.tags(from: tagListRawValue ?? "")
    }

    var tagColorOverrides: [String: CardTagColorOverride] {
        CardTagColorPalette.overrides(from: tagColorOverridesRawValue)
    }

    func tagColorHex(for tag: String) -> String {
        CardTagColorPalette.colorHex(for: tag, overrides: tagColorOverrides)
    }

    func tagColorStyle(for tag: String) -> CardTagColorStyle {
        CardTagColorPalette.colorStyle(for: tag, overrides: tagColorOverrides)
    }
}

enum CardTagLimiter {
    static let maxTags = 10
    static let maxHalfWidthUnits = 20

    static func normalizedRawValue(_ value: String) -> String {
        tags(from: value).joined(separator: "\n")
    }

    static func tags(from value: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n\r")
        var result: [String] = []
        var seen: Set<String> = []

        for rawPart in value.components(separatedBy: separators) {
            let tag = normalizedTag(rawPart)
            guard !tag.isEmpty else { continue }
            let key = CardTagIndex.normalizedKey(tag)
            guard !seen.contains(key) else { continue }
            result.append(tag)
            seen.insert(key)
            if result.count >= maxTags {
                break
            }
        }

        return result
    }

    static func normalizedTag(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let indexedTag = CardTagIndex.canonicalTag(for: trimmed) {
            return indexedTag
        }
        if CardTagColorPalette.isPresetColored(trimmed) {
            return trimmed
        }
        return limited(trimmed)
    }

    static func limited(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var units = 0
        var result = ""

        for character in trimmed {
            let nextUnits = units + halfWidthUnits(for: character)
            if nextUnits > maxHalfWidthUnits {
                break
            }
            result.append(character)
            units = nextUnits
        }

        return result
    }

    private static func halfWidthUnits(for character: Character) -> Int {
        character.unicodeScalars.allSatisfy(\.isASCII) ? 1 : 2
    }
}

enum CardTagIndex {
    static func canonicalTag(for tag: String) -> String? {
        let key = normalizedKey(tag)
        guard !key.isEmpty else { return nil }
        let language = AppSettings.shared.resolvedLanguage
        return RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: key)?.names.value(for: language)
    }

    static func suggestions(for query: String, excluding existingTags: [String] = []) -> [String] {
        let language = AppSettings.shared.resolvedLanguage
        return searchEntries(for: query, excluding: existingTags, limit: 8).map {
            $0.names.value(for: language)
        }
    }

    static func searchEntries(
        for query: String,
        excluding existingTags: [String] = [],
        limit: Int? = nil
    ) -> [RemoteTagEntry] {
        let key = normalizedKey(query)
        guard !key.isEmpty else { return [] }

        let existingKeys = Set(existingTags.map(normalizedKey))
        let ranked = RemoteTagCatalogSnapshot.searchRecordValue().compactMap { record -> (Int, RemoteTagEntry)? in
            guard !record.searchableKeys.contains(where: existingKeys.contains) else { return nil }

            let score: Int
            if record.displayKeys.contains(key) {
                score = 0
            } else if record.aliasKeys.contains(key) {
                score = 1
            } else if record.displayKeys.contains(where: { $0.hasPrefix(key) }) {
                score = 2
            } else if record.aliasKeys.contains(where: { $0.hasPrefix(key) }) {
                score = 3
            } else if record.searchableKeys.contains(where: { $0.contains(key) }) {
                score = 4
            } else {
                return nil
            }
            return (score, record.entry)
        }
        .sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1.id < rhs.1.id : lhs.0 < rhs.0
        }
        .map(\.1)

        guard let limit else { return ranked }
        return Array(ranked.prefix(max(0, limit)))
    }

    static func featuredSuggestions(limit: Int = 6) -> [String] {
        let language = AppSettings.shared.resolvedLanguage
        return RemoteTagCatalogSnapshot.value().prefix(max(0, limit)).map {
            $0.names.value(for: language)
        }
    }

    static var categories: [RemoteTagCategory] {
        RemoteTagCatalogSnapshot.categoryValue()
    }

    static func entries(in category: RemoteTagCategory) -> [RemoteTagEntry] {
        RemoteTagCatalogSnapshot.entries(in: category)
    }

    nonisolated static func normalizedKey(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "！", with: "!")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

enum CardTagColorPalette {
    nonisolated static let fallbackHex = "#6F7582"

    private nonisolated static let multiDefaults: [(hexes: [String], keywords: [String])] = [
        (
            ["#39C5BB", "#00A0E9", "#88DD44", "#FF9900", "#EE1166", "#884499"],
            ["projectsekai", "project sekai", "pjsk", "啤酒烧烤", "啤酒燒烤", "プロセカ", "世界计划", "世界計畫", "世界計画", "世嘉彩舞", "彩舞", "世界计划彩色舞台", "世界計畫彩色舞台"]
        ),
        (
            ["#FF9900", "#FFBB00", "#FF66BB", "#33DD99", "#BB88EE"],
            ["Wonderlands x Showtime 拼色", "Wonderlands x Showtime Mix", "ワンダショMIX", "wonderlandsxshowtimemix", "wonderlands x showtime mix", "wsmix", "wxs mix", "wxs多色", "wxs拼色", "ws多色", "ws拼色", "ワンダショmix", "ワンダショ多色", "ワンダショ拼色"]
        ),
        (
            ["#39C5BB", "#FFE211", "#FFB000", "#FF69B4", "#E44D98", "#0068B7"],
            ["术力口", "ボカロ", "vocaloid", "vocalo", "VOCALOID"]
        ),
        (["#00A0E9", "#33AAEE", "#FFDD45", "#EE6666", "#BBDD22"], ["leoneed", "leo/need", "l/n", "ln", "レオニ", "Leo/need"]),
        (["#88DD44", "#FFCCAA", "#99CCFF", "#FFAACC", "#99EEDD"], ["moremorejump", "MORE MORE JUMP!", "mmj", "モモジャン", "桃跳"]),
        (["#EE1166", "#FF6699", "#00BBDD", "#FF7722", "#0077DD"], ["vividbadsquad", "vbs", "ビビバス", "Vivid BAD SQUAD"]),
        (["#FF9900", "#FFBB00", "#FF66BB", "#33DD99", "#BB88EE"], ["wonderlandsxshowtime", "Wonderlands x Showtime", "wonderlandsxshowti", "Wonderlands x Showti", "ワンダーランズ x ショウタイム", "ワンダーランズ×ショウタイム", "ws", "wxs", "wxS", "ワンダショ", "ワショ"]),
        (["#884499", "#BB6688", "#8889CC", "#CCAA88", "#DDAACC"], ["nightcord", "Nightcord at 25:00", "25点，Nightcord见。", "25點，Nightcord見。", "25時、ナイトコードで。", "n25", "25ji", "25時", "25时", "25點", "25点", "ニーゴ"]),
        (["#FF3377", "#FF5522", "#3366CC", "#FF99CC", "#FFCC33", "#AA66CC"], ["poppinparty", "poppin'party", "ポピパ", "Poppin'Party"]),
        (["#E53344", "#E5004F", "#55BB77", "#FF77AA", "#CC3333", "#FFCC66"], ["afterglow", "aglow", "美竹兰组", "美竹蘭組"]),
        (["#33DDAA", "#FF66AA", "#66CCFF", "#FFEE99", "#88DD44", "#CC99FF"], ["pastelpalettes", "pastel*palettes", "pp", "パスパレ", "彩组", "彩組"]),
        (["#3344AA", "#3344AA", "#66CCFF", "#DD2244", "#AA44DD", "#9999CC"], ["roselia", "roselia组"]),
        (["#FFC02A", "#FFCC33", "#AA66CC", "#FF9933", "#66CCFF", "#996633"], ["hellohappyworld", "hhw", "ハロハピ", "hello happy world", "Hello Happy World!"]),
        (["#33AADD", "#AABBFF", "#FF99CC", "#99DD66", "#FFCC66", "#6699CC"], ["morfonica", "モニカ", "Morfonica"]),
        (["#66CC33", "#AA3333", "#77CC44", "#FF9933", "#FF77BB", "#66CCFF"], ["raiseasuilen", "raise a suilen", "ras", "RAISE A SUILEN"]),
        (["#3381B0", "#77BBDD", "#FF8899", "#66CC99", "#DDBB66", "#4455AA"], ["mygo", "mygo!!!!!", "迷子", "MyGO!!!!!"]),
        (["#881144", "#CC4466", "#884499", "#66AA66", "#336699", "#DDBB66"], ["avemujica", "母鸡卡", "Ave Mujica"]),
        (["#7D4CFF", "#FF66AA", "#66CCFF", "#FFCC66", "#99DD66", "#CC99FF"], ["mugendaimewtype", "mugendai mewtype", "夢限大みゅーたいぷ", "梦限大", "夢限大", "Mugendai Mewtype"]),
        (["#F4B6C2", "#FF99CC", "#FFD34E", "#5B8FE8", "#E94B4B"], ["kessokuband", "結束バンド", "结束乐队", "結束樂隊", "Kessoku Band"]),
        (["#F2C94C", "#FF8FB3", "#5AA0E6", "#FFD23F", "#CFA7FF", "#61C28B"], ["htt", "hokagoteatime", "ho-kago tea time", "放学后茶会", "放學後茶會", "放課後ティータイム", "Ho-kago Tea Time"]),
        (["#E60033", "#F05A8A", "#9B6DFF", "#FFD447", "#58A6FF", "#5EC26A"], ["togenashitogeari", "トゲナシトゲアリ", "有刺无刺", "有刺無刺", "TOGENASHI TOGEARI", "トゲトゲ", "刺"]),
        (["#FFFFFF", "#32C5FF", "#FFFFFF"], ["maimai", "舞萌", "舞萌DX", "maimai dx", "maimaidx"]),
        (["#FF4D6D", "#FFD447", "#62DC70", "#43C7FF", "#9B6DFF"], ["maimai 15000+", "maimai15000+", "15000+"]),
    ]

    private nonisolated static let splitDefaults: [(leadingHex: String, trailingHex: String, keywords: [String])] = [
        ("#00A0E9", "#33AAEE", ["星乃一歌", "一歌", "Ichika Hoshino", "ichika", "hoshinoichika"]),
        ("#00A0E9", "#FFDD45", ["天马咲希", "天馬咲希", "咲希", "Saki Tenma", "saki", "tenmasaki"]),
        ("#00A0E9", "#EE6666", ["望月穗波", "望月穂波", "穗波", "穂波", "Honami Mochizuki", "honami", "mochizukihonami"]),
        ("#00A0E9", "#BBDD22", ["日野森志步", "日野森志歩", "志步", "志歩", "Shiho Hinomori", "shiho", "hinomorishiho"]),
        ("#88DD44", "#FFCCAA", ["花里实乃理", "花里實乃理", "花里実乃理", "花里みのり", "实乃理", "實乃理", "実乃理", "みのり", "Minori Hanasato", "minori", "hanasatominori"]),
        ("#88DD44", "#99CCFF", ["桐谷遥", "桐谷遙", "遥", "遙", "Haruka Kiritani", "haruka", "kiritaniharuka"]),
        ("#88DD44", "#FFAACC", ["桃井爱莉", "桃井愛莉", "爱莉", "愛莉", "Airi Momoi", "airi", "momoiairi"]),
        ("#88DD44", "#99EEDD", ["日野森雫", "雫", "Shizuku Hinomori", "shizuku", "hinomorishizuku"]),
        ("#EE1166", "#FF6699", ["小豆泽心羽", "小豆澤心羽", "小豆沢こはね", "心羽", "こはね", "Kohane Azusawa", "kohane", "azusawakohane"]),
        ("#EE1166", "#00BBDD", ["白石杏", "杏", "An Shiraishi", "an", "shiraishian"]),
        ("#EE1166", "#FF7722", ["东云彰人", "東雲彰人", "彰人", "Akito Shinonome", "akito", "shinonomeakito"]),
        ("#EE1166", "#0077DD", ["青柳冬弥", "青柳冬彌", "冬弥", "冬彌", "Toya Aoyagi", "toya", "touya", "aoyagitoya"]),
        ("#FF9900", "#FFBB00", ["天马司", "天馬司", "司", "Tsukasa Tenma", "tsukasa", "tenmatsukasa"]),
        ("#FF9900", "#FF66BB", ["凤笑梦", "鳳笑夢", "鳳えむ", "笑梦", "笑夢", "Emu Otori", "emu", "otoriemu"]),
        ("#FF9900", "#33DD99", ["草薙宁宁", "草薙寧寧", "草薙寧々", "宁宁", "寧寧", "寧々", "Nene Kusanagi", "nene", "kusanaginene"]),
        ("#FF9900", "#BB88EE", ["神代类", "神代類", "类", "類", "Rui Kamishiro", "rui", "kamishirorui"]),
        ("#884499", "#BB6688", ["宵崎奏", "奏", "Kanade Yoisaki", "kanade", "yoisakikanade"]),
        ("#884499", "#8889CC", ["朝比奈真冬", "朝比奈まふゆ", "真冬", "Mafuyu Asahina", "mafuyu", "asahinamafuyu"]),
        ("#884499", "#CCAA88", ["东云绘名", "東雲繪名", "東雲絵名", "绘名", "繪名", "絵名", "Ena Shinonome", "ena", "shinonomeena"]),
        ("#884499", "#DDAACC", ["晓山瑞希", "曉山瑞希", "暁山瑞希", "瑞希", "Mizuki Akiyama", "mizuki", "akiyamamizuki"]),
        ("#FF3377", "#FF5522", ["户山香澄", "戸山香澄", "香澄", "Kasumi Toyama", "kasumi", "toyamakasumi"]),
        ("#FF3377", "#3366CC", ["花园多惠", "花園たえ", "多惠", "たえ", "Tae Hanazono", "tae", "hanazonotae"]),
        ("#FF3377", "#FF99CC", ["牛込里美", "牛込りみ", "里美", "りみ", "Rimi Ushigome", "rimi", "ushigomerimi"]),
        ("#FF3377", "#FFCC33", ["山吹沙绫", "山吹沙綾", "山吹沙綾", "沙绫", "沙綾", "Saaya Yamabuki", "saaya", "yamabukisaaya"]),
        ("#FF3377", "#AA66CC", ["市谷有咲", "有咲", "Arisa Ichigaya", "arisa", "ichigayaarisa"]),
        ("#E53344", "#E5004F", ["美竹兰", "美竹蘭", "蘭", "Ran Mitake", "ran", "mitakeran"]),
        ("#E53344", "#55BB77", ["青叶摩卡", "青葉モカ", "摩卡", "モカ", "Moca Aoba", "moca", "aobamoca"]),
        ("#E53344", "#FF77AA", ["上原绯玛丽", "上原緋瑪麗", "上原ひまり", "绯玛丽", "緋瑪麗", "ひまり", "Himari Uehara", "himari", "ueharahimari"]),
        ("#E53344", "#CC3333", ["宇田川巴", "巴", "Tomoe Udagawa", "tomoe", "udagawatomoe"]),
        ("#E53344", "#FFCC66", ["羽泽鸫", "羽澤つぐみ", "鸫", "つぐみ", "Tsugumi Hazawa", "tsugumi", "hazawatsugumi"]),
        ("#33DDAA", "#FF66AA", ["丸山彩", "彩", "Aya Maruyama", "aya", "maruyamaaya"]),
        ("#33DDAA", "#66CCFF", ["冰川日菜", "氷川日菜", "日菜", "Hina Hikawa", "hina", "hikawahina"]),
        ("#33DDAA", "#FFEE99", ["白鹭千圣", "白鷺千聖", "千圣", "千聖", "Chisato Shirasagi", "chisato", "shirasagichisato"]),
        ("#33DDAA", "#88DD44", ["大和麻弥", "大和麻彌", "麻弥", "麻彌", "Maya Yamato", "maya", "yamatomaya"]),
        ("#33DDAA", "#CC99FF", ["若宫伊芙", "若宮イヴ", "伊芙", "イヴ", "Eve Wakamiya", "eve", "wakamiyaeve"]),
        ("#3344AA", "#3344AA", ["凑友希那", "湊友希那", "友希那", "Yukina Minato", "yukina", "minatoyukina"]),
        ("#3344AA", "#66CCFF", ["冰川纱夜", "氷川紗夜", "纱夜", "紗夜", "Sayo Hikawa", "sayo", "hikawasayo"]),
        ("#3344AA", "#DD2244", ["今井莉莎", "今井リサ", "莉莎", "リサ", "Lisa Imai", "lisa", "imailisa"]),
        ("#3344AA", "#AA44DD", ["宇田川亚子", "宇田川あこ", "亚子", "あこ", "Ako Udagawa", "ako", "udagawaako"]),
        ("#3344AA", "#9999CC", ["白金燐子", "燐子", "Rinko Shirokane", "rinko", "shirokanerinko"]),
        ("#FFC02A", "#FFCC33", ["弦卷心", "弦巻こころ", "心", "こころ", "Kokoro Tsurumaki", "kokoro", "tsurumakikokoro"]),
        ("#FFC02A", "#AA66CC", ["濑田薰", "瀬田薫", "薰", "薫", "Kaoru Seta", "kaoru", "setakaoru"]),
        ("#FFC02A", "#FF9933", ["北泽育美", "北沢はぐみ", "育美", "はぐみ", "Hagumi Kitazawa", "hagumi", "kitazawahagumi"]),
        ("#FFC02A", "#66CCFF", ["松原花音", "花音", "Kanon Matsubara", "kanon", "matsubarakanon"]),
        ("#FFC02A", "#996633", ["奥泽美咲", "奥沢美咲", "美咲", "米歇尔", "ミッシェル", "Misaki Okusawa", "Michelle", "misaki", "okusawamisaki"]),
        ("#33AADD", "#AABBFF", ["仓田真白", "倉田ましろ", "真白", "ましろ", "Mashiro Kurata", "mashiro", "kuratamashiro"]),
        ("#33AADD", "#FF99CC", ["桐谷透子", "桐ヶ谷透子", "透子", "Toko Kirigaya", "toko", "kirigayatoko"]),
        ("#33AADD", "#99DD66", ["广町七深", "広町七深", "七深", "Nanami Hiromachi", "nanami", "hiromachinanami"]),
        ("#33AADD", "#FFCC66", ["二叶筑紫", "二葉つくし", "筑紫", "つくし", "Tsukushi Futaba", "tsukushi", "futabatukushi", "futabatsukushi"]),
        ("#33AADD", "#6699CC", ["八潮瑠唯", "瑠唯", "Rui Yashio", "yashiorui"]),
        ("#66CC33", "#AA3333", ["和奏蕾依", "和奏レイ", "蕾依", "レイヤ", "LAYER", "Rei Wakana", "reiwakana"]),
        ("#66CC33", "#77CC44", ["朝日六花", "六花", "ロック", "LOCK", "Rokka Asahi", "rokka", "asahirokka"]),
        ("#66CC33", "#FF9933", ["佐藤益木", "益木", "マスキング", "MASKING", "Masuki Sato", "masuki", "satomasuki"]),
        ("#66CC33", "#FF77BB", ["鳰原令王那", "令王那", "パレオ", "PAREO", "Reona Nyubara", "reona", "nyubarareona"]),
        ("#66CC33", "#66CCFF", ["珠手知由", "知由", "チュチュ", "CHU2", "Chiyu Tamade", "chiyu", "tamadechiyu"]),
        ("#3381B0", "#77BBDD", ["高松灯", "高松燈", "灯", "燈", "Tomori Takamatsu", "tomori", "takamatsutomori"]),
        ("#3381B0", "#FF8899", ["千早爱音", "千早愛音", "爱音", "愛音", "Anon Chihaya", "anon", "chihayaanon"]),
        ("#3381B0", "#66CC99", ["要乐奈", "要楽奈", "乐奈", "楽奈", "Raana Kaname", "raana", "kanameraana"]),
        ("#3381B0", "#DDBB66", ["长崎素世", "長崎そよ", "素世", "そよ", "Soyo Nagasaki", "soyo", "nagasakisoyo"]),
        ("#3381B0", "#4455AA", ["椎名立希", "立希", "Taki Shiina", "taki", "shiinataki"]),
        ("#881144", "#CC4466", ["三角初华", "三角初華", "初华", "初華", "Doloris", "Uika Misumi", "uika", "misumiuika"]),
        ("#881144", "#884499", ["丰川祥子", "豊川祥子", "祥子", "Oblivionis", "Sakiko Togawa", "sakiko", "togawasakiko"]),
        ("#881144", "#66AA66", ["若叶睦", "若葉睦", "睦", "Mortis", "Mutsumi Wakaba", "mutsumi", "wakabamutsumi"]),
        ("#881144", "#336699", ["八幡海铃", "八幡海鈴", "海铃", "海鈴", "Timoris", "Umiri Yahata", "umiri", "yahataumiri"]),
        ("#881144", "#DDBB66", ["祐天寺若麦", "若麦", "若麥", "Amoris", "Nyamu Yutenji", "nyamu", "yutenjinyamu"]),
        ("#7D4CFF", "#FF66AA", ["仲町阿拉蕾", "仲町あられ", "阿拉蕾", "あられ", "Arale Nakamachi", "arale", "nakamachiarale"]),
        ("#7D4CFF", "#66CCFF", ["宫永野乃花", "宮永ののか", "野乃花", "ののか", "Nonoka Miyanaga", "nonoka", "miyanaganonoka"]),
        ("#7D4CFF", "#FFCC66", ["峰月律", "律", "Ritsu Minetsuki", "ritsu", "minetsukiritsu"]),
        ("#7D4CFF", "#99DD66", ["藤都子", "都子", "Miyako Fuji", "miyako", "fujimiyako"]),
        ("#7D4CFF", "#CC99FF", ["千石由乃", "千石ユノ", "由乃", "ユノ", "Yuno Sengoku", "yuno", "sengokuyuno"]),
        ("#F4B6C2", "#FF99CC", ["后藤一里", "後藤ひとり", "波奇", "ぼっち", "Hitori Gotoh", "hitorigotoh"]),
        ("#F4B6C2", "#FFD34E", ["伊地知虹夏", "虹夏", "Nijika Ijichi", "nijika", "ijichinijika"]),
        ("#F4B6C2", "#5B8FE8", ["山田凉", "山田涼", "山田リョウ", "凉", "涼", "リョウ", "Ryo Yamada", "ryo", "yamadaryo"]),
        ("#F4B6C2", "#E94B4B", ["喜多郁代", "喜多", "喜多ちゃん", "Ikuyo Kita", "kita", "ikuyokita"]),
        ("#F2C94C", "#FF8FB3", ["平泽唯", "平澤唯", "平沢唯", "唯", "Yui Hirasawa", "yui", "hirasawayui"]),
        ("#F2C94C", "#5AA0E6", ["秋山澪", "澪", "Mio Akiyama", "mio", "akiyamamio"]),
        ("#F2C94C", "#FFD23F", ["田井中律", "Ritsu Tainaka", "tainakaritsu"]),
        ("#F2C94C", "#CFA7FF", ["琴吹紬", "紬", "Tsumugi Kotobuki", "mugi", "tsumugi", "kotobukitsumugi"]),
        ("#F2C94C", "#61C28B", ["中野梓", "梓", "Azusa Nakano", "azusa", "azunyan", "あずにゃん", "nakanoazusa"]),
        ("#F2C94C", "#F5A6B8", ["平泽忧", "平澤憂", "平沢憂", "忧", "憂", "Ui Hirasawa", "ui", "hirasawaui"]),
        ("#F2C94C", "#72BFA3", ["真锅和", "真鍋和", "和", "Nodoka Manabe", "nodoka", "manabenodoka"]),
        ("#F2C94C", "#B990D8", ["山中佐和子", "山中さわ子", "佐和子", "さわ子", "Sawako Yamanaka", "sawako", "yamanakasawako"]),
        ("#F2C94C", "#D59A5B", ["铃木纯", "鈴木純", "纯", "純", "Jun Suzuki", "jun", "suzukijun"]),
        ("#E60033", "#F05A8A", ["井芹仁菜", "仁菜", "Nina Iseri", "nina", "iserinina"]),
        ("#E60033", "#9B6DFF", ["河原木桃香", "桃香", "Momoka Kawaragi", "momoka", "kawaragimomoka"]),
        ("#E60033", "#FFD447", ["安和昴", "安和すばる", "昴", "すばる", "Subaru Awa", "subaru", "awasubaru"]),
        ("#E60033", "#58A6FF", ["海老塚智", "智", "Tomo Ebizuka", "tomo", "ebizukatomo"]),
        ("#E60033", "#5EC26A", ["卢帕", "盧帕", "ルパ", "Rupa", "rupa"]),
        ("#8A3FB5", "#D68AF2", ["maimai 10000+", "maimai10000+", "10000+"]),
        ("#9D3F28", "#F08A4B", ["maimai 12000+", "maimai12000+", "12000+"]),
        ("#72BDE8", "#C4EDFF", ["maimai 13000+", "maimai13000+", "13000+"]),
        ("#F2B705", "#FFE77A", ["maimai 14000+", "maimai14000+", "14000+"]),
        ("#E8CF63", "#FFF8C4", ["maimai 14500+", "maimai14500+", "14500+"]),
    ]

    private nonisolated static let defaults: [(hex: String, keywords: [String])] = [
        ("#39C5BB", ["术力口", "ボカロ", "vocaloid", "vocalo", "初音未来", "初音ミク", "初音", "hatsunemiku", "miku", "镜音铃", "鏡音リン", "镜音连", "鏡音レン", "巡音流歌", "巡音ルカ", "meiko", "kaito"]),
        ("#E5004F", ["bangdream", "バンドリ", "邦邦", "户山香澄", "戸山香澄", "美竹兰", "美竹蘭", "丸山彩", "凑友希那", "湊友希那", "弦卷心", "弦巻こころ", "仓田真白", "倉田ましろ"]),
        ("#E53344", ["afterglow", "aglow", "美竹兰组", "美竹蘭組", "青叶摩卡", "青葉モカ", "上原绯玛丽", "上原ひまり", "宇田川巴", "羽泽鸫", "羽澤つぐみ"]),
        ("#33DDAA", ["pastelpalettes", "pastel*palettes", "pp", "パスパレ", "彩组", "彩組", "冰川日菜", "氷川日菜", "白鹭千圣", "白鷺千聖", "大和麻弥", "大和麻彌", "若宫伊芙", "若宮イヴ"]),
        ("#FFC02A", ["hellohappyworld", "hhw", "ハロハピ", "hello happy world", "弦卷心", "弦巻こころ", "濑田薰", "瀬田薫", "北泽育美", "北沢はぐみ", "松原花音", "奥泽美咲", "奥沢美咲", "米歇尔", "ミッシェル"]),
        ("#33AADD", ["morfonica", "モニカ", "仓田真白", "倉田ましろ", "桐谷透子", "桐ヶ谷透子", "广町七深", "広町七深", "二叶筑紫", "二葉つくし", "八潮瑠唯"]),
        ("#66CC33", ["raiseasuilen", "raise a suilen", "ras", "レイチェル", "layer", "lock", "masking", "pareo", "chu2", "和奏蕾依", "朝日六花", "佐藤益木", "鳰原令王那", "珠手知由"]),
        ("#3381B0", ["mygo", "mygo!!!!!", "迷子", "高松灯", "高松燈", "千早爱音", "千早愛音", "要乐奈", "要楽奈", "长崎素世", "長崎そよ", "椎名立希"]),
        ("#881144", ["avemujica", "母鸡卡", "三角初华", "三角初華", "丰川祥子", "豊川祥子", "若叶睦", "若葉睦", "祐天寺若麦", "八幡海铃", "八幡海鈴"]),
        ("#3344AA", ["roselia", "roselia组", "凑友希那", "湊友希那", "冰川纱夜", "氷川紗夜", "今井莉莎", "今井リサ", "宇田川亚子", "宇田川あこ", "白金燐子"]),
        ("#FF3377", ["poppinparty", "poppin'party", "ポピパ", "户山香澄", "戸山香澄", "花园多惠", "花園たえ", "牛込里美", "牛込りみ", "山吹沙绫", "山吹沙綾", "市谷有咲"]),
        ("#7D4CFF", ["mugendaimewtype", "mugendai mewtype", "夢限大みゅーたいぷ", "梦限大", "夢限大", "仲町阿拉蕾", "仲町あられ", "宫永野乃花", "宮永ののか", "峰月律", "藤都子", "千石由乃", "千石ユノ"]),
        ("#00A0E9", ["projectsekai", "project sekai", "pjsk", "啤酒烧烤", "啤酒燒烤", "プロセカ", "世界计划", "世界計畫", "世界計画", "世嘉彩舞", "彩舞", "世界计划彩色舞台", "世界計畫彩色舞台"]),
        ("#00A0E9", ["leoneed", "leo/need", "l/n", "ln", "レオニ", "星乃一歌", "一歌", "天马咲希", "天馬咲希", "咲希", "望月穗波", "望月穂波", "穗波", "穂波", "日野森志步", "日野森志歩", "志步", "志歩"]),
        ("#88DD44", ["moremorejump", "MORE MORE JUMP!", "mmj", "モモジャン", "桃跳", "花里实乃理", "花里実乃理", "花里みのり", "实乃理", "実乃理", "みのり", "桐谷遥", "桃井爱莉", "桃井愛莉", "爱莉", "愛莉", "日野森雫"]),
        ("#EE1166", ["vividbadsquad", "vbs", "ビビバス", "小豆泽心羽", "小豆沢こはね", "こはね", "白石杏", "东云彰人", "東雲彰人", "彰人", "青柳冬弥", "青柳冬彌", "冬弥", "冬彌"]),
        ("#FF9900", ["wonderlandsxshowtime", "Wonderlands x Showtime", "ワンダーランズ x ショウタイム", "ワンダーランズ×ショウタイム", "ws", "wxS", "wxs", "ワンダショ", "ワショ", "天马司", "天馬司", "凤笑梦", "鳳えむ", "笑梦", "草薙宁宁", "草薙寧々", "宁宁", "寧々", "神代类", "神代類"]),
        ("#884499", ["nightcord", "Nightcord at 25:00", "25点，Nightcord见。", "25點，Nightcord見。", "25時、ナイトコードで。", "n25", "25ji", "25時", "25时", "25點", "25点", "ニーゴ", "宵崎奏", "朝比奈真冬", "真冬", "东云绘名", "東雲絵名", "绘名", "絵名", "晓山瑞希", "暁山瑞希", "瑞希"]),
        ("#F2A900", ["arknights", "明日方舟", "アークナイツ", "方舟", "罗德岛", "rhodesisland", "阿米娅", "阿米婭", "アーミヤ", "凯尔希", "凱爾希", "ケルシー", "博士", "陈", "チェン", "德克萨斯", "德克薩斯", "テキサス", "拉普兰德", "ラップランド", "能天使", "エクシア", "银灰", "銀灰", "シルバーアッシュ", "斯卡蒂", "スカジ", "w"]),
        ("#00AEEF", ["bluearchive", "ブルアカ", "蔚蓝档案", "碧蓝档案", "ba", "砂狼白子", "白子", "シロコ", "小鸟游星野", "小鳥遊ホシノ", "星野", "ホシノ", "陆八魔亚瑠", "陸八魔アル", "亚瑠", "アル", "空崎日奈", "日奈", "ヒナ", "早濑优香", "早瀬ユウカ", "优香", "ユウカ", "圣园未花", "聖園ミカ", "未花", "ミカ", "天童爱丽丝", "天童アリス", "爱丽丝", "アリス"]),
        ("#5D7EDB", ["honkaistarrail", "hsr", "崩坏星穹铁道", "崩壊スターレイル", "星铁", "星鐵", "开拓者", "開拓者", "三月七", "丹恒", "丹恆", "姬子", "瓦尔特", "瓦爾特", "卡芙卡", "kafka", "银狼", "銀狼", "刃", "景元", "饮月", "飲月", "黄泉", "流萤", "流螢", "firefly", "知更鸟", "知更鳥", "robin", "星期日", "sunday"]),
        ("#C9A063", ["genshin", "genshinimpact", "原神", "旅行者", "荧", "熒", "空", "派蒙", "paimon", "温迪", "ウェンティ", "钟离", "鍾離", "雷电将军", "雷電将軍", "雷神", "纳西妲", "納西妲", "nahida", "芙宁娜", "芙寧娜", "furina", "魈", "达达利亚", "達達利亞", "公子", "胡桃", "神里绫华", "神里綾華", "可莉"]),
        ("#E4007F", ["lovelive", "ラブライブ", "ll", "缪斯", "μ's", "aqours", "虹咲", "liella", "高坂穗乃果", "高坂穂乃果", "南小鸟", "南ことり", "园田海未", "園田海未", "西木野真姬", "西木野真姫", "矢泽妮可", "矢澤にこ", "妮可", "にこ", "高海千歌", "樱内梨子", "桜内梨子", "渡边曜", "渡辺曜", "上原步梦", "上原歩夢", "涩谷香音", "澁谷かのん", "唐可可"]),
        ("#F6B51D", ["ensemblestars", "enstars", "あんスタ", "偶像梦幻祭", "偶像夢幻祭", "es", "明星昴流", "冰鹰北斗", "氷鷹北斗", "游木真", "衣更真绪", "衣更真緒", "朔间零", "朔間零", "羽风薰", "羽風薫", "濑名泉", "瀬名泉", "月永雷欧", "月永レオ", "朱樱司", "朱桜司", "天城一彩", "天城燐音", "白鸟蓝良", "白鳥藍良"]),
        ("#F34E7B", ["idolmaster", "theidolmaster", "imas", "アイマス", "偶像大师", "偶像大師", "765", "灰姑娘", "cgss", "百万现场", "mltd", "闪耀色彩", "シャニマス", "天海春香", "如月千早", "星井美希", "岛村卯月", "島村卯月", "涩谷凛", "渋谷凛", "本田未央", "春日未来", "最上静香", "伊吹翼", "樱木真乃", "櫻木真乃", "风野灯织", "風野灯織", "八宫巡", "八宮めぐる"]),
        ("#8D5AC2", ["umamusume", "ウマ娘", "赛马娘", "賽馬娘", "马娘", "特别周", "スペシャルウィーク", "无声铃鹿", "サイレンススズカ", "东海帝王", "トウカイテイオー", "小栗帽", "オグリキャップ", "黄金船", "ゴールドシップ", "米浴", "ライスシャワー", "目白麦昆", "メジロマックイーン", "北部玄驹", "キタサンブラック", "里见光钻", "サトノダイヤモンド"]),
        ("#F4B6C2", ["bocchitherock", "ぼっちざろっく", "孤独摇滚", "孤獨搖滾", "孤摇", "孤搖", "kessokuband", "結束バンド", "结束乐队", "結束樂隊", "后藤一里", "後藤ひとり", "波奇", "ぼっち", "伊地知虹夏", "虹夏", "山田凉", "山田リョウ", "山田涼", "喜多郁代", "喜多ちゃん", "喜多"]),
        ("#F2C94C", ["k-on", "kon", "けいおん", "けいおん！", "轻音少女", "輕音少女", "轻音部", "輕音部", "放学后茶会", "放學後茶會", "放課後ティータイム", "htt", "hokagoteatime", "ho-kago tea time", "平泽唯", "平澤唯", "平沢唯", "秋山澪", "田井中律", "琴吹紬", "中野梓", "平泽忧", "平澤憂", "真锅和", "真鍋和", "山中佐和子", "山中さわ子", "铃木纯", "鈴木純"]),
        ("#E60033", ["girlsbandcry", "gbc", "ガールズバンドクライ", "ガールズバンドくらい", "ガルクラ", "少女乐队哭泣", "少女樂隊哭泣", "togenashitogeari", "トゲナシトゲアリ", "有刺无刺", "有刺無刺", "井芹仁菜", "河原木桃香", "安和昴", "安和すばる", "海老塚智", "卢帕", "盧帕", "ルパ"]),
        ("#E60012", ["touhou", "touhouproject", "东方project", "東方project", "东方", "東方", "博丽灵梦", "博麗霊夢", "灵梦", "霊夢", "雾雨魔理沙", "霧雨魔理沙", "魔理沙", "十六夜咲夜", "咲夜", "魂魄妖梦", "魂魄妖夢", "妖梦", "妖夢", "蕾米莉亚", "蕾米莉亞", "レミリア", "芙兰朵露", "芙蘭朵露", "フランドール", "琪露诺", "チルノ", "古明地恋", "古明地こいし"]),
        ("#7B4BC9", ["eva", "nge", "Evangelion", "エヴァンゲリオン", "新世纪福音战士", "新世紀福音戰士", "碇真嗣", "碇シンジ", "绫波丽", "綾波レイ", "明日香", "アスカ", "渚薰", "渚カヲル", "葛城美里", "葛城ミサト"]),
        ("#8CC7A1", ["frieren", "葬送的芙莉莲", "葬送的芙莉蓮", "葬送のフリーレン", "芙莉莲", "芙莉蓮", "フリーレン", "菲伦", "菲倫", "フェルン", "修塔尔克", "修塔爾克", "シュタルク", "辛美尔", "辛美爾", "ヒンメル", "阿乌拉", "阿烏拉", "アウラ"]),
        ("#4B3F72", ["jjk", "jujutsukaisen", "咒术回战", "咒術迴戰", "呪術廻戦", "虎杖悠仁", "伏黑惠", "伏黒恵", "钉崎野蔷薇", "釘崎野薔薇", "五条悟", "五條悟", "夏油杰", "夏油傑"]),
        ("#2E8B57", ["demonslayer", "kimetsu", "鬼灭之刃", "鬼滅之刃", "鬼滅の刃", "灶门炭治郎", "竈門炭治郎", "灶门祢豆子", "竈門禰豆子", "我妻善逸", "嘴平伊之助", "富冈义勇", "富岡義勇", "冨岡義勇"]),
        ("#F58220", ["haikyu", "haikyuu", "ハイキュー", "排球少年", "日向翔阳", "日向翔陽", "影山飞雄", "影山飛雄", "月岛萤", "月島蛍", "孤爪研磨", "黑尾铁朗", "黒尾鉄朗"]),
        ("#1E73BE", ["conan", "detectiveconan", "名侦探柯南", "名偵探柯南", "名探偵コナン", "江户川柯南", "江戸川コナン", "工藤新一", "毛利兰", "毛利蘭", "灰原哀", "安室透", "降谷零"]),
        ("#8A6A4F", ["aot", "snk", "attackontitan", "进击的巨人", "進擊的巨人", "進撃の巨人", "艾伦耶格尔", "艾連葉卡", "エレン", "三笠阿克曼", "ミカサ", "阿尔敏阿诺德", "アルミン", "利威尔", "里維", "リヴァイ"]),
        ("#E84A27", ["chainsawman", "csm", "电锯人", "鏈鋸人", "チェンソーマン", "电次", "デンジ", "玛奇玛", "瑪奇瑪", "マキマ", "早川秋", "早川アキ", "帕瓦", "パワー", "蕾塞", "レゼ"]),
        ("#E85AA8", ["oshinoko", "我推的孩子", "推しの子", "星野爱", "星野愛", "星野アイ", "星野爱久爱海", "星野愛久愛海", "阿库亚", "阿庫亞", "露比", "有马加奈", "有馬かな", "黑川茜", "黒川あかね"]),
        ("#7BA05B", ["spyxfamily", "SPY x FAMILY", "SPY×FAMILY", "间谍过家家", "間諜家家酒", "阿尼亚福杰", "安妮亞佛傑", "アーニャ", "劳埃德福杰", "洛伊德佛傑", "ロイド", "约尔福杰", "約兒佛傑", "ヨル"]),
        ("#FFCB05", ["pokemon", "pokémon", "宝可梦", "寶可夢", "ポケモン", "精灵宝可梦", "神奇寶貝", "皮卡丘", "ピカチュウ", "小智", "サトシ", "喷火龙", "噴火龍", "リザードン", "伊布", "イーブイ", "梦幻", "夢幻", "ミュウ"]),
        ("#32C5FF", ["maimai", "舞萌", "舞萌DX", "maimai dx", "maimaidx"]),
        ("#D68AF2", ["maimai 10000+", "maimai10000+"]),
        ("#F08A4B", ["maimai 12000+", "maimai12000+"]),
        ("#C4EDFF", ["maimai 13000+", "maimai13000+"]),
        ("#FFE77A", ["maimai 14000+", "maimai14000+"]),
        ("#FFF8C4", ["maimai 14500+", "maimai14500+"]),
        ("#9B6DFF", ["maimai 15000+", "maimai15000+"]),
    ]

    nonisolated static func colorHex(for tag: String, overrides: [String: CardTagColorOverride] = [:]) -> String {
        colorStyle(for: tag, overrides: overrides).leadingHex
    }

    nonisolated static func colorStyle(for tag: String, overrides: [String: CardTagColorOverride] = [:]) -> CardTagColorStyle {
        let key = normalized(tag)
        if let preset = presetStyle(for: tag) {
            if overrides[key]?.mode == .solid {
                return CardTagColorStyle(leadingHex: preset.solidHex, trailingHex: nil)
            }
            return preset.style
        }

        if let override = overrides[key],
           override.mode == .custom {
            return CardTagColorStyle(segmentHexes: normalizedHexes(override.hexes))
        }

        return CardTagColorStyle(leadingHex: defaultHex(for: tag), trailingHex: nil)
    }

    nonisolated static func overrides(from rawValue: String?) -> [String: CardTagColorOverride] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8) else {
            return [:]
        }

        if let decoded = try? JSONDecoder().decode([String: CardTagColorOverride].self, from: data) {
            return decoded.reduce(into: [:]) { result, pair in
                let key = normalized(pair.key)
                guard !key.isEmpty else { return }
                let normalizedOverride = normalized(pair.value)
                if !normalizedOverride.hexes.isEmpty || normalizedOverride.mode != .custom {
                    result[key] = normalizedOverride
                }
            }
        }

        guard let legacy = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return legacy.reduce(into: [:]) { result, pair in
            let key = normalized(pair.key)
            let value = normalizedHex(pair.value)
            if !key.isEmpty, let value {
                result[key] = CardTagColorOverride(mode: .custom, hexes: [value])
            }
        }
    }

    nonisolated static func rawValue(from overrides: [String: CardTagColorOverride], tags: [String]) -> String? {
        var normalizedOverrides: [String: CardTagColorOverride] = [:]
        let validKeys = Set(tags.map(normalized))

        for (tag, override) in overrides {
            let key = normalized(tag)
            guard validKeys.contains(key) else { continue }

            if presetStyle(for: tag) != nil {
                if override.mode == .solid {
                    normalizedOverrides[key] = CardTagColorOverride(mode: .solid, hexes: [])
                }
                continue
            }

            guard !isPresetColored(tag) else { continue }
            let hexes = normalizedHexes(override.hexes)
            if !hexes.isEmpty {
                normalizedOverrides[key] = CardTagColorOverride(mode: .custom, hexes: hexes)
            }
        }

        guard !normalizedOverrides.isEmpty,
              let data = try? JSONEncoder().encode(normalizedOverrides) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    nonisolated static func normalized(_ tag: String) -> String {
        CardTagIndex.normalizedKey(tag)
    }

    nonisolated static func isPresetColored(_ tag: String) -> Bool {
        presetStyle(for: tag) != nil || defaultHexMatch(for: tag) != nil
    }

    nonisolated static func hasPresetSplitStyle(for tag: String) -> Bool {
        presetStyle(for: tag) != nil
    }

    nonisolated static func presetMode(for tag: String, overrides: [String: CardTagColorOverride]) -> CardTagColorOverride.Mode {
        overrides[normalized(tag)]?.mode == .solid ? .solid : .preset
    }

    nonisolated static func presetSolidHex(for tag: String) -> String {
        presetStyle(for: tag)?.solidHex ?? defaultHex(for: tag)
    }

    nonisolated static func customHexes(for tag: String, overrides: [String: CardTagColorOverride]) -> [String] {
        let key = normalized(tag)
        if let override = overrides[key], override.mode == .custom {
            let hexes = normalizedHexes(override.hexes)
            if !hexes.isEmpty { return hexes }
        }
        return [fallbackHex]
    }

    private nonisolated static func presetStyle(for tag: String) -> (style: CardTagColorStyle, solidHex: String)? {
        if let remotePreset = RemoteTagCatalogSnapshot.colorPreset(for: tag) {
            let hexes = normalizedPresetHexes(remotePreset.colors)
            let solidHex = remotePreset.solidColor ?? hexes.first ?? fallbackHex
            return (CardTagColorStyle(segmentHexes: hexes), solidHex)
        }

        let key = normalized(tag)

        for entry in multiDefaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                let hexes = normalizedPresetHexes(entry.hexes)
                return (CardTagColorStyle(segmentHexes: hexes), hexes.first ?? fallbackHex)
            }
        }

        for entry in splitDefaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                let leadingHex = normalizedHex(entry.leadingHex) ?? fallbackHex
                let trailingHex = normalizedHex(entry.trailingHex) ?? fallbackHex
                return (CardTagColorStyle(segmentHexes: [leadingHex, trailingHex]), trailingHex)
            }
        }

        return nil
    }

    private nonisolated static func defaultHex(for tag: String) -> String {
        defaultHexMatch(for: tag) ?? fallbackHex
    }

    private nonisolated static func defaultHexMatch(for tag: String) -> String? {
        if let remoteHex = RemoteTagCatalogSnapshot.colors(for: tag)?.first {
            return normalizedHex(remoteHex)
        }

        let key = normalized(tag)
        for entry in defaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                return normalizedHex(entry.hex) ?? fallbackHex
            }
        }
        return nil
    }

    private nonisolated static func normalized(_ override: CardTagColorOverride) -> CardTagColorOverride {
        switch override.mode {
        case .preset, .solid:
            return CardTagColorOverride(mode: override.mode, hexes: [])
        case .custom:
            return CardTagColorOverride(mode: .custom, hexes: normalizedHexes(override.hexes))
        }
    }

    private nonisolated static func normalizedHexes(_ values: [String]) -> [String] {
        Array(values.compactMap(normalizedHex).prefix(3))
    }

    private nonisolated static func normalizedPresetHexes(_ values: [String]) -> [String] {
        values.compactMap(normalizedHex)
    }

    nonisolated static func normalizedHex(_ value: String) -> String? {
        var hex = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !hex.hasPrefix("#") {
            hex = "#" + hex
        }
        return isValidHex(hex) ? hex : nil
    }

    private nonisolated static func isValidHex(_ value: String) -> Bool {
        value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
    }
}

struct CardTagColorOverride: Codable, Equatable {
    enum Mode: String, Codable {
        case preset
        case solid
        case custom
    }

    var mode: Mode
    var hexes: [String]
}

struct CardTagColorStyle {
    let segmentHexes: [String]

    nonisolated init(leadingHex: String, trailingHex: String?) {
        if let trailingHex {
            segmentHexes = [leadingHex, trailingHex]
        } else {
            segmentHexes = [leadingHex]
        }
    }

    nonisolated init(segmentHexes: [String]) {
        self.segmentHexes = segmentHexes.isEmpty ? [CardTagColorPalette.fallbackHex] : segmentHexes
    }

    nonisolated var leadingHex: String {
        segmentHexes.first ?? CardTagColorPalette.fallbackHex
    }

    nonisolated var trailingHex: String? {
        segmentHexes.dropFirst().first
    }

    nonisolated var isSplit: Bool {
        Set(segmentHexes).count > 1
    }

    nonisolated var isMulticolor: Bool {
        segmentHexes.count > 1 && isSplit
    }
}
