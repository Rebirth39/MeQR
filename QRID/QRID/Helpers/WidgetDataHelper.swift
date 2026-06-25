import Foundation
import SwiftData
import SwiftUI
import CoreImage.CIFilterBuiltins
import WidgetKit

struct WidgetClusterData: Codable {
    let id: String
    let name: String
    let subtitle: String
    let backgroundColorHex: String
    let borderColorHex: String
    let textColorHex: String
    let avatarBase64: String?
    let profileCount: Int
    let qrContent: String?
    let qrColorHex: String?
    let useClusterBackground: Bool
    let widgetOpacity: Double
    let widgetBackgroundImageBase64: String?
    let widgetTextColorHex: String
    let widgetSmallOffsetX: Double
    let widgetSmallOffsetY: Double
    let widgetMediumOffsetX: Double
    let widgetMediumOffsetY: Double
    let widgetLargeOffsetX: Double
    let widgetLargeOffsetY: Double
}

enum WidgetDataHelper {
    static let appGroupID = "group.com.lucasli.qrid"

    static var sharedFileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.appendingPathComponent("clusters.json")
    }

    static func sync(clusters: [QRCluster]) {
        let items: [WidgetClusterData] = clusters.map { cluster in
            let profiles = cluster.profiles.sorted { $0.createdAt < $1.createdAt }
            let index = cluster.widgetProfileIndex ?? 0
            let selectedProfile = profiles.indices.contains(index) ? profiles[index] : profiles.first
            return WidgetClusterData(
                id: cluster.id.uuidString,
                name: cluster.name,
                subtitle: cluster.subtitle,
                backgroundColorHex: cluster.backgroundColorHex,
                borderColorHex: cluster.borderColorHex,
                textColorHex: cluster.textColorHex ?? "#000000",
                avatarBase64: cluster.avatarImageData?.base64EncodedString(),
                profileCount: profiles.count,
                qrContent: selectedProfile?.qrContent,
                qrColorHex: cluster.qrColorHex ?? selectedProfile?.foregroundColorHex,
                useClusterBackground: cluster.widgetUseClusterBackground ?? true,
                widgetOpacity: cluster.widgetOpacity ?? 0.8,
                widgetBackgroundImageBase64: cluster.widgetBackgroundImageData?.base64EncodedString(),
                widgetTextColorHex: cluster.widgetTextColorHex ?? (cluster.textColorHex ?? "#000000"),
                widgetSmallOffsetX: cluster.widgetSmallOffsetX ?? 0,
                widgetSmallOffsetY: cluster.widgetSmallOffsetY ?? 0,
                widgetMediumOffsetX: cluster.widgetMediumOffsetX ?? 0,
                widgetMediumOffsetY: cluster.widgetMediumOffsetY ?? 0,
                widgetLargeOffsetX: cluster.widgetLargeOffsetX ?? 0,
                widgetLargeOffsetY: cluster.widgetLargeOffsetY ?? 0
            )
        }

        guard let url = sharedFileURL else { return }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func writeTestData() {
        let test = WidgetClusterData(
            id: "test",
            name: "测试",
            subtitle: "",
            backgroundColorHex: "#FFFFFF",
            borderColorHex: "#000000",
            textColorHex: "#000000",
            avatarBase64: nil,
            profileCount: 1,
            qrContent: "https://example.com",
            qrColorHex: "#000000",
            useClusterBackground: true,
            widgetOpacity: 0.8,
            widgetBackgroundImageBase64: nil,
            widgetTextColorHex: "#000000",
            widgetSmallOffsetX: 0,
            widgetSmallOffsetY: 0,
            widgetMediumOffsetX: 0,
            widgetMediumOffsetY: 0,
            widgetLargeOffsetX: 0,
            widgetLargeOffsetY: 0
        )
        guard let url = sharedFileURL else { return }
        if let data = try? JSONEncoder().encode([test]) {
            try? data.write(to: url)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
