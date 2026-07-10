import SwiftUI

struct ClusterCardView: View {
    let cluster: QRCluster
    var size: CGFloat = 180
    var containerWidth: CGFloat = UIScreen.main.bounds.width
    var onProfileSelected: ((Int) -> Void)? = nil

    @State private var selectedIndex: Int = 0
    @State private var isShowingPassBack = false
    @State private var passFlipRotation: Double = 0
    @State private var isPassFlipAnimating = false

    private var sortedProfiles: [QRProfile] {
        cluster.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    private var currentProfile: QRProfile? {
        sortedProfiles[safe: selectedIndex]
    }

    var body: some View {
        Group {
            switch cluster.templateStyle {
            case .standard, .polaroid:
                standardCard
            case .conventionPass:
                conventionPassCard
            case .rhodesPass:
                rhodesPassCard
            }
        }
        .onChange(of: sortedProfiles.count) { _, newCount in
            if selectedIndex >= newCount {
                selectedIndex = max(0, newCount - 1)
            }
        }
        .onChange(of: selectedIndex) { _, newIndex in
            onProfileSelected?(newIndex)
        }
        .onChange(of: cluster.id) { _, _ in
            isShowingPassBack = false
            passFlipRotation = 0
            isPassFlipAnimating = false
        }
        .onChange(of: cluster.templateStyle) { _, _ in
            isShowingPassBack = false
            passFlipRotation = 0
            isPassFlipAnimating = false
        }
    }

    private var standardCard: some View {
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
                    .clipped()
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
    }

    private var polaroidCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                polaroidInfoPanel
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)

                qrSlot(side: min(size, 134))
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.black.opacity(0.08), lineWidth: 1)
                    )

            }
            .frame(height: 176)

            if sortedProfiles.count > 1 {
                platformPicker
            }
        }
        .padding(12)
        .frame(maxWidth: containerWidth - 20, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
    }

    private var polaroidInfoPanel: some View {
        ZStack(alignment: .topLeading) {
            templateImagePanel
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Rectangle()
                .fill(.white.opacity(0.64))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 9) {
                avatarImage
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 3))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                Text(cluster.name)
                    .font(.headline.bold())
                    .foregroundStyle(.black.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                if !cluster.subtitle.isEmpty {
                    Text(cluster.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.62))
                        .lineLimit(3)
                } else if let profile = currentProfile {
                    Label(profile.platformDisplayName, systemImage: profile.platform.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var conventionPassCard: some View {
        passFlipCard(front: conventionPassFront, back: passBackCard(cornerRadius: max(18, cluster.cornerRadius)))
    }

    private var conventionPassFront: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: ClusterTemplateStyle.conventionPass.iconName)
                    .font(.system(size: 18, weight: .bold))
                Text("MEQR PASS")
                    .font(.system(size: 18, weight: .black))
                Spacer()
                Text(Date.now, format: .dateTime.month().day())
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(cluster.textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cluster.textColor.opacity(0.72), lineWidth: 1.4)
            )

            HStack(alignment: .top, spacing: 12) {
                avatarImage
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(cluster.textColor.opacity(0.24), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(cluster.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(cluster.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(cluster.passSubtitleText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cluster.textColor.opacity(0.66))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 12) {
                qrSlot(side: min(size + 10, 190))
                    .padding(9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(cluster.textColor.opacity(0.10), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L.templateConventionPass)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cluster.textColor.opacity(0.62))

                    if let profile = currentProfile {
                        Label(profile.platformDisplayName, systemImage: profile.platform.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(cluster.textColor)
                            .lineLimit(2)
                    }

                    if sortedProfiles.count > 1 {
                        passPlatformPicker
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: containerWidth - 32, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: max(18, cluster.cornerRadius))
                .fill(cluster.backgroundColor.opacity(max(cluster.cardOpacity ?? 0.78, 0.72)))
        )
    }

    private var rhodesPassCard: some View {
        passFlipCard(front: rhodesPassFront, back: rhodesPassBack)
    }

    private var rhodesPassFront: some View {
        VStack(spacing: 0) {
            rhodesTopStrip

            HStack(spacing: 0) {
                rhodesSideRail
                rhodesContent
            }
        }
        .frame(maxWidth: containerWidth - 32, alignment: .leading)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.70), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(cluster.textColor.opacity(0.18), lineWidth: 1)
                .padding(-8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var rhodesTopStrip: some View {
        HStack(spacing: 0) {
            Rectangle().fill(cluster.qrColor.opacity(0.82))
            Rectangle().fill(cluster.textColor.opacity(0.82))
            Rectangle().fill(cluster.backgroundColor.opacity(0.92))
        }
        .frame(height: 24)
        .overlay(alignment: .trailing) {
            Text("#\(String(format: "%02d", cluster.sortOrder + 1))")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black.opacity(0.62))
                .padding(.trailing, 14)
        }
    }

    private var rhodesSideRail: some View {
        ZStack {
            Rectangle()
                .fill(cluster.textColor.opacity(0.86))

            VStack(spacing: 10) {
                Text("MEQR")
                    .font(.system(size: 18, weight: .black))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)

                barcodeLines
                    .frame(width: 34, height: 92)

                Text("PASS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 62, height: 36)
            }
            .foregroundStyle(.white.opacity(0.88))
        }
        .frame(width: 50)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private var rhodesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            rhodesHeroPanel
            rhodesDetailsRow
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rhodesHeroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            rhodesBannerPanel
                .frame(height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 9) {
                avatarImage
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(cluster.passSubtitleText)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var rhodesDetailsRow: some View {
        HStack(alignment: .top, spacing: 10) {
            qrSlot(side: max(120, min(size - 26, 154)))
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )

            rhodesInfoBlock
        }
    }

    private var rhodesInfoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.passLabel)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(cluster.textColor.opacity(0.66))

            if sortedProfiles.count > 1 {
                passPlatformPicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rhodesPassBack: some View {
        VStack(spacing: 0) {
            rhodesTopStrip

            HStack(spacing: 0) {
                rhodesSideRail

                passBackContent
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: containerWidth - 32, alignment: .leading)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.70), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(cluster.textColor.opacity(0.18), lineWidth: 1)
                .padding(-8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func passFlipCard<Front: View, Back: View>(front: Front, back: Back) -> some View {
        front
        .modifier(PassFlipModifier(angle: passFlipRotation, back: back, verticalOverscan: 44))
        .contentShape(RoundedRectangle(cornerRadius: max(18, cluster.cornerRadius)))
        .onTapGesture {
            guard !isPassFlipAnimating else { return }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            flipPassCard()
        }
    }

    private func passBackCard(cornerRadius: CGFloat) -> some View {
        passBackContent
        .padding(16)
        .frame(maxWidth: containerWidth - 32, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cluster.backgroundColor.opacity(max(cluster.cardOpacity ?? 0.78, 0.72)))
        )
    }

    private var passBackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                avatarImage
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(cluster.textColor.opacity(0.18), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(cluster.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(cluster.passSubtitleText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cluster.textColor.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(cluster.textColor.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 8) {
                if cluster.subtitle.isEmpty {
                    Text(L.subtitleInfo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(cluster.textColor.opacity(0.38))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(cluster.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(cluster.textColor.opacity(0.82))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: 190)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cluster.textColor.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func flipPassCard() {
        let targetBack = !isShowingPassBack
        isPassFlipAnimating = true
        isShowingPassBack = targetBack

        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.48)) {
            passFlipRotation = targetBack ? 180 : 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            isPassFlipAnimating = false
        }
    }

    private var polaroidPhotoPanel: some View {
        ZStack {
            Color.white

            VStack(spacing: 10) {
                avatarImage
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(cluster.qrColor.opacity(0.18), lineWidth: 6))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

                HStack(spacing: 24) {
                    Rectangle()
                        .fill(cluster.textColor.opacity(0.12))
                        .frame(width: 74, height: 2)
                    Circle()
                        .fill(cluster.qrColor.opacity(0.65))
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(cluster.textColor.opacity(0.12))
                        .frame(width: 74, height: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var templateImagePanel: some View {
        if let data = cluster.backgroundImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                cluster.backgroundColor
                LinearGradient(
                    colors: [
                        cluster.textColor.opacity(0.20),
                        cluster.backgroundColor.opacity(0.10),
                        cluster.qrColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private var rhodesBannerPanel: some View {
        if let data = cluster.rhodesBannerImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            templateImagePanel
        }
    }

    private var barcodeLines: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(.white.opacity(index.isMultiple(of: 3) ? 0.92 : 0.62))
                    .frame(width: index.isMultiple(of: 4) ? 4 : 2)
            }
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
        let qrColor = cluster.qrColorHex.map { Color(hex: $0) } ?? profile.foregroundColor
        let baseImage = hasCustomBg
            ? QRCodeGenerator.generateTransparent(from: profile.qrContent, foreground: qrColor)
            : QRCodeGenerator.generate(from: profile.qrContent, foreground: qrColor, background: profile.backgroundColor)
        let uiImage = hasCustomBg
            ? baseImage.flatMap(QRCodeGenerator.trimQuietZoneForDisplay)
            : baseImage
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

    @ViewBuilder
    private func qrSlot(side: CGFloat) -> some View {
        if let profile = currentProfile {
            qrImage(for: profile)
                .frame(width: side, height: side)
                .clipped()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: side, height: side)
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

    private var passPlatformPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sortedProfiles.enumerated()), id: \.element.id) { index, profile in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = index
                    }
                } label: {
                    Label(profile.platformDisplayName, systemImage: profile.platform.iconName)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PassFlipModifier<Back: View>: AnimatableModifier {
    var angle: Double
    let back: Back
    let verticalOverscan: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var normalizedAngle: Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    private var isShowingFront: Bool {
        normalizedAngle < 90 || normalizedAngle > 270
    }

    private var flipProgress: CGFloat {
        CGFloat(abs(sin(normalizedAngle * .pi / 180)))
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isShowingFront ? 1 : 0)

            back
                .opacity(isShowingFront ? 0 : 1)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .padding(.vertical, verticalOverscan)
        .compositingGroup()
        .scaleEffect(1 - 0.055 * flipProgress)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
    }
}
