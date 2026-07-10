import Foundation
import SwiftData
import SwiftUI

enum ClusterTemplateStyle: String, CaseIterable, Identifiable {
    case standard
    case polaroid
    case conventionPass
    case rhodesPass

    var id: String { rawValue }

    static var selectableCases: [ClusterTemplateStyle] {
        [.standard, .conventionPass, .rhodesPass]
    }

    var displayName: String {
        switch self {
        case .standard:
            return L.templateStandard
        case .polaroid:
            return L.templatePolaroid
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
        case .polaroid:
            return "photo"
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
            let style = ClusterTemplateStyle(rawValue: templateStyleRawValue ?? "") ?? .standard
            return style == .polaroid ? .standard : style
        }
        set { templateStyleRawValue = newValue.rawValue }
    }

    var passSubtitleText: String {
        let trimmed = passSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L.passLabel : trimmed
    }
}
