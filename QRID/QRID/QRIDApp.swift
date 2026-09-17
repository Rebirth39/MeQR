import SwiftUI
import SwiftData

@main
struct QRIDApp: App {
    @StateObject private var announcementManager = AnnouncementManager()
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
                    .environmentObject(announcementManager)
                    .onAppear { announcementManager.refresh() }
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @AppStorage(OnboardingStorage.completionKey) private var hasCompletedOnboarding = false
    @State private var startupError: String?
    @State private var syncRevoked = false
    @EnvironmentObject private var announcementManager: AnnouncementManager
    @AppStorage("meqr_legal_ack_version") private var legalAckVersion = ""
    @State private var showLegalUpdate = false
    private let legalVersion = "2026-09-16"

    init(startupError: String? = nil) {
        _startupError = State(initialValue: startupError)
    }

    var body: some View {
        MainView()
            .task {
                if legalAckVersion != legalVersion { showLegalUpdate = true }
                await RemoteTagCatalog.shared.refreshIfNeeded()
                for cluster in clusters { cluster.migrateTagReferences() }
                do { try modelContext.save() } catch { startupError = error.localizedDescription }
                await CardTagOutbox.shared.drain()
                if await ProfileSync.verifyBindings(context: modelContext, clusters: clusters) > 0 { syncRevoked = true }
            }
            .sheet(isPresented: $showLegalUpdate) {
                LegalUpdateView(kind: .terms) { legalAckVersion = legalVersion; showLegalUpdate = false }
            }
            .fullScreenCover(isPresented: onboardingPresentation) {
                OnboardingView(
                    hasExistingCards: !clusters.isEmpty,
                    onFinish: { hasCompletedOnboarding = true },
                    onSkip: { hasCompletedOnboarding = true }
                )
                .interactiveDismissDisabled()
            }
            .alert(L.syncRevokedTitle, isPresented: $syncRevoked) {
                Button("好", role: .cancel) { }
            } message: {
                Text(L.syncRevokedMessage)
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

struct LegalUpdateView: View {
    enum Kind {
        case terms, privacy
        var title: String { self == .terms ? L.termsUpdateTitle : L.privacySyncTitle }
        var body: String { self == .terms ? L.termsUpdateBody : L.privacySyncBody }
        var linkLabel: String { self == .terms ? L.termsViewFull : L.privacyViewFull }
        var linkURL: URL { URL(string: self == .terms ? "https://meqrcode.cn/legal#terms" : "https://meqrcode.cn/legal#privacy")! }
    }
    let kind: Kind
    let onAccept: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(kind.title)
                        .font(.title2.bold())
                    Text(kind.body)
                        .foregroundStyle(.secondary)
                    Link(kind.linkLabel, destination: kind.linkURL)
                        .font(.headline)
                    Button(L.legalReadAndAgree) { onAccept() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .navigationTitle(L.legalImportantUpdate)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

struct WidgetSyncView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \QRCluster.sortOrder) private var clusters: [QRCluster]

    var body: some View {
        Color.clear
            .onAppear {
                WidgetDataHelper.sync(clusters: clusters)
                Task { await EncounterStore.shared.syncPendingSessions() }
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    Task { await CardTagOutbox.shared.drain() }
                    Task { await EncounterStore.shared.syncPendingSessions() }
                    WidgetDataHelper.sync(clusters: clusters)
                }
            }
    }
}
