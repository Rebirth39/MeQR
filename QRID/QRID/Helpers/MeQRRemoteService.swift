import Foundation

enum MeQRRemoteService {
    private static let apiBaseURL = URL(string: "https://meqr-api-bovpnioqev.cn-shanghai.fcapp.run")!

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
