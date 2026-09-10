import Foundation
import UIKit

struct MeQRExchangeProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var version: Int
    var name: String
    var subtitle: String
    var intro: String
    var avatarJPEGBase64: String?
    var backgroundJPEGBase64: String?
    var bannerJPEGBase64: String?
    var textColorHex: String?
    var backgroundColorHex: String?
    var qrColorHex: String?
    var templateStyleRawValue: String?
    var profiles: [MeQRExchangePlatform]
    var sharedAt: Date

    init(cluster: QRCluster, profiles includedProfiles: [QRProfile]? = nil, avatarMaxBytes: Int = 640) {
        self.init(
            name: cluster.name,
            subtitle: cluster.subtitle,
            intro: cluster.subtitle,
            avatarImageData: cluster.avatarImageData,
            backgroundImageData: avatarMaxBytes > 0 ? cluster.backgroundImageData : nil,
            bannerImageData: avatarMaxBytes > 0 ? cluster.rhodesBannerImageData : nil,
            textColorHex: cluster.textColorHex,
            backgroundColorHex: cluster.backgroundColorHex,
            qrColorHex: cluster.qrColorHex,
            templateStyleRawValue: cluster.templateStyleRawValue,
            profiles: includedProfiles ?? cluster.profiles,
            maxProfiles: 3,
            avatarMaxBytes: avatarMaxBytes
        )
        id = cluster.id
    }

    init(offlineCluster cluster: QRCluster, profile includedProfile: QRProfile?) {
        self.init(
            name: cluster.name,
            subtitle: Self.offlineSubtitle(from: cluster.subtitle),
            intro: "",
            avatarImageData: nil,
            backgroundImageData: nil,
            bannerImageData: nil,
            textColorHex: cluster.textColorHex,
            backgroundColorHex: cluster.backgroundColorHex,
            qrColorHex: cluster.qrColorHex,
            templateStyleRawValue: cluster.templateStyleRawValue,
            profiles: includedProfile.map { [$0] } ?? Array(cluster.profiles.sorted { $0.createdAt < $1.createdAt }.prefix(1)),
            maxProfiles: 1,
            avatarMaxBytes: 0
        )
        id = cluster.id
    }

    private init(
        name: String,
        subtitle: String,
        intro: String,
        avatarImageData: Data?,
        backgroundImageData: Data?,
        bannerImageData: Data?,
        textColorHex: String?,
        backgroundColorHex: String?,
        qrColorHex: String?,
        templateStyleRawValue: String?,
        profiles sourceProfiles: [QRProfile],
        maxProfiles: Int,
        avatarMaxBytes: Int
    ) {
        id = UUID()
        version = 1
        self.name = name
        self.subtitle = subtitle
        self.intro = intro
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.qrColorHex = qrColorHex
        self.templateStyleRawValue = templateStyleRawValue
        avatarJPEGBase64 = Self.avatarBase64(from: avatarImageData, maxBytes: min(avatarMaxBytes, 180_000))
        bannerJPEGBase64 = Self.avatarBase64(from: bannerImageData, maxBytes: avatarMaxBytes > 0 ? 80_000 : 0)
        backgroundJPEGBase64 = Self.backgroundBase64(
            from: backgroundImageData,
            avatarJPEGBase64: avatarJPEGBase64,
            bannerJPEGBase64: bannerJPEGBase64
        )
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

    static func colorLayerAvatarJPEG(from data: Data?, maxBytes: Int) -> Data? {
        guard maxBytes > 0,
              let data,
              let image = UIImage(data: data),
              let jpeg = image.jpegDataForMeQRAvatar(targetMaxBytes: maxBytes),
              jpeg.count <= maxBytes else { return nil }
        return jpeg
    }

    private static func backgroundBase64(
        from data: Data?,
        avatarJPEGBase64: String?,
        bannerJPEGBase64: String?
    ) -> String? {
        guard let data else { return nil }
        // The cloud function rejects any profile JSON larger than ~900 KB (900 * 1024).
        // Reserve room for the avatar and the small JSON wrappers, then spend the rest on
        // the background at the highest quality that fits instead of a fixed 5 MB cap.
        let avatarBytes = avatarJPEGBase64?.utf8.count ?? 0
        let bannerBytes = bannerJPEGBase64?.utf8.count ?? 0
        let targetJSONBytes = 820_000
        let reservedBytes = 16_000
        let budget = max(48 * 1024, targetJSONBytes - avatarBytes - bannerBytes - reservedBytes)
        let maxRawBytes = budget * 3 / 4

        // Already small enough: upload the original bytes with no re-compression loss.
        if data.count <= maxRawBytes {
            return data.base64EncodedString()
        }
        guard let image = UIImage(data: data),
              let jpeg = image.jpegDataForMeQRBackground(targetMaxBytes: maxRawBytes) else { return nil }
        return jpeg.base64EncodedString()
    }

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case version = "v"
        case name = "n"
        case subtitle = "s"
        case intro = "u"
        case avatarJPEGBase64 = "a"
        case backgroundJPEGBase64 = "b"
        case bannerJPEGBase64 = "bn"
        case textColorHex = "tc"
        case backgroundColorHex = "bc"
        case qrColorHex = "qc"
        case templateStyleRawValue = "ts"
        case profiles = "p"
        case sharedAt = "t"

        case legacyID = "id"
        case legacyVersion = "version"
        case legacyName = "name"
        case legacySubtitle = "subtitle"
        case legacyIntro = "intro"
        case legacyAvatarJPEGBase64 = "avatarJPEGBase64"
        case legacyBackgroundJPEGBase64 = "backgroundJPEGBase64"
        case legacyBannerJPEGBase64 = "bannerJPEGBase64"
        case legacyTextColorHex = "textColorHex"
        case legacyBackgroundColorHex = "backgroundColorHex"
        case legacyQRColorHex = "qrColorHex"
        case legacyTemplateStyleRawValue = "templateStyleRawValue"
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
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
            ?? container.decodeIfPresent(String.self, forKey: .legacyIntro)
            ?? subtitle
        avatarJPEGBase64 = try container.decodeIfPresent(String.self, forKey: .avatarJPEGBase64)
            ?? container.decodeIfPresent(String.self, forKey: .legacyAvatarJPEGBase64)
        backgroundJPEGBase64 = try container.decodeIfPresent(String.self, forKey: .backgroundJPEGBase64)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBackgroundJPEGBase64)
        bannerJPEGBase64 = try container.decodeIfPresent(String.self, forKey: .bannerJPEGBase64)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBannerJPEGBase64)
        textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex)
            ?? container.decodeIfPresent(String.self, forKey: .legacyTextColorHex)
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBackgroundColorHex)
        qrColorHex = try container.decodeIfPresent(String.self, forKey: .qrColorHex)
            ?? container.decodeIfPresent(String.self, forKey: .legacyQRColorHex)
        templateStyleRawValue = try container.decodeIfPresent(String.self, forKey: .templateStyleRawValue)
            ?? container.decodeIfPresent(String.self, forKey: .legacyTemplateStyleRawValue)
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
        try container.encode(id, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(name, forKey: .name)
        if !subtitle.isEmpty {
            try container.encode(subtitle, forKey: .subtitle)
        }
        try container.encode(intro, forKey: .intro)
        if let avatarJPEGBase64 {
            try container.encode(avatarJPEGBase64, forKey: .avatarJPEGBase64)
        }
        if let backgroundJPEGBase64 {
            try container.encode(backgroundJPEGBase64, forKey: .backgroundJPEGBase64)
        }
        if let bannerJPEGBase64 {
            try container.encode(bannerJPEGBase64, forKey: .bannerJPEGBase64)
        }
        if let textColorHex {
            try container.encode(textColorHex, forKey: .textColorHex)
        }
        if let backgroundColorHex {
            try container.encode(backgroundColorHex, forKey: .backgroundColorHex)
        }
        if let qrColorHex {
            try container.encode(qrColorHex, forKey: .qrColorHex)
        }
        if let templateStyleRawValue {
            try container.encode(templateStyleRawValue, forKey: .templateStyleRawValue)
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
        let sideCandidates: [CGFloat]
        if targetMaxBytes >= 64 * 1024 {
            sideCandidates = [1024, 768, 512, 384, 256, 192, 160, 128, 112, 96, 80, 64, 56, 48, 40, 32, 28, 24, 20, 16]
        } else {
            sideCandidates = [256, 192, 160, 128, 112, 96, 80, 64, 56, 48, 40, 32, 28, 24, 20, 16]
        }
        let qualityCandidates: [CGFloat] = [0.84, 0.74, 0.64, 0.54, 0.44, 0.34, 0.24, 0.16, 0.1]
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

    func jpegDataForMeQRBackground(targetMaxBytes: Int) -> Data? {
        // Favor resolution over heavy quality loss so the background stays legible:
        // walk down large side lengths first, and at each size drop quality only as far
        // as 0.55 before shrinking further.
        let sideCandidates: [CGFloat] = [2048, 1536, 1280, 1080, 900, 768, 640, 540, 480, 420, 360, 320]
        let qualityCandidates: [CGFloat] = [0.85, 0.78, 0.70, 0.62, 0.55]
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
}
