import Foundation
import Combine

struct Announcement: Codable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let url: URL
    let publishedAt: String
}

@MainActor
final class AnnouncementManager: ObservableObject {
    @Published private(set) var latest: Announcement?
    @Published private(set) var history: [Announcement] = []
    private let readKey = "meqr.readAnnouncementID"
    func refresh() {
        guard let url = URL(string: "https://meqrcode.cn/announcements/feed.json") else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let wrapper = try? JSONDecoder().decode(Feed.self, from: data),
                  !wrapper.announcements.isEmpty else { return }
            history = wrapper.announcements
            guard wrapper.latest.id != UserDefaults.standard.string(forKey: readKey) else { return }
            latest = wrapper.latest
        }
    }
    func markRead() { if let id = latest?.id { UserDefaults.standard.set(id, forKey: readKey); latest = nil } }
    private struct Feed: Codable { let latest: Announcement; let announcements: [Announcement] }
}
