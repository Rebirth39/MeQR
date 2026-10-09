import Foundation
import Combine
import UIKit

struct SupportTicket: Codable, Identifiable, Equatable {
    struct Attachment: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        let mimeType: String
        let byteSize: Int

        enum CodingKeys: String, CodingKey {
            case id, name
            case mimeType = "mime_type"
            case byteSize = "byte_size"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let alternate = try decoder.container(keyedBy: AlternateKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
                ?? alternate.decode(String.self, forKey: .mime)
            byteSize = try container.decodeIfPresent(Int.self, forKey: .byteSize)
                ?? alternate.decode(Int.self, forKey: .size)
        }

        private enum AlternateKeys: String, CodingKey { case mime, size }
    }

    struct UserMessage: Codable, Equatable, Identifiable {
        var id: String
        var text: String
        var at: String
        var attachments: [Attachment]

        enum CodingKeys: String, CodingKey { case id, text, at, attachments }
        private enum AlternateKeys: String, CodingKey { case attachment }

        init(id: String = UUID().uuidString, text: String, at: String, attachments: [Attachment] = []) {
            self.id = id
            self.text = text
            self.at = at
            self.attachments = attachments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            at = try container.decodeIfPresent(String.self, forKey: .at) ?? ""
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? (at + text)
            if let list = try container.decodeIfPresent([Attachment].self, forKey: .attachments) {
                attachments = list
            } else {
                let alternate = try decoder.container(keyedBy: AlternateKeys.self)
                attachments = try alternate.decodeIfPresent(Attachment.self, forKey: .attachment).map { [$0] } ?? []
            }
        }
    }

    let id: String
    var title: String
    var status: String
    var needsInfo: Bool
    var adminNote: String
    var supportCode: String
    var createdAt: String
    var updatedAt: String
    var requestID: String?
    var userMessages: [UserMessage]

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case needsInfo = "needs_info"
        case adminNote = "admin_note"
        case supportCode = "support_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case requestID = "request_id"
        case userMessages = "user_messages"
    }

    init(id: String, title: String, status: String, needsInfo: Bool, adminNote: String,
         supportCode: String, createdAt: String, updatedAt: String, requestID: String?,
         userMessages: [UserMessage] = []) {
        self.id = id
        self.title = title
        self.status = status
        self.needsInfo = needsInfo
        self.adminNote = adminNote
        self.supportCode = supportCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.requestID = requestID
        self.userMessages = userMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        needsInfo = try container.decodeIfPresent(Bool.self, forKey: .needsInfo) ?? false
        adminNote = try container.decodeIfPresent(String.self, forKey: .adminNote) ?? ""
        supportCode = try container.decodeIfPresent(String.self, forKey: .supportCode) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        requestID = try container.decodeIfPresent(String.self, forKey: .requestID)
        userMessages = try container.decodeIfPresent([UserMessage].self, forKey: .userMessages) ?? []
    }
}

enum DeviceIdentity {
    private static let service = "meqr.support-tickets.v1"
    private static let account = "device-id"
    private static let lock = NSLock()
    private static var cachedID: String?

    static var id: String {
        lock.lock()
        defer { lock.unlock() }
        if let cachedID { return cachedID }
        if let data = read(), let saved = String(data: data, encoding: .utf8), isValid(saved) {
            cachedID = saved
            return saved
        }
        let raw = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let value = isValid(raw) ? raw : UUID().uuidString
        save(value)
        cachedID = value
        return value
    }

    static func adopt(_ value: String) {
        guard isValid(value) else { return }
        lock.lock()
        defer { lock.unlock() }
        save(value)
        cachedID = value
    }

    static func isValid(_ value: String) -> Bool {
        value.count >= 8 && value.count <= 80 && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
    }

    private static func read() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(insert as CFDictionary, nil)
        }
    }
}

enum SupportTicketClient {
    enum Failure: Error { case invalidResponse, limited }

    private static let base = URL(string: "https://report.meqrcode.cn")!

    static func tickets(deviceID: String) async throws -> (tickets: [SupportTicket], blankCode: String?) {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let url = base.appendingPathComponent("api/tickets/by-device/\(deviceID)")
        let (data, response) = try await session.data(from: url)
        try validate(response)
        struct List: Decodable { let tickets: [SupportTicket]; let blank_support_code: String? }
        let list = try JSONDecoder().decode(List.self, from: data)
        return (list.tickets, list.blank_support_code)
    }

    static func blankCode(deviceID: String) async throws -> (code: String, deviceID: String?, generated: Bool, rotated: Bool) {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: base.appendingPathComponent("api/support-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["device_id": deviceID])
        let (data, response) = try await session.data(for: request)
        try validate(response)
        struct Receipt: Decodable {
            let support_code: String
            let device_id: String?
            let device_id_generated: Bool?
            let rotated: Bool?
        }
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        guard receipt.support_code.range(of: "^[A-HJ-KM-NP-Z2-9]{6}$", options: .regularExpression) != nil else { throw Failure.invalidResponse }
        return (receipt.support_code, receipt.device_id, receipt.device_id_generated ?? false, receipt.rotated ?? false)
    }

    static func postMessage(ticketID: String, deviceID: String, text: String, requestID: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: base.appendingPathComponent("api/tickets/\(ticketID)/message"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["device_id": deviceID, "text": text, "request_id": requestID])
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    static func postAttachment(ticketID: String, deviceID: String, text: String,
                                requestID: String, attachment: TicketAttachmentPayload) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        appendField("device_id", deviceID, boundary: boundary, to: &body)
        appendField("text", text, boundary: boundary, to: &body)
        appendField("request_id", requestID, boundary: boundary, to: &body)
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"attachment\"; filename=\"\(attachment.fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(attachment.mimeType)\r\n\r\n".utf8))
        body.append(attachment.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: base.appendingPathComponent("api/tickets/\(ticketID)/attachment"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private static func appendField(_ name: String, _ value: String, boundary: String, to body: inout Data) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 180
        return URLSession(configuration: configuration)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        if http.statusCode == 429 { throw Failure.limited }
        guard (200...299).contains(http.statusCode) else { throw Failure.invalidResponse }
    }
}

struct TicketAttachmentPayload {
    let data: Data
    let fileName: String
    let mimeType: String
}

@MainActor final class SupportTicketStore: ObservableObject {
    static let shared = SupportTicketStore()

    @Published private(set) var tickets: [SupportTicket] = []
    @Published private(set) var blankCode: String?
    @Published private(set) var hasUpdate = false
    @Published private(set) var codeRotated = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private let url: URL
    private var lastRefresh: Date?
    private var baselineEstablished = false
    private var fetchingCode = false
    private var codeRevision = 0
    private var seenSignature: String?

    private var updateSignature: String {
        tickets.map { "\($0.id)|\($0.status)|\($0.needsInfo)|\($0.adminNote)" }.joined(separator: ";")
    }

    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory.appendingPathComponent("support-tickets.json")
        guard let data = try? Data(contentsOf: self.url),
              let saved = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        tickets = saved.tickets
        blankCode = saved.blankCode
        baselineEstablished = saved.baselineEstablished
        hasUpdate = saved.hasUpdate ?? false
        seenSignature = saved.seenSignature
    }

    func noteSubmitted(requestID: String?, ticketID: String, supportCode: String?, title: String, nextCode: String? = nil) {
        let now = Self.isoNow()
        if let index = tickets.firstIndex(where: { $0.id == ticketID }) {
            if let supportCode { tickets[index].supportCode = supportCode }
            tickets[index].requestID = tickets[index].requestID ?? requestID
        } else {
            tickets.insert(SupportTicket(
                id: ticketID, title: title, status: "open", needsInfo: false,
                adminNote: "", supportCode: supportCode ?? "", createdAt: now, updatedAt: now,
                requestID: requestID
            ), at: 0)
        }
        if let nextCode, nextCode.range(of: "^[A-HJ-KM-NP-Z2-9]{6}$", options: .regularExpression) != nil {
            blankCode = nextCode
            codeRevision += 1
        } else if let supportCode, !supportCode.isEmpty, blankCode == supportCode {
            blankCode = nil
            codeRevision += 1
            Task { await refreshBlankCode() }
        }
        save()
    }

    func ticket(forRequestID requestID: String) -> SupportTicket? {
        tickets.first(where: { $0.requestID == requestID })
    }

    func refresh(force: Bool = false) async {
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        let codeRevisionAtStart = codeRevision
        do {
            let response = try await SupportTicketClient.tickets(deviceID: DeviceIdentity.id)
            let fetched = response.tickets
            lastRefresh = Date()
            loadFailed = false
            let known = baselineEstablished || !tickets.isEmpty
            var changed = false
            var merged: [SupportTicket] = []
            for ticket in fetched {
                var value = ticket
                if let old = tickets.first(where: { $0.id == ticket.id }) {
                    value.requestID = old.requestID
                    value.userMessages = reconcileMessages(local: old.userMessages, remote: ticket.userMessages)
                    if old.status != ticket.status || old.needsInfo != ticket.needsInfo || old.adminNote != ticket.adminNote { changed = true }
                } else if known {
                    changed = true
                }
                merged.append(value)
            }
            let fetchedIDs = Set(merged.map(\.id))
            tickets = tickets.filter { !fetchedIDs.contains($0.id) } + merged
            if codeRevisionAtStart == codeRevision {
                if let code = response.blankCode, code.range(of: "^[A-HJ-KM-NP-Z2-9]{6}$", options: .regularExpression) != nil {
                    if blankCode != nil && blankCode != code { codeRotated = true }
                    blankCode = code
                    codeRevision += 1
                } else if let blankCode, fetched.contains(where: { $0.supportCode == blankCode }) {
                    self.blankCode = nil
                    codeRevision += 1
                }
            }
            baselineEstablished = true
            if changed && updateSignature != seenSignature { hasUpdate = true }
            save()
        } catch {
            loadFailed = true
        }
    }

    private func reconcileMessages(local: [SupportTicket.UserMessage], remote: [SupportTicket.UserMessage]) -> [SupportTicket.UserMessage] {
        guard !local.isEmpty else { return remote }
        var merged = remote
        for message in local where !remote.contains(where: { $0.text == message.text && $0.attachments == message.attachments }) {
            merged.append(message)
        }
        return merged
    }

    func ensureBlankCode() async {
        guard blankCode == nil else { return }
        await refreshBlankCode()
    }

    func obtainBlankCode() async throws -> String {
        if let blankCode, blankCode.range(of: "^[A-HJ-KM-NP-Z2-9]{6}$", options: .regularExpression) != nil {
            return blankCode
        }
        let revision = codeRevision
        let receipt = try await SupportTicketClient.blankCode(deviceID: DeviceIdentity.id)
        if revision == codeRevision {
            blankCode = receipt.code
            codeRevision += 1
        }
        if receipt.generated, let deviceID = receipt.deviceID { DeviceIdentity.adopt(deviceID) }
        save()
        return receipt.code
    }

    func refreshBlankCode() async {
        guard !fetchingCode else { return }
        fetchingCode = true
        defer { fetchingCode = false }
        let revision = codeRevision
        do {
            let receipt = try await SupportTicketClient.blankCode(deviceID: DeviceIdentity.id)
            guard revision == codeRevision else { return }
            if blankCode != nil && blankCode != receipt.code { codeRotated = true }
            blankCode = receipt.code
            codeRevision += 1
            if receipt.generated, let deviceID = receipt.deviceID { DeviceIdentity.adopt(deviceID) }
            save()
        } catch { }
    }

    func clearRotatedNotice() { codeRotated = false }

    func noteMessage(ticketID: String, text: String) {
        guard let index = tickets.firstIndex(where: { $0.id == ticketID }) else { return }
        tickets[index].userMessages.append(SupportTicket.UserMessage(text: text, at: Self.isoNow()))
        save()
    }

    func markUpdateSeen() {
        seenSignature = updateSignature
        hasUpdate = false
        save()
    }

    static func displayTime(_ iso: String) -> String {
        guard let date = parseISO(iso) else { return iso }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func parseISO(_ iso: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: iso) { return date }
        return ISO8601DateFormatter().date(from: iso)
    }

    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private struct Snapshot: Codable {
        var tickets: [SupportTicket]
        var blankCode: String?
        var baselineEstablished: Bool
        var hasUpdate: Bool?
        var seenSignature: String?
    }

    private func save() {
        let snapshot = Snapshot(tickets: tickets, blankCode: blankCode, baselineEstablished: baselineEstablished, hasUpdate: hasUpdate, seenSignature: seenSignature)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
