import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage
import SwiftData

struct MeQRScannerView: View {
    let localCluster: QRCluster?
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var decodedProfile: MeQRExchangeProfile?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var pendingSessionID: String?
    @State private var showingMyCode = false
    @State private var lastRoutedPayload: String?
    @State private var lastRoutedDate = Date.distantPast
    @State private var pendingExternalURL: URL?
    @AppStorage("meqr.allowExternalLinks") private var allowExternalAlways = false

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
                                showingMyCode = true
                            } label: {
                                Label(L.myExchangeCode, systemImage: "qrcode")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(ScannerGlassButtonStyle())
                        }

                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            Label(L.importMeQRFromPhoto, systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(ScannerGlassButtonStyle())
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
                    Button(L.cancel) { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                requestCameraAccessIfNeeded()
            }
            .onChange(of: pickedItem) { _, item in
                Task { await decodePhoto(item) }
            }
            .sheet(item: $decodedProfile) { profile in
                EncounterPreviewView(
                    profile: profile,
                    sessionID: pendingSessionID,
                    localProfile: localProfile
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
            .confirmationDialog("打开外部链接？", isPresented: Binding(
                get: { pendingExternalURL != nil },
                set: { if !$0 { pendingExternalURL = nil } }
            ), titleVisibility: .visible) {
                Button("本次允许") { openPendingExternalURL() }
                Button("之后都允许") { allowExternalAlways = true; openPendingExternalURL() }
                Button("不允许", role: .cancel) { pendingExternalURL = nil }
            } message: {
                Text("将离开喜劳转扩并打开其他 App 或网页。")
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

    private func handlePayload(_ payload: String, frame: UIImage?) {
        Task { @MainActor in
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
            await decodePayload(payload, colorAvatarJPEG: colorAvatarJPEG)
        }
    }

    @MainActor
    private func decodePayload(_ payload: String, colorAvatarJPEG: Data? = nil) async {
        pendingSessionID = nil

        if let localProfile = try? MeQRExchangeCodec.decode(payload) {
            decodedProfile = applyingColorAvatar(colorAvatarJPEG, to: localProfile)
            return
        }

        if MeQRRemoteService.canFetchEncounterSession(from: payload) {
            do {
                let session = try await MeQRRemoteService.fetchEncounterSession(from: payload)
                guard let creatorProfile = session.creatorProfile else {
                    throw MeQRRemoteServiceError.server(L.notMeQRProfileCode)
                }
                pendingSessionID = session.sessionID
                decodedProfile = applyingColorAvatar(colorAvatarJPEG, to: creatorProfile)
                return
            } catch {
                // Continue to the offline fragment below when the session is unavailable.
            }
        }

        if MeQRRemoteService.canFetchProfile(from: payload) {
            do {
                let profile = try await MeQRRemoteService.fetchProfile(from: payload)
                decodedProfile = applyingColorAvatar(colorAvatarJPEG, to: profile)
                return
            } catch {
                if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
                    decodedProfile = applyingColorAvatar(colorAvatarJPEG, to: fallbackProfile)
                    return
                }
                errorMessage = error.localizedDescription
                showError = true
                return
            }
        }

        if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
            decodedProfile = applyingColorAvatar(colorAvatarJPEG, to: fallbackProfile)
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
        // Cooldown: avoid re-routing the same non-MeQR payload repeatedly as the
        // camera keeps firing the metadata callback on the same code.
        let now = Date()
        if payload == lastRoutedPayload, now.timeIntervalSince(lastRoutedDate) < 3 {
            return true
        }

        guard let platform = Platform.detect(from: payload) else {
            // Not a known social platform: open http(s) URLs in the browser.
            if let url = URL(string: payload), url.scheme?.hasPrefix("http") == true {
                lastRoutedPayload = payload
                lastRoutedDate = now
                requestExternalOpen(url)
                return true
            }
            return false
        }

        lastRoutedPayload = payload
        lastRoutedDate = now

        if platform == .wechat {
            openWeChatScan()
            return true
        }

        guard let url = URL(string: payload), url.scheme != nil else { return true }

        if platform == .xiaohongshu {
            openXiaohongshu(url)
            return true
        }

        // Universal Link: opens the matching app if installed, falls back to Safari.
        requestExternalOpen(url)
        return true
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
            let key = url.absoluteString.lowercased()
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
        let s = url.absoluteString.lowercased()
        guard let range = s.range(of: #"[0-9a-f]{24}"#, options: .regularExpression) else {
            return nil
        }
        return String(s[range])
    }

    private static func resolveXiaohongshuRedirect(_ url: URL) async -> URL? {
        var url = url
        if url.scheme == "http", var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.scheme = "https"
            url = comps.url ?? url
        }

        // xhslink returns 302 only to GET (HEAD gives 404). We only need the
        // Location header, not the body, so stop following redirects and read it
        // from the response directly.
        let delegate = RedirectStopDelegate()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        _ = try? await session.data(for: request)
        return delegate.redirectURL
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
        if allowExternalAlways {
            UIApplication.shared.open(url)
        } else {
            pendingExternalURL = url
        }
    }

    @MainActor
    private func openPendingExternalURL() {
        guard let url = pendingExternalURL else { return }
        pendingExternalURL = nil
        UIApplication.shared.open(url)
    }

    private var localProfile: MeQRExchangeProfile? {
        guard let localCluster else { return nil }
        return MeQRExchangeProfile(cluster: localCluster, avatarMaxBytes: 256 * 1024)
    }

    @MainActor
    private func decodePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = QRCodeGenerator.imageForDecoding(from: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            let decoded = try await QRCodeGenerator.decodeEnhanced(from: image)
            await decodePayload(decoded.payload, colorAvatarJPEG: decoded.colorAvatarJPEG)
        } catch {
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
