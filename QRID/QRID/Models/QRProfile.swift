import Foundation
import SwiftData
import SwiftUI

@Model
final class QRProfile {
    var id: UUID
    var name: String
    var platformType: String
    var qrContent: String?
    var importedImageData: Data?
    var foregroundColorHex: String
    var backgroundColorHex: String
    var cornerRadius: Double
    var createdAt: Date
    var isGenerated: Bool

    init(
        name: String,
        platformType: String = "custom",
        qrContent: String? = nil,
        importedImageData: Data? = nil,
        foregroundColorHex: String = "#000000",
        backgroundColorHex: String = "#FFFFFF",
        cornerRadius: Double = 16,
        isGenerated: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.platformType = platformType
        self.qrContent = qrContent
        self.importedImageData = importedImageData
        self.foregroundColorHex = foregroundColorHex
        self.backgroundColorHex = backgroundColorHex
        self.cornerRadius = cornerRadius
        self.createdAt = Date()
        self.isGenerated = isGenerated
    }

    var foregroundColor: Color {
        Color(hex: foregroundColorHex)
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex)
    }

    var platform: Platform {
        Platform(rawValue: platformType) ?? .custom
    }
}

enum Platform: String, CaseIterable, Identifiable {
    case wechat, qq, whatsapp, instagram, twitter, tiktok
    case snapchat, telegram, discord, linkedin, github
    case facebook, youtube, email, phone, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wechat: return "WeChat"
        case .qq: return "QQ"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .twitter: return "X / Twitter"
        case .tiktok: return "TikTok"
        case .snapchat: return "Snapchat"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .linkedin: return "LinkedIn"
        case .github: return "GitHub"
        case .facebook: return "Facebook"
        case .youtube: return "YouTube"
        case .email: return "Email"
        case .phone: return "Phone"
        case .custom: return "Custom"
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
        }
    }
}
