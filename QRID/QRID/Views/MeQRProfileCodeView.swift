import SwiftUI
import Photos

struct MeQRProfileCodeView: View {
    let cluster: QRCluster

    @Environment(\.dismiss) private var dismiss
    @State private var codeString = ""
    @State private var colorAvatarJPEG: Data?
    @State private var showSavedAlert = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var showingCodeSettings = false
    @State private var selectedProfileIDs: Set<UUID> = []
    @State private var selectedOfflineProfileID: UUID?
    @State private var exchangeSubtitle = ""
    @State private var codeModeText = ""
    @State private var uploadTask: Task<Void, Never>?
    @State private var activeFingerprint: String?

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

    private var displaySubtitle: String {
        limitedExchangeSubtitle(exchangeSubtitle)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isCompactHeight = geo.size.height < 820
                let availableWidth = max(0, geo.size.width - 32)
                let contentWidth = min(availableWidth, 370)
                let cardWidth = min(contentWidth, cluster.templateStyle == .rhodesPass ? 336 : 342)
                let qrHorizontalPadding: CGFloat = isCompactHeight ? 14 : 16
                let qrSide = min(isCompactHeight ? 214 : 228, max(168, cardWidth - qrHorizontalPadding * 2 - 28))
                let avatarSide: CGFloat = isCompactHeight ? 46 : 52
                let titleSize: CGFloat = isCompactHeight ? 23 : 25
                let subtitleSize: CGFloat = isCompactHeight ? 14 : 15
                ZStack {
                    exchangeBackground
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: isCompactHeight ? 10 : 12) {
                            VStack(alignment: .leading, spacing: isCompactHeight ? 5 : 6) {
                                avatar
                                    .frame(width: avatarSide, height: avatarSide)
                                    .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 2))
                                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)

                                Text(cluster.name)
                                    .font(.system(size: titleSize, weight: .black))
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                if !displaySubtitle.isEmpty {
                                    Text(displaySubtitle)
                                        .font(.system(size: subtitleSize, weight: .semibold))
                                        .foregroundStyle(.black.opacity(0.78))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                            MeQRExchangeCard(
                                codeString: codeString,
                                colorAvatarJPEG: colorAvatarJPEG,
                                codeModeText: codeModeText,
                                includedProfiles: includedProfiles,
                                includedPlatformSummary: includedPlatformSummary,
                                templateStyle: cluster.templateStyle,
                                textColor: cluster.textColor,
                                backgroundColor: cluster.backgroundColor,
                                qrColor: cluster.qrColor,
                                qrSide: qrSide,
                                qrHorizontalPadding: qrHorizontalPadding,
                                cardWidth: cardWidth,
                                isCompactHeight: isCompactHeight
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(.top, isCompactHeight ? 10 : 18)
                        .padding(.bottom, 96)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        saveCodeToPhotos()
                    } label: {
                        Label(L.saveMeQRCode, systemImage: "square.and.arrow.down")
                            .font(.system(size: isCompactHeight ? 15 : 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompactHeight ? 44 : 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
                    .frame(maxWidth: max(0, min(geo.size.width - 44, 360)))
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 6))
                }
            }
            .navigationTitle(L.meqrProfileCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .preferredColorScheme(.light)
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
            .onDisappear {
                uploadTask?.cancel()
                uploadTask = nil
                activeFingerprint = nil
            }
            .onChange(of: selectedProfileIDs) { _, _ in
                persistSelection()
                selectedOfflineProfileID = normalizedOfflineProfileID(selectedOfflineProfileID)
                persistOfflineSelection()
                buildCode()
            }
            .onChange(of: selectedOfflineProfileID) { _, _ in
                persistOfflineSelection()
                buildCode()
            }
            .onChange(of: exchangeSubtitle) { _, newValue in
                let limited = limitedExchangeSubtitle(newValue)
                if limited != newValue {
                    exchangeSubtitle = limited
                }
                persistExchangeSubtitle()
                buildCode()
            }
            .sheet(isPresented: $showingCodeSettings) {
                MeQRCodeSettingsView(
                    profiles: sortedProfiles,
                    selectedProfileIDs: $selectedProfileIDs,
                    selectedOfflineProfileID: $selectedOfflineProfileID,
                    exchangeSubtitle: $exchangeSubtitle
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

    private var exchangeSubtitleStorageKey: String {
        "meqr.exchange.subtitle.\(cluster.id.uuidString)"
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
                    .foregroundStyle(.black.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private var exchangeBackground: some View {
        ZStack {
            if let data = cluster.backgroundImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                cluster.backgroundColor
            }

            Rectangle()
                .fill(.white.opacity(0.16))

            LinearGradient(
                colors: [
                    .white.opacity(0.10),
                    cluster.templateStyle == .conventionPass ? cluster.qrColor.opacity(0.16) : cluster.backgroundColor.opacity(0.18),
                    .black.opacity(cluster.templateStyle == .conventionPass ? 0.10 : 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func buildCode() {
        do {
            let selectedProfiles = selectedProfilesForCode()
            let exchangeSubtitle = displaySubtitle
            let fingerprint = try exchangeFingerprint(selectedProfiles: selectedProfiles, subtitle: exchangeSubtitle)
            guard activeFingerprint != fingerprint else { return }
            uploadTask?.cancel()
            activeFingerprint = fingerprint
            let store = MeQRExchangeCodeStore()
            var record: MeQRExchangeCodeRecord
            if let cached = store.load(clusterID: cluster.id, fingerprint: fingerprint),
               cached.onlineProfile.subtitle == cluster.subtitle {
                record = cached
            } else {
                let credentials = MeQRExchangeCodeRecord.credentials()
                var offline = MeQRExchangeProfile(offlineCluster: cluster, profile: offlineProfile)
                offline.subtitle = exchangeSubtitle
                var online = MeQRExchangeProfile(cluster: cluster, profiles: selectedProfiles, avatarMaxBytes: 256 * 1024)
                online.intro = ""
                let code = colorEnhancedCode(for: try MeQRExchangeCodec.encodeHybrid(
                    remoteURL: "https://profile.meqrcode.cn/encounter-sessions/" + credentials.sessionID,
                    offlineProfile: offline
                ))
                record = MeQRExchangeCodeRecord(fingerprint: fingerprint, payload: code.payload, avatarJPEG: code.avatarJPEG,
                    sessionID: credentials.sessionID, ownerToken: credentials.ownerToken, onlineProfile: online,
                    eventID: EventStore.shared.activeEvent?.id, synced: false)
                try store.save(record, clusterID: cluster.id)
            }
            codeString = record.payload
            colorAvatarJPEG = record.avatarJPEG
            codeModeText = record.synced ? L.meqrCodeOnlineReady : L.meqrCodeUploading
            EncounterStore.shared.registerOutgoingSession(record.sessionID, ownerToken: record.ownerToken)
            guard !record.synced else { return }
            let pending = record
            uploadTask = Task { @MainActor in
                do {
                    try await MeQRRemoteService.publishExchangeCode(pending)
                    try Task.checkCancellation()
                    guard activeFingerprint == fingerprint else { return }
                    try store.markSynced(pending, clusterID: cluster.id)
                    codeModeText = L.meqrCodeOnlineReady
                } catch {
                    guard !Task.isCancelled, activeFingerprint == fingerprint else { return }
                    codeModeText = L.meqrCodeUploadFailed(error.localizedDescription)
                }
            }
        } catch {
            activeFingerprint = nil
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func exchangeFingerprint(selectedProfiles: [QRProfile], subtitle: String) throws -> String {
        var values = [
            "exchange-v2", cluster.id.uuidString, cluster.name, cluster.subtitle, subtitle,
            MeQRExchangeCodeRecord.digest(cluster.avatarImageData ?? Data()),
            MeQRExchangeCodeRecord.digest(cluster.backgroundImageData ?? Data()),
            MeQRExchangeCodeRecord.digest(cluster.rhodesBannerImageData ?? Data()),
            cluster.backgroundColorHex, cluster.textColorHex ?? "", cluster.qrColorHex ?? "",
            cluster.templateStyleRawValue ?? "", offlineProfile?.id.uuidString ?? "",
            EventStore.shared.activeEvent?.id.uuidString ?? ""
        ]
        for profile in selectedProfiles {
            values.append(contentsOf: [profile.id.uuidString, profile.platformType, profile.platformDisplayName, profile.qrContent])
        }
        return MeQRExchangeCodeRecord.digest(try JSONEncoder().encode(values))
    }

    private func selectedProfilesForCode() -> [QRProfile] {
        includedProfiles.isEmpty ? Array(sortedProfiles.prefix(defaultSelectionCount)) : includedProfiles
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

        let savedSubtitle = UserDefaults.standard.string(forKey: exchangeSubtitleStorageKey)
        exchangeSubtitle = limitedExchangeSubtitle(savedSubtitle ?? cluster.subtitle)
        persistExchangeSubtitle()
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

    private func persistExchangeSubtitle() {
        UserDefaults.standard.set(limitedExchangeSubtitle(exchangeSubtitle), forKey: exchangeSubtitleStorageKey)
    }

    private func limitedExchangeSubtitle(_ value: String) -> String {
        ExchangeSubtitleLimiter.limited(value)
    }

    private func colorLayerAvatar(for payload: String) -> Data? {
        let capacity = QRCodeGenerator.colorLayerPayloadCapacity(from: payload, correctionLevel: "M")
        return MeQRExchangeProfile.colorLayerAvatarJPEG(from: cluster.avatarImageData, maxBytes: capacity)
    }

    private func colorEnhancedCode(for payload: String) -> (payload: String, avatarJPEG: Data?) {
        guard cluster.avatarImageData != nil else { return (payload, nil) }
        let enhancedPayload = QRCodeGenerator.paddedForColorLayer(
            payload,
            minimumPayloadCapacity: 800,
            correctionLevel: "M"
        )
        return (enhancedPayload, colorLayerAvatar(for: enhancedPayload))
    }

    private func saveCodeToPhotos() {
        guard !codeString.isEmpty else {
            saveError = L.meqrCodeStillPreparing
            showSaveError = true
            return
        }

        let renderer = ImageRenderer(content: MeQRProfileCodeShareImage(
            cluster: cluster,
            codeString: codeString,
            colorAvatarJPEG: colorAvatarJPEG,
            codeModeText: codeModeText,
            includedProfiles: includedProfiles
        ))
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
                    } else {
                        saveError = L.photoPermissionNeeded
                        showSaveError = true
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

private struct MeQRExchangeCard: View {
    let codeString: String
    let colorAvatarJPEG: Data?
    let codeModeText: String
    let includedProfiles: [QRProfile]
    let includedPlatformSummary: String
    let templateStyle: ClusterTemplateStyle
    let textColor: Color
    let backgroundColor: Color
    let qrColor: Color
    let qrSide: CGFloat
    let qrHorizontalPadding: CGFloat
    let cardWidth: CGFloat
    let isCompactHeight: Bool

    var body: some View {
        if templateStyle == .rhodesPass {
            rhodesBody
        } else {
            defaultBody
        }
    }

    private var defaultBody: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 10) {
            templateHeader

            qrCode
                .accessibilityIdentifier("exchange-code-qr")
                .frame(width: qrSide, height: qrSide)
                .padding(.horizontal, qrHorizontalPadding)
                .padding(.vertical, isCompactHeight ? 12 : 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .frame(maxWidth: .infinity, alignment: .center)

            if !codeModeText.isEmpty {
                codeModeLabel
            }

            codeHintLabel

            platformChips
                .padding(.horizontal, 10)
        }
        .padding(.vertical, templateStyle == .standard ? (isCompactHeight ? 12 : 14) : (isCompactHeight ? 14 : 16))
        .frame(width: cardWidth, alignment: .top)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(cardStroke, lineWidth: templateStyle == .conventionPass ? 1.4 : 1)
        )
    }

    private var rhodesBody: some View {
        VStack(spacing: 0) {
            rhodesTopStrip

            HStack(spacing: 0) {
                rhodesSideRail

                VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 10) {
                    qrCode
                        .accessibilityIdentifier("exchange-code-qr")
                        .frame(width: rhodesQRSide, height: rhodesQRSide)
                        .padding(isCompactHeight ? 10 : 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if !codeModeText.isEmpty {
                        codeModeLabel
                    }

                    codeHintLabel

                    platformChips
                        .padding(.horizontal, 10)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, isCompactHeight ? 12 : 14)
                .padding(.top, isCompactHeight ? 12 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: cardWidth, alignment: .top)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.70), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(textColor.opacity(0.18), lineWidth: 1)
                .padding(-8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var templateHeader: some View {
        switch templateStyle {
        case .standard:
            EmptyView()
        case .conventionPass:
            HStack(spacing: 8) {
                Image(systemName: ClusterTemplateStyle.conventionPass.iconName)
                Text("MEQR PASS")
                Spacer()
                Text(Date.now, format: .dateTime.month().day())
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.black))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(textColor.opacity(0.72), lineWidth: 1.2)
            )
            .padding(.horizontal, 10)
        case .rhodesPass:
            EmptyView()
        }
    }

    private var rhodesTopStrip: some View {
        HStack(spacing: 0) {
            Rectangle().fill(qrColor.opacity(0.82))
            Rectangle().fill(textColor.opacity(0.82))
            Rectangle().fill(backgroundColor.opacity(0.92))
        }
        .frame(height: 24)
    }

    private var rhodesSideRail: some View {
        ZStack {
            Rectangle()
                .fill(textColor.opacity(0.86))

            VStack(spacing: 10) {
                Text("MEQR")
                    .font(.system(size: 16, weight: .black))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(.white.opacity(index.isMultiple(of: 3) ? 0.92 : 0.62))
                            .frame(width: index.isMultiple(of: 4) ? 4 : 2)
                    }
                }
                .frame(width: 34, height: 86)

                Text(rhodesDateText)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .frame(width: 40, height: 46)
            }
            .foregroundStyle(.white.opacity(0.88))
        }
        .frame(width: 52)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private var rhodesDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM\ndd"
        return formatter.string(from: Date())
    }

    private var rhodesQRSide: CGFloat {
        min(qrSide, max(132, cardWidth - 112))
    }

    private var cardCornerRadius: CGFloat {
        switch templateStyle {
        case .standard:
            return 22
        case .conventionPass:
            return 24
        case .rhodesPass:
            return 14
        }
    }

    private var cardBackground: Color {
        switch templateStyle {
        case .standard:
            return .white.opacity(0.68)
        case .conventionPass:
            return .white.opacity(0.76)
        case .rhodesPass:
            return .white.opacity(0.88)
        }
    }

    private var cardStroke: Color {
        switch templateStyle {
        case .standard:
            return .white.opacity(0.5)
        case .conventionPass:
            return .black.opacity(0.16)
        case .rhodesPass:
            return .black.opacity(0.22)
        }
    }

    @ViewBuilder
    private var qrCode: some View {
        if codeString.isEmpty {
            ProgressView()
                .scaleEffect(1.3)
        } else if let image = QRCodeGenerator.generateColorLayered(
            from: codeString,
            avatarJPEG: colorAvatarJPEG,
            correctionLevel: "M"
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

    private var codeModeLabel: some View {
        Text(codeModeText)
            .font(.caption2)
            .foregroundStyle(.black.opacity(0.66))
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    private var codeHintLabel: some View {
        Text(L.meqrCodeHint)
            .font(.caption2)
            .foregroundStyle(.black.opacity(0.72))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var platformChips: some View {
        if includedProfiles.isEmpty {
            Text(includedPlatformSummary)
                .font(.caption)
                .foregroundStyle(.black.opacity(0.7))
        } else {
            FlowLayout(spacing: 10, rowSpacing: 10) {
                ForEach(includedProfiles, id: \.id) { profile in
                    Label(profile.platformDisplayName, systemImage: profile.platform.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .foregroundStyle(.black)
                        .background(.white.opacity(0.76), in: Capsule())
                }
            }
        }
    }
}

private struct MeQRCodeSettingsView: View {
    let profiles: [QRProfile]
    @Binding var selectedProfileIDs: Set<UUID>
    @Binding var selectedOfflineProfileID: UUID?
    @Binding var exchangeSubtitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var draftSubtitle: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $draftSubtitle)
                        .frame(minHeight: 86)
                        .scrollContentBackground(.hidden)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.exchangeCardIntroHint)
                        Text(ExchangeSubtitleLimiter.usageText(for: draftSubtitle))
                            .foregroundStyle(ExchangeSubtitleLimiter.isOverLimit(draftSubtitle) ? .red : .secondary)
                    }
                }

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
            .onAppear {
                draftSubtitle = exchangeSubtitle
            }
            .onDisappear {
                commitSubtitle()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) {
                        commitSubtitle()
                        dismiss()
                    }
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

    private func commitSubtitle() {
        exchangeSubtitle = ExchangeSubtitleLimiter.limited(draftSubtitle)
    }
}

private struct MeQRProfileCodeShareImage: View {
    let cluster: QRCluster
    let codeString: String
    let colorAvatarJPEG: Data?
    let codeModeText: String
    let includedProfiles: [QRProfile]

    private var includedPlatformSummary: String {
        let names = includedProfiles.map(\.platformDisplayName).joined(separator: " / ")
        return L.meqrIncludedPlatforms(includedProfiles.count, names)
    }

    var body: some View {
        ZStack {
            shareBackground

            VStack(alignment: .leading, spacing: 16) {
                shareHeader

                MeQRExchangeCard(
                    codeString: codeString,
                    colorAvatarJPEG: colorAvatarJPEG,
                    codeModeText: codeModeText,
                    includedProfiles: includedProfiles,
                    includedPlatformSummary: includedPlatformSummary,
                    templateStyle: cluster.templateStyle,
                    textColor: cluster.textColor,
                    backgroundColor: cluster.backgroundColor,
                    qrColor: cluster.qrColor,
                    qrSide: cluster.templateStyle == .rhodesPass ? 210 : 222,
                    qrHorizontalPadding: 14,
                    cardWidth: cluster.templateStyle == .rhodesPass ? 328 : 318,
                    isCompactHeight: false
                )
                .frame(maxWidth: .infinity, alignment: .center)

                Text("MeQR")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: 334, alignment: .leading)
            .padding(.vertical, 24)
        }
        .frame(width: 390, height: 640)
        .clipped()
    }

    @ViewBuilder
    private var shareBackground: some View {
        if let data = cluster.backgroundImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(.white.opacity(0.34))
        } else {
            cluster.backgroundColor.opacity(0.72)
        }
    }

    private var shareHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if let data = cluster.avatarImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.name)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !cluster.subtitle.isEmpty {
                    Text(ExchangeSubtitleLimiter.limited(cluster.subtitle))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private enum ExchangeSubtitleLimiter {
    private static let maxHalfWidthUnits = 50

    static func limited(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var units = 0
        var result = ""

        for character in normalized {
            let nextUnits = units + halfWidthUnits(for: character)
            if nextUnits > maxHalfWidthUnits {
                break
            }
            result.append(character)
            units = nextUnits
        }

        return result
    }

    static func isOverLimit(_ value: String) -> Bool {
        halfWidthUnitCount(value) > maxHalfWidthUnits
    }

    static func usageText(for value: String) -> String {
        let halfUnits = halfWidthUnitCount(value)
        let whole = halfUnits / 2
        let suffix = halfUnits % 2 == 0 ? "" : ".5"
        return L.exchangeIntroUsage("\(whole)\(suffix)")
    }

    private static func halfWidthUnitCount(_ value: String) -> Int {
        value.reduce(0) { partial, character in
            partial + halfWidthUnits(for: character)
        }
    }

    private static func halfWidthUnits(for character: Character) -> Int {
        if character.isNewline {
            return 0
        }
        return character.unicodeScalars.allSatisfy(\.isASCII) ? 1 : 2
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposalWidth: proposal.width ?? 320)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, proposalWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(for subviews: Subviews, proposalWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let maxWidth = max(proposalWidth, 1)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }

    private struct FlowItem {
        var index: Int
        var size: CGSize
    }

    private struct FlowRow {
        var items: [FlowItem]
        var width: CGFloat
        var height: CGFloat
    }
}
