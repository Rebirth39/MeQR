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
                previewSection
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
                       let image = UIImage(data: data) {
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
            .alert("Could Not Save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
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
            ColorPicker("文字颜色", selection: $widgetTextColor)
        }
    }

    private var backgroundSection: some View {
        Section(L.widgetBackground) {
            Toggle(L.useCustomBackground, isOn: $widgetUseCustomBackground)

            if widgetUseCustomBackground {
                if let image = widgetBackgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        if let raw = widgetBackgroundImage {
                            rawBackgroundImage = CroppableImage(image: raw)
                        }
                    } label: {
                        Label(L.cropBackground, systemImage: "crop")
                    }

                    Button {
                        widgetBackgroundImage = nil
                        backgroundPhotosItem = nil
                    } label: {
                        Label(L.removeBackground, systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                } else {
                    PhotosPicker(selection: $backgroundPhotosItem, matching: .images) {
                        Label(L.selectBackgroundImage, systemImage: "photo")
                    }
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

    private var previewSection: some View {
        Section(L.preview) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Widget Preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    widgetPreviewCard(size: .systemSmall, width: 100, height: 100)
                    widgetPreviewCard(size: .systemMedium, width: 200, height: 100)
                }

                widgetPreviewCard(size: .systemLarge, width: 200, height: 200)
            }
            .padding(.top, 8)
        }
    }

    private var offsetSection: some View {
        Section("背景位置") {
            Picker("尺寸", selection: $selectedOffsetSize) {
                Text("小号").tag(0)
                Text("中号").tag(1)
                Text("大号").tag(2)
            }
            .pickerStyle(.segmented)

            if selectedOffsetSize == 0 {
                offsetSliders(
                    x: $widgetSmallOffsetX,
                    y: $widgetSmallOffsetY,
                    label: "小号"
                )
            } else if selectedOffsetSize == 1 {
                offsetSliders(
                    x: $widgetMediumOffsetX,
                    y: $widgetMediumOffsetY,
                    label: "中号"
                )
            } else {
                offsetSliders(
                    x: $widgetLargeOffsetX,
                    y: $widgetLargeOffsetY,
                    label: "大号"
                )
            }
        }
    }

    private func offsetSliders(x: Binding<Double>, y: Binding<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("水平")
                    .font(.caption)
                    .frame(width: 32, alignment: .leading)
                Slider(value: x, in: -100...100, step: 1)
                Text("\(Int(x.wrappedValue))")
                    .font(.caption)
                    .frame(width: 28, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Text("垂直")
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

    // MARK: - Preview Card

    private func widgetPreviewCard(size: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        let bgColor = widgetUseClusterBackground ? cluster.backgroundColor : Color.white
        let opacity = widgetOpacity
        let (offsetX, offsetY) = previewOffset(for: size)

        return ZStack {
            if widgetUseCustomBackground, let image = widgetBackgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .offset(x: offsetX, y: offsetY)
                    .opacity(opacity)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgColor.opacity(opacity))
            }

            if size == .systemSmall {
                VStack(alignment: .leading, spacing: 6) {
                    avatarPreview(size: 32)
                    Text(cluster.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(widgetTextColor)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if size == .systemMedium {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        avatarPreview(size: 36)
                        Text(cluster.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(widgetTextColor)
                            .lineLimit(1)
                    }
                    Spacer()
                    qrPreviewView(size: 44)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        avatarPreview(size: 40)
                        Text(cluster.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(widgetTextColor)
                    }
                    qrPreviewView(size: 72)
                }
                .padding(12)
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

    @ViewBuilder
    private func avatarPreview(size: CGFloat) -> some View {
        if let data = cluster.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func qrPreviewView(size: CGFloat) -> some View {
        if let profile = selectedProfile,
           let qrImage = QRCodeGenerator.generate(
               from: profile.qrContent,
               foreground: cluster.qrColor,
               background: widgetUseClusterBackground ? cluster.backgroundColor : Color.white
           ) {
            Image(uiImage: qrImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size))
                .foregroundStyle(cluster.textColor.opacity(0.5))
        }
    }

    private var selectedProfile: QRProfile? {
        guard !profiles.isEmpty else { return nil }
        let index = widgetProfileIndex
        return profiles.indices.contains(index) ? profiles[index] : profiles.first
    }

    private func previewOffset(for size: WidgetFamily) -> (CGFloat, CGFloat) {
        switch size {
        case .systemSmall: return (CGFloat(widgetSmallOffsetX), CGFloat(widgetSmallOffsetY))
        case .systemMedium: return (CGFloat(widgetMediumOffsetX), CGFloat(widgetMediumOffsetY))
        case .systemLarge: return (CGFloat(widgetLargeOffsetX), CGFloat(widgetLargeOffsetY))
        default: return (0, 0)
        }
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
            onDismiss?()
            dismiss()
        } catch {
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
