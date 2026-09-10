import Foundation

enum MeQRRemoteService {
    private static let apiBaseURL = URL(string: "https://api.meqrcode.cn")!
    private static let meqrHosts: Set<String> = ["api.meqrcode.cn", "profile.meqrcode.cn"]

    static func uploadProfile(_ profile: MeQRExchangeProfile) async throws -> String {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("profiles"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(ProfileUploadRequest(profile: profile))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let uploadResponse = try JSONDecoder().decode(ProfileUploadResponse.self, from: data)
        guard !uploadResponse.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeQRRemoteServiceError.missingURL
        }
        return uploadResponse.url
    }

    static func publishExchangeCode(_ record: MeQRExchangeCodeRecord) async throws {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("encounter-sessions/\(record.sessionID)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(record.ownerToken, forHTTPHeaderField: "X-MeQR-Owner")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EncounterSessionCreationRequest(creatorProfile: record.onlineProfile, eventID: record.eventID?.uuidString))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    static func canFetchProfile(from string: String) -> Bool {
        guard let url = URL(string: string),
              url.scheme?.hasPrefix("http") == true,
              meqrHosts.contains(url.host() ?? "") else {
            return false
        }
        return url.path().hasPrefix("/profiles/")
    }

    static func fetchProfile(from string: String) async throws -> MeQRExchangeProfile {
        guard let url = URL(string: string), canFetchProfile(from: string) else {
            throw MeQRRemoteServiceError.unsupportedURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MeQRExchangeProfile.self, from: data)
    }

    static func canFetchEncounterSession(from string: String) -> Bool {
        encounterSessionID(from: string) != nil
    }

    static func encounterSessionID(from string: String) -> String? {
        guard let url = URL(string: string),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              meqrHosts.contains(url.host()?.lowercased() ?? "") else { return nil }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[1] == "encounter-sessions" else { return nil }
        let id = String(parts[2])
        guard !id.isEmpty, id.utf8.count <= 128,
              id.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        return id
    }

    static func createEncounterSession(creatorProfile: MeQRExchangeProfile, eventID: UUID?) async throws -> MeQREncounterSessionCreation {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("encounter-sessions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(EncounterSessionCreationRequest(
            creatorProfile: creatorProfile,
            eventID: eventID?.uuidString
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MeQREncounterSessionCreation.self, from: data)
    }

    static func fetchEncounterSession(from string: String, ownerToken: String? = nil) async throws -> MeQREncounterSession {
        guard let url = URL(string: string), canFetchEncounterSession(from: string) else {
            throw MeQRRemoteServiceError.unsupportedURL
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let ownerToken {
            request.setValue(ownerToken, forHTTPHeaderField: "X-MeQR-Owner")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MeQREncounterSession.self, from: data)
    }

    static func confirmEncounterSession(sessionID: String, peerProfile: MeQRExchangeProfile) async throws {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("encounter-sessions/\(sessionID)/confirm"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(EncounterSessionConfirmationRequest(peerProfile: peerProfile))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               let error = errorResponse.error,
               !error.isEmpty {
                throw MeQRRemoteServiceError.server(error)
            }
            throw MeQRRemoteServiceError.httpStatus(httpResponse.statusCode)
        }
    }
}

struct MeQREncounterSessionCreation: Decodable {
    let sessionID: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case url
    }
}

struct MeQREncounterSession: Decodable {
    let sessionID: String
    let creatorProfile: MeQRExchangeProfile?
    let peerProfile: MeQRExchangeProfile?
    let eventID: String?
    let status: String
    let reusable: Bool?
    let confirmations: [MeQREncounterConfirmation]?

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case creatorProfile
        case peerProfile
        case eventID = "eventId"
        case status
        case reusable
        case confirmations
    }
}

struct MeQREncounterConfirmation: Decodable {
    let id: String
    let profile: MeQRExchangeProfile
    let confirmedAt: Double
}

private struct EncounterSessionCreationRequest: Encodable {
    let creatorProfile: MeQRExchangeProfile
    let eventID: String?

    enum CodingKeys: String, CodingKey {
        case creatorProfile
        case eventID = "eventId"
    }
}

private struct EncounterSessionConfirmationRequest: Encodable {
    let peerProfile: MeQRExchangeProfile
}

private struct ProfileUploadRequest: Encodable {
    let profile: MeQRExchangeProfile
}

private struct ProfileUploadResponse: Decodable {
    let url: String
}

private struct ErrorResponse: Decodable {
    let error: String?
}

enum MeQRRemoteServiceError: LocalizedError {
    case httpStatus(Int)
    case missingURL
    case server(String)
    case unsupportedURL

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "HTTP \(status)"
        case .missingURL:
            return L.tryAgain
        case .server(let message):
            return message
        case .unsupportedURL:
            return L.notMeQRProfileCode
        }
    }
}
