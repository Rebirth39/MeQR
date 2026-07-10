import Foundation
import Combine

struct EncounterRecord: Codable, Identifiable, Hashable {
    var id: UUID
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

    init(exchangeProfile: MeQRExchangeProfile, event: MeQREvent? = nil) {
        id = UUID()
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

    private let storageKey = "meqr_encounter_records_v1"

    private init() {
        load()
    }

    func add(_ exchangeProfile: MeQRExchangeProfile, event: MeQREvent? = nil) {
        records.insert(EncounterRecord(exchangeProfile: exchangeProfile, event: event ?? EventStore.shared.activeEvent), at: 0)
        save()
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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder.meqrEncounter.decode([EncounterRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.metAt > $1.metAt }
    }

    private func save() {
        guard let data = try? JSONEncoder.meqrEncounter.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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

    var activeEvent: MeQREvent? {
        guard let activeEventID else { return nil }
        return events.first { $0.id == activeEventID }
    }

    private init() {
        activeEventID = UserDefaults.standard.string(forKey: activeEventStorageKey).flatMap(UUID.init(uuidString:))
        load()
    }

    func refreshRemoteEvents() async {
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        if events.isEmpty {
            events = Self.defaultEvents
            save()
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
