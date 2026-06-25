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
    case snapchat, telegram, discord, linkedin, github
    case facebook, youtube, email, phone, custom
    case xiaohongshu, bilibili, douyin, weibo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wechat: return L.tr("微信", "WeChat")
        case .qq: return "QQ"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .twitter: return L.tr("X (推特)", "X (Twitter)")
        case .tiktok: return "TikTok"
        case .snapchat: return "Snapchat"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .linkedin: return "LinkedIn"
        case .github: return "GitHub"
        case .facebook: return "Facebook"
        case .youtube: return "YouTube"
        case .email: return L.tr("邮箱", "Email")
        case .phone: return L.tr("电话", "Phone")
        case .custom: return L.tr("自定义", "Custom")
        case .xiaohongshu: return L.tr("小红书", "Xiaohongshu")
        case .bilibili: return L.tr("B站", "Bilibili")
        case .douyin: return L.tr("抖音", "Douyin")
        case .weibo: return L.tr("微博", "Weibo")
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
        case .linkedin: return "briefcase.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .facebook: return "person.2.fill"
        case .youtube: return "play.rectangle.fill"
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
        if lower.contains("t.me") || lower.contains("telegram.me") || lower.contains("telegram.org") { return .telegram }
        if lower.contains("discord.com") || lower.contains("discord.gg") { return .discord }
        if lower.contains("linkedin.com") { return .linkedin }
        if lower.contains("github.com") { return .github }
        if lower.contains("facebook.com") || lower.contains("fb.com") || lower.contains("fb.me") { return .facebook }
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("xiaohongshu.com") || lower.contains("xhslink.com") { return .xiaohongshu }
        if lower.contains("bilibili.com") || lower.contains("b23.tv") { return .bilibili }
        if lower.contains("douyin.com") || lower.contains("iesdouyin.com") { return .douyin }
        if lower.contains("weibo.com") || lower.contains("weibo.cn") { return .weibo }
        if lower.contains("wechat") || lower.contains("weixin") { return .wechat }
        if lower.contains("instagram") { return .instagram }
        if lower.contains("twitter") { return .twitter }
        if lower.contains("tiktok") { return .tiktok }
        if lower.contains("snapchat") { return .snapchat }
        if lower.contains("telegram") { return .telegram }
        if lower.contains("discord") { return .discord }
        if lower.contains("linkedin") { return .linkedin }
        if lower.contains("github") { return .github }
        if lower.contains("facebook") { return .facebook }
        if lower.contains("youtube") { return .youtube }
        if lower.contains("whatsapp") { return .whatsapp }
        if lower.contains("xiaohongshu") || lower.contains("xhs") { return .xiaohongshu }
        if lower.contains("bilibili") { return .bilibili }
        if lower.contains("douyin") { return .douyin }
        if lower.contains("weibo") { return .weibo }
        if lower.contains("mailto:") { return .email }
        if !lower.hasPrefix("http://"), !lower.hasPrefix("https://"),
           lower.contains("@"), lower.contains(".") {
            return .email
        }
        return nil
    }
}
