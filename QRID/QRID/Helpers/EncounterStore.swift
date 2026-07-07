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

    init(exchangeProfile: MeQRExchangeProfile) {
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

    func add(_ exchangeProfile: MeQRExchangeProfile) {
        records.insert(EncounterRecord(exchangeProfile: exchangeProfile), at: 0)
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
