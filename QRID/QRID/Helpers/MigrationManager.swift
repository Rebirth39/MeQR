import Foundation
import SwiftData

struct MigrationManager {
    static func performClusterMigrationIfNeeded(context: ModelContext) {
        let key = "hasPerformedClusterMigration_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let descriptor = FetchDescriptor<QRProfile>(predicate: #Predicate { $0.cluster == nil })
        let orphanProfiles: [QRProfile]
        do {
            orphanProfiles = try context.fetch(descriptor)
        } catch {
            print("Cluster migration fetch failed: \(error)")
            return
        }

        guard !orphanProfiles.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        // Group profiles by shared fields to detect which ones should be in the same cluster
        // For now, each existing profile becomes its own cluster (1:1 mapping)
        for (index, profile) in orphanProfiles.enumerated() {
            let cluster = QRCluster(
                name: profile.name,
                subtitle: profile.subtitle,
                avatarImageData: profile.avatarImageData,
                backgroundColorHex: profile.backgroundColorHex,
                borderColorHex: profile.borderColorHex,
                cornerRadius: profile.cornerRadius,
                sortOrder: index
            )
            context.insert(cluster)
            profile.cluster = cluster
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            print("Cluster migration failed: \(error)")
        }
    }
}
