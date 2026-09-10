import SwiftUI
import SwiftData

enum AppLanguage: Sendable { case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum AppSettings { static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = ProcessInfo.processInfo.arguments.contains("chinese") ? .zhHans : .en }
}
@Model final class QRProfile {
    var cluster: QRCluster?
    init() {}
}

@main struct TagUXHost: App {
    var body: some Scene { WindowGroup { Host() } }
}

struct Host: View {
    @State private var tags = "Project Sekai\nHatsune Miku"
    @State private var overrides: [String: CardTagColorOverride] = [:]
    @State private var report = false
    @State private var library = false
    @State private var persistence = ""
    init() {
        if ProcessInfo.processInfo.arguments.contains("palette") {
            _overrides = State(initialValue: ["projectsekai": CardTagColorOverride(mode: .custom, hexes: ["#123456", "#ABCDEF", "#FF9900", "#EE1166", "#FFFFFF"])])
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardTagInputView(text: $tags, colorOverrides: overrides)
                    Button("Library") { library = true }
                    Button("New Request") { report = true }
                }
                CardTagColorEditor(tagInput: tags, colorOverrides: $overrides)
                Section {
                    Text(overrides["projectsekai"]?.hexes.joined(separator: ",") ?? "").accessibilityIdentifier("stored-palette")
                    Text(overrides["hatsunemiku"]?.hexes.joined(separator: ",") ?? "").accessibilityIdentifier("copied-palette")
                    Text(persistence).accessibilityIdentifier("persistence")
                }
            }
            .navigationTitle("Tag UX")
            .sheet(isPresented: $library) { CardTagCatalogBrowser(text: $tags, colorOverrides: overrides) }
            .sheet(isPresented: $report) {
                CardTagReportView(tag: "New Character", isNewTag: true, submitReport: { payload in
                    guard payload["work"] == "Example IP", payload["reason"] == "request" else { throw CardTagReportClient.Failure.rejected }
                    return "MEQR-20260908-ABCDEF"
                })
            }
            .task {
                await RemoteTagCatalog.shared.refreshIfNeeded()
                do {
                    let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".store")
                    let config = ModelConfiguration(url: url)
                    let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: config)
                    let context = ModelContext(container)
                    let cluster = QRCluster(name: "Fixture", tagListRawValue: "世界计划", tagColorOverridesRawValue: "{\"世界计划\":\"#123456\"}")
                    context.insert(cluster); try context.save()
                    let reopened = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: config)
                    let loaded = try ModelContext(reopened).fetch(FetchDescriptor<QRCluster>())[0]
                    guard loaded.tagColorStyle(for: loaded.tags[0]).leadingHex == "#123456", loaded.tagReferencesRawValue != nil else { throw CocoaError(.coderReadCorrupt) }
                    persistence = "Storage passed"
                } catch { persistence = error.localizedDescription }
            }
        }
        .frame(maxWidth: ProcessInfo.processInfo.arguments.contains("narrow") ? 320 : .infinity)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("large") ? .accessibility1 : .large)
        .preferredColorScheme(.light)
    }
}
