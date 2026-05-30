import SwiftUI
import PhotosUI
import SwiftData

struct AddProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var platformType = "custom"
    @State private var qrContent = ""
    @State private var isGenerated = true
    @State private var importedImage: UIImage?
    @State private var photosItem: PhotosPickerItem?
    @State private var foregroundColor = Color.black
    @State private var backgroundColor = Color.white
    @State private var cornerRadius: Double = 16

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                detailsSection
                appearanceSection
                previewSection
            }
            .navigationTitle("New QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: photosItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        importedImage = image
                    }
                }
            }
        }
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        Section("Source") {
            Picker("Input Method", selection: $isGenerated) {
                Text("Generate from Text").tag(true)
                Text("Import Image").tag(false)
            }
            .pickerStyle(.segmented)

            if isGenerated {
                TextField("URL or text to encode", text: $qrContent, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                PhotosPicker(selection: $photosItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(importedImage == nil ? "Select QR Image" : "Change Image")
                    }
                }
                if let image = importedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section("Details") {
            TextField("Profile Name", text: $name)
                .textInputAutocapitalization(.words)

            Picker("Platform", selection: $platformType) {
                ForEach(Platform.allCases) { platform in
                    HStack {
                        Image(systemName: platform.iconName)
                        Text(platform.displayName)
                    }
                    .tag(platform.rawValue)
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            ColorPicker("QR Code Color", selection: $foregroundColor)
            ColorPicker("Background Color", selection: $backgroundColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("Corner Radius: \(Int(cornerRadius))")
                    .font(.subheadline)
                Slider(value: $cornerRadius, in: 0...40, step: 1)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section("Preview") {
            HStack {
                Spacer()
                previewCard
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var previewCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .frame(width: 160, height: 160)

                if isGenerated {
                    previewQRImage
                } else if let image = importedImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            HStack(spacing: 6) {
                Image(systemName: selectedPlatform.iconName)
                    .foregroundStyle(foregroundColor)
                Text(name.isEmpty ? "Preview" : name)
                    .font(.caption.bold())
                    .foregroundStyle(foregroundColor)
            }
        }
    }

    @ViewBuilder
    private var previewQRImage: some View {
        if !qrContent.isEmpty,
           let uiImage = QRCodeGenerator.generate(
               from: qrContent,
               foreground: foregroundColor,
               background: backgroundColor
           ) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 120, height: 120)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var selectedPlatform: Platform {
        Platform(rawValue: platformType) ?? .custom
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isGenerated {
            return !qrContent.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return importedImage != nil
        }
    }

    private func save() {
        let imageData = isGenerated ? nil : importedImage?.jpegData(compressionQuality: 0.9)
        let profile = QRProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            platformType: platformType,
            qrContent: isGenerated ? qrContent.trimmingCharacters(in: .whitespaces) : nil,
            importedImageData: imageData,
            foregroundColorHex: foregroundColor.toHex() ?? "#000000",
            backgroundColorHex: backgroundColor.toHex() ?? "#FFFFFF",
            cornerRadius: cornerRadius,
            isGenerated: isGenerated
        )
        modelContext.insert(profile)
        dismiss()
    }
}
