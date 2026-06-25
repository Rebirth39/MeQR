import Foundation
import SwiftData
import SwiftUI

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
}
