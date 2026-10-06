import SwiftUI
import SwiftData

private let exactQQ = "https://qm.qq.com/q/lNrSSk9uFy"

@main struct CoreUXHost: App {
    let container: ModelContainer
    @StateObject private var announcements = AnnouncementManager()
    init() {
        URLProtocol.registerClass(AuditTransport.self)
        AppSettings.shared.selectedLanguage = .zhHans
        let schema = Schema([QRCluster.self, QRProfile.self])
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("relationship-audit.store")
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        container.mainContext.autosaveEnabled = false
        if !ProcessInfo.processInfo.arguments.contains("readback") {
            for c in try! container.mainContext.fetch(FetchDescriptor<QRCluster>()) { container.mainContext.delete(c) }
            for p in try! container.mainContext.fetch(FetchDescriptor<QRProfile>()) { container.mainContext.delete(p) }
            try! container.mainContext.save()
            if ProcessInfo.processInfo.arguments.contains("existing") {
                let c = QRCluster(name: "Existing")
                let p = QRProfile(platformType: "custom", qrContent: "fixture")
                p.attach(to: c, in: container.mainContext)
                try! container.mainContext.save()
            }
        }
    }
    var body: some Scene {
        WindowGroup {
            AuditRoot().modelContainer(container)
                .environmentObject(announcements)
                .environment(\.appSettings, AppSettings.shared)
        }
    }
}

struct AuditRoot: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \QRCluster.sortOrder) private var clusters: [QRCluster]
    @Query private var profiles: [QRProfile]
    @State private var showNew = false
    @State private var showExisting = false
    @State private var showGuide = false
    @State private var result = "waiting"
    var body: some View {
        VStack {
            if showGuide {
                OnboardingView(hasExistingCards: false, onFinish: { showGuide = false }, onSkip: { showGuide = false })
            } else {
                Button("New Card") { showNew = true }
                Button("Add To Existing") { showExisting = true }
                Button("Guide") { showGuide = true }
                ForEach(clusters) { c in Text(c.name) }
            }
            Text("cards=\(clusters.count);profiles=\(profiles.count);qq=\(profiles.filter { $0.qrContent == exactQQ }.count)")
                .accessibilityIdentifier("audit-store").font(.caption2)
            Text(result).accessibilityIdentifier("model-result").font(.caption2)
        }
        .sheet(isPresented: $showNew) { AddProfileView() }
        .sheet(isPresented: $showExisting) {
            if let c = clusters.first { AddProfileView(addToCluster: c) }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("model-checks") {
                do { result = try await runModelChecks() }
                catch { result = "FAIL: \(error)" }
            }
        }
    }
}

struct CheckFailure: Error { let message: String }
@MainActor private func runModelChecks() async throws -> String {
    func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message: message) }
    }
    let schema = Schema([QRCluster.self, QRProfile.self])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("checks-\(UUID()).store")
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let c = QRCluster(name: "QQ Card", subtitle: "fallback", backgroundColorHex: "#FAFAFA")
    let p = QRProfile(platformType: "qq", qrContent: exactQQ)
    p.attach(to: c, in: context)
    try check(p.modelContext === context && c.modelContext === context, "both models registered")
    try check(c.profiles.count == 1 && p.cluster === c && p.name == "QQ Card", "inverse and fallback")
    p.attach(to: c, in: context)
    try check(c.profiles.count == 1, "repeated attach must not duplicate")
    try context.save()
    let second = QRProfile(platformType: "wechat", qrContent: "https://u.wechat.com/audit")
    second.attach(to: c, in: context)
    try context.save()
    let reader = ModelContext(container)
    let readCards = try reader.fetch(FetchDescriptor<QRCluster>())
    try check(readCards.count == 1 && readCards[0].profiles.count == 2, "persist and refetch")
    try check(readCards[0].profiles.allSatisfy { $0.cluster?.id == c.id }, "inverse survives refetch")
    let moved = QRCluster(name: "Moved")
    second.attach(to: moved, in: context)
    try context.save()
    try check(c.profiles.count == 1 && moved.profiles.count == 1, "reparent updates both inverses")
    let orphan = QRProfile(platformType: "custom", qrContent: "legacy")
    orphan.name = "Legacy"
    context.insert(orphan)
    try context.save()
    try MigrationManager.performClusterMigrationIfNeeded(context: context)
    try check(orphan.cluster?.name == "Legacy", "orphan migration")
    let all = try context.fetch(FetchDescriptor<QRCluster>())
    guard let exported = BackupManager.exportBackup(clusters: all) else { throw CheckFailure(message: "export") }
    let restoreContainer = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    let restored = restoreContainer.mainContext
    try check(BackupManager.importBackup(from: exported, modelContext: restored), "import backup")
    let restoredCards = try restored.fetch(FetchDescriptor<QRCluster>())
    let restoredProfiles = try restored.fetch(FetchDescriptor<QRProfile>())
    try check(restoredCards.count == 3 && restoredProfiles.count == 3, "backup cardinality")
    try check(restoredProfiles.allSatisfy { $0.cluster != nil } && restoredProfiles.contains { $0.qrContent == exactQQ }, "backup relationships and content")
    // Exercise sync growth and shrink without any assets or network access.
    var doc = ProfileSync.document(c, images: [:])
    doc.qrItems.append(.init(platform: "github", customPlatformName: "", qrContent: "https://github.com/audit"))
    try await ProfileSync.apply(.init(profileId: "synthetic", revision: 1, document: doc), to: c, context: context, token: "synthetic")
    try check(c.profiles.count == 2 && c.profiles.allSatisfy { $0.cluster === c }, "sync add")
    doc.qrItems.removeLast()
    try await ProfileSync.apply(.init(profileId: "synthetic", revision: 2, document: doc), to: c, context: context, token: "synthetic")
    try check(c.profiles.count == 1, "sync remove")
    let deleteID = moved.id
    context.delete(moved)
    try context.save()
    let remaining = try ModelContext(container).fetch(FetchDescriptor<QRProfile>())
    try check(remaining.count == 2 && !remaining.contains { $0.cluster?.id == deleteID }, "cascade deletion")
    // Drafts stay completely outside persistence and still render the exact QR.
    let draft = QRCluster(name: "Preview", backgroundColorHex: "#FAFAFA")
    let draftProfile = QRProfile(platformType: "qq", qrContent: exactQQ)
    draftProfile.captureClusterFallback(from: draft)
    let renderer = ImageRenderer(content: ClusterCardView(cluster: draft, containerWidth: 390, previewProfiles: [draftProfile]))
    guard let previewImage = renderer.uiImage else { throw CheckFailure(message: "draft renders") }
    let decoded = try await QRCodeGenerator.decode(from: previewImage)
    try check(decoded == exactQQ, "draft QR is scannable and preserves content")
    try check(draft.modelContext == nil && draftProfile.modelContext == nil && draftProfile.cluster == nil && draft.profiles.isEmpty, "draft has no persistence relationships")
    return "PASS: registration,inverse,idempotence,refetch,reparent,migration,backup,sync,cascade,preview"
}

final class AuditTransport: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
