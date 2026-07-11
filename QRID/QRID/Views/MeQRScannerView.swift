import SwiftUI
import PhotosUI
import AVFoundation

struct MeQRScannerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var decodedProfile: MeQRExchangeProfile?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if cameraAuthorized {
                    QRScannerRepresentable { payload in
                        handlePayload(payload)
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
                EncounterPreviewView(profile: profile)
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

    private func handlePayload(_ payload: String) {
        Task { await decodePayload(payload) }
    }

    @MainActor
    private func decodePayload(_ payload: String) async {
        if let localProfile = try? MeQRExchangeCodec.decode(payload) {
            decodedProfile = localProfile
            return
        }

        if MeQRRemoteService.canFetchProfile(from: payload) {
            do {
                decodedProfile = try await MeQRRemoteService.fetchProfile(from: payload)
                return
            } catch {
                if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
                    decodedProfile = fallbackProfile
                    return
                }
                errorMessage = error.localizedDescription
                showError = true
                return
            }
        }

        if let fallbackProfile = MeQRExchangeCodec.offlineFallback(from: payload) {
            decodedProfile = fallbackProfile
            return
        }

        errorMessage = L.notMeQRProfileCode
        showError = true
    }

    @MainActor
    private func decodePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            let payload = try await QRCodeGenerator.decode(from: image)
            await decodePayload(payload)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onPayload: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onPayload = onPayload
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onPayload: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastPayload = ""
    private var lastPayloadDate = Date.distantPast

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
        onPayload?(payload)
    }
}
