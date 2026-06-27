import SwiftUI
import PhotosUI
import SwiftData
import WidgetKit

struct EditClusterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]

    let cluster: QRCluster

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var textColor: Color = .black
    @State private var backgroundColor: Color = .white
    @State private var qrColor: Color = .black
    @State private var cornerRadius: Double = 16
    @State private var cardOpacity: Double = 0.7
    @State private var avatarImage: UIImage?
    @State private var avatarPhotosItem: PhotosPickerItem?
    @State private var rawAvatarImage: CroppableImage?
    @State private var backgroundImage: UIImage?
    @State private var rawBackgroundImage: CroppableImage?
    @State private var backgroundPhotosItem: PhotosPickerItem?
    @State private var showingAddQR = false
    @State private var editingProfile: QRProfile?
    @State private var widgetProfileIndex: Int = 0
    @State private var widgetUseClusterBackground: Bool = true
    @State private var widgetOpacity: Double = 0.8
    @State private var widgetBackgroundImage: UIImage?
    @State private var widgetUseCustomBackground: Bool = false
    @State private var showingWidgetSettings = false
    @State private var saveError: String?
    @State private var showSaveError = false

    private var sortedProfiles: [QRProfile] {
        cluster.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Form {
                clusterInfoSection
                appearanceSection
                widgetSection
                backgroundImageSection
                qrCodesSection
            }
            .navigationTitle(L.editCluster)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadCluster() }
            .onChange(of: avatarPhotosItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        rawAvatarImage = CroppableImage(image: image)
                    }
                }
            }
            .onChange(of: backgroundPhotosItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        rawBackgroundImage = CroppableImage(image: image)
                    }
                }
            }
            .fullScreenCover(item: $rawAvatarImage) { item in
                AvatarCropView(
                    sourceImage: item.image,
                    onDone: { cropped in
                        avatarImage = cropped
                        rawAvatarImage = nil
                    },
                    onCancel: {
                        rawAvatarImage = nil
                    }
                )
            }
            .fullScreenCover(item: $rawBackgroundImage) { item in
                BackgroundCropView(
                    sourceImage: item.image,
                    onDone: { cropped in
                        backgroundImage = cropped
                        rawBackgroundImage = nil
                    },
                    onCancel: {
                        rawBackgroundImage = nil
                    }
                )
            }
            .sheet(isPresented: $showingAddQR) {
                AddProfileView(addToCluster: cluster)
            }
            .sheet(item: $editingProfile) { profile in
                EditProfileView(profile: profile)
            }
            .sheet(isPresented: $showingWidgetSettings) {
                WidgetSettingsView(
                    cluster: cluster,
                    profiles: sortedProfiles,
                    onDismiss: { loadWidgetSettings() }
                )
            }
            .alert("Could Not Save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    // MARK: - Cluster Info

    private var clusterInfoSection: some View {
        Section(L.clusterInfo) {
            HStack {
                avatarPreview
                    .frame(width: 60, height: 60)
                Spacer()
                PhotosPicker(selection: $avatarPhotosItem, matching: .images) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text(avatarImage == nil ? L.chooseAvatar : L.changeAvatar)
                    }
                }
            }

            TextField(L.clusterName, text: $name)
                .textInputAutocapitalization(.words)

            TextField(L.subtitleInfo, text: $subtitle, axis: .vertical)
                .lineLimit(1...3)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(L.appearance) {
            ColorPicker(L.textColor, selection: $textColor)
            ColorPicker(L.backgroundColor, selection: $backgroundColor)
            ColorPicker(L.qrCodeColor, selection: $qrColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(L.cornerRadius): \(Int(cornerRadius))")
                    .font(.subheadline)
                Slider(value: $cornerRadius, in: 0...40, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(L.cardOpacity): \(Int(cardOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: $cardOpacity, in: 0.2...1.0, step: 0.05)
            }
        }
    }

    private var widgetSection: some View {
        Section(L.widgetSettings) {
            widgetPreview

            Button {
                showingWidgetSettings = true
            } label: {
                HStack {
                    Text(L.widgetSettings)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget 预览")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Small widget preview
            HStack(spacing: 12) {
                widgetPreviewCard(size: .systemSmall, width: 80, height: 80)
                widgetPreviewCard(size: .systemMedium, width: 160, height: 80)
            }

            widgetPreviewCard(size: .systemLarge, width: 160, height: 160)
        }
        .padding(.top, 8)
    }

    private func widgetPreviewCard(size: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        let bgColor = widgetUseClusterBackground ? backgroundColor : Color.white
        let opacity = widgetOpacity

        return ZStack {
            if widgetUseCustomBackground, let image = widgetBackgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(opacity)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgColor.opacity(opacity))
            }

            if size == .systemSmall {
                VStack(alignment: .leading, spacing: 4) {
                    avatarPreview
                        .frame(width: 24, height: 24)
                    Text(name.isEmpty ? "预览" : name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if size == .systemMedium {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        avatarPreview
                            .frame(width: 28, height: 28)
                        Text(name.isEmpty ? "预览" : name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "qrcode")
                        .font(.system(size: 28))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        avatarPreview
                            .frame(width: 32, height: 32)
                        Text(name.isEmpty ? "预览" : name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(textColor)
                    }
                    Image(systemName: "qrcode")
                        .font(.system(size: 48))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var backgroundImageSection: some View {
        Section(L.backgroundImage) {
            PhotosPicker(selection: $backgroundPhotosItem, matching: .images) {
                Label(backgroundImage == nil ? L.useCustomImage : L.changeBackgroundImage, systemImage: "photo")
            }

            if backgroundImage != nil {
                Button(L.removeBackgroundImage) {
                    backgroundImage = nil
                    backgroundPhotosItem = nil
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - QR Codes List

    private var qrCodesSection: some View {
        Section {
            ForEach(sortedProfiles) { profile in
                Button {
                    editingProfile = profile
                } label: {
                    HStack {
                        Image(systemName: profile.platform.iconName)
                            .foregroundStyle(profile.foregroundColor)
                            .frame(width: 24)
                        Text(profile.platformDisplayName)
                        Spacer()
                        Text(profile.qrContent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                deleteProfiles(at: indexSet)
            }

            Button {
                showingAddQR = true
            } label: {
                Label(L.addQRToCluster, systemImage: "plus.circle.fill")
            }
        } header: {
            Text(L.qrCodesInCluster)
        }
    }

    // MARK: - Avatar Preview

    @ViewBuilder
    private var avatarPreview: some View {
        if let image = avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadCluster() {
        name = cluster.name
        subtitle = cluster.subtitle
        textColor = cluster.textColor
        backgroundColor = cluster.backgroundColor
        qrColor = cluster.qrColor
        cornerRadius = cluster.cornerRadius
        cardOpacity = cluster.cardOpacity ?? 0.7
        if let data = cluster.avatarImageData {
            avatarImage = UIImage(data: data)
        }
        if let data = cluster.backgroundImageData {
            backgroundImage = UIImage(data: data)
        }
        widgetProfileIndex = cluster.widgetProfileIndex ?? 0
        widgetUseClusterBackground = cluster.widgetUseClusterBackground ?? true
        widgetOpacity = cluster.widgetOpacity ?? 0.8
        if let data = cluster.widgetBackgroundImageData {
            widgetBackgroundImage = UIImage(data: data)
            widgetUseCustomBackground = true
        }
    }

    private func save() {
        cluster.name = name.trimmingCharacters(in: .whitespaces)
        cluster.subtitle = subtitle.trimmingCharacters(in: .whitespaces)
        cluster.avatarImageData = avatarImage?.jpegData(compressionQuality: 0.9)
        cluster.backgroundImageData = backgroundImage?.jpegData(compressionQuality: 0.9)
        cluster.textColorHex = textColor.toHex() ?? "#000000"
        cluster.backgroundColorHex = backgroundColor.toHex() ?? "#FFFFFF"
        cluster.qrColorHex = qrColor.toHex() ?? "#000000"
        cluster.cornerRadius = cornerRadius
        cluster.cardOpacity = cardOpacity

        let newQRColorHex = cluster.qrColorHex ?? "#000000"
        for profile in sortedProfiles {
            profile.foregroundColorHex = newQRColorHex
            profile.captureClusterFallback(from: cluster)
        }
        cluster.widgetProfileIndex = widgetProfileIndex
        cluster.widgetUseClusterBackground = widgetUseClusterBackground
        cluster.widgetOpacity = widgetOpacity
        cluster.widgetBackgroundImageData = widgetUseCustomBackground ? resizedWidgetImageData(from: widgetBackgroundImage) : nil
        do {
            try modelContext.save()
            WidgetDataHelper.sync(clusters: clusters)
            BackupManager.writeAutoBackup(clusters: clusters)
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func loadWidgetSettings() {
        widgetProfileIndex = cluster.widgetProfileIndex ?? 0
        widgetUseClusterBackground = cluster.widgetUseClusterBackground ?? true
        widgetOpacity = cluster.widgetOpacity ?? 0.8
        if let data = cluster.widgetBackgroundImageData {
            widgetBackgroundImage = UIImage(data: data)
            widgetUseCustomBackground = true
        } else {
            widgetBackgroundImage = nil
            widgetUseCustomBackground = false
        }
        cluster.widgetTextColorHex = cluster.widgetTextColorHex ?? cluster.textColorHex ?? "#000000"
    }

    private func resizedWidgetImageData(from image: UIImage?) -> Data? {
        guard let image = image else { return nil }
        let maxDimension: CGFloat = 400
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image.jpegData(compressionQuality: 0.7)
        }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    private func deleteProfiles(at offsets: IndexSet) {
        let profilesToDelete = offsets.map { sortedProfiles[$0] }
        let remainingCount = sortedProfiles.count - profilesToDelete.count
        let shouldDismissAfterSave = remainingCount == 0
        for profile in profilesToDelete {
            modelContext.delete(profile)
        }
        if shouldDismissAfterSave {
            modelContext.delete(cluster)
        }
        do {
            try modelContext.save()
            let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
            ))
            WidgetDataHelper.sync(clusters: persistedClusters)
            BackupManager.writeAutoBackup(clusters: persistedClusters)
            if shouldDismissAfterSave {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}
