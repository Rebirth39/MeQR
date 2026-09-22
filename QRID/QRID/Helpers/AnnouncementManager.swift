import Foundation
import Combine

struct Announcement: Codable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let url: URL
    let publishedAt: String
    let titleByLanguage: [String: String]?
    let summaryByLanguage: [String: String]?

    var localizedTitle: String {
        let key = Announcement.languageKey
        return titleByLanguage?[key] ?? title
    }

    var localizedSummary: String {
        let key = Announcement.languageKey
        return summaryByLanguage?[key] ?? summary
    }

    private static var languageKey: String {
        switch AppSettings.shared.resolvedLanguage {
        case .en: return "en"
        case .ja: return "ja"
        case .zhHans, .zhHantHK, .zhHantTW, .system: return "zh"
        }
    }
}

@MainActor
final class AnnouncementManager: ObservableObject {
    @Published private(set) var latest: Announcement?
    @Published private(set) var history: [Announcement] = []
    private let readKey = "meqr.readAnnouncementID"
    private var lastRefresh: Date?
    func refresh() {
        refresh(force: false)
    }
    func refresh(force: Bool) {
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        lastRefresh = Date()
        guard let url = URL(string: "https://meqrcode.cn/announcements/feed.json") else { return }
        Task {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                request.timeoutInterval = 12
                let (data, _) = try await URLSession.shared.data(for: request)
                let wrapper = try JSONDecoder().decode(Feed.self, from: data)
                history = wrapper.announcements
                guard wrapper.latest.id != UserDefaults.standard.string(forKey: readKey) else { return }
                latest = wrapper.latest
            } catch { }
        }
    }
    func markRead() { if let id = latest?.id { UserDefaults.standard.set(id, forKey: readKey); latest = nil } }
    private struct Feed: Codable { let latest: Announcement; let announcements: [Announcement] }
}
