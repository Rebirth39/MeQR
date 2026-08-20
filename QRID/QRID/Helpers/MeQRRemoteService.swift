import Foundation

enum MeQRRemoteService {
    private static let apiBaseURL = URL(string: "https://api.meqrcode.cn")!

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

    static func canFetchProfile(from string: String) -> Bool {
        guard let url = URL(string: string),
              let baseHost = apiBaseURL.host(),
              url.scheme?.hasPrefix("http") == true,
              url.host() == baseHost else {
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
        guard let url = URL(string: string),
              let baseHost = apiBaseURL.host(),
              url.scheme?.hasPrefix("http") == true,
              url.host() == baseHost else {
            return false
        }
        return url.path().hasPrefix("/encounter-sessions/")
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

    static func fetchEncounterSession(from string: String) async throws -> MeQREncounterSession {
        guard let url = URL(string: string), canFetchEncounterSession(from: string) else {
            throw MeQRRemoteServiceError.unsupportedURL
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case creatorProfile
        case peerProfile
        case eventID = "eventId"
        case status
    }
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
