import SwiftUI
import PhotosUI
import SwiftData
import WidgetKit

struct WidgetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]

    let cluster: QRCluster
    let profiles: [QRProfile]
    var onDismiss: (() -> Void)?

    @State private var widgetProfileIndex: Int = 0
    @State private var widgetUseClusterBackground: Bool = true
    @State private var widgetOpacity: Double = 0.8
    @State private var widgetTextColor: Color = .black
    @State private var widgetBackgroundImage: UIImage?
    @State private var widgetUseCustomBackground: Bool = false
    @State private var rawBackgroundImage: CroppableImage?
    @State private var backgroundPhotosItem: PhotosPickerItem?
    @State private var widgetSmallOffsetX: Double = 0
    @State private var widgetSmallOffsetY: Double = 0
    @State private var widgetMediumOffsetX: Double = 0
    @State private var widgetMediumOffsetY: Double = 0
    @State private var widgetLargeOffsetX: Double = 0
    @State private var widgetLargeOffsetY: Double = 0
    @State private var selectedOffsetSize: Int = 0
    @State private var saveError: String?
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                qrSelectionSection
                backgroundSection
                opacitySection
                offsetSection
            }
            .navigationTitle(L.widgetSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) {
                        onDismiss?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) { save() }
                }
            }
            .onAppear { loadFromCluster() }
            .onChange(of: backgroundPhotosItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = QRCodeGenerator.imageForEditing(from: data) {
                        rawBackgroundImage = CroppableImage(image: image)
                    }
                }
            }
            .fullScreenCover(item: $rawBackgroundImage) { item in
                BackgroundCropView(
                    sourceImage: item.image,
                    onDone: { cropped in
                        widgetBackgroundImage = cropped
                        rawBackgroundImage = nil
                    },
                    onCancel: {
                        rawBackgroundImage = nil
                    }
                )
            }
            .alert(L.couldNotSave, isPresented: $showSaveError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(saveError ?? L.tryAgain)
            }
        }
    }

    // MARK: - Sections

    private var qrSelectionSection: some View {
        Section(L.widgetDisplay) {
            if !profiles.isEmpty {
                Picker(L.showQR, selection: $widgetProfileIndex) {
                    ForEach(0..<profiles.count, id: \.self) { index in
                        Text(profiles[index].platformDisplayName)
                            .tag(index)
                    }
                }
            }
            Toggle(L.useClusterBackgroundColor, isOn: $widgetUseClusterBackground)
            ColorPicker(L.textColor, selection: $widgetTextColor)
        }
    }

    private var backgroundSection: some View {
        Section(L.widgetBackground) {
            Toggle(L.useCustomBackground, isOn: $widgetUseCustomBackground)

            if widgetUseCustomBackground {
                PhotosPicker(selection: $backgroundPhotosItem, matching: .images) {
                    Label(widgetBackgroundImage == nil ? L.selectBackgroundImage : L.changeBackgroundImage, systemImage: "photo")
                }

                if widgetBackgroundImage != nil {
                    Button {
                        widgetBackgroundImage = nil
                        backgroundPhotosItem = nil
                    } label: {
                        Label(L.removeBackground, systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private var opacitySection: some View {
        Section(L.opacity) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(L.opacity): \(Int(widgetOpacity * 100))%")
                    .font(.subheadline)
                Slider(value: $widgetOpacity, in: 0.1...1.0, step: 0.05)
            }
        }
    }

    private var offsetSection: some View {
        Section(L.widgetBackgroundPosition) {
            Picker(L.widgetSize, selection: $selectedOffsetSize) {
                Text(L.widgetSmall).tag(0)
                Text(L.widgetMedium).tag(1)
                Text(L.widgetLarge).tag(2)
            }
            .pickerStyle(.segmented)

            if selectedOffsetSize == 0 {
                offsetSliders(
                    x: $widgetSmallOffsetX,
                    y: $widgetSmallOffsetY,
                    label: L.widgetSmall
                )
            } else if selectedOffsetSize == 1 {
                offsetSliders(
                    x: $widgetMediumOffsetX,
                    y: $widgetMediumOffsetY,
                    label: L.widgetMedium
                )
            } else {
                offsetSliders(
                    x: $widgetLargeOffsetX,
                    y: $widgetLargeOffsetY,
                    label: L.widgetLarge
                )
            }
        }
    }

    private func offsetSliders(x: Binding<Double>, y: Binding<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.horizontal)
                    .font(.caption)
                    .frame(width: 32, alignment: .leading)
                Slider(value: x, in: -100...100, step: 1)
                Text("\(Int(x.wrappedValue))")
                    .font(.caption)
                    .frame(width: 28, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Text(L.vertical)
                    .font(.caption)
                    .frame(width: 32, alignment: .leading)
                Slider(value: y, in: -100...100, step: 1)
                Text("\(Int(y.wrappedValue))")
                    .font(.caption)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Data

    private func loadFromCluster() {
        widgetProfileIndex = cluster.widgetProfileIndex ?? 0
        widgetUseClusterBackground = cluster.widgetUseClusterBackground ?? true
        widgetOpacity = cluster.widgetOpacity ?? 0.8
        widgetTextColor = Color(hex: cluster.widgetTextColorHex ?? cluster.textColorHex ?? "#000000")
        if let data = cluster.widgetBackgroundImageData {
            widgetBackgroundImage = UIImage(data: data)
            widgetUseCustomBackground = true
        } else {
            widgetBackgroundImage = nil
            widgetUseCustomBackground = false
        }
        widgetSmallOffsetX = cluster.widgetSmallOffsetX ?? 0
        widgetSmallOffsetY = cluster.widgetSmallOffsetY ?? 0
        widgetMediumOffsetX = cluster.widgetMediumOffsetX ?? 0
        widgetMediumOffsetY = cluster.widgetMediumOffsetY ?? 0
        widgetLargeOffsetX = cluster.widgetLargeOffsetX ?? 0
        widgetLargeOffsetY = cluster.widgetLargeOffsetY ?? 0
    }

    private func save() {
        cluster.widgetProfileIndex = widgetProfileIndex
        cluster.widgetUseClusterBackground = widgetUseClusterBackground
        cluster.widgetOpacity = widgetOpacity
        cluster.widgetTextColorHex = widgetTextColor.toHex() ?? "#000000"
        cluster.widgetBackgroundImageData = widgetUseCustomBackground ? resizedWidgetImageData(from: widgetBackgroundImage) : nil
        cluster.widgetSmallOffsetX = widgetSmallOffsetX
        cluster.widgetSmallOffsetY = widgetSmallOffsetY
        cluster.widgetMediumOffsetX = widgetMediumOffsetX
        cluster.widgetMediumOffsetY = widgetMediumOffsetY
        cluster.widgetLargeOffsetX = widgetLargeOffsetX
        cluster.widgetLargeOffsetY = widgetLargeOffsetY
        do {
            try modelContext.save()
            WidgetDataHelper.sync(clusters: clusters)
            BackupManager.writeAutoBackup(clusters: clusters)
            onDismiss?()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
            showSaveError = true
        }
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
}
