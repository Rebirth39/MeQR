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

    private var clustersSignature: [String] {
        clusters.map { cluster in
            let profiles = cluster.profiles.sorted { $0.createdAt < $1.createdAt }
            let profileSignature = profiles
                .map { "\($0.id.uuidString)|\($0.platformType)|\($0.qrContent)|\($0.foregroundColorHex)|\($0.customPlatformName ?? "")" }
                .joined(separator: ";")
            return [
                cluster.id.uuidString,
                cluster.name,
                cluster.subtitle,
                cluster.avatarImageData?.base64EncodedString() ?? "",
                cluster.backgroundImageData?.base64EncodedString() ?? "",
                cluster.backgroundColorHex,
                cluster.borderColorHex,
                cluster.textColorHex ?? "",
                cluster.qrColorHex ?? "",
                String(cluster.cornerRadius),
                String(cluster.cardOpacity ?? 0.7),
                String(cluster.sortOrder),
                String(cluster.widgetProfileIndex ?? -1),
                String(cluster.widgetUseClusterBackground ?? true),
                cluster.widgetBackgroundImageData?.base64EncodedString() ?? "",
                String(cluster.widgetOpacity ?? 0.8),
                cluster.widgetTextColorHex ?? "",
                String(cluster.widgetSmallOffsetX ?? 0),
                String(cluster.widgetSmallOffsetY ?? 0),
                String(cluster.widgetMediumOffsetX ?? 0),
                String(cluster.widgetMediumOffsetY ?? 0),
                String(cluster.widgetLargeOffsetX ?? 0),
                String(cluster.widgetLargeOffsetY ?? 0),
                profileSignature
            ].joined(separator: "|")
        }
    }

    var body: some View {
        Color.clear
            .onAppear {
                WidgetDataHelper.sync(clusters: clusters)
            }
            .onChange(of: clustersSignature) { _, _ in
                WidgetDataHelper.sync(clusters: clusters)
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    WidgetDataHelper.sync(clusters: clusters)
                }
            }
    }
}
