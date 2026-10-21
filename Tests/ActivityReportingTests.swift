import Foundation

actor ActivityMock {
    var requests: [(String, String?, [String: Any])] = []
    var failNext = false
    var wrongReply = false
    var day = "2026-10-20"

    func configure(fail: Bool = false, wrong: Bool = false, day: String = "2026-10-20") {
        failNext = fail
        wrongReply = wrong
        self.day = day
    }

    func count() -> Int { requests.count }
    func paths() -> [String] { requests.map { $0.0 } }
    func localFlags() -> [[String: Bool]] {
        requests.filter { $0.0 == "activity" }.map {
            ["day": $0.2["countDay"] as? Bool ?? false, "month": $0.2["countMonth"] as? Bool ?? false]
        }
    }

    func send(_ path: String, _ token: String?, _ body: Data?) throws -> Data {
        let object = try body.map { try JSONSerialization.jsonObject(with: $0) as! [String: Any] } ?? [:]
        requests.append((path, token, object))
        if failNext {
            failNext = false
            throw URLError(.timedOut)
        }
        if path == "activity-period" {
            precondition(token == nil && body == nil)
            return try JSONSerialization.data(withJSONObject: ["day": day, "month": String(day.prefix(7))])
        }
        if path == "activity" {
            precondition(token == nil)
            precondition(Set(object.keys) == Set(["day", "countDay", "countMonth"]))
        } else {
            precondition(token == "secret" && object.isEmpty)
        }
        return try JSONSerialization.data(withJSONObject: [
            "day": day, "month": String(day.prefix(7)), "acknowledged": !wrongReply,
            "scope": path == "activity" ? "local_installations" : "sync_profiles",
            "dayCounted": object["countDay"] as? Bool ?? false,
            "monthCounted": object["countMonth"] as? Bool ?? false
        ])
    }
}

@main
struct ActivityReportingTests {
    static func main() async throws {
        let suite = "meqr.activity.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let mock = ActivityMock()
        let date = ISO8601DateFormatter().date(from: "2026-10-20T01:00:00Z")!
        let reporter = ActivityReporter(defaults: defaults, clock: { date }, sender: { path, token, body in
            try await mock.send(path, token, body)
        })
        await reporter.report(bindings: [])
        let firstOpen = await mock.count()
        precondition(firstOpen == 2)
        precondition(defaults.string(forKey: "activity.local.day") == "2026-10-20")
        await reporter.report(bindings: [])
        let afterRepeatedLocal = await mock.count()
        precondition(afterRepeatedLocal == 2)
        let nextDate = date.addingTimeInterval(86400)
        await mock.configure(day: "2026-10-21")
        let nextDay = ActivityReporter(defaults: defaults, clock: { nextDate }, sender: { path, token, body in
            try await mock.send(path, token, body)
        })
        await nextDay.report(bindings: [])
        let flags = await mock.localFlags()
        precondition(flags == [["day": true, "month": true], ["day": true, "month": false]])
        let bindings = [ActivityBinding(profileID: "first", token: "secret"), ActivityBinding(profileID: "first", token: "secret")]
        await mock.configure(fail: true, day: "2026-10-21")
        await nextDay.report(bindings: bindings)
        precondition(defaults.string(forKey: "activity.sync.day.first") == nil)
        await nextDay.report(bindings: bindings)
        precondition(defaults.string(forKey: "activity.sync.day.first") == "2026-10-21")
        let beforeRepeatedSync = await mock.count()
        await nextDay.report(bindings: bindings)
        let afterRepeatedSync = await mock.count()
        precondition(beforeRepeatedSync == afterRepeatedSync)
        await mock.configure(wrong: true, day: "2026-10-21")
        await nextDay.report(bindings: [ActivityBinding(profileID: "invalid", token: "secret")])
        precondition(defaults.string(forKey: "activity.sync.day.invalid") == nil)
        await mock.configure(day: "2026-10-21")
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { await nextDay.report(bindings: [ActivityBinding(profileID: "concurrent", token: "secret")]) }
            }
        }
        let paths = await mock.paths()
        precondition(paths.filter { $0 == "profiles/concurrent/activity" }.count == 1)
        precondition(defaults.string(forKey: "activity.sync.month.first") == nil)
        print("PASS: automatic first-open reporting, anonymous payload, daily/monthly local state, sync daily-only cache, response-loss retry, invalid ACK, duplicate bindings and concurrent foreground calls")
    }
}
