import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct MyTicketsView: View {
    @StateObject private var store = SupportTicketStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let code = store.blankCode {
                    Section {
                        LabeledContent(L.supportCode, value: code)
                            .textSelection(.enabled)
                        if store.codeRotated {
                            Text(L.supportCodeRotated)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text(L.blankCodeFooter)
                    }
                }
                Section {
                    if store.isLoading && store.tickets.isEmpty {
                        ProgressView()
                    } else if store.tickets.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.ticketListEmpty)
                            Text(L.ticketListEmptyHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(store.tickets) { ticket in
                            NavigationLink {
                                TicketDetailView(ticketID: ticket.id)
                            } label: {
                                TicketRow(ticket: ticket)
                            }
                        }
                    }
                }
                if store.loadFailed {
                    Section {
                        Text(L.ticketLoadFailed).foregroundStyle(.red)
                        Button(L.retry) { Task { await store.refresh(force: true) } }
                    }
                }
            }
            .navigationTitle(L.myTickets)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } }
            }
            .task {
                await store.refresh()
                await store.refreshBlankCode()
            }
            .refreshable { await store.refresh(force: true) }
            .onDisappear {
                store.clearRotatedNotice()
                store.markUpdateSeen()
            }
        }
    }
}

private struct TicketRow: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ticket.title.isEmpty ? ticket.id : ticket.title)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(ticket.localizedStatus)
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(ticket.statusColor.opacity(0.15))
                    .foregroundStyle(ticket.statusColor)
                    .clipShape(Capsule())
                if ticket.needsInfo {
                    Text(L.ticketNeedsInfo)
                        .font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(SupportTicketStore.displayTime(ticket.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !ticket.supportCode.isEmpty {
                Text("\(L.supportCode): \(ticket.supportCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TicketDetailView: View {
    let ticketID: String
    @StateObject private var store = SupportTicketStore.shared
    @State private var draft = ""
    @State private var sending = false
    @State private var sendError: String?
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedAttachment: TicketAttachmentPayload?
    @State private var loadingAttachment = false

    private var ticket: SupportTicket? {
        store.tickets.first(where: { $0.id == ticketID })
    }

    private var draftValid: Bool {
        draft.count <= 2000 && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedAttachment != nil)
    }

    var body: some View {
        Form {
            if let ticket {
                if ticket.needsInfo {
                    Section {
                        Label(L.ticketNeedsInfo, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.headline)
                        Text(L.ticketNeedsInfoDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    if !ticket.title.isEmpty { LabeledContent(L.tagReportDescription, value: ticket.title) }
                    LabeledContent(L.tagReportTicket, value: ticket.id)
                        .textSelection(.enabled)
                    if !ticket.supportCode.isEmpty {
                        LabeledContent(L.supportCode, value: ticket.supportCode)
                            .textSelection(.enabled)
                    }
                    LabeledContent(L.ticketStatus, value: ticket.localizedStatus)
                    LabeledContent(L.ticketSubmittedAt, value: SupportTicketStore.displayTime(ticket.createdAt))
                    LabeledContent(L.ticketUpdatedAt, value: SupportTicketStore.displayTime(ticket.updatedAt))
                }
                Section(L.adminReply) {
                    if ticket.adminNote.isEmpty {
                        Text(L.ticketNoReply).foregroundStyle(.secondary)
                    } else {
                        Text(ticket.adminNote).textSelection(.enabled)
                    }
                }
                if !ticket.userMessages.isEmpty {
                    Section(L.ticketMyMessages) {
                        ForEach(ticket.userMessages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                if !message.text.isEmpty { Text(message.text).textSelection(.enabled) }
                                ForEach(message.attachments) { attachment in
                                    Label(attachment.name, systemImage: attachment.mimeType.hasPrefix("video/") ? "video" : "photo")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(SupportTicketStore.displayTime(message.at))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if ticket.supportCode.isEmpty {
                    Section {
                        Text(L.ticketAnonymousNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                Section(L.ticketAddInfo) {
                    PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                        Label(L.ticketAddFile, systemImage: "paperclip")
                    }
                    .disabled(sending || loadingAttachment)
                    if loadingAttachment {
                        ProgressView(L.ticketAttachmentLoading)
                    } else if let selectedAttachment {
                        HStack {
                            Label(selectedAttachment.fileName, systemImage: selectedAttachment.mimeType.hasPrefix("video/") ? "video" : "photo")
                                .lineLimit(1)
                            Spacer()
                            Button(L.ticketRemoveAttachment) {
                                selectedItem = nil
                                self.selectedAttachment = nil
                            }
                            .font(.caption)
                        }
                    }
                    TextField(L.ticketAddInfoPlaceholder, text: $draft, axis: .vertical)
                        .lineLimit(3...8)
                        .disabled(sending)
                        .accessibilityIdentifier("ticket-message-input")
                    if draft.count > 2000 { Text("\(draft.count)/2000").foregroundStyle(.red) }
                    if sending {
                        ProgressView()
                    } else {
                        Button(L.ticketSend) { Task { await send() } }
                            .disabled(!draftValid || loadingAttachment)
                            .accessibilityIdentifier("ticket-message-send")
                    }
                    if let sendError { Text(sendError).foregroundStyle(.red) }
                }
                }
            }
        }
        .navigationTitle(ticket?.title.isEmpty == false ? ticket!.title : ticketID)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, item in
            Task { await loadAttachment(item) }
        }
    }

    @MainActor private func loadAttachment(_ item: PhotosPickerItem?) async {
        selectedAttachment = nil
        guard let item else { return }
        loadingAttachment = true
        defer { loadingAttachment = false }
        let type = item.supportedContentTypes.first
        let mimeType = type?.preferredMIMEType ?? "application/octet-stream"
        guard mimeType.hasPrefix("image/") || mimeType.hasPrefix("video/") else {
            sendError = L.ticketAttachmentFailed
            return
        }
        do {
            let data = try await TicketAttachmentLoader.loadBounded(item: item)
            let extensionName = type?.preferredFilenameExtension ?? (mimeType.hasPrefix("video/") ? "mov" : "jpg")
            selectedAttachment = TicketAttachmentPayload(
                data: data,
                fileName: "meqr-evidence.\(extensionName)",
                mimeType: mimeType
            )
            sendError = nil
        } catch TicketAttachmentLoader.Error.tooLarge {
            sendError = L.ticketAttachmentTooLarge
        } catch {
            sendError = L.ticketAttachmentFailed
        }
    }

    private var draftFingerprint: String {
        "\(draft)|\(selectedAttachment?.fileName ?? ""):\(selectedAttachment?.data.count ?? 0)"
    }

    @MainActor private func send() async {
        guard !sending, draftValid else { return }
        sending = true
        sendError = nil
        defer { sending = false }
        let fingerprint = draftFingerprint
        let requestID = Self.persistedRequestID(ticketID: ticketID, fingerprint: fingerprint) ?? UUID().uuidString
        do {
            if let selectedAttachment {
                try await SupportTicketClient.postAttachment(
                    ticketID: ticketID,
                    deviceID: DeviceIdentity.id,
                    text: draft,
                    requestID: requestID,
                    attachment: selectedAttachment
                )
            } else {
                try await SupportTicketClient.postMessage(
                    ticketID: ticketID,
                    deviceID: DeviceIdentity.id,
                    text: draft,
                    requestID: requestID
                )
                store.noteMessage(ticketID: ticketID, text: draft)
            }
            Self.clearPersistedRequestID(ticketID: ticketID)
            draft = ""
            selectedItem = nil
            selectedAttachment = nil
            await store.refresh(force: true)
        } catch {
            Self.persistRequestID(requestID, ticketID: ticketID, fingerprint: fingerprint)
            sendError = (error as? SupportTicketClient.Failure) == .limited ? L.tagReportLimited : L.ticketMessageFailed
        }
    }

    private static func requestIDKey(ticketID: String) -> String { "meqr.ticket-message-request-id.\(ticketID)" }

    private static func persistedRequestID(ticketID: String, fingerprint: String) -> String? {
        guard let saved = UserDefaults.standard.dictionary(forKey: requestIDKey(ticketID: ticketID)),
              saved["fingerprint"] as? String == fingerprint,
              let requestID = saved["request_id"] as? String,
              UUID(uuidString: requestID) != nil else { return nil }
        return requestID
    }

    private static func persistRequestID(_ requestID: String, ticketID: String, fingerprint: String) {
        UserDefaults.standard.set(["fingerprint": fingerprint, "request_id": requestID], forKey: requestIDKey(ticketID: ticketID))
    }

    private static func clearPersistedRequestID(ticketID: String) {
        UserDefaults.standard.removeObject(forKey: requestIDKey(ticketID: ticketID))
    }
}

enum TicketAttachmentLoader {
    enum Error: Swift.Error { case tooLarge }
    static let maxBytes = 50 * 1024 * 1024

    static func loadBounded(item: PhotosPickerItem) async throws -> Data {
        if let size = declaredSize(item: item), size > maxBytes { throw Error.tooLarge }
        let data = try await item.loadTransferable(type: Data.self) ?? { throw CocoaError(.fileReadUnknown) }()
        if data.count > maxBytes { throw Error.tooLarge }
        return data
    }

    static func declaredSize(item: PhotosPickerItem) -> Int? {
        guard let identifier = item.itemIdentifier,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject,
              let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
        return resource.value(forKey: "fileSize") as? Int
    }
}

extension SupportTicket {
    var localizedStatus: String {
        switch status {
        case "processing": return L.ticketStatusProcessing
        case "resolved": return L.ticketStatusResolved
        case "closed": return L.ticketStatusClosed
        default: return L.ticketStatusOpen
        }
    }

    var statusColor: Color {
        switch status {
        case "processing": return .blue
        case "resolved": return .green
        case "closed": return .gray
        default: return .secondary
        }
    }
}

struct TicketUpdateBanner: View {
    @StateObject private var store = SupportTicketStore.shared
    let onOpen: () -> Void

    var body: some View {
        if store.hasUpdate {
            Button(action: onOpen) {
                HStack {
                    Image(systemName: "exclamationmark.bubble")
                    Text(L.ticketUpdateBanner).lineLimit(1).truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline).padding(.horizontal, 14).frame(height: 52)
                .background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ticket-update-banner")
        }
    }
}
