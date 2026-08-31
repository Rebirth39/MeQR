import SwiftUI
import SwiftData

@main
struct QRIDApp: App {
    private let modelBootstrap: ModelContainerBootstrap = {
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
            return ModelContainerBootstrap(
                container: try ModelContainer(for: schema, configurations: [configuration]),
                errorMessage: nil
            )
        } catch {
            let persistentError = error
            let fallbackConfiguration = ModelConfiguration(
                "QRID-Recovery",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                return ModelContainerBootstrap(
                    container: try ModelContainer(for: schema, configurations: [fallbackConfiguration]),
                    errorMessage: persistentError.localizedDescription
                )
            } catch {
                return ModelContainerBootstrap(
                    container: nil,
                    errorMessage: "\(persistentError.localizedDescription)\n\n\(error.localizedDescription)"
                )
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let container = modelBootstrap.container {
                AppRootView(startupError: modelBootstrap.errorMessage)
                    .environment(\.appSettings, AppSettings.shared)
                    .onOpenURL { _ in
                        // Widget tap opens app via meqr://open
                    }
                    .background {
                        WidgetSyncView()
                    }
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    "无法载入本地数据",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(modelBootstrap.errorMessage ?? "未知错误")
                )
            }
        }
    }
}

private struct ModelContainerBootstrap {
    let container: ModelContainer?
    let errorMessage: String?
}

struct AppRootView: View {
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @AppStorage(OnboardingStorage.completionKey) private var hasCompletedOnboarding = false
    @State private var startupError: String?

    init(startupError: String? = nil) {
        _startupError = State(initialValue: startupError)
    }

    var body: some View {
        MainView()
            .fullScreenCover(isPresented: onboardingPresentation) {
                OnboardingView(
                    hasExistingCards: !clusters.isEmpty,
                    onFinish: { hasCompletedOnboarding = true },
                    onSkip: { hasCompletedOnboarding = true }
                )
                .interactiveDismissDisabled()
            }
            .alert("本地数据暂时无法载入", isPresented: startupErrorPresentation) {
                Button("好", role: .cancel) {
                    startupError = nil
                }
            } message: {
                Text("App 已进入临时恢复模式，本次修改不会保存。原有数据没有被删除。\n\n\(startupError ?? "")")
            }
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )
    }

    private var startupErrorPresentation: Binding<Bool> {
        Binding(
            get: { startupError != nil },
            set: { if !$0 { startupError = nil } }
        )
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
