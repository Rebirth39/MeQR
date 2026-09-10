import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage
import SwiftData

struct MeQRDecodedScan: Identifiable {
    let id = UUID()
    let profile: MeQRExchangeProfile
    let sessionID: String?
    let localProfile: MeQRExchangeProfile?
}

@MainActor
struct MeQRScannerView: View {
    let localCluster: QRCluster?
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var decodedScan: MeQRDecodedScan?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var showingMyCode = false
    @State private var lastRoutedPayload: String?
    @State private var lastRoutedDate = Date.distantPast
    @State private var pendingContent: String?
    @State private var decodeTask: Task<Void, Never>?
    @State private var isScannerActive = false
    @State private var showingPhotoPicker = false
    @State private var trustedLinkTask: Task<Void, Never>?
    @State private var isOpeningTrustedLink = false

    init(localCluster: QRCluster? = nil) {
        self.localCluster = localCluster
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if cameraAuthorized {
                    QRScannerRepresentable { payload, frame in
                        handlePayload(payload, frame: frame)
                    }
                    .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                VStack(spacing: 14) {
                    VStack(spacing: 12) {
                        if localCluster != nil {
                            Button {
                                cancelDecode()
                                showingMyCode = true
                            } label: {
                                Label(L.myExchangeCode, systemImage: "qrcode")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(ScannerGlassButtonStyle())
                        }

                        Button {
                            cancelDecode()
                            showingPhotoPicker = true
                        } label: {
                            Label(L.importMeQRFromPhoto, systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(ScannerGlassButtonStyle())
                        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickedItem, matching: .images)
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 24))
                .padding()
            }
            .navigationTitle(L.scanMeQRCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) {
                        isScannerActive = false
                        cancelDecode()
                        dismiss()
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                isScannerActive = true
                requestCameraAccessIfNeeded()
            }
            .onDisappear {
                isScannerActive = false
                cancelDecode()
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                handlePhoto(item)
            }
            .sheet(item: $decodedScan) { scan in
                EncounterPreviewView(
                    profile: scan.profile,
                    sessionID: scan.sessionID,
                    localProfile: scan.localProfile
                )
            }
            .sheet(isPresented: $showingMyCode) {
                if let localCluster {
                    MeQRProfileCodeView(cluster: localCluster)
                }
            }
            .alert(L.couldNotDecodeQR, isPresented: $showError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(errorMessage ?? L.notMeQRProfileCode)
            }
            .sheet(isPresented: Binding(
                get: { pendingContent != nil },
                set: { if !$0 { pendingContent = nil } }
            )) {
                if let content = pendingContent {
                    QRLinkReviewView(content: content) { url in
                        pendingContent = nil
                        switch Platform.detect(from: content) {
                        case .wechat: openWeChatScan()
                        case .xiaohongshu: openXiaohongshu(url)
                        default: UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
    }

private struct ScannerGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(configuration.isPressed ? 0.62 : 0.3), lineWidth: 1))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.2), radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

    private func requestCameraAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraAuthorized = granted
                    if !granted {
                        errorMessage = L.cameraPermissionNeeded
                        showError = true
                    }
                }
            }
        case .denied, .restricted:
            cameraAuthorized = false
            errorMessage = L.cameraPermissionNeeded
            showError = true
        @unknown default:
            cameraAuthorized = false
        }
    }

    private var canPresentScanResult: Bool {
        isScannerActive && pendingContent == nil && decodedScan == nil && !showingMyCode && !showError && !isOpeningTrustedLink
    }

    private func cancelDecode() {
        decodeTask?.cancel()
        decodeTask = nil
        trustedLinkTask?.cancel()
        trustedLinkTask = nil
        isOpeningTrustedLink = false
    }

    private func handlePayload(_ payload: String, frame: UIImage?) {
        guard canPresentScanResult, !showingPhotoPicker, pickedItem == nil, decodeTask == nil else { return }
        // Reserve the slot synchronously so the next camera callback cannot start another decode.
        decodeTask = Task { @MainActor in
            defer {
                // A cancelled task may finish after a replacement has taken the slot.
                if !Task.isCancelled { decodeTask = nil }
            }
            guard !Task.isCancelled, canPresentScanResult else { return }
            // Fast path: only MeQR codes carry a color layer worth the expensive
            // decodeEnhanced pass. Social-platform and plain-URL codes route at once.
            let isMeQRPayload = (try? MeQRExchangeCodec.decode(payload)) != nil
                || MeQRRemoteService.canFetchEncounterSession(from: payload)
                || MeQRRemoteService.canFetchProfile(from: payload)
                || MeQRExchangeCodec.offlineFallback(from: payload) != nil

            if !isMeQRPayload {
                if !routeGenericQR(payload) {
                    errorMessage = L.notMeQRProfileCode
                    showError = true
                }
                return
            }

            var colorAvatarJPEG: Data?
            if let frame,
               let decoded = try? await QRCodeGenerator.decodeEnhanced(from: frame) {
                colorAvatarJPEG = decoded.colorAvatarJPEG
            }
            guard !Task.isCancelled, canPresentScanResult else { return }
            await decodePayload(payload, colorAvatarJPEG: colorAvatarJPEG)
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem) {
        guard canPresentScanResult else { return }
        cancelDecode()
        decodeTask = Task { @MainActor in
            defer {
                if !Task.isCancelled { decodeTask = nil }
            }
            await decodePhoto(item)
        }
    }

    @MainActor
    private func decodePayload(_ payload: String, colorAvatarJPEG: Data? = nil) async {
        guard !Task.isCancelled, canPresentScanResult else { return }
        if let localProfile = try? MeQRExchangeCodec.decode(payload) {
            presentScan(applyingColorAvatar(colorAvatarJPEG, to: localProfile), isOffline: true)
            return
        }

        if MeQRRemoteService.canFetchEncounterSession(from: payload) {
            do {
                let session = try await MeQRRemoteService.fetchEncounterSession(from: payload)
                guard !Task.isCancelled, canPresentScanResult else { return }
                guard let creatorProfile = session.creatorProfile else {
                    throw MeQRRemoteServiceError.server(L.notMeQRProfileCode)
                }
                presentScan(applyingColorAvatar(colorAvatarJPEG, to: creatorProfile), sessionID: session.sessionID)
                return
            } catch {
                guard !Task.isCancelled, canPresentScanResult else { return }
                if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
                    presentScan(applyingColorAvatar(colorAvatarJPEG, to: fallbackProfile),
                                sessionID: MeQRRemoteService.encounterSessionID(from: payload), isOffline: true)
                    return
                }
            }
        }

        if MeQRRemoteService.canFetchProfile(from: payload) {
            do {
                let profile = try await MeQRRemoteService.fetchProfile(from: payload)
                guard !Task.isCancelled, canPresentScanResult else { return }
                presentScan(applyingColorAvatar(colorAvatarJPEG, to: profile))
                return
            } catch {
                guard !Task.isCancelled, canPresentScanResult else { return }
                if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
                    presentScan(applyingColorAvatar(colorAvatarJPEG, to: fallbackProfile), isOffline: true)
                    return
                }
                errorMessage = error.localizedDescription
                showError = true
                return
            }
        }

        if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
            presentScan(applyingColorAvatar(colorAvatarJPEG, to: fallbackProfile), isOffline: true)
            return
        }

        if routeGenericQR(payload) {
            return
        }

        errorMessage = L.notMeQRProfileCode
        showError = true
    }

    @MainActor
    @discardableResult
    private func routeGenericQR(_ payload: String) -> Bool {
        guard pendingContent == nil, decodedScan == nil, !showingMyCode else { return true }
        // Cooldown: avoid re-routing the same non-MeQR payload repeatedly as the
        // camera keeps firing the metadata callback on the same code.
        let now = Date()
        if payload == lastRoutedPayload, now.timeIntervalSince(lastRoutedDate) < 3 {
            return true
        }

        lastRoutedPayload = payload
        lastRoutedDate = now
        if let destination = QRLinkPolicy.trustedDestination(payload), let url = QRLinkPolicy.webURL(payload) {
            openTrustedLink(url, destination: destination)
            return true
        }
        pendingContent = payload
        return true
    }

    private func openTrustedLink(_ url: URL, destination: QRLinkPolicy.TrustedDestination) {
        isOpeningTrustedLink = true
        trustedLinkTask = Task { @MainActor in
            defer {
                if !Task.isCancelled {
                    isOpeningTrustedLink = false
                    trustedLinkTask = nil
                    lastRoutedDate = Date()
                }
            }
            guard !Task.isCancelled, isScannerActive else { return }
            let error = await Self.openTrustedDestination(url, destination: destination)
            guard !Task.isCancelled, isScannerActive else { return }
            if let error { errorMessage = error; showError = true }
        }
    }

    static func openTrustedDestination(_ url: URL, destination: QRLinkPolicy.TrustedDestination) async -> String? {
        guard !Task.isCancelled else { return nil }
        switch destination {
        case .wechatScan:
            let opened = await UIApplication.shared.open(URL(string: "weixin://scanqrcode")!)
            return opened ? nil : L.wechatNotInstalled
        case .qq, .web:
            let opened = await UIApplication.shared.open(url)
            return opened ? nil : L.qrAppOpenFailed
        case .xiaohongshu:
            let key = url.absoluteString
            var userID = xiaohongshuUserIDCache.object(forKey: key as NSString) as String?
            if userID == nil, let resolved = await resolveXiaohongshuRedirect(url) {
                userID = xiaohongshuUserID(from: resolved)
            }
            guard !Task.isCancelled else { return nil }
            let opened: Bool
            if let userID, let appURL = URL(string: "xhsdiscover://user/\(userID)") {
                xiaohongshuUserIDCache.setObject(userID as NSString, forKey: key as NSString)
                opened = await UIApplication.shared.open(appURL)
            } else {
                opened = await UIApplication.shared.open(url, options: [.universalLinksOnly: true])
            }
            return opened ? nil : L.qrAppOpenFailed
        }
    }

    @MainActor
    private func openXiaohongshu(_ url: URL) {
        // Xiaohongshu doesn't route xiaohongshu.com via Universal Link; opening
        // the web URL (or the xhslink short link) lands in Safari. The app opens
        // a user profile through xhsdiscover://user/<user_id>, so extract the
        // 24-hex user ID and deep-link instead.
        if let userID = Self.xiaohongshuUserID(from: url) {
            openXiaohongshuApp(userID: userID, fallback: url)
            return
        }

        // xhslink.com short links need one redirect hop to reveal the profile URL.
        Task { @MainActor in
            let key = url.absoluteString
            if let cached = Self.xiaohongshuUserIDCache.object(forKey: key as NSString) {
                openXiaohongshuApp(userID: cached as String, fallback: url)
                return
            }
            if let resolved = await Self.resolveXiaohongshuRedirect(url),
               let userID = Self.xiaohongshuUserID(from: resolved) {
                Self.xiaohongshuUserIDCache.setObject(userID as NSString, forKey: key as NSString)
                openXiaohongshuApp(userID: userID, fallback: resolved)
            } else {
                requestExternalOpen(url)
            }
        }
    }

    @MainActor
    private func openXiaohongshuApp(userID: String, fallback: URL) {
        guard let schemeURL = URL(string: "xhsdiscover://user/\(userID)") else {
            requestExternalOpen(fallback)
            return
        }
        if UIApplication.shared.canOpenURL(schemeURL) {
            requestExternalOpen(schemeURL)
        } else {
            requestExternalOpen(fallback)
        }
    }

    private static let xiaohongshuUserIDCache = NSCache<NSString, NSString>()

    private static func xiaohongshuUserID(from url: URL) -> String? {
        QRLinkPolicy.xiaohongshuProfileID(url)
    }

    private static func resolveXiaohongshuRedirect(_ url: URL) async -> URL? {
        guard var current = QRLinkPolicy.xiaohongshuRedirectURL(url) else { return nil }
        var visited = Set<URL>()
        for _ in 0..<4 {
            guard !Task.isCancelled, visited.insert(current).inserted else { return nil }
            if Self.xiaohongshuUserID(from: current) != nil { return current }
            // Check every redirect before following it; short links can have multiple hops.
            let delegate = RedirectStopDelegate()
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 8
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: current)
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            _ = try? await session.data(for: request)
            guard !Task.isCancelled, let redirected = delegate.redirectURL,
                  let checked = QRLinkPolicy.xiaohongshuRedirectURL(redirected) else { return nil }
            current = checked
        }
        return Self.xiaohongshuUserID(from: current) != nil ? current : nil
    }

    @MainActor
    private func openWeChatScan() {
        guard let scanURL = URL(string: "weixin://scanqrcode") else { return }
        if UIApplication.shared.canOpenURL(scanURL) {
            UIApplication.shared.open(scanURL)
        } else {
            errorMessage = L.wechatNotInstalled
            showError = true
        }
    }

    @MainActor
    private func requestExternalOpen(_ url: URL) {
        // Used by the manually approved flow; trusted links have their own App routing.
        UIApplication.shared.open(url)
    }

    private func presentScan(_ profile: MeQRExchangeProfile, sessionID: String? = nil, isOffline: Bool = false) {
        // The sheet receives one snapshot; separate State values can be stale on first presentation.
        decodedScan = MeQRDecodedScan(profile: profile, sessionID: sessionID, localProfile: localProfile(forOffline: isOffline))
    }

    private func localProfile(forOffline isOffline: Bool) -> MeQRExchangeProfile? {
        guard let localCluster else { return nil }
        let sorted = localCluster.profiles.sorted { $0.createdAt < $1.createdAt }
        let savedIDs = UserDefaults.standard.stringArray(forKey: "meqr.exchange.selectedProfiles.\(localCluster.id.uuidString)") ?? []
        let selected = sorted.filter { savedIDs.contains($0.id.uuidString) }
        let included = Array((selected.isEmpty ? sorted : selected).prefix(3))
        if isOffline {
            let savedID = UserDefaults.standard.string(forKey: "meqr.exchange.offlineProfile.\(localCluster.id.uuidString)")
            let platform = included.first { $0.id.uuidString == savedID } ?? included.first
            var profile = MeQRExchangeProfile(offlineCluster: localCluster, profile: platform)
            if let subtitle = UserDefaults.standard.string(forKey: "meqr.exchange.subtitle.\(localCluster.id.uuidString)") {
                profile.subtitle = subtitle
            }
            return profile
        }
        var profile = MeQRExchangeProfile(cluster: localCluster, profiles: included, avatarMaxBytes: 256 * 1024)
        profile.intro = ""
        return profile
    }

    @MainActor
    private func decodePhoto(_ item: PhotosPickerItem?) async {
        guard let item, !Task.isCancelled, canPresentScanResult else { return }
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled, canPresentScanResult else { return }
            guard let data,
                  let image = QRCodeGenerator.imageForDecoding(from: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            let decoded = try await QRCodeGenerator.decodeEnhanced(from: image)
            guard !Task.isCancelled, canPresentScanResult else { return }
            await decodePayload(decoded.payload, colorAvatarJPEG: decoded.colorAvatarJPEG)
        } catch {
            guard !Task.isCancelled, canPresentScanResult else { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func applyingColorAvatar(_ jpeg: Data?, to profile: MeQRExchangeProfile) -> MeQRExchangeProfile {
        guard let jpeg else { return profile }
        let currentBytes = profile.avatarJPEGBase64.flatMap { Data(base64Encoded: $0) }?.count ?? 0
        guard jpeg.count > currentBytes else { return profile }
        var enhanced = profile
        enhanced.avatarJPEGBase64 = jpeg.base64EncodedString()
        return enhanced
    }
}

/// Captures the first redirect's Location header and cancels the rest of the
/// request, so we never download the redirect target's (potentially large) body.
private final class RedirectStopDelegate: NSObject, URLSessionTaskDelegate {
    private(set) var redirectURL: URL?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectURL = request.url
        completionHandler(nil)
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onPayload: (String, UIImage?) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onPayload = onPayload
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onPayload: ((String, UIImage?) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastPayload = ""
    private var lastPayloadDate = Date.distantPast
    private let frameQueue = DispatchQueue(label: "meqr.color-layer.frames", qos: .userInitiated)
    private let frameLock = NSLock()
    private let imageContext = CIContext()
    private var latestPixelBuffer: CVPixelBuffer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            videoOutput.connection(with: .video)?.videoRotationAngle = 90
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = readableObject.stringValue else {
            return
        }

        let now = Date()
        guard payload != lastPayload || now.timeIntervalSince(lastPayloadDate) > 2 else { return }
        lastPayload = payload
        lastPayloadDate = now

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPayload?(payload, latestFrameImage())
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock()
        latestPixelBuffer = pixelBuffer
        frameLock.unlock()
    }

    private func latestFrameImage() -> UIImage? {
        frameLock.lock()
        let pixelBuffer = latestPixelBuffer
        frameLock.unlock()
        guard let pixelBuffer else { return nil }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
