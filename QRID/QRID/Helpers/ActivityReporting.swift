import Foundation

struct ActivityBinding: Sendable {
    let profileID: String
    let token: String
}

actor ActivityReporter {
    typealias Sender = @Sendable (String, String?, Data?) async throws -> Data
    static let shared = ActivityReporter()
    private let defaults: UserDefaults
    private let sender: Sender
    private let clock: @Sendable () -> Date
    private var inFlight = false

    init(defaults: UserDefaults = .standard, clock: @escaping @Sendable () -> Date = { Date() },
         sender: @escaping Sender = ActivityReporter.send) {
        self.defaults = defaults
        self.clock = clock
        self.sender = sender
    }

    private func day() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: clock())
    }

    func report(bindings: [ActivityBinding]) async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        let today = day()
        if bindings.isEmpty {
            if defaults.string(forKey: "activity.local.day") == today,
               defaults.string(forKey: "activity.local.month") == String(today.prefix(7)) { return }
            do {
                let period = try JSONSerialization.jsonObject(with: await sender("activity-period", nil, nil)) as? [String: Any]
                guard let serverDay = period?["day"] as? String, let month = period?["month"] as? String,
                      serverDay.count == 10, month == String(serverDay.prefix(7)) else { return }
                let countDay = defaults.string(forKey: "activity.local.day") != serverDay
                let countMonth = defaults.string(forKey: "activity.local.month") != month
                guard countDay || countMonth else { return }
                let body = try JSONSerialization.data(withJSONObject: ["day": serverDay, "countDay": countDay, "countMonth": countMonth])
                let reply = try JSONSerialization.jsonObject(with: await sender("activity", nil, body)) as? [String: Any]
                guard reply?["acknowledged"] as? Bool == true, reply?["scope"] as? String == "local_installations",
                      reply?["day"] as? String == serverDay, reply?["month"] as? String == month,
                      reply?["dayCounted"] as? Bool == countDay, reply?["monthCounted"] as? Bool == countMonth else { return }
                if countDay { defaults.set(serverDay, forKey: "activity.local.day") }
                if countMonth { defaults.set(month, forKey: "activity.local.month") }
            } catch { return }
        } else {
            var visited: Set<String> = []
            for binding in bindings {
                guard visited.insert(binding.profileID).inserted else { continue }
                let key = "activity.sync.day." + binding.profileID
                if defaults.string(forKey: key) == today { continue }
                do {
                    let data = try await sender("profiles/\(binding.profileID)/activity", binding.token, Data("{}".utf8))
                    let reply = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard reply?["acknowledged"] as? Bool == true, reply?["scope"] as? String == "sync_profiles",
                          let serverDay = reply?["day"] as? String, serverDay.count == 10 else { continue }
                    defaults.set(serverDay, forKey: key)
                } catch { continue }
            }
        }
    }

    static func send(_ path: String, token: String?, body: Data?) async throws -> Data {
        let base = URL(string: "https://profile.meqrcode.cn/sync-v1/")!
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count <= 4096 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
