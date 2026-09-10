import Foundation
import SwiftData

@main struct TagAudit20260909Tests {
    @MainActor static func main() async throws {
        var failures = 0
        func check(_ condition: Bool, _ message: String) {
            print("\(condition ? "PASS" : "FAIL"): \(message)")
            if !condition { failures += 1 }
        }
        func install(colors: [String] = ["#112233", "#445566"], solid: String? = "#778899", empty: Bool = false) {
            let entry = RemoteTagEntry(id: "fixture-id", names: .init(
                zhHans: "Fixture Hans", zhHantHK: "Fixture HK", zhHantTW: "Fixture TW",
                en: "Fixture English", ja: "Fixture Japanese"), aliases: ["fixture-alias"],
                colors: colors, solidColor: solid, kind: "work", parentID: nil)
            RemoteTagCatalogSnapshot.replace(with: .init(schemaVersion: 1, revision: "audit", entries: empty ? [] : [entry], categories: nil, changelog: nil))
        }
        install()
        let custom = CardTagColorOverride(mode: .custom, hexes: ["#ABCDEF"], textWeight: .bold)
        let original = CardTagReference.reconcile(names: ["Fixture English"], overrides: ["fixtureenglish": custom], previous: [])
        let alias = CardTagReference.reconcile(names: ["fixture-alias"], overrides: [:], previous: original)
        check(alias[0].localID == original[0].localID && alias[0].override == original[0].override,
              "Saving an alias preserves reference identity and custom color/weight")
        AppSettings.shared.resolvedLanguage = .zhHans
        let translated = CardTagReference.reconcile(names: ["Fixture Japanese"], overrides: [:], previous: original)
        check(translated[0].localID == original[0].localID && translated[0].override == custom,
              "Saving an earlier editor language preserves reference identity and override")
        AppSettings.shared.resolvedLanguage = .en

        let migrated = QRCluster(name: "migration", tagListRawValue: "Fixture English\nfixture-alias\nFixture Japanese",
                                 tagColorOverridesRawValue: "{\"fixture-alias\":\"#ABCDEF\"}")
        check(migrated.tags == ["Fixture English"], "Migration deduplicates aliases by catalog identity")
        check(migrated.tagColorStyle(for: "Fixture English").segmentHexes == ["#ABCDEF"],
              "Migration retains an override keyed by a legacy alias")
        let oversized = QRCluster(name: "limits", tagListRawValue: (0..<12).map { "custom-\($0)" }.joined(separator: "\n"))
        check(oversized.tags.count == CardTagLimiter.maxTags, "Migration preserves the ten-tag limit")

        install(empty: true)
        let early = QRCluster(name: "before catalog")
        early.setTags(["fixture-alias"], overrides: ["fixture-alias": custom])
        install()
        early.migrateTagReferences()
        check(CardTagReference.decode(early.tagReferencesRawValue)?.first?.catalogID == "fixture-id",
              "Saving before catalog loading still permits later legacy migration")
        check(early.tagColorStyle(for: early.tags[0]).segmentHexes == ["#ABCDEF"], "Deferred migration preserves custom colors")

        let cluster = QRCluster(name: "export", tagListRawValue: "Fixture English")
        cluster.setTags(cluster.tags, overrides: ["fixtureenglish": .init(mode: .solid, hexes: [], textWeight: .bold)])
        install(colors: ["#AABBCC", "#DDEEFF"], solid: nil)
        check(cluster.tagColorStyle(for: "Fixture English").segmentHexes == ["#AABBCC"],
              "A catalog palette without solidColor uses its current first color")
        let snapshot = BackupManager.auditSnapshot(cluster)
        let data = try JSONEncoder().encode(snapshot)
        let artifact = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("tag-backup-fixture.json")
        try data.write(to: artifact)
        let decoded = try JSONDecoder().decode(BackupManager.ClusterBackup.self, from: data)
        install(empty: true)
        let refs = CardTagReference.decode(decoded.tagReferencesRawValue)!
        check(refs[0].colors == ["#AABBCC", "#DDEEFF"] && refs[0].solidColor == "#AABBCC",
              "Backup snapshots the visible catalog palette for offline restoration")
        check(refs[0].override?.mode == .solid && refs[0].override?.textWeight == .bold,
              "Backup retains explicit color mode and text weight")
        let container = try ModelContainer(for: QRCluster.self, QRProfile.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let restored = QRCluster(name: decoded.name, tagListRawValue: decoded.tagListRawValue,
                                 tagColorOverridesRawValue: decoded.tagColorOverridesRawValue)
        restored.tagReferencesRawValue = decoded.tagReferencesRawValue
        context.insert(restored)
        try context.save()
        let fetched = try ModelContext(container).fetch(FetchDescriptor<QRCluster>())[0]
        check(fetched.tagColorStyle(for: fetched.tags[0]).segmentHexes == ["#AABBCC"],
              "SwiftData save/refetch restores the exported solid color without a catalog")

        try await queue(check: check)
        if failures > 0 { exit(1) }
    }

    @MainActor static func queue(check: (Bool, String) -> Void) async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("queue-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("scheduled.json")
        let id = UUID().uuidString
        var job = CardTagOutbox.Job(payload: ["request_id": id, "tag_name": "scheduled"])
        job.nextAttempt = Date().addingTimeInterval(0.1)
        try JSONEncoder().encode([job]).write(to: file)
        var cancelledTransport = false
        var calls = 0
        let outbox = CardTagOutbox(url: file, monitorNetwork: false) { _ in
            calls += 1
            cancelledTransport = Task.isCancelled
            try Task.checkCancellation()
            return "MEQR-20260909-ABCDEF"
        }
        await outbox.drain()
        try await Task.sleep(for: .milliseconds(1500))
        check(calls == 1 && !cancelledTransport && outbox.jobs[0].ticket != nil,
              "Timer-driven retry reaches the transport without inheriting cancellation")
        try outbox.cancel(id)
        let canceled = CardTagOutbox(url: file, monitorNetwork: false) { _ in
            calls += 1
            return "unexpected"
        }
        await canceled.drain()
        check(canceled.jobs.isEmpty && calls == 1, "Canceled queue item stays deleted after reload")
        let pendingFile = directory.appendingPathComponent("pending.json")
        job.nextAttempt = Date().addingTimeInterval(0.1)
        try JSONEncoder().encode([job]).write(to: pendingFile)
        let pending = CardTagOutbox(url: pendingFile, monitorNetwork: false) { _ in
            calls += 1
            return "unexpected"
        }
        await pending.drain()
        try pending.cancel(id)
        try await Task.sleep(for: .milliseconds(1200))
        check(calls == 1 && pending.jobs.isEmpty, "Cancel before a scheduled retry prevents submission")
    }
}
