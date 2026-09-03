import Foundation

struct MeQREventCertificate: Codable, Sendable {
    let version: Int
    let eventID: String
    let channelID: String
    let eventName: String
    let publicKey: String
    let validFrom: Date
    let validUntil: Date
    let signature: String
}

struct MeQREventCheckInChallenge: Codable, Sendable {
    let eventID: String
    let challenge: String
    let issuedAt: Date
    let expiresAt: Date
    let signature: String
}

struct MeQREventNotification: Codable, Identifiable, Sendable {
    let id: String
    let eventID: String
    let title: String
    let body: String
    let publishedAt: Date
    let expiresAt: Date?
    let hop: Int
    let signature: String
}

enum MeQREventNotificationProtocol {
    static let protocolVersion = 1
    static let maxHopCount = 8
    static let maxNotificationBytes = 64 * 1024
    static func verifyCertificate(_ certificate: MeQREventCertificate) -> Bool { false }
    static func verifyCheckIn(_ challenge: MeQREventCheckInChallenge, certificate: MeQREventCertificate) -> Bool { false }
    static func verifyNotification(_ notification: MeQREventNotification, certificate: MeQREventCertificate) -> Bool { false }
}
