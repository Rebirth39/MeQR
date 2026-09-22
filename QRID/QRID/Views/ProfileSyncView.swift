import SwiftUI
import SwiftData

struct ProfileSyncView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \QRCluster.sortOrder) private var clusters: [QRCluster]
    @State private var selected: UUID?
    @State private var binding: SyncBinding?
    @State private var devices: SyncDeviceList?
    @State private var code = ""
    @State private var invite = ""
    @State private var pending = false
    @State private var busy = false
    @State private var message = ""
    @State private var conflict = false
    @State private var confirmDisconnect = false
    @State private var confirmClear = false
    @AppStorage("meqr_sync_privacy_ack_v1") private var syncPrivacyAck = false
    @State private var showSyncPrivacy = false
    private var cluster: QRCluster? { clusters.first { $0.id == selected } }

    var body: some View {
        Form {
            Section {
                Text(L.syncIntro1)
                    .font(.subheadline)
                Text(L.syncIntro2)
                    .font(.footnote).foregroundStyle(.secondary)
                Text(L.syncIntro3)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section(L.syncLocalCards) {
                Picker(L.syncSelectCard, selection: $selected) {
                    Text(L.syncSelectPlaceholder).tag(UUID?.none)
                    ForEach(clusters) { c in Text(c.name).tag(Optional(c.id)) }
                }
                if let c = cluster {
                    if let b = binding {
                        Text("\(b.role == "owner" ? L.syncRoleOwner : L.syncRoleBound) · \(L.syncCloudVersion) \(b.revision)")
                        Button(L.syncNow) { run { try await syncCard(c) } }
                        Button(L.syncRefreshDevices) { run { try await refreshDevices() } }
                        if b.role == "owner" {
                            Button(L.syncGenerateCode) { run {
                                let data = try await ProfileSync.request("profiles/\(b.profileId)/invite", method: "POST", token: b.token, body: ProfileSync.json([:]))
                                invite = formatCode((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["code"] as? String ?? "")
                                try await refreshDevices()
                            } }
                        }
                        if !invite.isEmpty {
                            Text(invite).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Button(L.syncCopyCode) { UIPasteboard.general.string = invite; message = L.syncCopied }
                        }
                        Button(b.role == "owner" ? L.syncStopOwner : L.syncUnbind, role: .destructive) { confirmDisconnect = true }
                        Button(L.syncClearCredential, role: .destructive) { confirmClear = true }
                    } else {
                        Button(L.syncEnable) { run { try await create(c) } }
                    }
                }
            }
            if let list = devices, let b = binding {
                Section(L.syncBoundDevices) {
                    ForEach(list.devices) { d in
                        HStack {
                            Text(d.name + (d.id == b.deviceId ? L.syncThisDevice : ""))
                            Spacer()
                            if b.role == "owner", d.role != "owner" {
                                Button(L.syncRemove, role: .destructive) { run {
                                    _ = try await ProfileSync.request("profiles/\(b.profileId)/devices/\(d.id)", method: "DELETE", token: b.token)
                                    try await refreshDevices()
                                } }
                            }
                        }
                    }
                }
                if b.role == "owner", !list.pending.isEmpty {
                    Section(L.syncPendingDevices) {
                        ForEach(list.pending) { d in
                            Button(L.syncAllow(d.name)) { run {
                                _ = try await ProfileSync.request("profiles/\(b.profileId)/approve/\(d.id)", method: "POST", token: b.token, body: ProfileSync.json([:]))
                                try await refreshDevices(); message = L.syncAllowed
                            } }
                        }
                    }
                }
            }
            Section(L.syncJoinSection) {
                TextField(L.syncJoinPlaceholder, text: Binding(get: { code }, set: { code = formatCode($0) })).textInputAutocapitalization(.characters).autocorrectionDisabled().disabled(pending).font(.system(.body, design: .monospaced))
                Button(pending ? L.syncCheckJoin : L.syncApplyJoin) { run { try await join() } }
                if pending { Button(L.syncCancelJoin) { run { try ProfileSync.saveSecret("pendingJoin", data: nil); pending = false; code = "" } } }
                Text(L.syncJoinHint)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if busy { ProgressView(L.syncSyncing) }
            if !message.isEmpty { Section { Text(message).font(.subheadline).textSelection(.enabled) } }
        }
        .disabled(busy)
        .navigationTitle(L.syncTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(busy)
        .interactiveDismissDisabled(busy)
        .onAppear { if selected == nil { selected = clusters.first?.id }; reload(); restorePending(); if !syncPrivacyAck { showSyncPrivacy = true } }
        .sheet(isPresented: $showSyncPrivacy) { LegalUpdateView(kind: .privacy) { syncPrivacyAck = true; showSyncPrivacy = false } }
        .onChange(of: selected) { _, _ in invite = ""; devices = nil; reload() }
        .task(id: selected) {
            while !Task.isCancelled {
                if let c = clusters.first(where: { $0.id == selected }),
                   let b = try? ProfileSync.binding(c.id) {
                    if let data = try? await ProfileSync.request("profiles/\(b.profileId)/devices", token: b.token),
                       let list = try? JSONDecoder().decode(SyncDeviceList.self, from: data) {
                        devices = list
                    }
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .refreshable { try? await refreshDevices() }
        .confirmationDialog(L.syncConflictTitle, isPresented: $conflict, titleVisibility: .visible) {
            Button(L.syncConflictLocal) { resolve("local") }
            Button(L.syncConflictRemote, role: .destructive) { resolve("remote") }
            Button(L.syncConflictLater, role: .cancel) { }
        } message: { Text(L.syncConflictMessage) }
        .confirmationDialog(L.syncDisconnectTitle, isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button(binding?.role == "owner" ? L.syncDisconnectOwner : L.syncDisconnectMember, role: .destructive) { run { try await disconnect() } }
        } message: { Text(L.syncDisconnectMessage) }
        .confirmationDialog(L.syncClearTitle, isPresented: $confirmClear, titleVisibility: .visible) {
            Button(L.syncClearAction, role: .destructive) { if let c = cluster { run { try ProfileSync.save(nil, for: c.id); devices = nil; invite = ""; message = L.syncStoppedLocal } } }
        } message: { Text(L.syncClearMessage) }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }; busy = true; message = ""
        Task { @MainActor in
            defer { busy = false; reload() }
            do { try await action() }
            catch { message = error.localizedDescription }
        }
    }
    private func reload() {
        do { binding = try cluster.flatMap { try ProfileSync.binding($0.id) } }
        catch { message = error.localizedDescription }
    }
    private func restorePending() {
        if let data = try? ProfileSync.secret("pendingJoin"), let value = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            code = value["code"] ?? ""; pending = true
        }
    }
    private func refreshDevices() async throws {
        guard let b = binding else { return }
        devices = try JSONDecoder().decode(SyncDeviceList.self, from: await ProfileSync.request("profiles/\(b.profileId)/devices", token: b.token))
    }
    private func create(_ c: QRCluster) async throws {
        let key = "create-" + c.id.uuidString
        let t: String
        if let saved = try ProfileSync.secret(key), let existing = String(data: saved, encoding: .utf8) { t = existing }
        else { t = try ProfileSync.token(); try ProfileSync.saveSecret(key, data: Data(t.utf8)) }
        var doc = ProfileSync.document(c, images: try ProfileSync.images(c)); doc.assets = [:]
        let data = try await ProfileSync.request("profiles", method: "POST", token: t, body: ProfileSync.json(["document": ProfileSync.object(doc), "deviceName": UIDevice.current.name]))
        let s = try JSONDecoder().decode(SyncSnapshot.self, from: data)
        guard let deviceId = s.deviceId, !s.profileId.isEmpty else { throw SyncFailure(code: 502, message: L.syncErrDeviceIncomplete) }
        let b = SyncBinding(profileId: s.profileId, deviceId: deviceId, token: t, role: "owner", revision: s.revision, baseline: nil)
        try ProfileSync.save(b, for: c.id); try ProfileSync.saveSecret(key, data: nil)
        try await ProfileSync.sync(c, context: context); message = L.syncEnabled
    }
    private func join() async throws {
        var value: [String: String]
        if let data = try ProfileSync.secret("pendingJoin") {
            value = try JSONDecoder().decode([String: String].self, from: data)
        } else {
            let clean = normalizeCode(code)
            guard (clean.count == 16 && clean.allSatisfy({ $0.isNumber || ($0 >= "A" && $0 <= "Z") })) || (clean.count == 32 && clean.allSatisfy({ "0123456789abcdef".contains($0) })) else { throw SyncFailure(code: 400, message: L.syncErrInvalidCode) }
            value = ["code": clean, "token": try ProfileSync.token(), "localID": UUID().uuidString]
            try ProfileSync.saveSecret("pendingJoin", data: JSONEncoder().encode(value)); pending = true
        }
        guard let t = value["token"], !t.isEmpty, let code = value["code"], !code.isEmpty,
              let localIDString = value["localID"], let id = UUID(uuidString: localIDString) else {
            throw SyncFailure(code: 400, message: L.syncErrJoinCorrupt)
        }
        _ = try await ProfileSync.request("join", method: "POST", token: t, body: ProfileSync.json(["code": code, "deviceName": UIDevice.current.name]))
        let data = try await ProfileSync.request("claim", method: "POST", token: t, body: ProfileSync.json(["code": code]))
        if (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["status"] as? String != "approved" { message = L.syncWaitingOwner; return }
        let s = try JSONDecoder().decode(SyncSnapshot.self, from: data)
        let c = clusters.first { $0.id == id } ?? QRCluster(name: s.document.name, sortOrder: clusters.count)
        c.id = id
        // Insert and save only after the complete remote snapshot can be downloaded.
        try await ProfileSync.apply(s, to: c, context: context, token: t)
        guard let deviceId = s.deviceId, !s.profileId.isEmpty else { throw SyncFailure(code: 502, message: L.syncErrDeviceIncomplete) }
        let b = SyncBinding(profileId: s.profileId, deviceId: deviceId, token: t, role: "member", revision: s.revision, baseline: ProfileSync.document(c, images: try ProfileSync.images(c)))
        try ProfileSync.save(b, for: c.id); try ProfileSync.saveSecret("pendingJoin", data: nil)
        selected = c.id; pending = false; self.code = ""; message = L.syncJoined
    }
    private func normalizeCode(_ value: String) -> String { let clean = value.replacingOccurrences(of: "-", with: "").uppercased().filter { ($0 >= "0" && $0 <= "9") || ($0 >= "A" && $0 <= "Z") }; return clean.count == 32 ? clean.lowercased() : clean }
    private func formatCode(_ value: String) -> String { let c = normalizeCode(value); return stride(from: 0, to: c.count, by: 4).map { String(c[c.index(c.startIndex, offsetBy: $0)..<c.index(c.startIndex, offsetBy: min($0 + 4, c.count))]) }.joined(separator: "-") }
    private func syncCard(_ c: QRCluster, resolution: String? = nil) async throws {
        do { try await ProfileSync.sync(c, context: context, resolution: resolution); message = L.syncDone }
        catch { if (error as? SyncFailure)?.code == 409 { conflict = true }; throw error }
    }
    private func resolve(_ choice: String) { if let c = cluster { run { try await syncCard(c, resolution: choice) } } }
    private func disconnect() async throws {
        guard let c = cluster, let b = binding else { return }
        let path = "profiles/\(b.profileId)" + (b.role == "owner" ? "" : "/devices/\(b.deviceId)")
        _ = try await ProfileSync.request(path, method: "DELETE", token: b.token)
        try ProfileSync.save(nil, for: c.id); devices = nil; invite = ""; message = L.syncStopped
    }
}
