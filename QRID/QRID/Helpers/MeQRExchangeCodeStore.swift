import Foundation
import CryptoKit

struct MeQRExchangeCodeRecord: Codable {
    let fingerprint: String
    let payload: String
    let avatarJPEG: Data?
    let sessionID: String
    let ownerToken: String
    let onlineProfile: MeQRExchangeProfile
    let eventID: UUID?
    var synced: Bool

    static func credentials() -> (sessionID: String, ownerToken: String) {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return ("v2-" + digest(Data(token.utf8)), token)
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct MeQRExchangeCodeStore {
    var directory: URL = URL.applicationSupportDirectory.appendingPathComponent("ExchangeCodes", isDirectory: true)

    func load(clusterID: UUID, fingerprint: String) -> MeQRExchangeCodeRecord? {
        guard let data = try? Data(contentsOf: file(clusterID)),
              let record = try? JSONDecoder().decode(MeQRExchangeCodeRecord.self, from: data),
              record.fingerprint == fingerprint,
              record.sessionID == "v2-" + MeQRExchangeCodeRecord.digest(Data(record.ownerToken.utf8)),
              MeQRExchangeCodec.offlineFallback(from: record.payload) != nil else { return nil }
        return record
    }

    func save(_ record: MeQRExchangeCodeRecord, clusterID: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: file(clusterID), options: .atomic)
    }

    func markSynced(_ record: MeQRExchangeCodeRecord, clusterID: UUID) throws {
        guard var current = load(clusterID: clusterID, fingerprint: record.fingerprint),
              current.sessionID == record.sessionID else { return }
        current.synced = true
        try save(current, clusterID: clusterID)
    }

    private func file(_ clusterID: UUID) -> URL {
        directory.appendingPathComponent(clusterID.uuidString + ".json")
    }
}
