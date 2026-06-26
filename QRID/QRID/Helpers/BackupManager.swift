import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum BackupManager {
    static let backupFileName = "MeQR-Backup.json"

    // MARK: - Backup Models

    struct Backup: Codable {
        let version: Int
        let exportedAt: Date
        let clusters: [ClusterBackup]
    }

    struct ClusterBackup: Codable {
        let name: String
        let subtitle: String
        let avatarImageData: Data?
        let backgroundImageData: Data?
        let backgroundColorHex: String
        let borderColorHex: String
        let textColorHex: String?
        let qrColorHex: String?
        let cornerRadius: Double
        let cardOpacity: Double?
        let sortOrder: Int
        let widgetProfileIndex: Int?
        let widgetUseClusterBackground: Bool?
        let widgetBackgroundImageData: Data?
        let widgetOpacity: Double?
        let widgetTextColorHex: String?
        let widgetSmallOffsetX: Double?
        let widgetSmallOffsetY: Double?
        let widgetMediumOffsetX: Double?
        let widgetMediumOffsetY: Double?
        let widgetLargeOffsetX: Double?
        let widgetLargeOffsetY: Double?
        let profiles: [ProfileBackup]
    }

    struct ProfileBackup: Codable {
        let platformType: String
        let qrContent: String
        let foregroundColorHex: String
        let customPlatformName: String?
    }

    private static func makeClusterBackup(_ cluster: QRCluster) -> ClusterBackup {
        ClusterBackup(
            name: cluster.name,
            subtitle: cluster.subtitle,
            avatarImageData: cluster.avatarImageData,
            backgroundImageData: cluster.backgroundImageData,
            backgroundColorHex: cluster.backgroundColorHex,
            borderColorHex: cluster.borderColorHex,
            textColorHex: cluster.textColorHex,
            qrColorHex: cluster.qrColorHex,
            cornerRadius: cluster.cornerRadius,
            cardOpacity: cluster.cardOpacity,
            sortOrder: cluster.sortOrder,
            widgetProfileIndex: cluster.widgetProfileIndex,
            widgetUseClusterBackground: cluster.widgetUseClusterBackground,
            widgetBackgroundImageData: cluster.widgetBackgroundImageData,
            widgetOpacity: cluster.widgetOpacity,
            widgetTextColorHex: cluster.widgetTextColorHex,
            widgetSmallOffsetX: cluster.widgetSmallOffsetX,
            widgetSmallOffsetY: cluster.widgetSmallOffsetY,
            widgetMediumOffsetX: cluster.widgetMediumOffsetX,
            widgetMediumOffsetY: cluster.widgetMediumOffsetY,
            widgetLargeOffsetX: cluster.widgetLargeOffsetX,
            widgetLargeOffsetY: cluster.widgetLargeOffsetY,
            profiles: cluster.profiles.map { profile in
                ProfileBackup(
                    platformType: profile.platformType,
                    qrContent: profile.qrContent,
                    foregroundColorHex: profile.foregroundColorHex,
                    customPlatformName: profile.customPlatformName
                )
            }
        )
    }

    // MARK: - Export

    static func exportBackup(clusters: [QRCluster]) -> URL? {
        let backup = Backup(
            version: 1,
            exportedAt: Date(),
            clusters: clusters.map(makeClusterBackup)
        )

        do {
            let data = try JSONEncoder().encode(backup)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(backupFileName)
            try data.write(to: url)
            return url
        } catch {
            print("Failed to export backup: \(error)")
            return nil
        }
    }

    static func writePreRestoreBackup(clusters: [QRCluster]) throws -> URL {
        let backup = Backup(
            version: 1,
            exportedAt: Date(),
            clusters: clusters.map(makeClusterBackup)
        )
        let data = try JSONEncoder().encode(backup)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = ISO8601DateFormatter()
        let safeDate = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = documents.appendingPathComponent("MeQR-PreRestore-\(safeDate).json")
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    // MARK: - Import

    static func importBackup(from url: URL, modelContext: ModelContext) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(Backup.self, from: data)

            let existingDescriptor = FetchDescriptor<QRCluster>()
            let existingClusters = try modelContext.fetch(existingDescriptor)
            if !existingClusters.isEmpty {
                _ = try writePreRestoreBackup(clusters: existingClusters)
            }

            for cluster in existingClusters {
                modelContext.delete(cluster)
            }

            for clusterBackup in backup.clusters {
                let cluster = QRCluster(
                    name: clusterBackup.name,
                    subtitle: clusterBackup.subtitle,
                    avatarImageData: clusterBackup.avatarImageData,
                    backgroundImageData: clusterBackup.backgroundImageData,
                    backgroundColorHex: clusterBackup.backgroundColorHex,
                    borderColorHex: clusterBackup.borderColorHex,
                    textColorHex: clusterBackup.textColorHex,
                    qrColorHex: clusterBackup.qrColorHex,
                    cornerRadius: clusterBackup.cornerRadius,
                    cardOpacity: clusterBackup.cardOpacity,
                    sortOrder: clusterBackup.sortOrder,
                    widgetProfileIndex: clusterBackup.widgetProfileIndex,
                    widgetUseClusterBackground: clusterBackup.widgetUseClusterBackground,
                    widgetBackgroundImageData: clusterBackup.widgetBackgroundImageData,
                    widgetOpacity: clusterBackup.widgetOpacity,
                    widgetTextColorHex: clusterBackup.widgetTextColorHex,
                    widgetSmallOffsetX: clusterBackup.widgetSmallOffsetX,
                    widgetSmallOffsetY: clusterBackup.widgetSmallOffsetY,
                    widgetMediumOffsetX: clusterBackup.widgetMediumOffsetX,
                    widgetMediumOffsetY: clusterBackup.widgetMediumOffsetY,
                    widgetLargeOffsetX: clusterBackup.widgetLargeOffsetX,
                    widgetLargeOffsetY: clusterBackup.widgetLargeOffsetY
                )
                modelContext.insert(cluster)

                for profileBackup in clusterBackup.profiles {
                    let profile = QRProfile(
                        platformType: profileBackup.platformType,
                        qrContent: profileBackup.qrContent,
                        foregroundColorHex: profileBackup.foregroundColorHex,
                        customPlatformName: profileBackup.customPlatformName,
                        cluster: cluster
                    )
                    modelContext.insert(profile)
                }
            }

            try modelContext.save()
            let restoredClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
            ))
            WidgetDataHelper.sync(clusters: restoredClusters)
            writeAutoBackup(clusters: restoredClusters)
            return true
        } catch {
            modelContext.rollback()
            print("Failed to import backup: \(error)")
            return false
        }
    }

    static func writeAutoBackup(clusters: [QRCluster]) {
        guard let backup = exportBackup(clusters: clusters) else { return }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destination = documents.appendingPathComponent(backupFileName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: backup, to: destination)
        } catch {
            print("Failed to write auto backup: \(error)")
        }
    }

    static func autoBackupURL() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(backupFileName)
    }
}
