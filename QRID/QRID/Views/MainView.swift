import SwiftUI
import SwiftData
import Photos

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) private var settings
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @State private var currentPage = 0
    @State private var showingAdd = false
    @State private var showingAddToExisting = false
    @State private var showingEditCluster = false
    @State private var showingEditQR = false
    @State private var showingDeleteOptions = false
    @State private var showingReorderClusters = false
    @State private var showingSettings = false
    @State private var cardHeight: CGFloat = 460
    @State private var currentSelectedProfileIndex: Int = 0
    @State private var clusterIdBeforeReorder: PersistentIdentifier?
    @State private var showSavedAlert = false

    private var currentCluster: QRCluster? {
        clusters[safe: currentPage]
    }

    private var currentProfiles: [QRProfile] {
        currentCluster?.profiles.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    private var currentSelectedIndex: Int {
        min(currentSelectedProfileIndex, max(0, currentProfiles.count - 1))
    }

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
        NavigationStack {
            Group {
                if clusters.isEmpty {
                    emptyState
                } else {
                    contentView
                }
            }
            .navigationTitle(L.qrID)
            .onAppear {
                WidgetDataHelper.sync(clusters: clusters)
                BackupManager.writeAutoBackup(clusters: clusters)
            }
            .onChange(of: clustersSignature) {
                WidgetDataHelper.sync(clusters: clusters)
                BackupManager.writeAutoBackup(clusters: clusters)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            saveCardToPhotos()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .foregroundStyle(currentCluster?.backgroundColor.uiContrastColor ?? .primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !clusters.isEmpty {
                        Menu {
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
                            Button {
                                showingSettings = true
                            } label: {
                                Label(L.settings, systemImage: "gear")
                            }
                            Button(role: .destructive) {
                                showingDeleteOptions = true
                            } label: {
                                Label(L.deleteCluster, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.circle")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .foregroundStyle(currentCluster?.backgroundColor.uiContrastColor ?? .primary)
                        }
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .confirmationDialog(L.chooseAction, isPresented: $showingAdd) {
                Button(L.newCluster) {
                    showAddNewCluster = true
                }
                Button(L.addToExistingCluster) {
                    showingAddToExisting = true
                }
                Button(L.cancel, role: .cancel) {}
            }
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: showingReorderClusters) { _, isShowing in
                if !isShowing, let savedId = clusterIdBeforeReorder {
                    if let newIndex = clusters.firstIndex(where: { $0.persistentModelID == savedId }) {
                        currentPage = newIndex
                    }
                    clusterIdBeforeReorder = nil
                }
            }
            .confirmationDialog(L.deleteProfile, isPresented: $showingDeleteOptions) {
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
                    Text("\(L.deleteConfirm) \"\(currentCluster?.name ?? "")\"?")
                }
            }
            .onAppear {
                MigrationManager.performClusterMigrationIfNeeded(context: modelContext)
            }
            .alert(L.savedToPhotos, isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @State private var showAddNewCluster = false

    // MARK: - Content

    private var contentView: some View {
        ZStack {
            // Background: image or solid color
            GeometryReader { geo in
                if let data = currentCluster?.backgroundImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    (currentCluster?.backgroundColor ?? .white)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                        ClusterCardView(cluster: cluster, size: 180) { profileIndex in
                            if index == currentPage {
                                currentSelectedProfileIndex = profileIndex
                            }
                        }
                        .padding(.horizontal, 16)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                .frame(height: cardHeight)
                .clipped()
                .onChange(of: currentPage) { _, _ in
                    currentSelectedProfileIndex = 0
                }

                if clusters.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<clusters.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.5))
                                .frame(width: index == currentPage ? 10 : 8,
                                       height: index == currentPage ? 10 : 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                } else {
                    Spacer(minLength: 32)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
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

    private func deleteCurrentQR() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        guard let cluster = currentCluster else { return }
        let profiles = cluster.profiles.sorted { $0.createdAt < $1.createdAt }
        guard !profiles.isEmpty else { return }
        let index = min(currentSelectedIndex, profiles.count - 1)
        let profileToDelete = profiles[index]
        modelContext.delete(profileToDelete)
        // Use local count — SwiftData relationship arrays may not update until save()
        let remainingCount = profiles.count - 1
        if remainingCount == 0 {
            modelContext.delete(cluster)
            if currentPage > 0 { currentPage -= 1 }
        } else {
            currentSelectedProfileIndex = min(index, remainingCount - 1)
        }
    }

    private func deleteCurrentCluster() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        guard let cluster = currentCluster else { return }
        modelContext.delete(cluster)
        if currentPage >= clusters.count && currentPage > 0 {
            currentPage = clusters.count - 1
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
                    } else {
                        print("Failed to save card: \(error?.localizedDescription ?? "unknown error")")
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
    let cardHeight: CGFloat = 460

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

                    Spacer()
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
