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
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 44, weight: .medium))
                    Text(L.scanMeQRHint)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(L.importMeQRFromPhoto, systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
            .alert(L.couldNotDecodeQR, isPresented: $showError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(errorMessage ?? L.notMeQRProfileCode)
            }
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
        Task {
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

        errorMessage = L.notMeQRProfileCode
        showError = true
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
                  let image = UIImage(data: data) else {
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
