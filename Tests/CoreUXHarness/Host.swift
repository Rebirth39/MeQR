import SwiftUI
import SwiftData
import CryptoKit

@main struct CoreUXHost: App {
    let container: ModelContainer
    let originalAvatarDigest: String
    @StateObject private var announcements = AnnouncementManager()
    init() {
        let schema = Schema([QRCluster.self, QRProfile.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        AppSettings.shared.selectedLanguage = .zhHans
        URLProtocol.registerClass(AuditTransport.self)
        let fixtureID = UUID(uuidString: "91B49C6D-7698-4D80-A170-7E7A4D1A68D0")!
        try! ProfileSync.save(nil, for: fixtureID)
        var digest = "none"
        if !ProcessInfo.processInfo.arguments.contains("empty") {
            for index in 0..<2 {
                let cluster = QRCluster(name: index == 0 ? "Audit One" : "Audit Two", subtitle: "Core UI audit", sortOrder: index)
                if index == 0 { cluster.id = fixtureID }
                var profiles = [QRProfile(platformType: "qq", qrContent: "https://qm.qq.com/q/audit"), QRProfile(platformType: "wechat", qrContent: "https://u.wechat.com/audit")]
                if ProcessInfo.processInfo.arguments.contains("single") { profiles.removeLast() }
                if ProcessInfo.processInfo.arguments.contains("three") {
                    profiles.append(QRProfile(platformType: "github", qrContent: "https://github.com/audit"))
                }
                cluster.widgetProfileIndex = profiles.count - 1
                if index == 0 && ProcessInfo.processInfo.arguments.contains("synced") {
                    try! ProfileSync.save(SyncBinding(profileId: "ui-test-only", deviceId: "ui-test-only", token: "ui-test-only", role: "owner", revision: 1), for: cluster.id)
                }
                container.mainContext.insert(cluster)
                for profile in profiles { profile.attach(to: cluster, in: container.mainContext) }
                if ProcessInfo.processInfo.arguments.contains("avatar") {
                    let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
                        for y in 0..<64 {
                            for x in 0..<64 {
                                UIColor(red: CGFloat((x*17+y*5)%256)/255, green: CGFloat((x*3+y*19)%256)/255, blue: CGFloat((x*7+y*11)%256)/255, alpha: 1).setFill()
                                ctx.fill(CGRect(x:x,y:y,width:1,height:1))
                            }
                        }
                    }
                    cluster.avatarImageData = image.jpegData(compressionQuality: 0.9)!
                    digest = MeQRExchangeCodeRecord.digest(cluster.avatarImageData!)
                }
                container.mainContext.insert(cluster)
            }
        }
        try! container.mainContext.save()
        originalAvatarDigest = digest
    }
    var body: some Scene {
        WindowGroup {
            AuditRoot(originalDigest: originalAvatarDigest)
                .environmentObject(announcements)
                .environment(\.appSettings, AppSettings.shared)
                .modelContainer(container)
        }
    }
}
struct AuditRoot: View {
    let originalDigest: String
    @Query(sort: \QRCluster.sortOrder) var clusters: [QRCluster]
    @Query private var profiles: [QRProfile]
    var body: some View {
        VStack(spacing: 0) {
            MainView()
            Text("clusters=\(clusters.count);profiles=\(profiles.count);widget=\(clusters.first?.widgetProfileIndex ?? -1)")
                .font(.caption2).accessibilityIdentifier("audit-store")
            if ProcessInfo.processInfo.arguments.contains("avatar") {
                Text(originalDigest).accessibilityIdentifier("original-avatar-digest")
                Text(clusters.first?.avatarImageData.map(MeQRExchangeCodeRecord.digest) ?? "none").accessibilityIdentifier("current-avatar-digest")
            }
        }
    }
}
final class AuditTransport: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
