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
    var pendingConfirmationProfile: MeQRExchangeProfile?
    var confirmationSentAt: Date?

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
    var ownerToken: String? = nil
    var receivedIDs: Set<String>? = nil
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
    @Published private(set) var isConfirming = false

    var pendingConfirmationCount: Int { records.filter { $0.pendingConfirmationProfile != nil }.count }

    private let storageKey = "meqr_encounter_records_v1"
    private let pendingStorageKey = "meqr_encounter_pending_sessions_v1"
    private var pendingSessions: [PendingEncounterSession] = []
    private var isSyncing = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func saveScannedProfile(_ profile: MeQRExchangeProfile, event: MeQREvent? = nil,
                            sessionID: String?, peerProfile: MeQRExchangeProfile?) {
        if let sessionID, let index = records.firstIndex(where: { $0.sessionID == sessionID }) {
            if records[index].confirmationSentAt == nil && records[index].pendingConfirmationProfile == nil {
                records[index].pendingConfirmationProfile = peerProfile
            }
        } else {
            var record = EncounterRecord(exchangeProfile: profile, event: event, sessionID: sessionID)
            if sessionID != nil { record.pendingConfirmationProfile = peerProfile }
            records.insert(record, at: 0)
        }
        // Persist the approved reply and the encounter together before attempting delivery.
        save()
    }

    func syncConfirmations() async {
        guard !isConfirming else { return }
        isConfirming = true
        defer { isConfirming = false }
        for record in records {
            guard !Task.isCancelled else { return }
            guard let profile = record.pendingConfirmationProfile, let sessionID = record.sessionID,
                  records.contains(where: { $0.id == record.id }) else { continue }
            do {
                try await MeQRRemoteService.confirmEncounterSession(sessionID: sessionID, peerProfile: profile)
                if let index = records.firstIndex(where: { $0.id == record.id }) {
                    records[index].pendingConfirmationProfile = nil
                    records[index].confirmationSentAt = Date()
                    save()
                }
            } catch {
                // Keep the original approved snapshot for foreground/refresh retries.
            }
        }
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

    func registerOutgoingSession(_ sessionID: String, ownerToken: String) {
        if let index = pendingSessions.firstIndex(where: { $0.id == sessionID }) {
            guard pendingSessions[index].ownerToken != ownerToken else { return }
            pendingSessions[index].ownerToken = ownerToken
        } else {
            pendingSessions.insert(PendingEncounterSession(id: sessionID, createdAt: Date(), ownerToken: ownerToken), at: 0)
        }
        pendingSessionCount = pendingSessions.count
        savePendingSessions()
    }

    func syncPendingSessions() async {
        await syncConfirmations()
        guard !pendingSessions.isEmpty, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        for pending in pendingSessions {
            do {
                let session = try await MeQRRemoteService.fetchEncounterSession(
                    from: "https://api.meqrcode.cn/encounter-sessions/\(pending.id)", ownerToken: pending.ownerToken
                )
                let eventID = session.eventID.flatMap(UUID.init(uuidString:))
                let event = EventStore.shared.events.first { $0.id == eventID }
                if session.reusable == true, let index = pendingSessions.firstIndex(where: { $0.id == pending.id }) {
                    var received = pendingSessions[index].receivedIDs ?? []
                    for confirmation in session.confirmations ?? [] where !received.contains(confirmation.id) {
                        add(confirmation.profile, event: nil, sessionID: pending.id + ":" + confirmation.id)
                        if let recordIndex = records.firstIndex(where: { $0.sessionID == pending.id + ":" + confirmation.id }) {
                            records[recordIndex].metAt = Date(timeIntervalSince1970: confirmation.confirmedAt / 1000)
                            records[recordIndex].eventID = eventID
                            records[recordIndex].eventTitle = event?.title
                            records[recordIndex].eventVenue = event?.venue
                        }
                        received.insert(confirmation.id)
                    }
                    sortRecords()
                    save()
                    pendingSessions[index].receivedIDs = received
                } else if session.status == "confirmed", let peerProfile = session.peerProfile {
                    if !records.contains(where: { $0.sessionID == pending.id }) {
                        var record = EncounterRecord(exchangeProfile: peerProfile, event: event, sessionID: pending.id)
                        record.eventID = eventID
                        records.insert(record, at: 0)
                        save()
                    }
                    pendingSessions.removeAll { $0.id == pending.id }
                }
            } catch {}
        }
        pendingSessionCount = pendingSessions.count
        savePendingSessions()
    }

    func update(_ record: EncounterRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        var updated = record
        updated.pendingConfirmationProfile = records[index].pendingConfirmationProfile
        updated.confirmationSentAt = records[index].confirmationSentAt
        records[index] = updated
        sortRecords()
        save()
    }

    func delete(_ record: EncounterRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    private func load() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder.meqrEncounter.decode([EncounterRecord].self, from: data) {
            records = decoded.sorted { $0.metAt > $1.metAt }
        } else {
            records = []
        }
        if let data = defaults.data(forKey: pendingStorageKey),
           let decodedPending = try? JSONDecoder.meqrEncounter.decode([PendingEncounterSession].self, from: data) {
            pendingSessions = decodedPending
            pendingSessionCount = decodedPending.count
        }
    }

    private func save() {
        guard let data = try? JSONEncoder.meqrEncounter.encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func savePendingSessions() {
        guard let data = try? JSONEncoder.meqrEncounter.encode(pendingSessions) else { return }
        defaults.set(data, forKey: pendingStorageKey)
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
