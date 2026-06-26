import Foundation
import SwiftData

struct MigrationManager {
    static func performClusterMigrationIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<QRProfile>(predicate: #Predicate { $0.cluster == nil })
        let orphanProfiles = try context.fetch(descriptor)
            .sorted { $0.createdAt < $1.createdAt }

        guard !orphanProfiles.isEmpty else { return }

        let existingClusters = try context.fetch(FetchDescriptor<QRCluster>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        ))
        var nextSortOrder = (existingClusters.map(\.sortOrder).max() ?? -1) + 1

        // Group profiles by shared fields to detect which ones should be in the same cluster
        // For now, each existing profile becomes its own cluster (1:1 mapping)
        for profile in orphanProfiles {
            let fallbackName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let clusterName = fallbackName.isEmpty ? profile.platformDisplayName : fallbackName
            let cluster = QRCluster(
                name: clusterName,
                subtitle: profile.subtitle,
                avatarImageData: profile.avatarImageData,
                backgroundColorHex: profile.backgroundColorHex,
                borderColorHex: profile.borderColorHex,
                qrColorHex: profile.foregroundColorHex,
                cornerRadius: profile.cornerRadius,
                sortOrder: nextSortOrder
            )
            nextSortOrder += 1
            context.insert(cluster)
            profile.attach(to: cluster)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
