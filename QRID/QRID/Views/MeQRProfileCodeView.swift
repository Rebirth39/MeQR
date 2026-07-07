import SwiftUI
import Photos

struct MeQRProfileCodeView: View {
    let cluster: QRCluster

    @Environment(\.dismiss) private var dismiss
    @State private var codeString = ""
    @State private var showSavedAlert = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var showingCodeSettings = false
    @State private var selectedProfileIDs: Set<UUID> = []
    @State private var selectedOfflineProfileID: UUID?
    @State private var codeModeText = ""

    private var sortedProfiles: [QRProfile] {
        cluster.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    private var defaultSelectionCount: Int {
        min(3, sortedProfiles.count)
    }

    private var includedProfiles: [QRProfile] {
        let selectedIDs = normalizedSelection(from: selectedProfileIDs)
        return sortedProfiles.filter { selectedIDs.contains($0.id) }
    }

    private var offlineProfile: QRProfile? {
        let normalizedID = normalizedOfflineProfileID(selectedOfflineProfileID)
        return sortedProfiles.first { $0.id == normalizedID }
    }

    private var includedPlatformSummary: String {
        let names = includedProfiles.map(\.platformDisplayName).joined(separator: " / ")
        return L.meqrIncludedPlatforms(includedProfiles.count, names)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    avatar
                        .frame(width: 76, height: 76)

                    VStack(spacing: 6) {
                        Text(cluster.name)
                            .font(.title3.bold())
                        if !cluster.subtitle.isEmpty {
                            Text(cluster.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    qrCode
                        .frame(width: 250, height: 250)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                        )

                    if !codeModeText.isEmpty {
                        Text(codeModeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(L.meqrCodeHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)

                    Text(includedPlatformSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .padding(.bottom, 20)

                Button {
                    saveCodeToPhotos()
                } label: {
                    Label(L.saveMeQRCode, systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .safeAreaPadding(.bottom, 12)
            .navigationTitle(L.meqrProfileCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCodeSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L.meqrCodeSettings)
                }
            }
            .onAppear {
                configureInitialSelection()
                buildCode()
            }
            .onChange(of: selectedProfileIDs) { _ in
                persistSelection()
                selectedOfflineProfileID = normalizedOfflineProfileID(selectedOfflineProfileID)
                persistOfflineSelection()
                buildCode()
            }
            .onChange(of: selectedOfflineProfileID) { _ in
                persistOfflineSelection()
                buildCode()
            }
            .sheet(isPresented: $showingCodeSettings) {
                MeQRCodeSettingsView(
                    profiles: sortedProfiles,
                    selectedProfileIDs: $selectedProfileIDs,
                    selectedOfflineProfileID: $selectedOfflineProfileID
                )
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

    private var selectionStorageKey: String {
        "meqr.exchange.selectedProfiles.\(cluster.id.uuidString)"
    }

    private var offlineSelectionStorageKey: String {
        "meqr.exchange.offlineProfile.\(cluster.id.uuidString)"
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = cluster.avatarImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(cluster.textColor.opacity(0.14))
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(cluster.textColor.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private var qrCode: some View {
        if codeString.isEmpty {
            ProgressView()
                .scaleEffect(1.3)
        } else if let image = QRCodeGenerator.generate(
            from: codeString,
            foreground: .black,
            background: .white,
            correctionLevel: "L"
        ) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private func buildCode() {
        do {
            codeString = try bestScannableCodeString()
            codeModeText = L.meqrCodeLocalReady
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func bestScannableCodeString() throws -> String {
        let profile = MeQRExchangeProfile(offlineCluster: cluster, profile: offlineProfile)
        return try MeQRExchangeCodec.encode(profile)
    }

    private func configureInitialSelection() {
        let savedIDs = UserDefaults.standard.stringArray(forKey: selectionStorageKey)?
            .compactMap(UUID.init(uuidString:))
        let defaultIDs = sortedProfiles.prefix(defaultSelectionCount).map(\.id)
        selectedProfileIDs = normalizedSelection(from: Set(savedIDs ?? defaultIDs))
        persistSelection()

        let savedOfflineID = UserDefaults.standard.string(forKey: offlineSelectionStorageKey).flatMap(UUID.init(uuidString:))
        selectedOfflineProfileID = normalizedOfflineProfileID(savedOfflineID)
        persistOfflineSelection()
    }

    private func normalizedSelection(from ids: Set<UUID>) -> Set<UUID> {
        let availableIDs = sortedProfiles.map(\.id)
        var normalized = ids.intersection(Set(availableIDs))

        if normalized.isEmpty {
            normalized = Set(availableIDs.prefix(defaultSelectionCount))
        }

        if normalized.count > 3 {
            var limited = Set<UUID>()
            for id in availableIDs where normalized.contains(id) {
                limited.insert(id)
                if limited.count >= 3 {
                    break
                }
            }
            normalized = limited
        }

        return normalized
    }

    private func normalizedOfflineProfileID(_ id: UUID?) -> UUID? {
        let selectedIDs = normalizedSelection(from: selectedProfileIDs)
        if let id, selectedIDs.contains(id) {
            return id
        }
        let availableIDs = sortedProfiles.map(\.id)
        return availableIDs.first { selectedIDs.contains($0) } ?? availableIDs.first
    }

    private func persistSelection() {
        let ids = normalizedSelection(from: selectedProfileIDs)
            .map(\.uuidString)
        UserDefaults.standard.set(ids, forKey: selectionStorageKey)
    }

    private func persistOfflineSelection() {
        if let selectedOfflineProfileID = normalizedOfflineProfileID(selectedOfflineProfileID) {
            UserDefaults.standard.set(selectedOfflineProfileID.uuidString, forKey: offlineSelectionStorageKey)
        }
    }

    private func saveCodeToPhotos() {
        guard !codeString.isEmpty else {
            saveError = L.meqrCodeStillPreparing
            showSaveError = true
            return
        }

        let renderer = ImageRenderer(content: MeQRProfileCodeShareImage(cluster: cluster, codeString: codeString))
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            saveError = L.tryAgain
            showSaveError = true
            return
        }

        let save: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showSavedAlert = true
                    } else {
                        saveError = error?.localizedDescription ?? L.tryAgain
                        showSaveError = true
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
            saveError = L.photoPermissionNeeded
            showSaveError = true
        @unknown default:
            saveError = L.tryAgain
            showSaveError = true
        }
    }
}

private struct MeQRCodeSettingsView: View {
    let profiles: [QRProfile]
    @Binding var selectedProfileIDs: Set<UUID>
    @Binding var selectedOfflineProfileID: UUID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if profiles.isEmpty {
                        Text(L.noQRCodesYet)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profiles, id: \.id) { profile in
                            Button {
                                toggle(profile)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: profile.platform.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.tint)
                                        .frame(width: 26, height: 26)

                                    Text(profile.platformDisplayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedProfileIDs.contains(profile.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(L.includedPlatforms)
                } footer: {
                    if profiles.count > 3 {
                        Text(L.chooseUpToThreePlatforms)
                    }
                }

                Section {
                    if profiles.isEmpty {
                        Text(L.noQRCodesYet)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profiles, id: \.id) { profile in
                            Button {
                                selectedOfflineProfileID = profile.id
                                selectedProfileIDs.insert(profile.id)
                                if selectedProfileIDs.count > 3 {
                                    trimOnlineSelection(keeping: profile.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: profile.platform.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.tint)
                                        .frame(width: 26, height: 26)

                                    Text(profile.platformDisplayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedOfflineProfileID == profile.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(L.offlineFallbackPlatform)
                } footer: {
                    Text(L.offlineFallbackPlatformHint)
                }
            }
            .navigationTitle(L.meqrCodeSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func toggle(_ profile: QRProfile) {
        if selectedProfileIDs.contains(profile.id) {
            selectedProfileIDs.remove(profile.id)
        } else {
            guard selectedProfileIDs.count < 3 else { return }
            selectedProfileIDs.insert(profile.id)
        }
    }

    private func trimOnlineSelection(keeping keptID: UUID) {
        var trimmed: Set<UUID> = [keptID]
        for profile in profiles where selectedProfileIDs.contains(profile.id) && profile.id != keptID {
            trimmed.insert(profile.id)
            if trimmed.count >= 3 { break }
        }
        selectedProfileIDs = trimmed
    }
}

private struct MeQRProfileCodeShareImage: View {
    let cluster: QRCluster
    let codeString: String

    var body: some View {
        ZStack {
            if let data = cluster.backgroundImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                cluster.backgroundColor
            }

            VStack(spacing: 18) {
                if let data = cluster.avatarImageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                }

                Text(cluster.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(cluster.textColor)

                if !cluster.subtitle.isEmpty {
                    Text(cluster.subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(cluster.textColor.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                if let image = QRCodeGenerator.generate(from: codeString, foreground: .black, background: .white, correctionLevel: "L") {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 24).fill(.white))
                }

                Text("MeQR")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(cluster.textColor.opacity(0.65))
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: cluster.cornerRadius)
                    .fill(cluster.backgroundColor.opacity(cluster.cardOpacity ?? 0.82))
            )
            .padding(30)
        }
        .frame(width: 393, height: 852)
        .clipped()
    }
}
