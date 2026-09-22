import SwiftUI
import SwiftData
import Photos

struct MainView: View {
    @EnvironmentObject private var announcementManager: AnnouncementManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) private var settings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @State private var currentPage = 0
    @State private var showingAddToExisting = false
    @State private var showingEditCluster = false
    @State private var showingEditQR = false
    @State private var showingDeleteOptions = false
    @State private var showingReorderClusters = false
    @State private var showingMoreSettings = false
    @State private var showingMeQRProfileCode = false
    @State private var showingMeQRScanner = false
    @State private var showingEncounters = false
    @State private var showingEvents = false
    @State private var currentSelectedProfileIndex: Int = 0
    @State private var clusterIdBeforeReorder: PersistentIdentifier?
    @State private var showSavedAlert = false
    @State private var saveError: String?
    @State private var showSaveError = false

    private var currentCluster: QRCluster? {
        clusters[safe: currentPage]
    }

    private var currentProfiles: [QRProfile] {
        currentCluster?.profiles.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    private var currentSelectedIndex: Int {
        min(currentSelectedProfileIndex, max(0, currentProfiles.count - 1))
    }

    private var navigationForegroundColor: Color {
        navigationBackgroundIsDark ? .white : .black
    }

    private var navigationColorScheme: ColorScheme {
        navigationBackgroundIsDark ? .dark : .light
    }

    private var navigationBackgroundIsDark: Bool {
        guard let currentCluster else { return false }

        if let data = currentCluster.backgroundImageData,
           let image = UIImage(data: data),
           let topLuminance = image.topAreaLuminance() {
            return topLuminance < 0.5
        }

        return currentCluster.backgroundColor.isDarkForUI
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AnnouncementBanner(manager: announcementManager)
                Group {
                    if clusters.isEmpty {
                        emptyState
                    } else {
                        contentView
                    }
                }
            }
            .background {
                if !clusters.isEmpty {
                    pageBackground.ignoresSafeArea()
                }
            }
            .navigationTitle(L.qrID)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingMeQRScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(L.scanMeQRCode)
                        if !clusters.isEmpty {
                            Menu {
                                Button {
                                    showingMeQRProfileCode = true
                                } label: {
                                    Label(L.meqrProfileCode, systemImage: "qrcode")
                                }
                                Button {
                                    showingEncounters = true
                                } label: {
                                    Label(L.encounters, systemImage: "person.2.crop.square.stack")
                                }
                                Button {
                                    showingEvents = true
                                } label: {
                                    Label(L.events, systemImage: "calendar")
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(L.meqrProfileCode)
                        }
                        Menu {
                            Button {
                                showAddNewCluster = true
                            } label: {
                                Label(L.newCluster, systemImage: "plus.circle.fill")
                            }
                            if !clusters.isEmpty {
                                Button {
                                    showingAddToExisting = true
                                } label: {
                                    Label(L.addToExistingCluster, systemImage: "rectangle.stack.badge.plus")
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .foregroundStyle(navigationForegroundColor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if !clusters.isEmpty {
                            Button {
                                showingEditCluster = true
                            } label: {
                                Label(L.editCluster, systemImage: "rectangle.3.group")
                            }
                            Button {
                                showingEditQR = true
                            } label: {
                                Label(L.editQRInCluster, systemImage: "qrcode")
                            }
                            Button {
                                clusterIdBeforeReorder = currentCluster?.persistentModelID
                                showingReorderClusters = true
                            } label: {
                                Label(L.reorderClusters, systemImage: "arrow.up.arrow.down")
                            }
                            Button(role: .destructive) {
                                showingDeleteOptions = true
                            } label: {
                                Label(L.deleteCluster, systemImage: "trash")
                            }
                            Divider()
                        }
                        Button {
                            showingMoreSettings = true
                        } label: {
                            Label(L.moreSettings, systemImage: "ellipsis.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .foregroundStyle(navigationForegroundColor)
                    }
                }
            }
            .toolbarColorScheme(navigationColorScheme, for: .navigationBar)
            .onChange(of: settings.language) { _, _ in }
            .sheet(isPresented: $showAddNewCluster) {
                AddProfileView()
            }
            .sheet(isPresented: $showingAddToExisting) {
                AddToExistingClusterView()
            }
            .sheet(isPresented: $showingEditCluster) {
                if let cluster = currentCluster {
                    EditClusterView(cluster: cluster)
                }
            }
            .sheet(isPresented: $showingEditQR) {
                if let profile = currentProfiles[safe: currentSelectedIndex] {
                    EditProfileView(profile: profile)
                }
            }
            .sheet(isPresented: $showingReorderClusters) {
                ReorderClustersView()
            }
            .sheet(isPresented: $showingMoreSettings) {
                MoreSettingsView()
            }
            .sheet(isPresented: $showingMeQRProfileCode) {
                if let cluster = currentCluster {
                    MeQRProfileCodeView(cluster: cluster)
                }
            }
            .sheet(isPresented: $showingMeQRScanner) {
                MeQRScannerView(localCluster: currentCluster)
            }
            .sheet(isPresented: $showingEncounters) {
                EncountersView()
            }
            .sheet(isPresented: $showingEvents) {
                EventCenterView()
            }
            .onChange(of: showingReorderClusters) { _, isShowing in
                if !isShowing, let savedId = clusterIdBeforeReorder {
                    if let newIndex = clusters.firstIndex(where: { $0.persistentModelID == savedId }) {
                        currentPage = newIndex
                    }
                    clusterIdBeforeReorder = nil
                }
            }
            .confirmationDialog(L.deleteCluster, isPresented: $showingDeleteOptions) {
                if let cluster = currentCluster, cluster.profiles.count > 1 {
                    Button(L.deleteQRFromCluster, role: .destructive) {
                        deleteCurrentQR()
                    }
                    Button(L.deleteCluster, role: .destructive) {
                        deleteCurrentCluster()
                    }
                    Button(L.cancel, role: .cancel) {}
                } else {
                    Button(L.delete, role: .destructive) {
                        deleteCurrentCluster()
                    }
                    Button(L.cancel, role: .cancel) {}
                }
            } message: {
                if let cluster = currentCluster, cluster.profiles.count > 1 {
                    Text("\(L.deleteClusterConfirm)")
                } else {
                    Text(L.deleteConfirm(currentCluster?.name ?? ""))
                }
            }
            .onAppear {
                migrateClustersIfNeeded()
            }
            .alert(L.savedToPhotos, isPresented: $showSavedAlert) {
                Button(L.ok, role: .cancel) {}
            }
            .alert(L.couldNotSave, isPresented: $showSaveError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(saveError ?? L.tryAgain)
            }
        }
    }

    @State private var showAddNewCluster = false

    // MARK: - Content

    private var contentView: some View {
        ClusterCardPager(clusters: clusters, currentPage: $currentPage) { profileIndex in
            currentSelectedProfileIndex = profileIndex
        }
        .onChange(of: currentPage) { _, _ in
            currentSelectedProfileIndex = 0
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageBackground: some View {
        GeometryReader { geo in
            let isLandscapeTablet = UIDevice.current.userInterfaceIdiom == .pad && geo.size.width > geo.size.height
            let imageData = isLandscapeTablet && currentCluster?.templateStyle == .rhodesPass
                ? currentCluster?.rhodesBannerImageData
                : currentCluster?.backgroundImageData
            if let data = imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                currentCluster?.backgroundColor ?? .white
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(L.noClustersYet)
                    .font(.title2.bold())
                Text(L.addFirstQR)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddNewCluster = true
            } label: {
                Label(L.newCluster, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Actions

    private func syncPersistedOutputsFromStore() throws {
        let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        ))
        WidgetDataHelper.sync(clusters: persistedClusters)
        BackupManager.writeAutoBackup(clusters: persistedClusters)
    }

    private func migrateClustersIfNeeded() {
        do {
            try MigrationManager.performClusterMigrationIfNeeded(context: modelContext)
            try syncPersistedOutputsFromStore()
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func deleteCurrentQR() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        guard let cluster = currentCluster else { return }
        let profiles = cluster.profiles.sorted { $0.createdAt < $1.createdAt }
        guard !profiles.isEmpty else { return }
        let previousPage = currentPage
        let previousSelectedProfileIndex = currentSelectedProfileIndex
        let index = min(currentSelectedIndex, profiles.count - 1)
        let profileToDelete = profiles[index]
        modelContext.delete(profileToDelete)
        // Use local count — SwiftData relationship arrays may not update until save()
        let remainingCount = profiles.count - 1
        if remainingCount == 0 {
            modelContext.delete(cluster)
            let remainingClusterCount = clusters.count - 1
            currentPage = min(currentPage, max(0, remainingClusterCount - 1))
        } else {
            currentSelectedProfileIndex = min(index, remainingCount - 1)
        }
        do {
            try modelContext.save()
            let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
            ))
            WidgetDataHelper.sync(clusters: persistedClusters)
            BackupManager.writeAutoBackup(clusters: persistedClusters)
        } catch {
            modelContext.rollback()
            currentPage = previousPage
            currentSelectedProfileIndex = previousSelectedProfileIndex
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func deleteCurrentCluster() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        guard let cluster = currentCluster else { return }
        do {
            if try ProfileSync.binding(cluster.id) != nil {
                saveError = L.deleteStopSyncFirst
                showSaveError = true
                return
            }
        } catch { saveError = error.localizedDescription; showSaveError = true; return }
        let previousPage = currentPage
        let previousSelectedProfileIndex = currentSelectedProfileIndex
        modelContext.delete(cluster)
        let remainingClusterCount = clusters.count - 1
        currentPage = min(currentPage, max(0, remainingClusterCount - 1))
        currentSelectedProfileIndex = 0
        do {
            try modelContext.save()
            let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
            ))
            WidgetDataHelper.sync(clusters: persistedClusters)
            BackupManager.writeAutoBackup(clusters: persistedClusters)
        } catch {
            modelContext.rollback()
            currentPage = previousPage
            currentSelectedProfileIndex = previousSelectedProfileIndex
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func saveCardToPhotos() {
        guard let cluster = currentCluster else { return }
        let renderer = ImageRenderer(content: ShareableCard(cluster: cluster))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        let save: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showSavedAlert = true
                    }
                }
            }
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        save()
                    }
                }
            }
        case .authorized, .limited:
            save()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Shareable Card

struct ShareableCard: View {
    let cluster: QRCluster
    let cardHeight: CGFloat = 520

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let data = cluster.backgroundImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    cluster.backgroundColor
                }

                VStack(spacing: 0) {
                    Spacer()

                    ClusterCardView(cluster: cluster, size: 180, containerWidth: geo.size.width)
                        .padding(.horizontal, 16)
                        .frame(height: cardHeight)

                    Spacer(minLength: 32)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: 393, height: 852)
        .ignoresSafeArea()
    }
}

// MARK: - Add To Existing Cluster View

struct AddToExistingClusterView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @State private var selectedCluster: QRCluster?

    var body: some View {
        NavigationStack {
            List {
                ForEach(clusters) { cluster in
                    Button {
                        selectedCluster = cluster
                    } label: {
                        HStack {
                            if let data = cluster.avatarImageData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text(cluster.name)
                                    .font(.headline)
                                Text("\(cluster.profiles.count) \(L.qrCodesInCluster)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L.selectCluster)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
            .sheet(item: $selectedCluster) { cluster in
                AddProfileView(addToCluster: cluster)
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
