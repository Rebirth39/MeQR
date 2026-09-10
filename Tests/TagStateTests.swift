import Foundation

@main struct TagStateTests {
    @MainActor static func main() async throws {
        let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        func install(_ data: Data) throws {
            RemoteTagCatalogSnapshot.replace(with: try JSONDecoder().decode(RemoteTagCatalogDocument.self, from: data))
        }
        try install(original)
        assert(CardTagIndex.searchEntries(for: "Saki").prefix(2).allSatisfy { $0.aliases.contains { $0.lowercased() == "saki" } })
        let scoped = CardTagIndex.searchEntries(for: "世界计划 咲希")
        assert(scoped.count == 1)
        assert(RemoteTagCatalogSnapshot.subtitle(for: scoped[0], language: .en).contains("Leo/need"))
        assert(!CardTagIndex.searchEntries(for: "Saki", excluding: [scoped[0].names.en]).contains { $0.id == scoped[0].id })
        let old = CardTagColorPalette.overrides(from: "{\"世界计划\":\"#123456\"}")
        var references = CardTagReference.reconcile(names: ["世界计划", "Saki"], overrides: old, previous: [])
        assert(references[0].catalogID == "tag-0001")
        assert(references[1].catalogID == nil)
        assert(references[0].override?.hexes == ["#123456"])
        references = CardTagReference.decode(CardTagReference.encode(references))!
        var document = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        var entries = document["entries"] as! [[String: Any]]
        let index = entries.firstIndex { $0["id"] as? String == "tag-0001" }!
        var names = entries[index]["names"] as! [String: String]
        names["en"] = "Renamed Sekai"
        entries[index]["names"] = names; document["entries"] = entries
        try install(JSONSerialization.data(withJSONObject: document))
        assert(references[0].displayName == "Renamed Sekai")
        assert(references[0].displayOverride.hexes == ["#123456"])
        AppSettings.shared.resolvedLanguage = .ja
        assert(references[0].displayName == names["ja"])
        assert(references[0].displayOverride.hexes == ["#123456"])
        AppSettings.shared.resolvedLanguage = .en
        references = CardTagReference.reconcile(names: references.map(\.displayName), overrides: ["renamedsekai": references[0].displayOverride], previous: references)
        references[0].override = nil
        entries.remove(at: index); document["entries"] = entries
        try install(JSONSerialization.data(withJSONObject: document))
        assert(references[0].displayName == "Renamed Sekai")
        assert(references[0].displayOverride.referenceColors?.count == 6)
        assert(CardTagColorPalette.colorStyle(for: references[0].displayName, overrides: ["renamedsekai": references[0].displayOverride]).segmentHexes.count == 6)
        let kept = CardTagReference.reconcile(names: references.map(\.displayName).reversed(), overrides: [:], previous: references)
        assert(kept.last?.catalogID == "tag-0001", "Reordering must retain missing catalog IDs")
        assert(CardTagInk(hexes: ["#000000", "#FFFFFF"]).outlined)
        assert(!CardTagInk(hexes: ["#FFFFFF", "#FFFFAA"]).outlined)
        assert(!CardTagInk(hexes: ["#FFFFFF"]).white)
        assert(CardTagInk(hexes: ["#000000"]).white)
        try await queue()
        print("PASS: context search, ambiguity, stable IDs, legacy overrides, rename/language/removal, six-color fallback, contrast, durable outbox")
    }

    @MainActor static func queue() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("queue.json")
        let id = UUID().uuidString
        let payload = ["request_id": id, "tag_name": "Fixture"]
        var calls = 0
        let offline = CardTagOutbox(url: file, monitorNetwork: false) { _ in calls += 1; throw URLError(.notConnectedToInternet) }
        _ = try offline.enqueue(payload)
        assert(calls == 0 && FileManager.default.fileExists(atPath: file.path))
        _ = try offline.enqueue(payload)
        assert(offline.jobs.count == 1)
        do { _ = try offline.enqueue(["request_id": id, "tag_name": "Changed"]); assertionFailure("Conflict allowed") } catch { }
        await offline.drain()
        assert(offline.jobs[0].status == "pending" && offline.jobs[0].nextAttempt > Date())
        let online = CardTagOutbox(url: file, monitorNetwork: false) { body in
            assert(body["request_id"] == id); calls += 1; return "MEQR-20260908-ABCDEF"
        }
        try await online.retry(id)
        assert(online.jobs[0].ticket == "MEQR-20260908-ABCDEF")
        let restored = CardTagOutbox(url: file, monitorNetwork: false) { _ in assertionFailure("Sent receipt resubmitted"); return "" }
        await restored.drain(); assert(calls == 2)
        try restored.cancel(id); assert(restored.jobs.isEmpty)
        let rejected = CardTagOutbox(url: file, monitorNetwork: false) { _ in throw CardTagReportClient.Failure.rejected }
        _ = try rejected.enqueue(payload); await rejected.drain()
        assert(rejected.jobs[0].status == "failed")
        try rejected.cancel(id)
        var stale = CardTagOutbox.Job(payload: payload); stale.status = "sending"
        try JSONEncoder().encode([stale]).write(to: file)
        let recovered = CardTagOutbox(url: file, monitorNetwork: false) { _ in throw CardTagReportClient.Failure.limited }
        assert(recovered.jobs[0].status == "pending")
        await recovered.drain()
        assert(recovered.jobs[0].nextAttempt.timeIntervalSinceNow > 590)
        let corrupt = directory.appendingPathComponent("corrupt.json")
        try Data("broken".utf8).write(to: corrupt)
        let blocked = CardTagOutbox(url: corrupt, monitorNetwork: false) { _ in assertionFailure("Corrupt queue sent"); return "" }
        do { _ = try blocked.enqueue(payload); assertionFailure("Corrupt queue overwritten") } catch { }
        let preserved = try String(contentsOf: corrupt, encoding: .utf8)
        assert(preserved == "broken")
    }
}
