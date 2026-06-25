import SwiftUI

struct ClusterCardView: View {
    let cluster: QRCluster
    var size: CGFloat = 180
    var containerWidth: CGFloat = UIScreen.main.bounds.width
    var onProfileSelected: ((Int) -> Void)? = nil

    @State private var selectedIndex: Int = 0

    private var sortedProfiles: [QRProfile] {
        cluster.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    private var currentProfile: QRProfile? {
        sortedProfiles[safe: selectedIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top: avatar + name (left) | info (right)
            HStack(alignment: .top, spacing: 12) {
                // Left: avatar + name
                VStack(alignment: .leading, spacing: 6) {
                    avatarImage
                        .frame(width: 56, height: 56)

                    Text(cluster.name)
                        .font(.headline.bold())
                        .foregroundStyle(cluster.textColor)
                        .lineLimit(1)
                }

                // Divider
                if !cluster.subtitle.isEmpty {
                    Rectangle()
                        .fill(cluster.textColor.opacity(0.3))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }

                // Right: info / subtitle
                if !cluster.subtitle.isEmpty {
                    Text(cluster.subtitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(cluster.textColor.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(9)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            // QR code
            if let profile = currentProfile {
                qrImage(for: profile)
                    .frame(width: size, height: size, alignment: .leading)
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size, alignment: .leading)
            }

            // Platform picker
            if sortedProfiles.count > 1 {
                platformPicker
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: containerWidth - 32, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cluster.cornerRadius)
                .fill(cluster.backgroundColor.opacity(cluster.cardOpacity ?? 0.7))
        )
        .onChange(of: sortedProfiles.count) { _, newCount in
            if selectedIndex >= newCount {
                selectedIndex = max(0, newCount - 1)
            }
        }
        .onChange(of: selectedIndex) { _, newIndex in
            onProfileSelected?(newIndex)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarImage: some View {
        if let data = cluster.avatarImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(cluster.textColor.opacity(0.15))

                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(cluster.textColor.opacity(0.6))
            }
        }
    }

    // MARK: - QR Code

    @ViewBuilder
    private func qrImage(for profile: QRProfile) -> some View {
        let hasCustomBg = cluster.backgroundImageData != nil
        let qrColor = cluster.qrColor ?? profile.foregroundColor
        let uiImage = hasCustomBg
            ? QRCodeGenerator.generateTransparent(from: profile.qrContent, foreground: qrColor)
            : QRCodeGenerator.generate(from: profile.qrContent, foreground: qrColor, background: profile.backgroundColor)
        if let uiImage = uiImage {
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

    // MARK: - Platform Picker

    private var platformPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sortedProfiles.enumerated()), id: \.element.id) { index, profile in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = index
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: profile.platform.iconName)
                                .font(.caption)
                            Text(profile.platformDisplayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(index == selectedIndex
                                    ? (currentProfile?.foregroundColor ?? .primary)
                                    : Color.white.opacity(0.55))
                        )
                        .foregroundStyle(index == selectedIndex
                            ? ((currentProfile?.foregroundColor ?? .primary).uiContrastColor)
                            : cluster.textColor)
                    }
                }
            }
        }
    }
}
