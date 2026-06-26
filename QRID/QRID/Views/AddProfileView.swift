import SwiftUI
import PhotosUI
import SwiftData

struct AddProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]

    /// If set, we're adding a QR code to an existing cluster.
    /// If nil, we're creating a new cluster with its first QR code.
    var addToCluster: QRCluster? = nil

    @State private var name = ""
    @State private var subtitle = ""
    @State private var platformType = "custom"
    @State private var customPlatformName = ""
    @State private var qrContent = ""
    @State private var isGenerated = true
    @State private var importedQRImage: UIImage?
    @State private var qrPhotosItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var rawAvatarImage: CroppableImage?
    @State private var avatarPhotosItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var rawBackgroundImage: CroppableImage?
    @State private var backgroundPhotosItem: PhotosPickerItem?
    @State private var textColor = Color.black
    @State private var backgroundColor = Color.white
    @State private var cornerRadius: Double = 16
    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var showDecodeError = false
    @State private var saveError: String?
    @State private var showSaveError = false

    private var isAddingToExisting: Bool { addToCluster != nil }

    private var nextSortOrder: Int {
        (clusters.map(\.sortOrder).max() ?? -1) + 1
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isAddingToExisting {
                    clusterInfoSection
                    clusterAppearanceSection
                    backgroundImageSection
                } else {
                    existingClusterInfo
                }
                qrSourceSection
                qrDetailsSection
                if !isAddingToExisting {
                    previewSection
                }
            }
            .navigationTitle(isAddingToExisting ? L.addQRToCluster : L.newCluster)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) { save() }
                }
            }
            .onAppear { loadFromExistingCluster() }
            .onChange(of: qrPhotosItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    await decodeImportedQR(newItem)
                }
            }
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
            .overlay {
                if isDecoding {
                    ProgressView(L.decodingQR)
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert(L.couldNotDecodeQR, isPresented: $showDecodeError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(decodeError ?? L.noQRFound)
            }
            .alert("保存结果", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {
                    if saveError?.hasPrefix("已保存") == true {
                        dismiss()
                    }
                }
            } message: {
                Text(saveError ?? "无法保存，请重试。")
            }
        }
    }

    // MARK: - Cluster Info (New Cluster mode)

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

    private var clusterAppearanceSection: some View {
        Section(L.appearance) {
            ColorPicker(L.textColor, selection: $textColor)
            ColorPicker(L.backgroundColor, selection: $backgroundColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(L.cornerRadius): \(Int(cornerRadius))")
                    .font(.subheadline)
                Slider(value: $cornerRadius, in: 0...40, step: 1)
            }
        }
    }

    // MARK: - Existing Cluster Info

    private var existingClusterInfo: some View {
        Section(L.clusterInfo) {
            if let cluster = addToCluster {
                HStack {
                    if let data = cluster.avatarImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(cluster.name)
                            .font(.headline)
                        if !cluster.subtitle.isEmpty {
                            Text(cluster.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(L.sharedFieldsNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - QR Source

    private var backgroundImageSection: some View {
        Section(L.backgroundImage) {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(L.removeBackgroundImage) {
                    backgroundImage = nil
                    backgroundPhotosItem = nil
                }
                .foregroundStyle(.red)
            } else {
                PhotosPicker(selection: $backgroundPhotosItem, matching: .images) {
                    Label(L.useCustomImage, systemImage: "photo")
                }
            }
        }
    }

    private var qrSourceSection: some View {
        Section(L.qrSource) {
            Picker(L.qrSource, selection: $isGenerated) {
                Text(L.generateFromText).tag(true)
                Text(L.importQRImage).tag(false)
            }
            .pickerStyle(.segmented)

            TextField(L.urlOrText, text: $qrContent, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .opacity(isGenerated ? 1 : 0)
                .frame(height: isGenerated ? nil : 0)
                .disabled(!isGenerated)

            PhotosPicker(selection: $qrPhotosItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(importedQRImage == nil ? L.selectQRImage : L.changeQRImage)
                }
            }
            .opacity(isGenerated ? 0 : 1)
            .frame(height: isGenerated ? 0 : nil)
            .disabled(isGenerated)

            if let image = importedQRImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(isGenerated ? 0 : 1)
            }
        }
    }

    // MARK: - QR Details

    private var qrDetailsSection: some View {
        Section(L.details) {
            Picker(L.platform, selection: $platformType) {
                ForEach(Platform.allCases) { platform in
                    HStack {
                        Image(systemName: platform.iconName)
                        Text(platform.displayName)
                    }
                    .tag(platform.rawValue)
                }
            }

            if platformType == "custom" {
                TextField(L.customPlatformName, text: $customPlatformName)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    // MARK: - Preview

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
                    .fill(textColor.opacity(0.15))
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(textColor.opacity(0.6))
            }
        }
    }

    private var previewSection: some View {
        Section(L.preview) {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    avatarPreview
                        .frame(width: 44, height: 44)
                    Text(name.isEmpty ? L.preview : name)
                        .font(.caption.bold())
                        .foregroundStyle(textColor)
                    Text(subtitle.isEmpty ? previewPlatformName : subtitle)
                        .font(.caption2)
                        .foregroundStyle(textColor.opacity(0.7))
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                            .frame(width: 100, height: 100)
                        previewQRImage
                            .frame(width: 80, height: 80)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.white.opacity(0.75))
                )
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var previewQRImage: some View {
        if !qrContent.isEmpty,
           let uiImage = QRCodeGenerator.generate(
               from: qrContent,
               foreground: .black,
               background: backgroundColor
           ) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    private var selectedPlatform: Platform {
        Platform(rawValue: platformType) ?? .custom
    }

    private var previewPlatformName: String {
        if platformType == "custom", !customPlatformName.isEmpty {
            return customPlatformName
        }
        return selectedPlatform.displayName
    }

    private var canSave: Bool {
        if isAddingToExisting {
            return !qrContent.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !qrContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func loadFromExistingCluster() {
        guard let cluster = addToCluster else { return }
        backgroundColor = cluster.backgroundColor
        cornerRadius = cluster.cornerRadius
        if let data = cluster.avatarImageData {
            avatarImage = UIImage(data: data)
        }
    }

    @MainActor
    private func decodeImportedQR(_ item: PhotosPickerItem) async {
        isDecoding = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            importedQRImage = image
            let decoded = try await QRCodeGenerator.decode(from: image)
            qrContent = decoded
            isGenerated = true
            if let detected = Platform.detect(from: decoded) {
                platformType = detected.rawValue
            }
            isDecoding = false
        } catch {
            isDecoding = false
            decodeError = (error as? QRCodeGenerator.QRDecodeError)?.errorDescription ?? error.localizedDescription
            showDecodeError = true
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedQR = qrContent.trimmingCharacters(in: .whitespaces)

        if !isAddingToExisting && trimmedName.isEmpty {
            saveError = "请输入合集名称。"
            showSaveError = true
            return
        }
        if trimmedQR.isEmpty {
            saveError = "请输入二维码内容。"
            showSaveError = true
            return
        }

        if let existingCluster = addToCluster {
            let profile = QRProfile(
                platformType: platformType,
                qrContent: trimmedQR,
                foregroundColorHex: existingCluster.qrColorHex ?? "#000000",
                customPlatformName: customPlatformName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customPlatformName.trimmingCharacters(in: .whitespaces),
                cluster: existingCluster
            )
            modelContext.insert(profile)
        } else {
            // New clusters default QR color to black; change it later in Edit Cluster
            let cluster = QRCluster(
                name: trimmedName,
                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                avatarImageData: avatarImage?.jpegData(compressionQuality: 0.9),
                backgroundImageData: backgroundImage?.jpegData(compressionQuality: 0.9),
                backgroundColorHex: backgroundColor.toHex() ?? "#FFFFFF",
                textColorHex: textColor.toHex() ?? "#000000",
                qrColorHex: "#000000",
                cornerRadius: cornerRadius,
                sortOrder: nextSortOrder
            )
            modelContext.insert(cluster)
            let profile = QRProfile(
                platformType: platformType,
                qrContent: trimmedQR,
                foregroundColorHex: "#000000",
                customPlatformName: customPlatformName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customPlatformName.trimmingCharacters(in: .whitespaces),
                cluster: cluster
            )
            modelContext.insert(profile)
        }

        do {
            try modelContext.save()
            do {
                let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                    sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
                ))
                WidgetDataHelper.sync(clusters: persistedClusters)
                BackupManager.writeAutoBackup(clusters: persistedClusters)
                saveError = "已保存，当前共有 \(persistedClusters.count) 个合集"
            } catch {
                saveError = "保存后读取失败：\(error.localizedDescription)"
            }
            showSaveError = true
        } catch {
            modelContext.rollback()
            saveError = "保存失败：\(error.localizedDescription)"
            showSaveError = true
        }
    }
}
