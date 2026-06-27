import SwiftUI
import SwiftData

@main
struct QRIDApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([QRCluster.self, QRProfile.self])
        let fileManager = FileManager.default

        do {
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeDirectoryURL = appSupportURL.appendingPathComponent("QRID", isDirectory: true)
            try fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)

            let configuration = ModelConfiguration(
                "QRID",
                schema: schema,
                url: storeDirectoryURL.appendingPathComponent("QRID.store"),
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.appSettings, AppSettings.shared)
                .onOpenURL { url in
                    // Widget tap opens app via meqr://open
                    print("Opened from URL: \(url)")
                }
                .background {
                    WidgetSyncView()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

struct WidgetSyncView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \QRCluster.sortOrder) private var clusters: [QRCluster]

    var body: some View {
        Color.clear
            .onAppear {
                WidgetDataHelper.sync(clusters: clusters)
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    WidgetDataHelper.sync(clusters: clusters)
                }
            }
    }
}
