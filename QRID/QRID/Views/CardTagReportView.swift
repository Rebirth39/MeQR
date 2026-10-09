import SwiftUI

struct CardTagReportMenu: ViewModifier {
    let tag: String
    var submitReport: (([String: String]) async throws -> String)? = nil
    @State private var showingReport = false
    @StateObject private var usage = CardTagUsageStore.shared

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { usage.toggleFavorite(tag) } label: {
                Label(usage.isFavorite(tag) ? L.tagUnfavorite : L.tagFavorite, systemImage: usage.isFavorite(tag) ? "star.slash" : "star")
            }
            Button { showingReport = true } label: { Label(L.tagReport, systemImage: "flag") }
        }
        .sheet(isPresented: $showingReport) { CardTagReportView(tag: tag, submitReport: submitReport) }
    }
}

struct CardTagReportView: View {
    let tag: String
    var isNewTag = false
    var submitReport: (([String: String]) async throws -> String)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "name"
    @State private var details = ""
    @State private var contact = ""
    @State private var isSubmitting = false
    @State private var ticket: String?
    @State private var error: String?
    @State private var discard = false
    @State private var requestID = UUID().uuidString
    @State private var previousPayload: [String: String] = [:]
    @State private var requestedName = ""
    @State private var work = ""
    @State private var colors = ""
    @State private var reference = ""
    @State private var queued = false
    @State private var showingOutbox = false
    @State private var supportCode: String?
    @State private var includeSupportCode = true

    var body: some View {
        NavigationStack {
            Form {
                if queued {
                    Section {
                        Text(L.tagQueueSaved)
                        Button(L.tagOutbox) { showingOutbox = true }
                    }
                } else if let ticket {
                    Section(L.tagReportSent) {
                        LabeledContent(L.tagReportTicket, value: ticket).textSelection(.enabled)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(L.tagReportTicket): \(ticket)")
                            .accessibilityIdentifier("tag-report-receipt")
                        if let supportCode {
                            LabeledContent(L.supportCode, value: supportCode).textSelection(.enabled)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(L.supportCode): \(supportCode)")
                                .accessibilityIdentifier("tag-report-support-code")
                            Text(L.supportCodeSavedNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        if isNewTag {
                            TextField(L.tagRequestName, text: $requestedName)
                            TextField(L.tagRequestIP, text: $work)
                            TextField(L.tagRequestColors, text: $colors)
                            TextField(L.tagRequestSource, text: $reference)
                                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        } else {
                        Text(tag)
                        Picker(L.tagReportReason, selection: $reason) {
                            Text(L.tagReportName).tag("name")
                            Text(L.tagReportColor).tag("color")
                            Text(L.tagReportDuplicate).tag("duplicate")
                            Text(L.tagReportOther).tag("other")
                        }
                        }
                        TextField(L.tagReportDescription, text: $details, axis: .vertical)
                            .lineLimit(4...8).accessibilityIdentifier("tag-report-description")
                        if details.count > 3000 { Text("\(details.count)/3000").foregroundStyle(.red) }
                        TextField(L.tagReportContact, text: $contact)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        if contact.count > 120 { Text("\(contact.count)/120").foregroundStyle(.red) }
                        Toggle(L.tagReportIncludeSupportCode, isOn: $includeSupportCode)
                        Text(L.tagReportIncludeSupportCodeHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isSubmitting)
                    if let error { Section { Text(error).foregroundStyle(.red) } }
                    if isSubmitting { Section { ProgressView() } }
                }
            }
            .navigationTitle(isNewTag ? L.tagRequestNew : L.tagReport).navigationBarTitleDisplayMode(.inline)
            .onAppear { if requestedName.isEmpty { requestedName = tag } }
            .sheet(isPresented: $showingOutbox) { CardTagOutboxView() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ticket == nil && !queued ? L.cancel : L.done) {
                        if ticket == nil && !queued && (!details.isEmpty || !contact.isEmpty || !work.isEmpty || !colors.isEmpty || !reference.isEmpty || requestedName != tag) { discard = true }
                        else { dismiss() }
                    }.disabled(isSubmitting)
                }
                if ticket == nil && !queued {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.tagReportSubmit) { Task { await submit() } }
                            .disabled(isSubmitting || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || details.count > 3000 || contact.count > 120
                                      || (isNewTag && (requestedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || work.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requestedName.count > 160 || work.count > 160 || colors.count > 240 || reference.count > 1000)))
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting || (ticket == nil && !queued && (!details.isEmpty || !contact.isEmpty || !work.isEmpty || !colors.isEmpty || !reference.isEmpty || requestedName != tag)))
        .confirmationDialog(L.tagReportDiscard, isPresented: $discard, titleVisibility: .visible) {
            Button(L.delete, role: .destructive) { dismiss() }
        }
    }

    @MainActor private func submit() async {
        guard !isSubmitting else { return }
        if isNewTag && !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let url = URLComponents(string: reference.trimmingCharacters(in: .whitespacesAndNewlines)),
                  ["http", "https"].contains(url.scheme ?? ""), let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
                error = L.tagRequestSource; return
            }
        }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        let entry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey(tag))
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var payload = ["tag_id": entry?.id ?? "", "tag_name": tag, "reason": reason,
                       "description": details, "contact": contact, "platform": "ios", "app_version": version,
                       "revision": RemoteTagCatalog.shared.revision, "source": RemoteTagCatalog.shared.sourceName,
                       "_include_support_code": includeSupportCode ? "true" : "false"]
        if isNewTag {
            payload["tag_id"] = ""; payload["tag_name"] = requestedName; payload["reason"] = "request"
            payload["work"] = work; payload["suggested_colors"] = colors; payload["reference_url"] = reference
        }
        if payload != previousPayload { requestID = UUID().uuidString; previousPayload = payload }
        payload["request_id"] = requestID
        // UI harnesses inject their own transport and never contact the live service.
        if let submitReport {
            do { ticket = try await submitReport(payload) }
            catch { self.error = L.tagReportFailed }
            return
        }
        do {
            let id = try CardTagOutbox.shared.enqueue(payload)
            queued = true
            await CardTagOutbox.shared.drain()
            if let receipt = CardTagOutbox.shared.jobs.first(where: { $0.id == id })?.ticket {
                ticket = receipt
                queued = false
                supportCode = SupportTicketStore.shared.ticket(forRequestID: id)?.supportCode
                if supportCode?.isEmpty == true { supportCode = nil }
            }
        } catch { self.error = L.tagQueueSaveFailed }
    }
}

enum CardTagReportClient {
    enum Failure: Error { case invalidResponse, limited, rejected }
    static func submit(_ payload: [String: String]) async throws -> String {
        var payload = payload
        let supportCodeChoice = payload.removeValue(forKey: "_include_support_code")
        let includeSupportCode = supportCodeChoice == "true"
        if supportCodeChoice == "false" {
            payload.removeValue(forKey: "device_id")
            payload.removeValue(forKey: "support_code")
        }
        if includeSupportCode {
            let code = try await SupportTicketStore.shared.obtainBlankCode()
            payload["device_id"] = DeviceIdentity.id
            payload["support_code"] = code
        }
        let base = URL(string: "https://report.meqrcode.cn/api/tag-reports")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (tokenData, tokenResponse) = try await session.data(from: base.appendingPathComponent("token"))
        try validate(tokenResponse)
        struct Token: Decodable { let token: String }
        let token = try JSONDecoder().decode(Token.self, from: tokenData).token
        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        struct Receipt: Decodable { let ticket_id: String; let support_code: String?; let next_support_code: String? }
        let receipt = try JSONDecoder().decode(Receipt.self, from: data)
        let ticket = receipt.ticket_id
        guard ticket.range(of: "^MEQR-[0-9]{8}-[A-F0-9]{6}$", options: .regularExpression) != nil else { throw Failure.invalidResponse }
        await SupportTicketStore.shared.noteSubmitted(
            requestID: payload["request_id"], ticketID: ticket,
            supportCode: receipt.support_code, title: payload["tag_name"] ?? "", nextCode: receipt.next_support_code
        )
        return ticket
    }
    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        if http.statusCode == 429 { throw Failure.limited }
        if [400, 409, 413, 415].contains(http.statusCode) { throw Failure.rejected }
        guard (200...299).contains(http.statusCode) else { throw Failure.invalidResponse }
    }
}
