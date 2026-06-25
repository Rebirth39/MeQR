import SwiftUI

struct QRCodeCardView: View {
    let profile: QRProfile
    var size: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头像
            avatarImage
                .frame(width: 80, height: 80)

            // 用户名
            Text(profile.displayName)
                .font(.title3.bold())
                .foregroundStyle(profile.foregroundColor)

            // 副标题 / 平台
            if !profile.displaySubtitle.isEmpty {
                Text(profile.displaySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(profile.foregroundColor.opacity(0.7))
            } else {
                Text(profile.platformDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(profile.foregroundColor.opacity(0.7))
            }

            // QR 码
            qrImage
                .frame(width: size, height: size, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: profile.displayCornerRadius)
                .fill(.white.opacity(0.75))
        )
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarImage: some View {
        if let data = profile.displayAvatarImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(profile.foregroundColor.opacity(0.15))

                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(profile.foregroundColor.opacity(0.6))
            }
        }
    }

    // MARK: - QR Code

    @ViewBuilder
    private var qrImage: some View {
        if let uiImage = QRCodeGenerator.generate(
            from: profile.qrContent,
            foreground: profile.foregroundColor,
            background: profile.backgroundColor
        ) {
            Image(uiImage: uiImage)
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
}
