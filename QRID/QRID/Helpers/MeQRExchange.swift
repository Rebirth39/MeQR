import Foundation
import UIKit

struct MeQRExchangeProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var version: Int
    var name: String
    var subtitle: String
    var avatarJPEGBase64: String?
    var backgroundJPEGBase64: String?
    var profiles: [MeQRExchangePlatform]
    var sharedAt: Date

    init(cluster: QRCluster, profiles includedProfiles: [QRProfile]? = nil, avatarMaxBytes: Int = 640) {
        self.init(
            name: cluster.name,
            subtitle: cluster.subtitle,
            avatarImageData: cluster.avatarImageData,
            profiles: includedProfiles ?? cluster.profiles,
            maxProfiles: 3,
            avatarMaxBytes: avatarMaxBytes
        )
    }

    init(offlineCluster cluster: QRCluster, profile includedProfile: QRProfile?) {
        self.init(
            name: cluster.name,
            subtitle: Self.offlineSubtitle(from: cluster.subtitle),
            avatarImageData: nil,
            profiles: includedProfile.map { [$0] } ?? Array(cluster.profiles.sorted { $0.createdAt < $1.createdAt }.prefix(1)),
            maxProfiles: 1,
            avatarMaxBytes: 0
        )
    }

    private init(
        name: String,
        subtitle: String,
        avatarImageData: Data?,
        profiles sourceProfiles: [QRProfile],
        maxProfiles: Int,
        avatarMaxBytes: Int
    ) {
        id = UUID()
        version = 1
        self.name = name
        self.subtitle = subtitle
        avatarJPEGBase64 = Self.avatarBase64(from: avatarImageData, maxBytes: avatarMaxBytes)
        backgroundJPEGBase64 = nil
        profiles = sourceProfiles
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(maxProfiles)
            .map { profile in
                MeQRExchangePlatform(
                    platformType: profile.platformType,
                    platformName: profile.platformDisplayName,
                    qrContent: profile.qrContent
                )
            }
        sharedAt = Date()
    }

    private static func offlineSubtitle(from value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let firstTwoLines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(2)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(firstTwoLines.prefix(25))
    }

    private static func avatarBase64(from data: Data?, maxBytes: Int) -> String? {
        guard maxBytes > 0 else { return nil }
        guard let data,
              let image = UIImage(data: data),
              let jpeg = image.jpegDataForMeQRAvatar(targetMaxBytes: maxBytes) else {
            return nil
        }
        return jpeg.base64EncodedString()
    }

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case version = "v"
        case name = "n"
        case subtitle = "s"
        case avatarJPEGBase64 = "a"
        case backgroundJPEGBase64 = "b"
        case profiles = "p"
        case sharedAt = "t"

        case legacyID = "id"
        case legacyVersion = "version"
        case legacyName = "name"
        case legacySubtitle = "subtitle"
        case legacyAvatarJPEGBase64 = "avatarJPEGBase64"
        case legacyBackgroundJPEGBase64 = "backgroundJPEGBase64"
        case legacyProfiles = "profiles"
        case legacySharedAt = "sharedAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
            ?? container.decodeIfPresent(UUID.self, forKey: .legacyID)
            ?? UUID()
        version = try container.decodeIfPresent(Int.self, forKey: .version)
            ?? container.decodeIfPresent(Int.self, forKey: .legacyVersion)
            ?? 1
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .legacyName)
            ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? container.decodeIfPresent(String.self, forKey: .legacySubtitle)
            ?? ""
        avatarJPEGBase64 = try container.decodeIfPresent(String.self, forKey: .avatarJPEGBase64)
            ?? container.decodeIfPresent(String.self, forKey: .legacyAvatarJPEGBase64)
        backgroundJPEGBase64 = try container.decodeIfPresent(String.self, forKey: .backgroundJPEGBase64)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBackgroundJPEGBase64)
        profiles = try container.decodeIfPresent([MeQRExchangePlatform].self, forKey: .profiles)
            ?? container.decodeIfPresent([MeQRExchangePlatform].self, forKey: .legacyProfiles)
            ?? []
        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .sharedAt) {
            sharedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            sharedAt = try container.decodeIfPresent(Date.self, forKey: .legacySharedAt)
                ?? Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(name, forKey: .name)
        if !subtitle.isEmpty {
            try container.encode(subtitle, forKey: .subtitle)
        }
        if let avatarJPEGBase64 {
            try container.encode(avatarJPEGBase64, forKey: .avatarJPEGBase64)
        }
        if let backgroundJPEGBase64 {
            try container.encode(backgroundJPEGBase64, forKey: .backgroundJPEGBase64)
        }
        try container.encode(profiles, forKey: .profiles)
        try container.encode(Int(sharedAt.timeIntervalSince1970), forKey: .sharedAt)
    }
}

struct MeQRExchangePlatform: Codable, Identifiable, Hashable {
    var id: UUID
    var platformType: String
    var platformName: String
    var qrContent: String

    init(id: UUID = UUID(), platformType: String, platformName: String, qrContent: String) {
        self.id = id
        self.platformType = platformType
        self.platformName = platformName
        self.qrContent = qrContent
    }

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case platformType = "t"
        case platformName = "n"
        case qrContent = "q"

        case legacyID = "id"
        case legacyPlatformType = "platformType"
        case legacyPlatformName = "platformName"
        case legacyQRContent = "qrContent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
            ?? container.decodeIfPresent(UUID.self, forKey: .legacyID)
            ?? UUID()
        platformType = try container.decodeIfPresent(String.self, forKey: .platformType)
            ?? container.decodeIfPresent(String.self, forKey: .legacyPlatformType)
            ?? "custom"
        platformName = try container.decodeIfPresent(String.self, forKey: .platformName)
            ?? container.decodeIfPresent(String.self, forKey: .legacyPlatformName)
            ?? L.custom
        qrContent = try container.decodeIfPresent(String.self, forKey: .qrContent)
            ?? container.decodeIfPresent(String.self, forKey: .legacyQRContent)
            ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(platformType, forKey: .platformType)
        try container.encode(platformName, forKey: .platformName)
        try container.encode(qrContent, forKey: .qrContent)
    }
}

enum MeQRExchangeCodec {
    static let scheme = "meqr"
    static let host = "profile"
    static let offlineFragmentPrefix = "offline="

    static func encode(_ profile: MeQRExchangeProfile) throws -> String {
        let data = try JSONEncoder.meqr.encode(profile)
        let payload = data.base64URLEncodedString()
        return "\(scheme)://\(host)?data=\(payload)"
    }

    static func encodePayload(_ profile: MeQRExchangeProfile) throws -> String {
        let data = try JSONEncoder.meqr.encode(profile)
        return data.base64URLEncodedString()
    }

    static func encodeHybrid(remoteURL: String, offlineProfile: MeQRExchangeProfile) throws -> String {
        let payload = try encodePayload(offlineProfile)
        if var components = URLComponents(string: remoteURL) {
            components.fragment = "\(offlineFragmentPrefix)\(payload)"
            if let url = components.string {
                return url
            }
        }
        return "\(remoteURL)#\(offlineFragmentPrefix)\(payload)"
    }

    static func decodePayload(_ payload: String) throws -> MeQRExchangeProfile {
        guard let data = Data(base64URLEncoded: payload) else {
            throw MeQRExchangeError.invalidCode
        }
        return try JSONDecoder.meqr.decode(MeQRExchangeProfile.self, from: data)
    }

    static func offlineFallback(from string: String) -> MeQRExchangeProfile? {
        guard let fragment = URLComponents(string: string)?.fragment else { return nil }
        let payload: String
        if fragment.hasPrefix(offlineFragmentPrefix) {
            payload = String(fragment.dropFirst(offlineFragmentPrefix.count))
        } else {
            payload = fragment
        }
        return try? decodePayload(payload)
    }

    static func decode(_ string: String) throws -> MeQRExchangeProfile {
        guard let components = URLComponents(string: string),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == host,
              let payload = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = Data(base64URLEncoded: payload) else {
            throw MeQRExchangeError.invalidCode
        }
        return try JSONDecoder.meqr.decode(MeQRExchangeProfile.self, from: data)
    }

    static func canDecode(_ string: String) -> Bool {
        (try? decode(string)) != nil
    }
}

enum MeQRExchangeError: Error, LocalizedError {
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return L.notMeQRProfileCode
        }
    }
}

private extension JSONEncoder {
    static var meqr: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var meqr: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}

private extension UIImage {
    func jpegDataForMeQRAvatar(targetMaxBytes: Int) -> Data? {
        let sideCandidates: [CGFloat] = [56, 48, 40, 32, 28, 24]
        let qualityCandidates: [CGFloat] = [0.5, 0.38, 0.28, 0.2, 0.14, 0.1]
        var smallestJPEG: Data?

        for maxSide in sideCandidates {
            guard let resized = resizedForMeQRAvatar(maxSide: maxSide) else { continue }
            for quality in qualityCandidates {
                guard let jpeg = resized.jpegData(compressionQuality: quality) else { continue }
                if smallestJPEG == nil || jpeg.count < smallestJPEG!.count {
                    smallestJPEG = jpeg
                }
                if jpeg.count <= targetMaxBytes {
                    return jpeg
                }
            }
        }

        return smallestJPEG
    }

    func resizedForMeQRAvatar(maxSide: CGFloat) -> UIImage? {
        let scale = min(maxSide / max(size.width, size.height), 1)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
