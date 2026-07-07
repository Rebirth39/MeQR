import SwiftUI
import PhotosUI
import SwiftData

struct EditProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]

    let profile: QRProfile

    @State private var platformType: String = "custom"
    @State private var customPlatformName: String = ""
    @State private var qrContent: String = ""
    @State private var qrPhotosItem: PhotosPickerItem?
    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var showDecodeError = false
    @State private var saveError: String?
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                clusterInfoSection
                qrSourceSection
                detailsSection
                previewSection
            }
            .navigationTitle(L.editQRInCluster)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) { save() }
                        .disabled(qrContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadProfile() }
            .onChange(of: qrPhotosItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    await decodeImportedQR(newItem)
                }
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
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(decodeError ?? L.noQRFound)
            }
            .alert(L.couldNotSave, isPresented: $showSaveError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(saveError ?? L.tryAgain)
            }
        }
    }

    // MARK: - Cluster Info (Read-only)

    private var clusterInfoSection: some View {
        Section {
            HStack {
                if let data = profile.displayAvatarImageData,
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
                    Text(profile.displayName)
                        .font(.headline)
                    if !profile.displaySubtitle.isEmpty {
                        Text(profile.displaySubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(L.sharedFieldsNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(L.clusterInfo)
        }
    }

    // MARK: - QR Source

    private var qrSourceSection: some View {
        Section(L.qrSource) {
            TextField(L.urlOrText, text: $qrContent, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            PhotosPicker(selection: $qrPhotosItem, matching: .images) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text(L.replaceFromQRImage)
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section(L.details) {
            Picker(L.platform, selection: $platformType) {
                Section(L.commonPlatforms) {
                    platformOptions(Platform.commonPlatforms)
                }
                Section(L.socialPlatforms) {
                    platformOptions(Platform.socialPlatforms)
                }
                Section(L.professionalPlatforms) {
                    platformOptions(Platform.professionalPlatforms)
                }
                platformOption(.custom)
            }

            if platformType == "custom" {
                TextField(L.customPlatformName, text: $customPlatformName)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    @ViewBuilder
    private func platformOptions(_ platforms: [Platform]) -> some View {
        ForEach(platforms) { platform in
            platformOption(platform)
        }
    }

    private func platformOption(_ platform: Platform) -> some View {
        HStack {
            Image(systemName: platform.iconName)
            Text(platform.displayName)
        }
        .tag(platform.rawValue)
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section(L.preview) {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(profile.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(profile.foregroundColor)
                    Text(profile.displaySubtitle.isEmpty ? profile.platformDisplayName : profile.displaySubtitle)
                        .font(.caption2)
                        .foregroundStyle(profile.foregroundColor.opacity(0.7))
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(profile.backgroundColor)
                            .frame(width: 100, height: 100)
                        previewQRImage
                            .frame(width: 80, height: 80)
                    }
                }
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
               foreground: profile.foregroundColor,
               background: profile.backgroundColor
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

    // MARK: - Actions

    private func loadProfile() {
        platformType = profile.platformType
        customPlatformName = profile.customPlatformName ?? ""
        qrContent = profile.qrContent
    }

    @MainActor
    private func decodeImportedQR(_ item: PhotosPickerItem) async {
        isDecoding = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            let decoded = try await QRCodeGenerator.decode(from: image)
            qrContent = decoded
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
        let resolvedPlatform = Platform.resolvedSelection(
            platformType: platformType,
            customPlatformName: customPlatformName
        )
        profile.platformType = resolvedPlatform.platformType
        profile.customPlatformName = resolvedPlatform.customPlatformName
        profile.qrContent = qrContent.trimmingCharacters(in: .whitespaces)
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
}
