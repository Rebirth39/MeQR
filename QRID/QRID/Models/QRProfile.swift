import Foundation
import SwiftData
import SwiftUI

@Model
final class QRProfile {
    var id: UUID
    var platformType: String
    var qrContent: String
    var foregroundColorHex: String
    var createdAt: Date

    // Old stored properties — kept temporarily for migration
    // These will be removed after all profiles have been migrated to clusters
    var name: String
    var subtitle: String
    var avatarImageData: Data?
    var backgroundColorHex: String
    var borderColorHex: String
    var cornerRadius: Double

    var cluster: QRCluster?

    init(
        platformType: String = "custom",
        qrContent: String,
        foregroundColorHex: String = "#000000",
        customPlatformName: String? = nil,
        cluster: QRCluster? = nil
    ) {
        self.id = UUID()
        self.platformType = platformType
        self.qrContent = qrContent
        self.foregroundColorHex = foregroundColorHex
        self.customPlatformName = customPlatformName
        self.createdAt = Date()
        self.cluster = cluster

        // Default values for legacy fields (unused after migration)
        self.name = ""
        self.subtitle = ""
        self.avatarImageData = nil
        self.backgroundColorHex = "#FFFFFF"
        self.borderColorHex = "#000000"
        self.cornerRadius = 16
    }

    func captureClusterFallback(from cluster: QRCluster) {
        name = cluster.name
        subtitle = cluster.subtitle
        avatarImageData = cluster.avatarImageData
        backgroundColorHex = cluster.backgroundColorHex
        borderColorHex = cluster.borderColorHex
        cornerRadius = cluster.cornerRadius
    }

    func attach(to cluster: QRCluster) {
        self.cluster = cluster
        captureClusterFallback(from: cluster)
    }

    // Computed pass-throughs — delegate to cluster when available, fall back to stored values for migration

    var displayName: String {
        cluster?.name ?? name
    }

    var displaySubtitle: String {
        cluster?.subtitle ?? subtitle
    }

    var displayAvatarImageData: Data? {
        cluster?.avatarImageData ?? avatarImageData
    }

    var displayBackgroundColorHex: String {
        cluster?.backgroundColorHex ?? backgroundColorHex
    }

    var displayBorderColorHex: String {
        cluster?.borderColorHex ?? borderColorHex
    }

    var displayCornerRadius: Double {
        cluster?.cornerRadius ?? cornerRadius
    }

    // Color computed properties

    var foregroundColor: Color {
        Color(hex: foregroundColorHex)
    }

    var backgroundColor: Color {
        cluster?.backgroundColor ?? Color(hex: backgroundColorHex)
    }

    var borderColor: Color {
        cluster?.borderColor ?? Color(hex: borderColorHex)
    }

    var customPlatformName: String?

    var platform: Platform {
        Platform(rawValue: platformType) ?? .custom
    }

    var platformDisplayName: String {
        if platform == .custom, let name = customPlatformName, !name.isEmpty {
            return name
        }
        return platform.displayName
    }
}

enum Platform: String, CaseIterable, Identifiable {
    case wechat, qq, whatsapp, instagram, twitter, tiktok
    case snapchat, telegram, discord, reddit, threads, mastodon, bluesky
    case linkedin, github, facebook, youtube, twitch, pinterest
    case line, signal, testflight, paypal, venmo, cashapp, linktree
    case email, phone, custom
    case xiaohongshu, bilibili, douyin, weibo

    var id: String { rawValue }

    static var commonPlatforms: [Platform] {
        [.wechat, .qq, .xiaohongshu, .bilibili, .instagram, .line, .github]
    }

    static var socialPlatforms: [Platform] {
        [localizedShortVideoPlatform, .weibo, .whatsapp, .twitter, .snapchat, .facebook, .reddit, .threads, .twitch]
    }

    static var professionalPlatforms: [Platform] {
        [.linkedin, .testflight]
    }

    static var selectablePlatforms: [Platform] {
        commonPlatforms + socialPlatforms + professionalPlatforms + [.custom]
    }

    static var localizedShortVideoPlatform: Platform {
        switch AppSettings.shared.resolvedLanguage {
        case .zhHans, .zhHantHK:
            return .douyin
        case .system, .zhHantTW, .en, .ja:
            return .tiktok
        }
    }

    var displayName: String {
        switch self {
        case .wechat: return L.wechat
        case .qq: return "QQ"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .twitter: return L.twitter
        case .tiktok: return L.douyinTikTok
        case .snapchat: return "Snapchat"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .reddit: return "Reddit"
        case .threads: return "Threads"
        case .mastodon: return "Mastodon"
        case .bluesky: return "Bluesky"
        case .linkedin: return "LinkedIn"
        case .github: return "GitHub"
        case .facebook: return "Facebook"
        case .youtube: return "YouTube"
        case .twitch: return "Twitch"
        case .pinterest: return "Pinterest"
        case .line: return "LINE"
        case .signal: return "Signal"
        case .testflight: return "TestFlight"
        case .paypal: return "PayPal"
        case .venmo: return "Venmo"
        case .cashapp: return "Cash App"
        case .linktree: return "Linktree"
        case .email: return L.emailPlatform
        case .phone: return L.phone
        case .custom: return L.custom
        case .xiaohongshu: return L.xiaohongshu
        case .bilibili: return L.bilibili
        case .douyin: return L.douyinTikTok
        case .weibo: return L.weibo
        }
    }

    var iconName: String {
        switch self {
        case .wechat: return "message.fill"
        case .qq: return "bubble.left.and.bubble.right.fill"
        case .whatsapp: return "phone.fill"
        case .instagram: return "camera.fill"
        case .twitter: return "bird"
        case .tiktok: return "music.note"
        case .snapchat: return "camera.viewfinder"
        case .telegram: return "paperplane.fill"
        case .discord: return "headphones"
        case .reddit: return "bubble.left.and.text.bubble.right.fill"
        case .threads: return "at"
        case .mastodon: return "person.wave.2.fill"
        case .bluesky: return "cloud.fill"
        case .linkedin: return "briefcase.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .facebook: return "person.2.fill"
        case .youtube: return "play.rectangle.fill"
        case .twitch: return "gamecontroller.fill"
        case .pinterest: return "pin.fill"
        case .line: return "message.circle.fill"
        case .signal: return "lock.circle.fill"
        case .testflight: return "airplane.circle.fill"
        case .paypal: return "creditcard.fill"
        case .venmo: return "dollarsign.circle.fill"
        case .cashapp: return "dollarsign.square.fill"
        case .linktree: return "link"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .custom: return "qrcode"
        case .xiaohongshu: return "bookmark.fill"
        case .bilibili: return "tv.fill"
        case .douyin: return "play.square.fill"
        case .weibo: return "antenna.radiowaves.left.and.right"
        }
    }

    /// Returns true if `domain` appears as a full domain (not a substring) in `text`.
    private static func isDomain(_ text: String, _ domain: String) -> Bool {
        guard let range = text.range(of: domain) else { return false }
        let before = range.lowerBound == text.startIndex || text[text.index(before: range.lowerBound)] == "/" || text[text.index(before: range.lowerBound)] == "@"
        let after = range.upperBound == text.endIndex || ["/", "?", "#", ":"].contains(text[range.upperBound])
        return before && after
    }

    private static func normalizedPlatformName(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    static func matchingDisplayName(_ name: String) -> Platform? {
        switch normalizedPlatformName(name) {
        case "wechat", "weixin", "wx", "微信": return .wechat
        case "qq": return .qq
        case "whatsapp": return .whatsapp
        case "instagram", "ig": return .instagram
        case "twitter", "x": return .twitter
        case "tiktok": return .tiktok
        case "snapchat": return .snapchat
        case "reddit": return .reddit
        case "threads": return .threads
        case "linkedin": return .linkedin
        case "github": return .github
        case "facebook", "fb": return .facebook
        case "twitch": return .twitch
        case "line": return .line
        case "testflight", "tf": return .testflight
        case "xiaohongshu", "xhs", "小红书", "小紅書": return .xiaohongshu
        case "bilibili", "bili": return .bilibili
        case "douyin", "抖音": return .douyin
        case "weibo", "微博": return .weibo
        default: return nil
        }
    }

    static func resolvedSelection(platformType: String, customPlatformName: String) -> (platformType: String, customPlatformName: String?) {
        let trimmedName = customPlatformName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selected = Platform(rawValue: platformType), selected != .custom else {
            let nameToMatch = trimmedName.isEmpty ? platformType : trimmedName
            if let matched = matchingDisplayName(nameToMatch), matched != .custom {
                return (matched.rawValue, nil)
            }
            return (Platform.custom.rawValue, trimmedName.isEmpty ? nil : trimmedName)
        }
        return (selected.rawValue, nil)
    }

    /// Detects the platform from a QR code URL/content string.
    static func detect(from url: String) -> Platform? {
        let lower = url.lowercased()
        if lower.contains("u.wechat.com") || lower.contains("wechat.com") || lower.contains("weixin") { return .wechat }
        if lower.contains("qm.qq.com") || lower.contains("qq.com") { return .qq }
        if lower.contains("wa.me") || lower.contains("whatsapp.com") { return .whatsapp }
        if lower.contains("instagram.com") || lower.contains("instagr.am") { return .instagram }
        if lower.contains("twitter.com") || isDomain(lower, "x.com") { return .twitter }
        if lower.contains("tiktok.com") || lower.contains("vm.tiktok.com") { return .tiktok }
        if lower.contains("snapchat.com") { return .snapchat }
        if lower.contains("reddit.com") || lower.contains("redd.it") { return .reddit }
        if lower.contains("threads.net") { return .threads }
        if lower.contains("linkedin.com") { return .linkedin }
        if lower.contains("github.com") { return .github }
        if lower.contains("facebook.com") || lower.contains("fb.com") || lower.contains("fb.me") { return .facebook }
        if lower.contains("twitch.tv") { return .twitch }
        if lower.contains("line.me") || lower.contains("lin.ee") { return .line }
        if lower.contains("testflight.apple.com") { return .testflight }
        if lower.contains("xiaohongshu.com") || lower.contains("xhslink.com") { return .xiaohongshu }
        if lower.contains("bilibili.com") || lower.contains("b23.tv") { return .bilibili }
        if lower.contains("douyin.com") || lower.contains("iesdouyin.com") { return .douyin }
        if lower.contains("weibo.com") || lower.contains("weibo.cn") { return .weibo }
        if lower.contains("wechat") || lower.contains("weixin") { return .wechat }
        if lower.contains("instagram") { return .instagram }
        if lower.contains("twitter") { return .twitter }
        if lower.contains("tiktok") { return .tiktok }
        if lower.contains("snapchat") { return .snapchat }
        if lower.contains("reddit") { return .reddit }
        if lower.contains("threads") { return .threads }
        if lower.contains("linkedin") { return .linkedin }
        if lower.contains("github") { return .github }
        if lower.contains("facebook") { return .facebook }
        if lower.contains("whatsapp") { return .whatsapp }
        if lower.contains("twitch") { return .twitch }
        if lower.contains("testflight") { return .testflight }
        if lower.contains("xiaohongshu") || lower.contains("xhs") { return .xiaohongshu }
        if lower.contains("bilibili") { return .bilibili }
        if lower.contains("douyin") { return .douyin }
        if lower.contains("weibo") { return .weibo }
        return nil
    }
}
