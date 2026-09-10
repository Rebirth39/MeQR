import SwiftUI

enum AppLanguage: Sendable {
    case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum AppSettings {
    static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = .zhHans }
}
extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

@main struct CardLayoutHost: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("scanner-sheet") {
            UserDefaults.standard.removeObject(forKey: "meqr_encounter_records_v1")
            UserDefaults.standard.removeObject(forKey: "meqr_encounter_pending_sessions_v1")
        }
        if ProcessInfo.processInfo.arguments.contains("exchange-ui") || ProcessInfo.processInfo.arguments.contains("encounter-sync") || ProcessInfo.processInfo.arguments.contains("encounter-delivery") || ProcessInfo.processInfo.arguments.contains("scanner-sheet") || ProcessInfo.processInfo.arguments.contains("redirect-test") {
            URLProtocol.registerClass(ExchangeTransport.self)
        }
    }
    var body: some Scene { WindowGroup { Host() } }
}

struct Host: View {
    @State private var clusters: [QRCluster]
    @State private var page = 0
    @State private var exchangeResult = ""
    @State private var subtitleResult = ""
    @State private var showingExchange = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let subtitle = arguments.contains("long")
            ? "生理男 心理中性 常驻深港\n初音未来重度依赖（友情向梦）\n全栈开发者\nmaimai（国服 w47・国际服 w46）\n世界计划（国・日服）（ws 团推，不吃 CP 只吃 CB 团魂）\n少女乐队\n原神（淡坑）"
            : "test info"
        let cluster = QRCluster(name: "重生 Rebirth", subtitle: arguments.contains("custom-subtitle") ? "Full card introduction\nSecond line belongs online\nThird line also belongs online" : subtitle, backgroundColorHex: "#DDEEF5", tagListRawValue: arguments.contains("tags") ? "世界计划\n初音未来\n少女乐队\n原神\nLoveLive!\n自定义标签" : nil)
        cluster.profiles = [QRProfile(platformType: "qq", qrContent: "https://example.com/qq"), QRProfile(platformType: "wechat", qrContent: "https://example.com/wechat")]
        if arguments.contains("rhodes-front") {
            cluster.templateStyle = .rhodesPass
            cluster.qrColorHex = "#39C5BB"
            cluster.backgroundImageData = try! Data(contentsOf: Bundle.main.url(forResource: "BG", withExtension: "jpg")!)
            cluster.profiles = [QRProfile(platformType: "qq", qrContent: "https://qm.qq.com/q/lNrSSk9uFy"),
                                QRProfile(platformType: "wechat", qrContent: "https://u.wechat.com/fixture"),
                                QRProfile(platformType: "github", qrContent: "https://github.com/fixture")]
        }
        if arguments.contains("preview-images") {
            cluster.profiles = [QRProfile(platformType: "qq", qrContent: "https://qm.qq.com/q/fixture"),
                                QRProfile(platformType: "wechat", qrContent: "https://u.wechat.com/fixture"),
                                QRProfile(platformType: "github", qrContent: arguments.contains("untrusted-link") ? "https://github.com.evil.test/fixture" : "https://github.com/fixture")]
        }
        if arguments.contains("custom-subtitle") {
            UserDefaults.standard.set("Only shared intro", forKey: "meqr.exchange.subtitle.\(cluster.id.uuidString)")
        }
        _clusters = State(initialValue: [cluster])
    }

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("redirect-test") {
            Text(exchangeResult).accessibilityIdentifier("redirect-result").task {
                ExchangeTransport.redirects = [
                    "https://xhslink.com/m/AbCd": "https://xhslink.com/m/Second",
                    "https://xhslink.com/m/Second": "https://www.xiaohongshu.com/user/profile/abcdef0123456789abcdef01",
                    "https://xhslink.com/m/Unsafe": "https://evil.test/user/profile/abcdef0123456789abcdef01",
                    "https://xhslink.com/m/Loop": "https://xhslink.com/m/Loop"
                ]
                let resolved = await ScannerRedirectFixture.resolveXiaohongshuRedirect(URL(string: "https://xhslink.com/m/AbCd")!)
                let unsafe = await ScannerRedirectFixture.resolveXiaohongshuRedirect(URL(string: "https://xhslink.com/m/Unsafe")!)
                let loop = await ScannerRedirectFixture.resolveXiaohongshuRedirect(URL(string: "https://xhslink.com/m/Loop")!)
                exchangeResult = resolved.flatMap(QRLinkPolicy.xiaohongshuProfileID) == "abcdef0123456789abcdef01" &&
                    unsafe == nil && loop == nil && ExchangeTransport.requests == 4 ? "RED redirects passed" : "RED redirects failed: resolved=\(resolved?.absoluteString ?? "nil") unsafe=\(unsafe?.absoluteString ?? "nil") loop=\(loop?.absoluteString ?? "nil") requests=\(ExchangeTransport.requests)"
            }
        } else if ProcessInfo.processInfo.arguments.contains("scanner-sheet") {
            ScannerSheetHost(cluster: clusters[0])
                .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("large") ? .xxxLarge : .large)
        } else {
        NavigationStack {
            ClusterCardPager(clusters: clusters, currentPage: $page) { _ in }
                .overlay(alignment: .bottom) {
                    if ProcessInfo.processInfo.arguments.contains("exchange") || ProcessInfo.processInfo.arguments.contains("exchange-ui") || ProcessInfo.processInfo.arguments.contains("encounter-sync") || ProcessInfo.processInfo.arguments.contains("encounter-delivery") {
                        VStack {
                            Text(exchangeResult).accessibilityIdentifier("exchange-result")
                            Text(subtitleResult).accessibilityIdentifier("subtitle-result")
                            if ProcessInfo.processInfo.arguments.contains("custom-subtitle") {
                                Button("Seed incorrect online intro") {
                                    let store = MeQRExchangeCodeStore()
                                    let file = store.directory.appendingPathComponent(clusters[0].id.uuidString + ".json")
                                    do {
                                        let cached = try JSONDecoder().decode(MeQRExchangeCodeRecord.self, from: Data(contentsOf: file))
                                        var online = cached.onlineProfile
                                        online.subtitle = "Only shared intro"
                                        let incorrect = MeQRExchangeCodeRecord(fingerprint: cached.fingerprint, payload: cached.payload,
                                            avatarJPEG: cached.avatarJPEG, sessionID: cached.sessionID, ownerToken: cached.ownerToken,
                                            onlineProfile: online, eventID: cached.eventID, synced: true)
                                        try store.save(incorrect, clusterID: clusters[0].id)
                                    } catch { exchangeResult = error.localizedDescription }
                                }
                            }
                        }
                    }
                }
                .task {
                    if ProcessInfo.processInfo.arguments.contains("encounter-delivery") {
                        do {
                            try await verifyEncounterDelivery(cluster: clusters[0])
                            exchangeResult = "Encounter delivery and 1.1.0 compatibility passed"
                        } catch { exchangeResult = error.localizedDescription }
                        return
                    }
                    if ProcessInfo.processInfo.arguments.contains("encounter-sync") {
                        do {
                            let eventStore = EventStore.shared
                            eventStore.addCustomEvent(title: "Original event", venue: "Original venue", address: "", date: Date(), details: "")
                            let event = eventStore.activeEvent!
                            eventStore.addCustomEvent(title: "Other event", venue: "Other venue", address: "", date: Date(), details: "")
                            let peer = MeQRExchangeProfile(cluster: clusters[0], avatarMaxBytes: 0)
                            let peerObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(peer))
                            let store = EncounterStore.shared
                            for reusable in [true, false] {
                                let sessionID = UUID().uuidString
                                var response: [String: Any] = ["sessionId": sessionID, "status": "confirmed", "eventId": event.id.uuidString, "reusable": reusable]
                                if reusable {
                                    response["confirmations"] = [["id": "peer", "profile": peerObject, "confirmedAt": 1_780_000_000_000.0]]
                                } else { response["peerProfile"] = peerObject }
                                ExchangeTransport.responseData = try JSONSerialization.data(withJSONObject: response)
                                store.registerOutgoingSession(sessionID, ownerToken: "test-owner")
                                await store.syncPendingSessions()
                                guard let record = store.records.first(where: { $0.sessionID == sessionID + (reusable ? ":peer" : "") }),
                                      record.eventID == event.id, record.eventTitle == event.title, record.eventVenue == event.venue else {
                                    throw CocoaError(.coderReadCorrupt)
                                }
                            }
                            exchangeResult = "Encounter event sync passed"
                        } catch { exchangeResult = error.localizedDescription }
                        return
                    }
                    guard ProcessInfo.processInfo.arguments.contains("exchange") else { return }
                    do {
                        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        let store = MeQRExchangeCodeStore(directory: directory)
                        let cluster = clusters[0]
                        let credentials = MeQRExchangeCodeRecord.credentials()
                        let online = MeQRExchangeProfile(cluster: cluster, avatarMaxBytes: 0)
                        let offline = MeQRExchangeProfile(offlineCluster: cluster, profile: cluster.profiles.first)
                        let payload = try MeQRExchangeCodec.encodeHybrid(remoteURL: "https://profile.meqrcode.cn/encounter-sessions/" + credentials.sessionID, offlineProfile: offline)
                        let record = MeQRExchangeCodeRecord(fingerprint: "first", payload: payload, avatarJPEG: nil,
                            sessionID: credentials.sessionID, ownerToken: credentials.ownerToken, onlineProfile: online, eventID: nil, synced: false)
                        try store.save(record, clusterID: cluster.id)
                        let reopened = MeQRExchangeCodeStore(directory: directory)
                        guard var loaded = reopened.load(clusterID: cluster.id, fingerprint: "first"), loaded.payload == payload,
                              loaded.onlineProfile.id == cluster.id, !loaded.synced,
                              reopened.load(clusterID: cluster.id, fingerprint: "changed") == nil,
                              MeQRExchangeCodec.offlineFallback(from: payload)?.id == cluster.id,
                              !payload.contains(credentials.ownerToken) else { throw CocoaError(.coderReadCorrupt) }
                        loaded.synced = true
                        try store.save(loaded, clusterID: cluster.id)
                        guard store.load(clusterID: cluster.id, fingerprint: "first")?.payload == payload else { throw CocoaError(.coderReadCorrupt) }
                        var mismatchedOnline = online
                        mismatchedOnline.subtitle = "Outdated original intro"
                        let legacyRecord = MeQRExchangeCodeRecord(fingerprint: "first", payload: payload, avatarJPEG: nil,
                            sessionID: credentials.sessionID, ownerToken: credentials.ownerToken,
                            onlineProfile: mismatchedOnline, eventID: nil, synced: true)
                        try store.save(legacyRecord, clusterID: cluster.id)
                        guard store.load(clusterID: cluster.id, fingerprint: "first")?.onlineProfile.subtitle == mismatchedOnline.subtitle else { throw CocoaError(.coderReadCorrupt) }
                        exchangeResult = "Exchange cache passed"
                    } catch { exchangeResult = error.localizedDescription }
                }
                .navigationTitle("喜劳转扩")
                .sheet(isPresented: $showingExchange, onDismiss: {
                    let directory = MeQRExchangeCodeStore().directory
                    if let data = try? Data(contentsOf: directory.appendingPathComponent(clusters[0].id.uuidString + ".json")),
                       let record = try? JSONDecoder().decode(MeQRExchangeCodeRecord.self, from: data) {
                        exchangeResult = MeQRExchangeCodeRecord.digest(Data(record.payload.utf8)) + ":" + String(ExchangeTransport.requests)
                        let offline = MeQRExchangeCodec.offlineFallback(from: record.payload)
                        subtitleResult = record.onlineProfile.subtitle + "|" + (offline?.subtitle ?? "missing") + "|" + (offline?.intro ?? "missing")
                    }
                }) { MeQRProfileCodeView(cluster: clusters[0]) }
                .toolbar {
                    if ProcessInfo.processInfo.arguments.contains("exchange-ui") {
                        Button("Exchange") { showingExchange = true }
                        Button("Change name") { clusters[0].name += " changed" }
                    }
                    Button("Toggle second") {
                        if clusters.count == 1 {
                            let cluster = QRCluster(name: "Second", subtitle: "test", backgroundColorHex: "#EEEEEE")
                            cluster.profiles = [QRProfile(qrContent: "https://example.com/second")]
                            clusters.append(cluster)
                        } else {
                            page = 0
                            clusters.removeLast()
                        }
                    }
                }
        }
        .frame(maxWidth: ProcessInfo.processInfo.arguments.contains("narrow") ? 320 : .infinity)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("large") ? .accessibility1 : .large)
        .preferredColorScheme(.light)
        }
    }
}

struct QRScannerRepresentable: View {
    static var payload = "https://profile.meqrcode.cn/encounter-sessions/NativeSheet01"
    let onScan: (String, UIImage?) -> Void
    var body: some View {
        Button("Scan session fixture") {
            onScan(Self.payload, nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScannerSheetHost: View {
    let cluster: QRCluster
    @ObservedObject private var store = EncounterStore.shared
    @ObservedObject private var opener = PlatformOpenProbe.shared
    var body: some View {
        VStack {
            MeQRScannerView(localCluster: cluster)
            Text(store.records.first?.sessionID ?? "No saved session")
                .accessibilityIdentifier("saved-session")
            Text(store.records.first?.pendingConfirmationProfile?.subtitle ?? "No pending reply")
                .accessibilityIdentifier("pending-intro")
            Text(opener.latest).accessibilityIdentifier("last-opened-url")
        }
        .task {
            var profile = MeQRExchangeProfile(cluster: cluster, avatarMaxBytes: 0)
            if ProcessInfo.processInfo.arguments.contains("preview-images") {
                profile.backgroundJPEGBase64 = try! Data(contentsOf: Bundle.main.url(forResource: "BG", withExtension: "jpg")!).base64EncodedString()
                let banner = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 300)).image { context in
                    UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 800, height: 300))
                }
                profile.bannerJPEGBase64 = banner.jpegData(compressionQuality: 0.8)!.base64EncodedString()
            }
            let object = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(profile))
            ExchangeTransport.responseData = try! JSONSerialization.data(withJSONObject: [
                "sessionId": "NativeSheet01", "creatorProfile": object, "status": "waiting"
            ])
            if ProcessInfo.processInfo.arguments.contains("offline-scan") {
                let offline = MeQRExchangeProfile(offlineCluster: cluster, profile: cluster.profiles.first)
                QRScannerRepresentable.payload = try! MeQRExchangeCodec.encodeHybrid(
                    remoteURL: QRScannerRepresentable.payload, offlineProfile: offline)
                ExchangeTransport.responseStatus = 503
            }
        }
    }
}

@MainActor final class PlatformOpenProbe: ObservableObject {
    static let shared = PlatformOpenProbe()
    @Published var latest = "No URL opened"
    static func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:]) async -> Bool {
        shared.latest = url.absoluteString
        return true
    }
}

final class ExchangeTransport: URLProtocol {
    static var requests = 0
    static var responseData = Data("{}".utf8)
    static var responseStatus = 200
    static var lastBody: Data?
    static var redirects: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        if let target = Self.redirects[request.url!.absoluteString] {
            let response = HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: nil, headerFields: ["Location": target])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: URL(string: target)!), redirectResponse: response)
            return
        }
        if let body = request.httpBody { Self.lastBody = body }
        else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            Self.lastBody = data
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseStatus, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
private func verifyEncounterDelivery(cluster: QRCluster) async throws {
    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "EncounterDelivery", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    let suite = "encounter-delivery-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = EncounterStore(defaults: defaults)
    let scanned = MeQRExchangeProfile(cluster: cluster, avatarMaxBytes: 0)
    let legacyID = "AbCd1234EfGh"
    try require(MeQRRemoteService.encounterSessionID(from: "https://profile.meqrcode.cn/encounter-sessions/\(legacyID)#meqr=test") == legacyID, "Legacy URL lost its session")
    for invalid in ["https://example.com/encounter-sessions/test", "https://profile.meqrcode.cn/encounter-sessions/test/confirm", "https://profile.meqrcode.cn/encounter-sessions/../test", "https://profile.meqrcode.cn/profiles/test"] {
        try require(MeQRRemoteService.encounterSessionID(from: invalid) == nil, "Invalid session URL accepted")
    }
    cluster.subtitle = "Full introduction\nSecond line\nThird line"
    UserDefaults.standard.set("Only short intro", forKey: "meqr.exchange.subtitle.\(cluster.id.uuidString)")
    let selected = cluster.profiles.last!
    UserDefaults.standard.set([selected.id.uuidString], forKey: "meqr.exchange.selectedProfiles.\(cluster.id.uuidString)")
    UserDefaults.standard.set(selected.id.uuidString, forKey: "meqr.exchange.offlineProfile.\(cluster.id.uuidString)")
    let online = ScannerReplyFixture(localCluster: cluster).localProfile(forOffline: false)!
    let offline = ScannerReplyFixture(localCluster: cluster).localProfile(forOffline: true)!
    try require(online.subtitle == cluster.subtitle && online.intro.isEmpty, "Online reply lost full intro")
    try require(offline.subtitle == "Only short intro" && offline.intro.isEmpty, "Offline reply leaked full intro")
    try require(online.profiles.map(\.qrContent) == [selected.qrContent] && offline.profiles.map(\.qrContent) == [selected.qrContent], "Reply ignored platform selection")
    try require(L.encounterWaitingForPeer(7).contains("7") && !L.encounterWaitingForPeer(7).contains("(count)"), "Count interpolation failed")

    store.saveScannedProfile(scanned, sessionID: legacyID, peerProfile: online)
    try require(store.records.count == 1 && store.pendingConfirmationCount == 1, "Save did not queue reply")
    let staleEditorCopy = store.records[0]
    ExchangeTransport.responseStatus = 503
    await store.syncConfirmations()
    try require(store.pendingConfirmationCount == 1, "Failed reply was discarded")
    let reloaded = EncounterStore(defaults: defaults)
    try require(reloaded.pendingConfirmationCount == 1, "Reply was lost on reload")
    ExchangeTransport.responseStatus = 200
    await reloaded.syncPendingSessions()
    try require(reloaded.pendingConfirmationCount == 0 && reloaded.records[0].confirmationSentAt != nil, "Reply without outgoing sessions did not retry")
    reloaded.update(staleEditorCopy)
    try require(reloaded.pendingConfirmationCount == 0, "Stale detail editor resurrected reply")
    let body = try JSONSerialization.jsonObject(with: ExchangeTransport.lastBody!) as! [String: Any]
    let legacyResponse: [String: Any] = ["sessionId": legacyID, "creatorProfile": NSNull(), "peerProfile": body["peerProfile"]!, "eventId": NSNull(), "status": "confirmed"]
    let responseData = try JSONSerialization.data(withJSONObject: legacyResponse)
    let legacyDecoded = try JSONDecoder().decode(Release110EncounterSession.self, from: responseData)
    try require(legacyDecoded.peerProfile?.subtitle == online.subtitle && legacyDecoded.status == "confirmed", "App Store decoder rejected online reply")
    let requests = ExchangeTransport.requests
    reloaded.saveScannedProfile(scanned, sessionID: legacyID, peerProfile: online)
    await reloaded.syncConfirmations()
    try require(reloaded.records.count == 1 && ExchangeTransport.requests == requests, "Rescan duplicated confirmed exchange")

    let offlineID = "v2-" + String(repeating: "a", count: 64)
    reloaded.saveScannedProfile(scanned, sessionID: offlineID, peerProfile: offline)
    await reloaded.syncConfirmations()
    let offlineBody = try JSONSerialization.jsonObject(with: ExchangeTransport.lastBody!) as! [String: Any]
    let legacyOffline = try JSONDecoder().decode(Release110ExchangeProfile.self, from: JSONSerialization.data(withJSONObject: offlineBody["peerProfile"]!))
    try require(legacyOffline.subtitle == "Only short intro" && legacyOffline.intro.isEmpty, "Deferred offline reply leaked full intro")
    reloaded.saveScannedProfile(scanned, sessionID: nil, peerProfile: online)
    reloaded.saveScannedProfile(scanned, sessionID: "missing-local-profile", peerProfile: nil)
    try require(reloaded.pendingConfirmationCount == 0, "One-way record created a reply")
    reloaded.saveScannedProfile(scanned, sessionID: "deleted", peerProfile: online)
    reloaded.delete(reloaded.records.first { $0.sessionID == "deleted" }!)
    try require(EncounterStore(defaults: defaults).pendingConfirmationCount == 0, "Deleted record kept an unsent reply")
    // The original 1.1.0 record has no new delivery keys; it must remain readable.
    var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(staleEditorCopy)) as! [String: Any]
    old.removeValue(forKey: "pendingConfirmationProfile")
    old.removeValue(forKey: "confirmationSentAt")
    let oldRecord = try JSONDecoder().decode(EncounterRecord.self, from: JSONSerialization.data(withJSONObject: old))
    try require(oldRecord.pendingConfirmationProfile == nil, "Old record migration invented a reply")
}
