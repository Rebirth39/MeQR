import Foundation
import SwiftData
import SwiftUI
import CryptoKit
import Security

struct SyncDocument: Codable, Equatable {
    var schemaVersion = 1
    var name: String
    var subtitle: String
    var passSubtitle: String
    var template: String
    var backgroundColor: String
    var borderColor: String
    var textColor: String
    var qrColor: String
    var cornerRadius: Double
    var cardOpacity: Double
    var qrItems: [Item]
    var tags: [Tag]
    var assets: [String: String]
    struct Item: Codable, Equatable {
        var platform: String
        var customPlatformName: String
        var qrContent: String
    }
    struct Tag: Codable, Equatable {
        var name: String
        var catalogID: String
        var mode: String
        var colors: [String]
        var presetColors: [String]
        var solidColor: String
        var weight: Int
    }
}
struct SyncSnapshot: Codable {
    var profileId: String
    var revision: Int
    var document: SyncDocument
    var deviceId: String?
    var role: String?
}
struct SyncBinding: Codable {
    var profileId: String
    var deviceId: String
    var token: String
    var role: String
    var revision: Int
    var baseline: SyncDocument?
}
struct SyncDeviceList: Decodable {
    struct Device: Decodable, Identifiable { var id: String; var name: String; var role: String? }
    var devices: [Device]
    var pending: [Device]
}
struct SyncFailure: LocalizedError {
    var code: Int
    var message: String
    var errorDescription: String? { message }
}

@MainActor
enum ProfileSync {
    static let endpoint = URL(string: "https://profile.meqrcode.cn/sync-v1/")!
    static func token() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SyncFailure(code: 0, message: L.syncErrToken) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func secret(_ key: String) throws -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "meqr.profile-sync.v1", kSecAttrAccount as String: key, kSecReturnData as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SyncFailure(code: 0, message: L.syncErrReadCredential) }
        return result as? Data
    }
    static func saveSecret(_ key: String, data: Data?) throws {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "meqr.profile-sync.v1", kSecAttrAccount as String: key]
        if let data {
            let update = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if update == errSecItemNotFound {
                var insert = q; insert[kSecValueData as String] = data
                insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw SyncFailure(code: 0, message: L.syncErrSaveCredential) }
            } else if update != errSecSuccess { throw SyncFailure(code: 0, message: L.syncErrUpdateCredential) }
        } else { SecItemDelete(q as CFDictionary) }
    }
    static func binding(_ id: UUID) throws -> SyncBinding? {
        guard let data = try secret(id.uuidString) else { return nil }
        return try JSONDecoder().decode(SyncBinding.self, from: data)
    }
    static func save(_ binding: SyncBinding?, for id: UUID) throws {
        try saveSecret(id.uuidString, data: binding.map { try JSONEncoder().encode($0) })
    }
    static func request(_ path: String, method: String = "GET", token: String, body: Data? = nil, binary: Bool = false) async throws -> Data {
        var req = URLRequest(url: endpoint.appendingPathComponent(path)); req.httpMethod = method
        req.timeoutInterval = 30; req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue(binary ? "application/octet-stream" : "application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept"); req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.statusCode == 200 else {
            let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw SyncFailure(code: response.statusCode, message: value?["error"] as? String ?? L.syncErrUnavailable(response.statusCode))
        }
        guard data.count <= 6 * 1024 * 1024 else { throw SyncFailure(code: 413, message: L.syncErrResponseLarge) }
        return data
    }
    static func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
    static func object<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) }
    static func images(_ c: QRCluster) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for (kind, input) in [("avatar", c.avatarImageData), ("background", c.backgroundImageData), ("banner", c.rhodesBannerImageData)] {
            guard let input else { continue }
            let limit = (kind == "avatar" ? 1 : 5) * 1024 * 1024
            let jpeg = input.starts(with: [0xff, 0xd8]); let png = input.starts(with: [0x89,0x50,0x4e,0x47])
            if input.count <= limit && (jpeg || png) { result[kind] = input; continue }
            guard let image = QRCodeGenerator.imageForEditing(from: input, maxPixelSize: 2560) else { throw SyncFailure(code: 400, message: L.syncErrImageRead(kind)) }
            guard let data = image.jpegData(compressionQuality: 0.85), data.count <= limit else { throw SyncFailure(code: 413, message: L.syncErrImageLarge) }
            result[kind] = data
        }
        return result
    }
    static func document(_ c: QRCluster, images: [String: Data]) -> SyncDocument {
        let refs = CardTagReference.decode(c.tagReferencesRawValue) ?? []
        let tags = c.tags.map { name -> SyncDocument.Tag in
            let ref = refs.first { $0.displayName == name || $0.fallbackName == name }
            let override = c.tagColorOverrides[CardTagColorPalette.normalized(name)]
            let colors = c.tagColorStyle(for: name).segmentHexes
            let weight = override?.textWeight ?? .regular
            return .init(name: ref?.fallbackName ?? name, catalogID: ref?.catalogID ?? "", mode: override?.mode.rawValue ?? (colors.count > 1 ? "preset" : "solid"), colors: colors,
                         presetColors: ref?.colors ?? colors, solidColor: ref?.solidColor ?? colors[0], weight: weight == .bold ? 900 : weight == .medium ? 600 : 400)
        }
        return .init(name: c.name, subtitle: c.subtitle, passSubtitle: c.passSubtitle ?? "", template: c.templateStyle.rawValue,
                     backgroundColor: c.backgroundColorHex, borderColor: c.borderColorHex, textColor: c.textColorHex ?? "#000000", qrColor: c.qrColorHex ?? "#000000",
                     cornerRadius: c.cornerRadius, cardOpacity: c.cardOpacity ?? 1,
                     qrItems: c.profiles.sorted { $0.createdAt < $1.createdAt }.map { .init(platform: $0.platformType, customPlatformName: $0.customPlatformName ?? "", qrContent: $0.qrContent) }, tags: tags, assets: images.mapValues(hash))
    }
    static func upload(_ images: [String: Data], binding: SyncBinding) async throws {
        for (_,data) in images {
            let reply = try await request("profiles/\(binding.profileId)/assets", method: "POST", token: binding.token, body: data, binary: true)
            guard (try JSONSerialization.jsonObject(with: reply) as? [String: String])?["hash"] == hash(data) else { throw SyncFailure(code: 400, message: L.syncErrUploadVerify) }
        }
    }
    static func apply(_ snapshot: SyncSnapshot, to c: QRCluster, context: ModelContext, token: String) async throws {
        let doc = snapshot.document
        guard doc.schemaVersion == 1, !doc.qrItems.isEmpty, doc.tags.count <= 10 else { throw SyncFailure(code: 400, message: L.syncErrFormatUnsupported) }
        var images: [String: Data] = [:]
        for (kind,digest) in doc.assets {
            let data = try await request("profiles/\(snapshot.profileId)/assets/\(digest)", token: token)
            guard hash(data) == digest, UIImage(data: data) != nil else { throw SyncFailure(code: 400, message: L.syncErrImageVerify) }
            images[kind] = data
        }
        // All downloads finish before mutating the local model. SwiftData commits atomically.
        if c.modelContext == nil { context.insert(c) }
        c.name = doc.name; c.subtitle = doc.subtitle; c.passSubtitle = doc.passSubtitle; c.templateStyleRawValue = doc.template
        c.backgroundColorHex = doc.backgroundColor; c.borderColorHex = doc.borderColor; c.textColorHex = doc.textColor; c.qrColorHex = doc.qrColor
        c.cornerRadius = doc.cornerRadius; c.cardOpacity = doc.cardOpacity
        c.avatarImageData = images["avatar"]; c.backgroundImageData = images["background"]; c.rhodesBannerImageData = images["banner"]
        let existing = c.profiles.sorted { $0.createdAt < $1.createdAt }
        for item in existing.dropFirst(doc.qrItems.count) { context.delete(item) }
        var updated: [QRProfile] = []
        for (i,item) in doc.qrItems.enumerated() {
            let p = i < existing.count ? existing[i] : QRProfile(qrContent: item.qrContent)
            p.platformType = item.platform; p.qrContent = item.qrContent; p.foregroundColorHex = doc.qrColor; p.customPlatformName = item.customPlatformName
            p.createdAt = Date(timeIntervalSince1970: Double(i)); context.insert(p); p.attach(to: c)
            updated.append(p)
        }
        c.profiles = updated
        let refs: [CardTagReference] = doc.tags.map { t in
            .init(catalogID: t.catalogID.isEmpty ? nil : t.catalogID, fallbackName: t.name, colors: t.presetColors, solidColor: t.solidColor,
                  override: .init(mode: CardTagColorOverride.Mode(rawValue: t.mode) ?? .custom, hexes: t.colors, textWeight: t.weight == 900 ? .bold : t.weight == 600 ? .medium : .regular))
        }
        c.tagReferencesRawValue = CardTagReference.encode(refs); c.tagListRawValue = doc.tags.map(\.name).joined(separator: "\n")
        do { try context.save() } catch { context.rollback(); throw error }
        let all = try context.fetch(FetchDescriptor<QRCluster>())
        WidgetDataHelper.sync(clusters: all); BackupManager.writeAutoBackup(clusters: all)
    }
    static func sync(_ c: QRCluster, context: ModelContext, resolution: String? = nil) async throws {
        guard var b = try binding(c.id) else { return }
        let images = try images(c), local = document(c, images: images)
        let remote = try JSONDecoder().decode(SyncSnapshot.self, from: await request("profiles/\(b.profileId)", token: b.token))
        if resolution == "remote" || (local == b.baseline && remote.revision != b.revision) {
            try await apply(remote, to: c, context: context, token: b.token)
            b.baseline = document(c, images: try self.images(c)); b.revision = remote.revision
        } else if local == remote.document {
            b.baseline = local; b.revision = remote.revision
        } else if local != b.baseline {
            guard remote.revision == b.revision || resolution == "local" else { throw SyncFailure(code: 409, message: L.syncErrConflict) }
            try await upload(images, binding: b)
            let data = try await request("profiles/\(b.profileId)", method: "PUT", token: b.token, body: json(["document": object(local), "revision": remote.revision]))
            let saved = try JSONDecoder().decode(SyncSnapshot.self, from: data)
            b.baseline = local; b.revision = saved.revision
        }
        try save(b, for: c.id)
    }

    /// Joined devices re-validate their binding once per launch; a revoked member loses its synced copy.
    /// Only definitive rejections (401/403) delete — 404 and network hiccups keep the local copy.
    @MainActor
    static func verifyBindings(context: ModelContext, clusters: [QRCluster]) async -> Int {
        var removed = 0
        var backedUp = false
        for cluster in clusters {
            guard let b = try? binding(cluster.id), b.role != "owner" else { continue }
            do {
                _ = try await request("profiles/\(b.profileId)/devices", token: b.token)
            } catch let failure as SyncFailure {
                guard failure.code == 401 || failure.code == 403 else { continue }
                if !backedUp { BackupManager.writeAutoBackup(clusters: clusters); backedUp = true }
                try? save(nil, for: cluster.id)
                context.delete(cluster)
                removed += 1
            } catch { continue }
        }
        if removed > 0 { try? context.save() }
        return removed
    }
}
