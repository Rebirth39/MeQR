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

    var tagColorOverrides: [String: String] {
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
    private struct LocalizedTagName {
        let zhHans: String
        let zhHantHK: String
        let zhHantTW: String
        let en: String
        let ja: String

        var allValues: [String] {
            [zhHans, zhHantHK, zhHantTW, en, ja]
        }

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

    private struct Entry {
        let name: LocalizedTagName
        let aliases: [String]

        var searchableValues: [String] { name.allValues + aliases }

        func display(for language: AppLanguage) -> String {
            name.value(for: language)
        }
    }

    private nonisolated static let entries: [Entry] = [
        Entry(name: .init(zhHans: "世界计划", zhHantHK: "世界計畫", zhHantTW: "世界計畫", en: "Project Sekai", ja: "プロセカ"), aliases: ["pjsk", "projectsekai", "project sekai", "啤酒烧烤", "啤酒燒烤", "世嘉彩舞", "彩舞"]),
        Entry(name: .init(zhHans: "Leo/need", zhHantHK: "Leo/need", zhHantTW: "Leo/need", en: "Leo/need", ja: "Leo/need"), aliases: ["ln", "l/n", "leoneed", "レオニ"]),
        Entry(name: .init(zhHans: "MORE MORE JUMP!", zhHantHK: "MORE MORE JUMP!", zhHantTW: "MORE MORE JUMP!", en: "MORE MORE JUMP!", ja: "MORE MORE JUMP!"), aliases: ["mmj", "more more jump", "moremorejump", "モモジャン", "桃跳"]),
        Entry(name: .init(zhHans: "Vivid BAD SQUAD", zhHantHK: "Vivid BAD SQUAD", zhHantTW: "Vivid BAD SQUAD", en: "Vivid BAD SQUAD", ja: "Vivid BAD SQUAD"), aliases: ["vbs", "vivid bad squad", "vividbadsquad", "ビビバス"]),
        Entry(name: .init(zhHans: "Wonderlands x Showtime", zhHantHK: "Wonderlands x Showtime", zhHantTW: "Wonderlands x Showtime", en: "Wonderlands x Showtime", ja: "ワンダーランズ x ショウタイム"), aliases: ["ws", "wxs", "wxS", "wonderlands x showtime", "wonderlandsxshowtime", "ワンダショ", "ワショ"]),
        Entry(name: .init(zhHans: "25点，Nightcord见。", zhHantHK: "25點，Nightcord見。", zhHantTW: "25點，Nightcord見。", en: "Nightcord at 25:00", ja: "25時、ナイトコードで。"), aliases: ["25ji", "n25", "nightcord", "25時、ナイトコードで。", "25時", "25时", "25點", "25点", "ニーゴ"]),
        Entry(name: .init(zhHans: "星乃一歌", zhHantHK: "星乃一歌", zhHantTW: "星乃一歌", en: "Ichika Hoshino", ja: "星乃一歌"), aliases: ["一歌", "ichika", "hoshinoichika"]),
        Entry(name: .init(zhHans: "天马咲希", zhHantHK: "天馬咲希", zhHantTW: "天馬咲希", en: "Saki Tenma", ja: "天馬咲希"), aliases: ["咲希", "saki", "tenmasaki"]),
        Entry(name: .init(zhHans: "望月穗波", zhHantHK: "望月穂波", zhHantTW: "望月穂波", en: "Honami Mochizuki", ja: "望月穂波"), aliases: ["穗波", "穂波", "honami", "mochizukihonami"]),
        Entry(name: .init(zhHans: "日野森志步", zhHantHK: "日野森志歩", zhHantTW: "日野森志歩", en: "Shiho Hinomori", ja: "日野森志歩"), aliases: ["志步", "志歩", "shiho", "hinomorishiho"]),
        Entry(name: .init(zhHans: "花里实乃理", zhHantHK: "花里實乃理", zhHantTW: "花里實乃理", en: "Minori Hanasato", ja: "花里みのり"), aliases: ["实乃理", "実乃理", "みのり", "minori", "hanasatominori"]),
        Entry(name: .init(zhHans: "桐谷遥", zhHantHK: "桐谷遙", zhHantTW: "桐谷遙", en: "Haruka Kiritani", ja: "桐谷遥"), aliases: ["遥", "遙", "haruka", "kiritaniharuka"]),
        Entry(name: .init(zhHans: "桃井爱莉", zhHantHK: "桃井愛莉", zhHantTW: "桃井愛莉", en: "Airi Momoi", ja: "桃井愛莉"), aliases: ["爱莉", "愛莉", "airi", "momoiairi"]),
        Entry(name: .init(zhHans: "日野森雫", zhHantHK: "日野森雫", zhHantTW: "日野森雫", en: "Shizuku Hinomori", ja: "日野森雫"), aliases: ["雫", "shizuku", "hinomorishizuku"]),
        Entry(name: .init(zhHans: "小豆泽心羽", zhHantHK: "小豆澤心羽", zhHantTW: "小豆澤心羽", en: "Kohane Azusawa", ja: "小豆沢こはね"), aliases: ["心羽", "こはね", "kohane", "azusawakohane"]),
        Entry(name: .init(zhHans: "白石杏", zhHantHK: "白石杏", zhHantTW: "白石杏", en: "An Shiraishi", ja: "白石杏"), aliases: ["杏", "an", "shiraishian"]),
        Entry(name: .init(zhHans: "东云彰人", zhHantHK: "東雲彰人", zhHantTW: "東雲彰人", en: "Akito Shinonome", ja: "東雲彰人"), aliases: ["彰人", "akito", "shinonomeakito"]),
        Entry(name: .init(zhHans: "青柳冬弥", zhHantHK: "青柳冬彌", zhHantTW: "青柳冬彌", en: "Toya Aoyagi", ja: "青柳冬弥"), aliases: ["冬弥", "冬彌", "toya", "touya", "aoyagitoya"]),
        Entry(name: .init(zhHans: "天马司", zhHantHK: "天馬司", zhHantTW: "天馬司", en: "Tsukasa Tenma", ja: "天馬司"), aliases: ["司", "tsukasa", "tenmatsukasa"]),
        Entry(name: .init(zhHans: "凤笑梦", zhHantHK: "鳳笑夢", zhHantTW: "鳳笑夢", en: "Emu Otori", ja: "鳳えむ"), aliases: ["笑梦", "笑夢", "emu", "otoriemu"]),
        Entry(name: .init(zhHans: "草薙宁宁", zhHantHK: "草薙寧寧", zhHantTW: "草薙寧寧", en: "Nene Kusanagi", ja: "草薙寧々"), aliases: ["宁宁", "寧寧", "寧々", "nene", "kusanaginene"]),
        Entry(name: .init(zhHans: "神代类", zhHantHK: "神代類", zhHantTW: "神代類", en: "Rui Kamishiro", ja: "神代類"), aliases: ["类", "類", "rui", "kamishirorui"]),
        Entry(name: .init(zhHans: "宵崎奏", zhHantHK: "宵崎奏", zhHantTW: "宵崎奏", en: "Kanade Yoisaki", ja: "宵崎奏"), aliases: ["奏", "kanade", "yoisakikanade"]),
        Entry(name: .init(zhHans: "朝比奈真冬", zhHantHK: "朝比奈真冬", zhHantTW: "朝比奈真冬", en: "Mafuyu Asahina", ja: "朝比奈まふゆ"), aliases: ["真冬", "mafuyu", "asahinamafuyu"]),
        Entry(name: .init(zhHans: "东云绘名", zhHantHK: "東雲繪名", zhHantTW: "東雲繪名", en: "Ena Shinonome", ja: "東雲絵名"), aliases: ["绘名", "繪名", "絵名", "ena", "shinonomeena"]),
        Entry(name: .init(zhHans: "晓山瑞希", zhHantHK: "曉山瑞希", zhHantTW: "曉山瑞希", en: "Mizuki Akiyama", ja: "暁山瑞希"), aliases: ["瑞希", "mizuki", "akiyamamizuki"]),
        Entry(name: .init(zhHans: "VOCALOID", zhHantHK: "VOCALOID", zhHantTW: "VOCALOID", en: "VOCALOID", ja: "ボカロ"), aliases: ["术力口", "ボカロ", "vocalo", "vocaloid"]),
        Entry(name: .init(zhHans: "初音未来", zhHantHK: "初音未來", zhHantTW: "初音未來", en: "Hatsune Miku", ja: "初音ミク"), aliases: ["初音", "miku", "hatsunemiku"]),
        Entry(name: .init(zhHans: "BanG Dream!", zhHantHK: "BanG Dream!", zhHantTW: "BanG Dream!", en: "BanG Dream!", ja: "バンドリ"), aliases: ["bangdream", "bandori", "邦邦", "バンドリ"]),
        Entry(name: .init(zhHans: "Poppin'Party", zhHantHK: "Poppin'Party", zhHantTW: "Poppin'Party", en: "Poppin'Party", ja: "Poppin'Party"), aliases: ["popipa", "poppinparty", "ポピパ"]),
        Entry(name: .init(zhHans: "Afterglow", zhHantHK: "Afterglow", zhHantTW: "Afterglow", en: "Afterglow", ja: "Afterglow"), aliases: ["aglow", "美竹兰组", "美竹蘭組"]),
        Entry(name: .init(zhHans: "Pastel*Palettes", zhHantHK: "Pastel*Palettes", zhHantTW: "Pastel*Palettes", en: "Pastel*Palettes", ja: "Pastel*Palettes"), aliases: ["pp", "pasupare", "パスパレ", "彩组", "彩組"]),
        Entry(name: .init(zhHans: "Roselia", zhHantHK: "Roselia", zhHantTW: "Roselia", en: "Roselia", ja: "Roselia"), aliases: ["roselia组"]),
        Entry(name: .init(zhHans: "Hello Happy World!", zhHantHK: "Hello Happy World!", zhHantTW: "Hello Happy World!", en: "Hello Happy World!", ja: "ハロー、ハッピーワールド！"), aliases: ["hhw", "hellohappyworld", "hello happy world", "ハロハピ"]),
        Entry(name: .init(zhHans: "Morfonica", zhHantHK: "Morfonica", zhHantTW: "Morfonica", en: "Morfonica", ja: "Morfonica"), aliases: ["monica", "モニカ"]),
        Entry(name: .init(zhHans: "RAISE A SUILEN", zhHantHK: "RAISE A SUILEN", zhHantTW: "RAISE A SUILEN", en: "RAISE A SUILEN", ja: "RAISE A SUILEN"), aliases: ["ras", "raiseasuilen"]),
        Entry(name: .init(zhHans: "MyGO!!!!!", zhHantHK: "MyGO!!!!!", zhHantTW: "MyGO!!!!!", en: "MyGO!!!!!", ja: "MyGO!!!!!"), aliases: ["mygo", "迷子"]),
        Entry(name: .init(zhHans: "Ave Mujica", zhHantHK: "Ave Mujica", zhHantTW: "Ave Mujica", en: "Ave Mujica", ja: "Ave Mujica"), aliases: ["avemujica", "母鸡卡"]),
        Entry(name: .init(zhHans: "梦限大 Mewtype", zhHantHK: "夢限大 Mewtype", zhHantTW: "夢限大 Mewtype", en: "Mugendai Mewtype", ja: "夢限大みゅーたいぷ"), aliases: ["mugendai", "mugendaimewtype", "mugendai mewtype", "梦限大", "夢限大", "夢限大みゅーたいぷ"]),
        Entry(name: .init(zhHans: "户山香澄", zhHantHK: "戶山香澄", zhHantTW: "戶山香澄", en: "Kasumi Toyama", ja: "戸山香澄"), aliases: ["香澄", "kasumi", "toyamakasumi"]),
        Entry(name: .init(zhHans: "花园多惠", zhHantHK: "花園多惠", zhHantTW: "花園多惠", en: "Tae Hanazono", ja: "花園たえ"), aliases: ["多惠", "たえ", "tae", "hanazonotae"]),
        Entry(name: .init(zhHans: "牛込里美", zhHantHK: "牛込里美", zhHantTW: "牛込里美", en: "Rimi Ushigome", ja: "牛込りみ"), aliases: ["里美", "りみ", "rimi", "ushigomerimi"]),
        Entry(name: .init(zhHans: "山吹沙绫", zhHantHK: "山吹沙綾", zhHantTW: "山吹沙綾", en: "Saaya Yamabuki", ja: "山吹沙綾"), aliases: ["沙绫", "沙綾", "saaya", "yamabukisaaya"]),
        Entry(name: .init(zhHans: "市谷有咲", zhHantHK: "市谷有咲", zhHantTW: "市谷有咲", en: "Arisa Ichigaya", ja: "市ヶ谷有咲"), aliases: ["有咲", "arisa", "ichigayaarisa"]),
        Entry(name: .init(zhHans: "美竹兰", zhHantHK: "美竹蘭", zhHantTW: "美竹蘭", en: "Ran Mitake", ja: "美竹蘭"), aliases: ["蘭", "ran", "mitakeran"]),
        Entry(name: .init(zhHans: "青叶摩卡", zhHantHK: "青葉摩卡", zhHantTW: "青葉摩卡", en: "Moca Aoba", ja: "青葉モカ"), aliases: ["摩卡", "モカ", "moca", "aobamoca"]),
        Entry(name: .init(zhHans: "上原绯玛丽", zhHantHK: "上原緋瑪麗", zhHantTW: "上原緋瑪麗", en: "Himari Uehara", ja: "上原ひまり"), aliases: ["绯玛丽", "緋瑪麗", "ひまり", "himari", "ueharahimari"]),
        Entry(name: .init(zhHans: "宇田川巴", zhHantHK: "宇田川巴", zhHantTW: "宇田川巴", en: "Tomoe Udagawa", ja: "宇田川巴"), aliases: ["tomoe", "udagawatomoe"]),
        Entry(name: .init(zhHans: "羽泽鸫", zhHantHK: "羽澤鶇", zhHantTW: "羽澤鶇", en: "Tsugumi Hazawa", ja: "羽沢つぐみ"), aliases: ["鸫", "鶇", "つぐみ", "tsugumi", "hazawatsugumi"]),
        Entry(name: .init(zhHans: "丸山彩", zhHantHK: "丸山彩", zhHantTW: "丸山彩", en: "Aya Maruyama", ja: "丸山彩"), aliases: ["aya", "maruyamaaya"]),
        Entry(name: .init(zhHans: "冰川日菜", zhHantHK: "冰川日菜", zhHantTW: "冰川日菜", en: "Hina Hikawa", ja: "氷川日菜"), aliases: ["日菜", "hina", "hikawahina"]),
        Entry(name: .init(zhHans: "白鹭千圣", zhHantHK: "白鷺千聖", zhHantTW: "白鷺千聖", en: "Chisato Shirasagi", ja: "白鷺千聖"), aliases: ["千圣", "千聖", "chisato", "shirasagichisato"]),
        Entry(name: .init(zhHans: "大和麻弥", zhHantHK: "大和麻彌", zhHantTW: "大和麻彌", en: "Maya Yamato", ja: "大和麻弥"), aliases: ["麻弥", "麻彌", "maya", "yamatomaya"]),
        Entry(name: .init(zhHans: "若宫伊芙", zhHantHK: "若宮伊芙", zhHantTW: "若宮伊芙", en: "Eve Wakamiya", ja: "若宮イヴ"), aliases: ["伊芙", "イヴ", "eve", "wakamiyaeve"]),
        Entry(name: .init(zhHans: "凑友希那", zhHantHK: "湊友希那", zhHantTW: "湊友希那", en: "Yukina Minato", ja: "湊友希那"), aliases: ["友希那", "yukina", "minatoyukina"]),
        Entry(name: .init(zhHans: "冰川纱夜", zhHantHK: "冰川紗夜", zhHantTW: "冰川紗夜", en: "Sayo Hikawa", ja: "氷川紗夜"), aliases: ["纱夜", "紗夜", "sayo", "hikawasayo"]),
        Entry(name: .init(zhHans: "今井莉莎", zhHantHK: "今井莉莎", zhHantTW: "今井莉莎", en: "Lisa Imai", ja: "今井リサ"), aliases: ["莉莎", "リサ", "lisa", "imailisa"]),
        Entry(name: .init(zhHans: "宇田川亚子", zhHantHK: "宇田川亞子", zhHantTW: "宇田川亞子", en: "Ako Udagawa", ja: "宇田川あこ"), aliases: ["亚子", "亞子", "あこ", "ako", "udagawaako"]),
        Entry(name: .init(zhHans: "白金燐子", zhHantHK: "白金燐子", zhHantTW: "白金燐子", en: "Rinko Shirokane", ja: "白金燐子"), aliases: ["燐子", "rinko", "shirokanerinko"]),
        Entry(name: .init(zhHans: "弦卷心", zhHantHK: "弦卷心", zhHantTW: "弦卷心", en: "Kokoro Tsurumaki", ja: "弦巻こころ"), aliases: ["こころ", "kokoro", "tsurumakikokoro"]),
        Entry(name: .init(zhHans: "濑田薰", zhHantHK: "瀨田薰", zhHantTW: "瀨田薰", en: "Kaoru Seta", ja: "瀬田薫"), aliases: ["薰", "薫", "kaoru", "setakaoru"]),
        Entry(name: .init(zhHans: "北泽育美", zhHantHK: "北澤育美", zhHantTW: "北澤育美", en: "Hagumi Kitazawa", ja: "北沢はぐみ"), aliases: ["育美", "はぐみ", "hagumi", "kitazawahagumi"]),
        Entry(name: .init(zhHans: "松原花音", zhHantHK: "松原花音", zhHantTW: "松原花音", en: "Kanon Matsubara", ja: "松原花音"), aliases: ["花音", "kanon", "matsubarakanon"]),
        Entry(name: .init(zhHans: "奥泽美咲", zhHantHK: "奧澤美咲", zhHantTW: "奧澤美咲", en: "Misaki Okusawa", ja: "奥沢美咲"), aliases: ["美咲", "米歇尔", "ミッシェル", "Michelle", "misaki", "okusawamisaki"]),
        Entry(name: .init(zhHans: "仓田真白", zhHantHK: "倉田真白", zhHantTW: "倉田真白", en: "Mashiro Kurata", ja: "倉田ましろ"), aliases: ["真白", "ましろ", "mashiro", "kuratamashiro"]),
        Entry(name: .init(zhHans: "桐谷透子", zhHantHK: "桐谷透子", zhHantTW: "桐谷透子", en: "Toko Kirigaya", ja: "桐ヶ谷透子"), aliases: ["透子", "toko", "kirigayatoko"]),
        Entry(name: .init(zhHans: "广町七深", zhHantHK: "廣町七深", zhHantTW: "廣町七深", en: "Nanami Hiromachi", ja: "広町七深"), aliases: ["七深", "nanami", "hiromachinanami"]),
        Entry(name: .init(zhHans: "二叶筑紫", zhHantHK: "二葉筑紫", zhHantTW: "二葉筑紫", en: "Tsukushi Futaba", ja: "二葉つくし"), aliases: ["筑紫", "つくし", "tsukushi", "futabatsukushi"]),
        Entry(name: .init(zhHans: "八潮瑠唯", zhHantHK: "八潮瑠唯", zhHantTW: "八潮瑠唯", en: "Rui Yashio", ja: "八潮瑠唯"), aliases: ["瑠唯", "yashiorui"]),
        Entry(name: .init(zhHans: "和奏蕾依", zhHantHK: "和奏蕾依", zhHantTW: "和奏蕾依", en: "Rei Wakana", ja: "和奏レイ"), aliases: ["蕾依", "レイヤ", "layer", "reiwakana"]),
        Entry(name: .init(zhHans: "朝日六花", zhHantHK: "朝日六花", zhHantTW: "朝日六花", en: "Rokka Asahi", ja: "朝日六花"), aliases: ["六花", "ロック", "lock", "rokka", "asahirokka"]),
        Entry(name: .init(zhHans: "佐藤益木", zhHantHK: "佐藤益木", zhHantTW: "佐藤益木", en: "Masuki Sato", ja: "マスキング"), aliases: ["益木", "masking", "masuki", "satomasuki"]),
        Entry(name: .init(zhHans: "鳰原令王那", zhHantHK: "鳰原令王那", zhHantTW: "鳰原令王那", en: "Reona Nyubara", ja: "パレオ"), aliases: ["令王那", "pareo", "reona", "nyubarareona"]),
        Entry(name: .init(zhHans: "珠手知由", zhHantHK: "珠手知由", zhHantTW: "珠手知由", en: "Chiyu Tamade", ja: "チュチュ"), aliases: ["知由", "chu2", "chiyu", "tamadechiyu"]),
        Entry(name: .init(zhHans: "高松灯", zhHantHK: "高松燈", zhHantTW: "高松燈", en: "Tomori Takamatsu", ja: "高松燈"), aliases: ["灯", "燈", "tmr", "tomori", "takamatsutomori"]),
        Entry(name: .init(zhHans: "千早爱音", zhHantHK: "千早愛音", zhHantTW: "千早愛音", en: "Anon Chihaya", ja: "千早愛音"), aliases: ["爱音", "愛音", "anon", "chihayaanon"]),
        Entry(name: .init(zhHans: "要乐奈", zhHantHK: "要樂奈", zhHantTW: "要樂奈", en: "Raana Kaname", ja: "要楽奈"), aliases: ["乐奈", "樂奈", "楽奈", "raana", "kanameraana"]),
        Entry(name: .init(zhHans: "长崎素世", zhHantHK: "長崎素世", zhHantTW: "長崎素世", en: "Soyo Nagasaki", ja: "長崎そよ"), aliases: ["素世", "そよ", "soyo", "nagasakisoyo"]),
        Entry(name: .init(zhHans: "椎名立希", zhHantHK: "椎名立希", zhHantTW: "椎名立希", en: "Taki Shiina", ja: "椎名立希"), aliases: ["立希", "taki", "shiinataki"]),
        Entry(name: .init(zhHans: "三角初华", zhHantHK: "三角初華", zhHantTW: "三角初華", en: "Uika Misumi", ja: "三角初華"), aliases: ["初华", "初華", "doloris", "uika", "misumiuika"]),
        Entry(name: .init(zhHans: "丰川祥子", zhHantHK: "豐川祥子", zhHantTW: "豐川祥子", en: "Sakiko Togawa", ja: "豊川祥子"), aliases: ["祥子", "oblivionis", "sakiko", "togawasakiko"]),
        Entry(name: .init(zhHans: "若叶睦", zhHantHK: "若葉睦", zhHantTW: "若葉睦", en: "Mutsumi Wakaba", ja: "若葉睦"), aliases: ["mortis", "mutsumi", "wakabamutsumi"]),
        Entry(name: .init(zhHans: "八幡海铃", zhHantHK: "八幡海鈴", zhHantTW: "八幡海鈴", en: "Umiri Yahata", ja: "八幡海鈴"), aliases: ["海铃", "海鈴", "timoris", "umiri", "yahataumiri"]),
        Entry(name: .init(zhHans: "祐天寺若麦", zhHantHK: "祐天寺若麥", zhHantTW: "祐天寺若麥", en: "Nyamu Yutenji", ja: "祐天寺若麦"), aliases: ["若麦", "若麥", "amoris", "nyamu", "yutenjinyamu"]),
        Entry(name: .init(zhHans: "仲町阿拉蕾", zhHantHK: "仲町阿拉蕾", zhHantTW: "仲町阿拉蕾", en: "Arale Nakamachi", ja: "仲町あられ"), aliases: ["阿拉蕾", "あられ", "arale", "nakamachiarale"]),
        Entry(name: .init(zhHans: "宫永野乃花", zhHantHK: "宮永野乃花", zhHantTW: "宮永野乃花", en: "Nonoka Miyanaga", ja: "宮永ののか"), aliases: ["野乃花", "ののか", "nonoka", "miyanaganonoka"]),
        Entry(name: .init(zhHans: "峰月律", zhHantHK: "峰月律", zhHantTW: "峰月律", en: "Ritsu Minetsuki", ja: "峰月律"), aliases: ["ritsu", "minetsukiritsu"]),
        Entry(name: .init(zhHans: "藤都子", zhHantHK: "藤都子", zhHantTW: "藤都子", en: "Miyako Fuji", ja: "藤都子"), aliases: ["都子", "miyako", "fujimiyako"]),
        Entry(name: .init(zhHans: "千石由乃", zhHantHK: "千石由乃", zhHantTW: "千石由乃", en: "Yuno Sengoku", ja: "千石ユノ"), aliases: ["由乃", "ユノ", "yuno", "sengokuyuno"]),
        Entry(name: .init(zhHans: "明日方舟", zhHantHK: "明日方舟", zhHantTW: "明日方舟", en: "Arknights", ja: "アークナイツ"), aliases: ["arknights", "方舟", "罗德岛", "羅德島", "rhodesisland"]),
        Entry(name: .init(zhHans: "阿米娅", zhHantHK: "阿米婭", zhHantTW: "阿米婭", en: "Amiya", ja: "アーミヤ"), aliases: ["amiya"]),
        Entry(name: .init(zhHans: "凯尔希", zhHantHK: "凱爾希", zhHantTW: "凱爾希", en: "Kal'tsit", ja: "ケルシー"), aliases: ["kaltsit", "kelsey"]),
        Entry(name: .init(zhHans: "陈", zhHantHK: "陳", zhHantTW: "陳", en: "Ch'en", ja: "チェン"), aliases: ["chen"]),
        Entry(name: .init(zhHans: "德克萨斯", zhHantHK: "德克薩斯", zhHantTW: "德克薩斯", en: "Texas", ja: "テキサス"), aliases: ["texas"]),
        Entry(name: .init(zhHans: "拉普兰德", zhHantHK: "拉普蘭德", zhHantTW: "拉普蘭德", en: "Lappland", ja: "ラップランド"), aliases: ["lappland"]),
        Entry(name: .init(zhHans: "能天使", zhHantHK: "能天使", zhHantTW: "能天使", en: "Exusiai", ja: "エクシア"), aliases: ["exusiai"]),
        Entry(name: .init(zhHans: "蔚蓝档案", zhHantHK: "蔚藍檔案", zhHantTW: "蔚藍檔案", en: "Blue Archive", ja: "ブルアカ"), aliases: ["bluearchive", "ba", "碧蓝档案", "碧藍檔案"]),
        Entry(name: .init(zhHans: "砂狼白子", zhHantHK: "砂狼白子", zhHantTW: "砂狼白子", en: "Shiroko Sunaookami", ja: "砂狼シロコ"), aliases: ["白子", "シロコ", "shiroko"]),
        Entry(name: .init(zhHans: "小鸟游星野", zhHantHK: "小鳥遊星野", zhHantTW: "小鳥遊星野", en: "Hoshino Takanashi", ja: "小鳥遊ホシノ"), aliases: ["星野", "ホシノ", "hoshino"]),
        Entry(name: .init(zhHans: "空崎日奈", zhHantHK: "空崎日奈", zhHantTW: "空崎日奈", en: "Hina Sorasaki", ja: "空崎ヒナ"), aliases: ["日奈", "ヒナ", "hina"]),
        Entry(name: .init(zhHans: "早濑优香", zhHantHK: "早瀨優香", zhHantTW: "早瀨優香", en: "Yuuka Hayase", ja: "早瀬ユウカ"), aliases: ["优香", "優香", "ユウカ", "yuuka"]),
        Entry(name: .init(zhHans: "崩坏星穹铁道", zhHantHK: "崩壞星穹鐵道", zhHantTW: "崩壞星穹鐵道", en: "Honkai: Star Rail", ja: "崩壊スターレイル"), aliases: ["hsr", "honkaistarrail", "星铁", "星鐵"]),
        Entry(name: .init(zhHans: "卡芙卡", zhHantHK: "卡芙卡", zhHantTW: "卡芙卡", en: "Kafka", ja: "カフカ"), aliases: ["kafka"]),
        Entry(name: .init(zhHans: "流萤", zhHantHK: "流螢", zhHantTW: "流螢", en: "Firefly", ja: "ホタル"), aliases: ["firefly"]),
        Entry(name: .init(zhHans: "知更鸟", zhHantHK: "知更鳥", zhHantTW: "知更鳥", en: "Robin", ja: "ロビン"), aliases: ["robin"]),
        Entry(name: .init(zhHans: "原神", zhHantHK: "原神", zhHantTW: "原神", en: "Genshin Impact", ja: "原神"), aliases: ["genshin", "genshinimpact"]),
        Entry(name: .init(zhHans: "纳西妲", zhHantHK: "納西妲", zhHantTW: "納西妲", en: "Nahida", ja: "ナヒーダ"), aliases: ["nahida"]),
        Entry(name: .init(zhHans: "芙宁娜", zhHantHK: "芙寧娜", zhHantTW: "芙寧娜", en: "Furina", ja: "フリーナ"), aliases: ["furina"]),
        Entry(name: .init(zhHans: "LoveLive!", zhHantHK: "LoveLive!", zhHantTW: "LoveLive!", en: "LoveLive!", ja: "ラブライブ"), aliases: ["lovelive", "ll", "ラブライブ"]),
        Entry(name: .init(zhHans: "偶像梦幻祭", zhHantHK: "偶像夢幻祭", zhHantTW: "偶像夢幻祭", en: "Ensemble Stars", ja: "あんスタ"), aliases: ["ensemblestars", "enstars", "es", "あんスタ"]),
        Entry(name: .init(zhHans: "偶像大师", zhHantHK: "偶像大師", zhHantTW: "偶像大師", en: "The Idolmaster", ja: "アイマス"), aliases: ["idolmaster", "theidolmaster", "imas", "アイマス"]),
        Entry(name: .init(zhHans: "赛马娘", zhHantHK: "賽馬娘", zhHantTW: "賽馬娘", en: "Uma Musume", ja: "ウマ娘"), aliases: ["umamusume", "马娘", "馬娘", "ウマ娘"]),
        Entry(name: .init(zhHans: "孤独摇滚", zhHantHK: "孤獨搖滾", zhHantTW: "孤獨搖滾", en: "Bocchi the Rock!", ja: "ぼっち・ざ・ろっく！"), aliases: ["bocchitherock", "孤摇", "孤搖", "ぼっちざろっく"]),
        Entry(name: .init(zhHans: "后藤一里", zhHantHK: "後藤一里", zhHantTW: "後藤一里", en: "Hitori Gotoh", ja: "後藤ひとり"), aliases: ["波奇", "ぼっち", "hitorigotoh"]),
        Entry(name: .init(zhHans: "东方Project", zhHantHK: "東方Project", zhHantTW: "東方Project", en: "Touhou Project", ja: "東方Project"), aliases: ["touhou", "touhouproject", "东方", "東方"]),
        Entry(name: .init(zhHans: "博丽灵梦", zhHantHK: "博麗靈夢", zhHantTW: "博麗靈夢", en: "Reimu Hakurei", ja: "博麗霊夢"), aliases: ["灵梦", "靈夢", "霊夢", "reimu"]),
        Entry(name: .init(zhHans: "雾雨魔理沙", zhHantHK: "霧雨魔理沙", zhHantTW: "霧雨魔理沙", en: "Marisa Kirisame", ja: "霧雨魔理沙"), aliases: ["魔理沙", "marisa"]),
        Entry(name: .init(zhHans: "新世纪福音战士", zhHantHK: "新世紀福音戰士", zhHantTW: "新世紀福音戰士", en: "Evangelion", ja: "エヴァンゲリオン"), aliases: ["eva", "nge", "新世纪福音战士", "新世紀エヴァンゲリオン", "エヴァ"]),
        Entry(name: .init(zhHans: "碇真嗣", zhHantHK: "碇真嗣", zhHantTW: "碇真嗣", en: "Shinji Ikari", ja: "碇シンジ"), aliases: ["真嗣", "シンジ", "shinji", "ikari"]),
        Entry(name: .init(zhHans: "绫波丽", zhHantHK: "綾波麗", zhHantTW: "綾波麗", en: "Rei Ayanami", ja: "綾波レイ"), aliases: ["绫波", "綾波", "丽", "麗", "rei", "ayanami"]),
        Entry(name: .init(zhHans: "明日香", zhHantHK: "明日香", zhHantTW: "明日香", en: "Asuka Langley", ja: "アスカ"), aliases: ["惣流明日香", "式波明日香", "アスカ", "asuka"]),
        Entry(name: .init(zhHans: "渚薰", zhHantHK: "渚薰", zhHantTW: "渚薰", en: "Kaworu Nagisa", ja: "渚カヲル"), aliases: ["薰", "カヲル", "kaworu", "nagisa"]),
        Entry(name: .init(zhHans: "葛城美里", zhHantHK: "葛城美里", zhHantTW: "葛城美里", en: "Misato Katsuragi", ja: "葛城ミサト"), aliases: ["美里", "ミサト", "misato"]),
        Entry(name: .init(zhHans: "葬送的芙莉莲", zhHantHK: "葬送的芙莉蓮", zhHantTW: "葬送的芙莉蓮", en: "Frieren", ja: "葬送のフリーレン"), aliases: ["frieren", "芙莉莲", "芙莉蓮", "フリーレン"]),
        Entry(name: .init(zhHans: "芙莉莲", zhHantHK: "芙莉蓮", zhHantTW: "芙莉蓮", en: "Frieren", ja: "フリーレン"), aliases: ["frieren", "フリーレン"]),
        Entry(name: .init(zhHans: "菲伦", zhHantHK: "菲倫", zhHantTW: "菲倫", en: "Fern", ja: "フェルン"), aliases: ["fern", "フェルン"]),
        Entry(name: .init(zhHans: "修塔尔克", zhHantHK: "修塔爾克", zhHantTW: "修塔爾克", en: "Stark", ja: "シュタルク"), aliases: ["stark", "シュタルク"]),
        Entry(name: .init(zhHans: "辛美尔", zhHantHK: "辛美爾", zhHantTW: "辛美爾", en: "Himmel", ja: "ヒンメル"), aliases: ["欣梅尔", "欣梅爾", "himmel", "ヒンメル"]),
        Entry(name: .init(zhHans: "阿乌拉", zhHantHK: "阿烏拉", zhHantTW: "阿烏拉", en: "Aura", ja: "アウラ"), aliases: ["aura", "アウラ"]),
        Entry(name: .init(zhHans: "咒术回战", zhHantHK: "咒術迴戰", zhHantTW: "咒術迴戰", en: "Jujutsu Kaisen", ja: "呪術廻戦"), aliases: ["jjk", "jujutsukaisen", "咒回", "呪術"]),
        Entry(name: .init(zhHans: "虎杖悠仁", zhHantHK: "虎杖悠仁", zhHantTW: "虎杖悠仁", en: "Yuji Itadori", ja: "虎杖悠仁"), aliases: ["虎杖", "itadori", "yuji"]),
        Entry(name: .init(zhHans: "伏黑惠", zhHantHK: "伏黑惠", zhHantTW: "伏黑惠", en: "Megumi Fushiguro", ja: "伏黒恵"), aliases: ["伏黑", "伏黒", "megumi", "fushiguro"]),
        Entry(name: .init(zhHans: "钉崎野蔷薇", zhHantHK: "釘崎野薔薇", zhHantTW: "釘崎野薔薇", en: "Nobara Kugisaki", ja: "釘崎野薔薇"), aliases: ["野蔷薇", "野薔薇", "nobara", "kugisaki"]),
        Entry(name: .init(zhHans: "五条悟", zhHantHK: "五條悟", zhHantTW: "五條悟", en: "Satoru Gojo", ja: "五条悟"), aliases: ["五条", "五條", "gojo", "satoru"]),
        Entry(name: .init(zhHans: "夏油杰", zhHantHK: "夏油傑", zhHantTW: "夏油傑", en: "Suguru Geto", ja: "夏油傑"), aliases: ["夏油", "geto", "suguru"]),
        Entry(name: .init(zhHans: "鬼灭之刃", zhHantHK: "鬼滅之刃", zhHantTW: "鬼滅之刃", en: "Demon Slayer", ja: "鬼滅の刃"), aliases: ["kimetsu", "demonslayer", "鬼灭", "鬼滅"]),
        Entry(name: .init(zhHans: "灶门炭治郎", zhHantHK: "竈門炭治郎", zhHantTW: "竈門炭治郎", en: "Tanjiro Kamado", ja: "竈門炭治郎"), aliases: ["炭治郎", "tanjiro", "kamado"]),
        Entry(name: .init(zhHans: "灶门祢豆子", zhHantHK: "竈門禰豆子", zhHantTW: "竈門禰豆子", en: "Nezuko Kamado", ja: "竈門禰豆子"), aliases: ["祢豆子", "禰豆子", "nezuko"]),
        Entry(name: .init(zhHans: "我妻善逸", zhHantHK: "我妻善逸", zhHantTW: "我妻善逸", en: "Zenitsu Agatsuma", ja: "我妻善逸"), aliases: ["善逸", "zenitsu"]),
        Entry(name: .init(zhHans: "嘴平伊之助", zhHantHK: "嘴平伊之助", zhHantTW: "嘴平伊之助", en: "Inosuke Hashibira", ja: "嘴平伊之助"), aliases: ["伊之助", "inosuke"]),
        Entry(name: .init(zhHans: "富冈义勇", zhHantHK: "富岡義勇", zhHantTW: "富岡義勇", en: "Giyu Tomioka", ja: "冨岡義勇"), aliases: ["义勇", "義勇", "giyu", "tomioka"]),
        Entry(name: .init(zhHans: "排球少年", zhHantHK: "排球少年", zhHantTW: "排球少年", en: "Haikyu!!", ja: "ハイキュー!!"), aliases: ["haikyuu", "haikyu", "ハイキュー"]),
        Entry(name: .init(zhHans: "日向翔阳", zhHantHK: "日向翔陽", zhHantTW: "日向翔陽", en: "Shoyo Hinata", ja: "日向翔陽"), aliases: ["翔阳", "翔陽", "hinata", "shoyo"]),
        Entry(name: .init(zhHans: "影山飞雄", zhHantHK: "影山飛雄", zhHantTW: "影山飛雄", en: "Tobio Kageyama", ja: "影山飛雄"), aliases: ["影山", "kageyama", "tobio"]),
        Entry(name: .init(zhHans: "月岛萤", zhHantHK: "月島螢", zhHantTW: "月島螢", en: "Kei Tsukishima", ja: "月島蛍"), aliases: ["月岛", "月島", "tsukishima", "kei"]),
        Entry(name: .init(zhHans: "孤爪研磨", zhHantHK: "孤爪研磨", zhHantTW: "孤爪研磨", en: "Kenma Kozume", ja: "孤爪研磨"), aliases: ["研磨", "kenma", "kozume"]),
        Entry(name: .init(zhHans: "黑尾铁朗", zhHantHK: "黒尾鐵朗", zhHantTW: "黒尾鐵朗", en: "Tetsuro Kuroo", ja: "黒尾鉄朗"), aliases: ["黑尾", "黒尾", "kuroo"]),
        Entry(name: .init(zhHans: "名侦探柯南", zhHantHK: "名偵探柯南", zhHantTW: "名偵探柯南", en: "Detective Conan", ja: "名探偵コナン"), aliases: ["conan", "detectiveconan", "柯南", "コナン"]),
        Entry(name: .init(zhHans: "江户川柯南", zhHantHK: "江戶川柯南", zhHantTW: "江戶川柯南", en: "Conan Edogawa", ja: "江戸川コナン"), aliases: ["柯南", "conan", "edogawa"]),
        Entry(name: .init(zhHans: "工藤新一", zhHantHK: "工藤新一", zhHantTW: "工藤新一", en: "Shinichi Kudo", ja: "工藤新一"), aliases: ["新一", "shinichi", "kudo"]),
        Entry(name: .init(zhHans: "毛利兰", zhHantHK: "毛利蘭", zhHantTW: "毛利蘭", en: "Ran Mouri", ja: "毛利蘭"), aliases: ["小兰", "小蘭", "ranmouri"]),
        Entry(name: .init(zhHans: "灰原哀", zhHantHK: "灰原哀", zhHantTW: "灰原哀", en: "Ai Haibara", ja: "灰原哀"), aliases: ["小哀", "haibara", "aihaibara"]),
        Entry(name: .init(zhHans: "安室透", zhHantHK: "安室透", zhHantTW: "安室透", en: "Rei Furuya", ja: "安室透"), aliases: ["降谷零", "安室", "amuro", "furuya"]),
        Entry(name: .init(zhHans: "进击的巨人", zhHantHK: "進擊的巨人", zhHantTW: "進擊的巨人", en: "Attack on Titan", ja: "進撃の巨人"), aliases: ["aot", "snk", "attackontitan", "进巨", "進巨"]),
        Entry(name: .init(zhHans: "艾伦耶格尔", zhHantHK: "艾連葉卡", zhHantTW: "艾連葉卡", en: "Eren Yeager", ja: "エレン・イェーガー"), aliases: ["艾伦", "艾連", "eren", "yeager"]),
        Entry(name: .init(zhHans: "三笠阿克曼", zhHantHK: "米卡莎阿卡曼", zhHantTW: "米卡莎阿卡曼", en: "Mikasa Ackerman", ja: "ミカサ・アッカーマン"), aliases: ["三笠", "米卡莎", "mikasa"]),
        Entry(name: .init(zhHans: "阿尔敏阿诺德", zhHantHK: "阿爾敏亞魯雷特", zhHantTW: "阿爾敏亞魯雷特", en: "Armin Arlert", ja: "アルミン・アルレルト"), aliases: ["阿尔敏", "阿爾敏", "armin"]),
        Entry(name: .init(zhHans: "利威尔", zhHantHK: "里維", zhHantTW: "里維", en: "Levi Ackerman", ja: "リヴァイ"), aliases: ["兵长", "兵長", "levi", "リヴァイ"]),
        Entry(name: .init(zhHans: "电锯人", zhHantHK: "鏈鋸人", zhHantTW: "鏈鋸人", en: "Chainsaw Man", ja: "チェンソーマン"), aliases: ["chainsawman", "csm", "链锯人", "鏈鋸人"]),
        Entry(name: .init(zhHans: "电次", zhHantHK: "淀治", zhHantTW: "淀治", en: "Denji", ja: "デンジ"), aliases: ["denji"]),
        Entry(name: .init(zhHans: "玛奇玛", zhHantHK: "瑪奇瑪", zhHantTW: "瑪奇瑪", en: "Makima", ja: "マキマ"), aliases: ["makima"]),
        Entry(name: .init(zhHans: "早川秋", zhHantHK: "早川秋", zhHantTW: "早川秋", en: "Aki Hayakawa", ja: "早川アキ"), aliases: ["aki", "hayakawaaki"]),
        Entry(name: .init(zhHans: "帕瓦", zhHantHK: "帕瓦", zhHantTW: "帕瓦", en: "Power", ja: "パワー"), aliases: ["power", "パワー"]),
        Entry(name: .init(zhHans: "蕾塞", zhHantHK: "蕾塞", zhHantTW: "蕾塞", en: "Reze", ja: "レゼ"), aliases: ["reze", "レゼ"]),
        Entry(name: .init(zhHans: "我推的孩子", zhHantHK: "【我推的孩子】", zhHantTW: "【我推的孩子】", en: "Oshi no Ko", ja: "【推しの子】"), aliases: ["oshinoko", "推しの子", "我推"]),
        Entry(name: .init(zhHans: "星野爱", zhHantHK: "星野愛", zhHantTW: "星野愛", en: "Ai Hoshino", ja: "星野アイ"), aliases: ["星野愛", "aihoshino"]),
        Entry(name: .init(zhHans: "星野爱久爱海", zhHantHK: "星野愛久愛海", zhHantTW: "星野愛久愛海", en: "Aqua Hoshino", ja: "星野愛久愛海"), aliases: ["阿库亚", "阿庫亞", "aqua", "hoshinoaqua"]),
        Entry(name: .init(zhHans: "星野瑠美衣", zhHantHK: "星野瑠美衣", zhHantTW: "星野瑠美衣", en: "Ruby Hoshino", ja: "星野瑠美衣"), aliases: ["露比", "ruby", "hoshinoruby"]),
        Entry(name: .init(zhHans: "有马加奈", zhHantHK: "有馬加奈", zhHantTW: "有馬加奈", en: "Kana Arima", ja: "有馬かな"), aliases: ["加奈", "kana", "arimakana"]),
        Entry(name: .init(zhHans: "黑川茜", zhHantHK: "黑川茜", zhHantTW: "黑川茜", en: "Akane Kurokawa", ja: "黒川あかね"), aliases: ["茜", "akane", "kurokawaakane"]),
        Entry(name: .init(zhHans: "间谍过家家", zhHantHK: "SPY x FAMILY 間諜家家酒", zhHantTW: "SPY x FAMILY 間諜家家酒", en: "SPY x FAMILY", ja: "SPY×FAMILY"), aliases: ["spyxfamily", "spy family", "间谍家家酒", "間諜家家酒"]),
        Entry(name: .init(zhHans: "阿尼亚福杰", zhHantHK: "安妮亞佛傑", zhHantTW: "安妮亞佛傑", en: "Anya Forger", ja: "アーニャ・フォージャー"), aliases: ["阿尼亚", "安妮亞", "anya"]),
        Entry(name: .init(zhHans: "劳埃德福杰", zhHantHK: "洛伊德佛傑", zhHantTW: "洛伊德佛傑", en: "Loid Forger", ja: "ロイド・フォージャー"), aliases: ["劳埃德", "洛伊德", "loid", "twilight"]),
        Entry(name: .init(zhHans: "约尔福杰", zhHantHK: "約兒佛傑", zhHantTW: "約兒佛傑", en: "Yor Forger", ja: "ヨル・フォージャー"), aliases: ["约尔", "約兒", "yor"]),
        Entry(name: .init(zhHans: "宝可梦", zhHantHK: "寶可夢", zhHantTW: "寶可夢", en: "Pokemon", ja: "ポケモン"), aliases: ["pokemon", "pokémon", "ポケモン", "精灵宝可梦", "神奇寶貝"]),
        Entry(name: .init(zhHans: "皮卡丘", zhHantHK: "皮卡丘", zhHantTW: "皮卡丘", en: "Pikachu", ja: "ピカチュウ"), aliases: ["pikachu", "ピカチュウ"]),
        Entry(name: .init(zhHans: "小智", zhHantHK: "小智", zhHantTW: "小智", en: "Ash Ketchum", ja: "サトシ"), aliases: ["ash", "satoshi", "サトシ"]),
        Entry(name: .init(zhHans: "喷火龙", zhHantHK: "噴火龍", zhHantTW: "噴火龍", en: "Charizard", ja: "リザードン"), aliases: ["charizard", "リザードン"]),
        Entry(name: .init(zhHans: "伊布", zhHantHK: "伊布", zhHantTW: "伊布", en: "Eevee", ja: "イーブイ"), aliases: ["eevee", "イーブイ"]),
        Entry(name: .init(zhHans: "梦幻", zhHantHK: "夢幻", zhHantTW: "夢幻", en: "Mew", ja: "ミュウ"), aliases: ["mew", "ミュウ"]),
   ]

    static func canonicalTag(for tag: String) -> String? {
        let key = normalizedKey(tag)
        guard !key.isEmpty else { return nil }
        let language = AppSettings.shared.resolvedLanguage
        return entries.first { entry in
            entry.searchableValues.contains(where: { key == normalizedKey($0) })
        }?.display(for: language)
    }

    static func suggestions(for query: String, excluding existingTags: [String] = []) -> [String] {
        let key = normalizedKey(query)
        guard !key.isEmpty else { return [] }

        let language = AppSettings.shared.resolvedLanguage
        let existingKeys = Set(existingTags.map(normalizedKey))
        var result: [String] = []
        var seen: Set<String> = []

        for entry in entries {
            let display = entry.display(for: language)
            let displayKey = normalizedKey(display)
            guard !existingKeys.contains(displayKey), !seen.contains(displayKey) else { continue }

            if entry.searchableValues.contains(where: { normalizedKey($0).hasPrefix(key) || normalizedKey($0).contains(key) }) {
                result.append(display)
                seen.insert(displayKey)
            }

            if result.count >= 8 {
                break
            }
        }

        return result
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
        ("#F4B6C2", ["bocchitherock", "ぼっちざろっく", "孤独摇滚", "孤獨搖滾", "孤摇", "孤搖", "后藤一里", "後藤ひとり", "波奇", "ぼっち", "伊地知虹夏", "虹夏", "山田凉", "山田リョウ", "山田涼", "喜多郁代", "喜多ちゃん", "喜多"]),
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
    ]

    nonisolated static func colorHex(for tag: String, overrides: [String: String] = [:]) -> String {
        let key = normalized(tag)
        if let override = overrides[key], isValidHex(override) {
            return override
        }

        for entry in multiDefaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                return entry.hexes.first ?? fallbackHex
            }
        }

        for entry in defaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                return entry.hex
            }
        }

        return fallbackHex
    }

    nonisolated static func colorStyle(for tag: String, overrides: [String: String] = [:]) -> CardTagColorStyle {
        let key = normalized(tag)
        if let override = overrides[key], isValidHex(override) {
            return CardTagColorStyle(leadingHex: override, trailingHex: nil)
        }

        for entry in multiDefaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                return CardTagColorStyle(segmentHexes: entry.hexes)
            }
        }

        for entry in splitDefaults {
            if entry.keywords.contains(where: { key == normalized($0) }) {
                return CardTagColorStyle(leadingHex: entry.leadingHex, trailingHex: entry.trailingHex)
            }
        }

        return CardTagColorStyle(leadingHex: colorHex(for: tag), trailingHex: nil)
    }

    nonisolated static func overrides(from rawValue: String?) -> [String: String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [:]) { result, pair in
            let key = normalized(pair.key)
            let value = normalizedHex(pair.value)
            if !key.isEmpty, let value {
                result[key] = value
            }
        }
    }

    nonisolated static func rawValue(from overrides: [String: String], tags: [String]) -> String? {
        var normalizedOverrides: [String: String] = [:]
        let validKeys = Set(tags.map(normalized))

        for (tag, hex) in overrides {
            let key = normalized(tag)
            guard validKeys.contains(key), let normalizedHex = normalizedHex(hex) else { continue }
            guard normalizedHex != colorHex(for: tag) else { continue }
            normalizedOverrides[key] = normalizedHex
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

    private nonisolated static func normalizedHex(_ value: String) -> String? {
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

    var leadingHex: String {
        segmentHexes.first ?? CardTagColorPalette.fallbackHex
    }

    var trailingHex: String? {
        segmentHexes.dropFirst().first
    }

    var isSplit: Bool {
        Set(segmentHexes).count > 1
    }

    var isMulticolor: Bool {
        segmentHexes.count > 1 && isSplit
    }
}
