import Foundation
import SwiftData

@main struct GlassStrengthTests {
    @MainActor static func main() throws {
        let store = URL(fileURLWithPath: CommandLine.arguments[1])
        do {
            let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: store))
            let c = try container.mainContext.fetch(FetchDescriptor<QRCluster>())[0]
            assert(c.name == "Legacy glass" && c.cardGlassStrength == nil)
            assert(c.resolvedCardGlassStrength == 0.5 && c.cardOpacity == 0.7 && c.profiles.count == 1)
            for (input, expected) in [(-1.0, 0.0), (2.0, 1.0), (Double.nan, 0.5), (Double.infinity, 0.5), (0.85, 0.85)] {
                c.cardGlassStrength = input
                assert(c.resolvedCardGlassStrength == expected)
            }
            c.cardGlassStrength = 0.85
            try container.mainContext.save()
        }
        let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: store))
        let context = container.mainContext
        let c = try context.fetch(FetchDescriptor<QRCluster>())[0]
        assert(c.cardGlassStrength == 0.85 && c.cardOpacity == 0.7)
        let exported = BackupManager.exportBackup(clusters: [c])!
        let data = try Data(contentsOf: exported)
        let backup = try JSONDecoder().decode(BackupManager.Backup.self, from: data)
        assert(backup.clusters[0].cardGlassStrength == 0.85)
        let restoreContainer = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        assert(BackupManager.importBackup(from: exported, modelContext: restoreContainer.mainContext))
        let restored = try restoreContainer.mainContext.fetch(FetchDescriptor<QRCluster>())[0]
        assert(restored.cardGlassStrength == 0.85 && restored.cardOpacity == 0.7 && restored.cardGlassEnabled == true && restored.profiles.count == 1)
        var legacyJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var clusters = legacyJSON["clusters"] as! [[String: Any]]
        clusters[0].removeValue(forKey: "cardGlassStrength")
        legacyJSON["clusters"] = clusters
        let legacyURL = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("old-backup.json")
        try JSONSerialization.data(withJSONObject: legacyJSON).write(to: legacyURL)
        assert(BackupManager.importBackup(from: legacyURL, modelContext: restoreContainer.mainContext))
        let old = try restoreContainer.mainContext.fetch(FetchDescriptor<QRCluster>())[0]
        assert(old.cardGlassStrength == nil && old.resolvedCardGlassStrength == 0.5 && old.cardOpacity == 0.7 && old.profiles.count == 1)
        print("PASS: old SwiftData migration, persistence, invalid values, backup restore and legacy backup default")
    }
}
