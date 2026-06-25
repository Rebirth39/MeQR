import SwiftUI
import SwiftData

@main
struct QRIDApp: App {
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
        .modelContainer(for: [QRCluster.self, QRProfile.self])
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
            .onChange(of: clusters) { _, newClusters in
                WidgetDataHelper.sync(clusters: newClusters)
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    WidgetDataHelper.sync(clusters: clusters)
                }
            }
    }
}
