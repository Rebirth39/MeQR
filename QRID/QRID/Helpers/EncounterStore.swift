import Foundation
import Combine

struct EncounterRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var sessionID: String?
    var name: String
    var subtitle: String
    var avatarJPEGBase64: String?
    var backgroundJPEGBase64: String?
    var profiles: [MeQRExchangePlatform]
    var metAt: Date
    var sourceSharedAt: Date
    var note: String
    var tags: [String]
    var eventID: UUID?
    var eventTitle: String?
    var eventVenue: String?
    var needsPhotoReturn: Bool?
    var exchangedFreebie: Bool?
    var followStatus: String?

    init(exchangeProfile: MeQRExchangeProfile, event: MeQREvent? = nil, sessionID: String? = nil) {
        id = UUID()
        self.sessionID = sessionID
        name = exchangeProfile.name
        subtitle = exchangeProfile.subtitle
        avatarJPEGBase64 = exchangeProfile.avatarJPEGBase64
        backgroundJPEGBase64 = exchangeProfile.backgroundJPEGBase64
        profiles = exchangeProfile.profiles
        metAt = Date()
        sourceSharedAt = exchangeProfile.sharedAt
        note = ""
        tags = []
        eventID = event?.id
        eventTitle = event?.title
        eventVenue = event?.venue
        needsPhotoReturn = false
        exchangedFreebie = false
        followStatus = nil
    }
}

private struct PendingEncounterSession: Codable, Identifiable {
    let id: String
    let createdAt: Date
}

struct MeQREvent: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var venue: String
    var address: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var latitude: Double?
    var longitude: Double?
    var sourceURL: URL?
    var isCustom: Bool

    var dateSummary: String {
        if let endDate, !Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var navigationQuery: String {
        [venue, address].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " ")
    }
}

@MainActor
final class EncounterStore: ObservableObject {
    static let shared = EncounterStore()

    @Published private(set) var records: [EncounterRecord] = []
    @Published private(set) var pendingSessionCount = 0

    private let storageKey = "meqr_encounter_records_v1"
    private let pendingStorageKey = "meqr_encounter_pending_sessions_v1"
    private var pendingSessions: [PendingEncounterSession] = []

    private init() {
        load()
    }

    func add(_ exchangeProfile: MeQRExchangeProfile, event: MeQREvent? = nil, sessionID: String? = nil) {
        if let sessionID, records.contains(where: { $0.sessionID == sessionID }) {
            return
        }
        records.insert(EncounterRecord(exchangeProfile: exchangeProfile, event: event ?? EventStore.shared.activeEvent, sessionID: sessionID), at: 0)
        save()
    }

    func registerOutgoingSession(_ sessionID: String) {
        guard !sessionID.isEmpty, !pendingSessions.contains(where: { $0.id == sessionID }) else { return }
        pendingSessions.insert(PendingEncounterSession(id: sessionID, createdAt: Date()), at: 0)
        pendingSessionCount = pendingSessions.count
        savePendingSessions()
    }

    func syncPendingSessions() async {
        guard !pendingSessions.isEmpty else { return }
        var remaining: [PendingEncounterSession] = []
        for pending in pendingSessions {
            do {
                let session = try await MeQRRemoteService.fetchEncounterSession(
                    from: "https://api.meqrcode.cn/encounter-sessions/\(pending.id)"
                )
                if session.status == "confirmed", let peerProfile = session.peerProfile {
                    add(peerProfile, event: EventStore.shared.activeEvent, sessionID: pending.id)
                } else {
                    remaining.append(pending)
                }
            } catch {
                remaining.append(pending)
            }
        }
        pendingSessions = remaining
        pendingSessionCount = remaining.count
        savePendingSessions()
    }

    func update(_ record: EncounterRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        sortRecords()
        save()
    }

    func delete(_ record: EncounterRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder.meqrEncounter.decode([EncounterRecord].self, from: data) {
            records = decoded.sorted { $0.metAt > $1.metAt }
        } else {
            records = []
        }
        if let data = UserDefaults.standard.data(forKey: pendingStorageKey),
           let decodedPending = try? JSONDecoder.meqrEncounter.decode([PendingEncounterSession].self, from: data) {
            pendingSessions = decodedPending
            pendingSessionCount = decodedPending.count
        }
    }

    private func save() {
        guard let data = try? JSONEncoder.meqrEncounter.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func savePendingSessions() {
        guard let data = try? JSONEncoder.meqrEncounter.encode(pendingSessions) else { return }
        UserDefaults.standard.set(data, forKey: pendingStorageKey)
    }

    private func sortRecords() {
        records.sort { $0.metAt > $1.metAt }
    }
}

@MainActor
final class EventStore: ObservableObject {
    static let shared = EventStore()

    @Published private(set) var events: [MeQREvent] = []
    @Published var activeEventID: UUID? {
        didSet {
            UserDefaults.standard.set(activeEventID?.uuidString, forKey: activeEventStorageKey)
        }
    }
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshError: String?

    private let storageKey = "meqr_events_v1"
    private let activeEventStorageKey = "meqr_active_event_id_v1"
    private let remoteEventsURL = URL(string: "https://api.meqrcode.cn/events")

    var activeEvent: MeQREvent? {
        guard let activeEventID else { return nil }
        return events.first { $0.id == activeEventID }
    }

    private init() {
        activeEventID = UserDefaults.standard.string(forKey: activeEventStorageKey).flatMap(UUID.init(uuidString:))
        load()
    }

    func refreshRemoteEvents() async {
        guard let remoteEventsURL else { return }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: remoteEventsURL, timeoutInterval: 15)
            request.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder.meqrEvents.decode([MeQREvent].self, from: data)
            mergeRemoteEvents(decoded)
            save()
        } catch {
            refreshError = error.localizedDescription
            if events.isEmpty {
                events = Self.defaultEvents
            }
        }
    }

    func addCustomEvent(title: String, venue: String, address: String, date: Date, details: String) {
        let event = MeQREvent(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: date,
            endDate: nil,
            latitude: nil,
            longitude: nil,
            sourceURL: nil,
            isCustom: true
        )
        events.insert(event, at: 0)
        activeEventID = event.id
        save()
    }

    func setActiveEvent(_ event: MeQREvent?) {
        activeEventID = event?.id
    }

    func deleteCustomEvent(_ event: MeQREvent) {
        guard event.isCustom else { return }
        events.removeAll { $0.id == event.id }
        if activeEventID == event.id {
            activeEventID = nil
        }
        save()
    }

    private func mergeRemoteEvents(_ remoteEvents: [MeQREvent]) {
        let customEvents = events.filter(\.isCustom)
        let remoteIDs = Set(remoteEvents.map(\.id))
        let keptCustomEvents = customEvents.filter { !remoteIDs.contains($0.id) }
        events = (keptCustomEvents + remoteEvents).sorted { lhs, rhs in
            if lhs.isCustom != rhs.isCustom { return lhs.isCustom && !rhs.isCustom }
            return lhs.startDate < rhs.startDate
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder.meqrEvents.decode([MeQREvent].self, from: data) else {
            events = Self.defaultEvents
            return
        }
        events = decoded
        if let activeEventID, !events.contains(where: { $0.id == activeEventID }) {
            self.activeEventID = nil
        }
    }

    private func save() {
        guard let data = try? JSONEncoder.meqrEvents.encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static var defaultEvents: [MeQREvent] {
        [
            MeQREvent(
                id: UUID(uuidString: "26F92A33-1F9E-45A4-83F8-59B9170D0726") ?? UUID(),
                title: "自定义线下扩列",
                venue: "现场",
                address: "",
                details: "服务器展会列表还没配置时，可以先用这个活动归档认识记录。",
                startDate: Date(),
                endDate: nil,
                latitude: nil,
                longitude: nil,
                sourceURL: nil,
                isCustom: false
            )
        ]
    }
}

private extension JSONEncoder {
    static var meqrEvents: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var meqrEvents: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var meqrEncounter: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var meqrEncounter: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
