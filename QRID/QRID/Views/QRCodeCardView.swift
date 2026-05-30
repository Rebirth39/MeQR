import SwiftUI

struct QRCodeCardView: View {
    let profile: QRProfile
    var size: CGFloat = 280

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: profile.cornerRadius)
                    .fill(profile.backgroundColor)
                    .frame(width: size, height: size)

                qrImage
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size * 0.75, height: size * 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: profile.cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            HStack(spacing: 8) {
                Image(systemName: profile.platform.iconName)
                    .font(.title3)
                    .foregroundStyle(profile.foregroundColor)

                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(profile.foregroundColor)
            }
        }
    }

    @ViewBuilder
    private var qrImage: some View {
        if profile.isGenerated, let content = profile.qrContent,
           let uiImage = QRCodeGenerator.generate(
               from: content,
               foreground: profile.foregroundColor,
               background: profile.backgroundColor
           ) {
            Image(uiImage: uiImage)
        } else if let data = profile.importedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.4, height: size * 0.4)
                .foregroundStyle(.secondary)
        }
    }
}
