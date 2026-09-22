import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

struct ClusterCardView: View {
    let cluster: QRCluster
    var size: CGFloat = 180
    var containerWidth: CGFloat = UIScreen.main.bounds.width
    var onProfileSelected: ((Int) -> Void)? = nil
    var landscapeTabletPresentation: Bool = false

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
            case .standard:
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
            .fixedSize(horizontal: false, vertical: true)

            if !landscapeTabletPresentation && !cluster.tags.isEmpty {
                cardTagChips
            }

            // QR code
            if let profile = currentProfile {
                qrImage(for: profile)
                    .padding(14)
                    .frame(width: size, height: size, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .clipped()
                    .accessibilityIdentifier("standard-card-qr")
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
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: cluster.cornerRadius)
                .fill(cluster.backgroundColor.opacity(cluster.cardOpacity ?? 0.7))
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
                qrSlot(side: min(size + 10, 190) - 22)
                    .padding(20)
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

    @ViewBuilder
    private var rhodesPassCard: some View {
        if landscapeTabletPresentation {
            rhodesPassFront
        } else {
            passFlipCard(front: rhodesPassFront, back: rhodesPassBack)
        }
    }

    private var rhodesPassFront: some View {
        rhodesSurface(VStack(spacing: 0) {
            rhodesTopStrip

            HStack(spacing: 0) {
                rhodesSideRail
                rhodesContent
            }
        }
        .frame(width: rhodesCardWidth, alignment: .topLeading)
        .frame(height: rhodesFixedCardHeight, alignment: .topLeading))
    }

    private var frostedBlurImage: UIImage? {
        let sourceData: Data?
        if landscapeTabletPresentation && cluster.templateStyle == .rhodesPass {
            sourceData = cluster.rhodesBannerImageData
        } else {
            sourceData = cluster.backgroundImageData
        }
        guard let data = sourceData else { return nil }
        let key = MeQRExchangeCodeRecord.digest(data) as NSString
        if let cached = Self.blurCache.object(forKey: key) { return cached }
        guard let image = Self.renderFrostedBlur(data: data) else { return nil }
        Self.blurCache.setObject(image, forKey: key)
        return image
    }

    private static let blurCache = NSCache<NSString, UIImage>()
    private static let blurContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func renderFrostedBlur(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 256,
              ] as CFDictionary) else { return nil }
        let input = CIImage(cgImage: cg)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input
        filter.radius = 12
        guard let output = filter.outputImage,
              let outCG = blurContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: outCG)
    }

    private func rhodesSurface<Content: View>(_ content: Content) -> some View {
        content
        .background {
            if rhodesGlassEnabled {
                ZStack {
                    cluster.backgroundColor.opacity(rhodesGlassOpacity)
                    if let blurred = frostedBlurImage {
                        Image(uiImage: blurred)
                            .resizable()
                            .scaledToFill()
                            .opacity(rhodesGlassOpacity)
                    }
                    Color.white.opacity(0.55 * rhodesGlassOpacity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(cluster.cardOpacity ?? 0.7))
            }
        }
        .overlay {
            if rhodesGlassEnabled {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.30 + 0.62 * rhodesGlassOpacity),
                                .white.opacity(0.10 + 0.18 * rhodesGlassOpacity),
                                .white.opacity(0.20 + 0.42 * rhodesGlassOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.70), lineWidth: 2)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    rhodesGlassEnabled
                        ? Color.white.opacity(0.10 + 0.20 * rhodesGlassOpacity)
                        : cluster.textColor.opacity(0.18),
                    lineWidth: 1
                )
                .padding(-8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.colorScheme, .light)
        .shadow(
            color: .black.opacity(rhodesGlassEnabled ? 0.06 + 0.12 * rhodesGlassOpacity : 0),
            radius: rhodesGlassEnabled ? 18 : 0,
            y: rhodesGlassEnabled ? 8 : 0
        )
    }

    private var rhodesCardWidth: CGFloat {
        if landscapeTabletPresentation {
            return min(920, max(760, containerWidth - 96))
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            return max(0, containerWidth - 32)
        }
        return max(0, containerWidth - 32)
    }

    private var rhodesFixedCardHeight: CGFloat? {
        if landscapeTabletPresentation { return 540 }
        if portraitTabletPresentation { return 760 }
        if UIDevice.current.userInterfaceIdiom == .phone { return 460 }
        return nil
    }

    private var rhodesGlassOpacity: Double {
        min(1, max(0.2, cluster.cardOpacity ?? 0.7))
    }

    private var rhodesGlassEnabled: Bool {
        cluster.cardGlassEnabled == true && cluster.templateStyle == .rhodesPass
    }

    private var portraitTabletPresentation: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && !landscapeTabletPresentation
    }

    private var largeRhodesText: Bool {
        (portraitTabletPresentation || landscapeTabletPresentation) && cluster.templateStyle == .rhodesPass
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
                .font(.system(size: largeRhodesText ? 14 : 11, weight: .black, design: .monospaced))
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
                    .font(.system(size: largeRhodesText ? 23 : 18, weight: .black))
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: largeRhodesText ? 90 : 72, height: largeRhodesText ? 90 : 72)

                barcodeLines
                    .frame(width: 34, height: 92)

                Text(rhodesDateText)
                    .font(.system(size: largeRhodesText ? 22 : 18, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .frame(width: largeRhodesText ? 58 : 40, height: largeRhodesText ? 64 : 46)
            }
            .foregroundStyle(.white.opacity(0.88))
        }
        .frame(width: portraitTabletPresentation ? 70 : landscapeTabletPresentation ? 60 : 50)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private var rhodesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if landscapeTabletPresentation {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 16) {
                        rhodesLandscapeIdentity

                        HStack(alignment: .top, spacing: 14) {
                            rhodesQRPanel
                            rhodesLandscapePlatformPanel
                                .frame(width: 170, alignment: .topLeading)
                        }
                    }
                    .frame(width: 444, alignment: .topLeading)

                    rhodesLandscapeUserInfo
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 34)
                }

                if !cluster.tags.isEmpty {
                    cardTagChips
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("rhodes-front-tags")
                }
            } else {
                rhodesHeroPanel
                rhodesDetailsRow
                if !cluster.tags.isEmpty {
                    cardTagChips
                        .accessibilityIdentifier("rhodes-front-tags")
                }
            }
        }
        .padding(12)
        .frame(width: landscapeTabletPresentation ? rhodesCardWidth - 60 : nil,
               alignment: .leading)
        .frame(maxWidth: landscapeTabletPresentation ? nil : .infinity, alignment: .leading)
    }

    private var rhodesHeroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                rhodesBannerPanel
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: portraitTabletPresentation ? 260 : 136)

            HStack(spacing: 9) {
                avatarImage
                    .frame(width: largeRhodesText ? 65 : 46, height: largeRhodesText ? 65 : 46)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.name)
                        .font(largeRhodesText ? .system(size: 25, weight: .black) : .title3.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(cluster.passSubtitleText)
                        .font(.system(size: largeRhodesText ? 13 : 10, weight: .heavy, design: .monospaced))
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
        .frame(height: portraitTabletPresentation ? 260 : 136)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var rhodesDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM\ndd"
        return formatter.string(from: Date())
    }

    @ViewBuilder
    private var rhodesDetailsRow: some View {
        if containerWidth < 360 {
            VStack(alignment: .leading, spacing: 10) {
                rhodesQRPanel
                    .frame(maxWidth: .infinity)
                if sortedProfiles.count > 1 { platformPicker }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                rhodesQRPanel
                rhodesInfoBlock
            }
        }
    }

    private var rhodesLandscapeUserInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.userInfoLabel)
                .font(.system(size: largeRhodesText ? 16 : 12, weight: .black, design: .monospaced))
                .foregroundStyle(cluster.textColor.opacity(0.94))

            if !cluster.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Group {
                    if landscapeTabletPresentation {
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(cluster.subtitle)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(cluster.textColor.opacity(0.82))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .frame(maxHeight: 300)
                    } else {
                        Text(cluster.subtitle)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(cluster.textColor.opacity(0.82))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity,
                       minHeight: landscapeTabletPresentation ? 220 : nil,
                       alignment: .topLeading)
                .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cluster.textColor.opacity(0.18), lineWidth: 1)
                }
            }

        }
    }

    private var rhodesLandscapePlatformPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.passLabel)
                .font(.system(size: largeRhodesText ? 16 : 12, weight: .black, design: .monospaced))
                .foregroundStyle(cluster.textColor.opacity(0.94))

            if sortedProfiles.count > 1 {
                passPlatformPicker
            }
        }
    }

    private var rhodesLandscapeIdentity: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarImage
                .frame(width: largeRhodesText ? 86 : 72, height: largeRhodesText ? 86 : 72)
                .overlay(Circle().stroke(cluster.textColor.opacity(0.22), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.name)
                    .font(.system(size: largeRhodesText ? 30 : 28, weight: .black))
                    .foregroundStyle(cluster.textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(cluster.passSubtitleText)
                    .font(.system(size: largeRhodesText ? 14 : 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(cluster.textColor.opacity(0.62))
            }
        }
    }

    private var rhodesQRPanel: some View {
            qrSlot(side: (portraitTabletPresentation || landscapeTabletPresentation) ? 220 : max(120, min(size - 26, 154)) - 24)
                .accessibilityIdentifier("rhodes-platform-qr")
                .padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.black.opacity(0.12), lineWidth: 1)
                )
                .accessibilityIdentifier("rhodes-qr-panel")

    }

    private var rhodesInfoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.passLabel)
                .font(.system(size: largeRhodesText ? 16 : 12, weight: .black, design: .monospaced))
                .foregroundStyle(cluster.textColor.opacity(0.66))

            if sortedProfiles.count > 1 {
                passPlatformPicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rhodesPassBack: some View {
        rhodesSurface(VStack(spacing: 0) {
            rhodesTopStrip

            HStack(spacing: 0) {
                rhodesSideRail

                passBackContent
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: max(0, containerWidth - 32), alignment: .topLeading)
        .frame(height: rhodesFixedCardHeight, alignment: .topLeading))
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
        VStack(alignment: .leading, spacing: largeRhodesText ? 18 : 14) {
            HStack(alignment: .center, spacing: largeRhodesText ? 16 : 12) {
                avatarImage
                    .frame(width: largeRhodesText ? 76 : 58, height: largeRhodesText ? 76 : 58)
                    .overlay(Circle().stroke(cluster.textColor.opacity(0.18), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.name)
                    .font(largeRhodesText ? .system(size: 25, weight: .black) : .title3.weight(.black))
                        .foregroundStyle(cluster.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(cluster.passSubtitleText)
                    .font(largeRhodesText ? .system(size: 15, weight: .bold) : .caption.weight(.bold))
                        .foregroundStyle(cluster.textColor.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(largeRhodesText ? .title3.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(cluster.textColor.opacity(0.55))
            }

            if !cluster.tags.isEmpty {
                cardTagChips
            }

            if !cluster.subtitle.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.userInfoLabel)
                        .font(largeRhodesText ? .system(size: 16, weight: .black, design: .monospaced) : .caption.weight(.black))
                        .foregroundStyle(cluster.textColor.opacity(0.94))

                    Group {
                        if largeRhodesText {
                            ScrollView(.vertical, showsIndicators: false) {
                                subtitleText
                            }
                            .frame(maxHeight: 340)
                        } else {
                            subtitleText
                        }
                    }
                }
                .padding(largeRhodesText ? 18 : 14)
                .frame(maxWidth: .infinity, minHeight: largeRhodesText ? 320 : 150, alignment: .topLeading)
                .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cluster.textColor.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private var subtitleText: some View {
        Text(cluster.subtitle)
            .font(largeRhodesText ? .system(size: 17, weight: .medium) : .subheadline.weight(.medium))
            .foregroundStyle(cluster.textColor.opacity(0.82))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var cardTagChips: some View {
        CardTagFlowLayout(spacing: 7, rowSpacing: 6) {
            ForEach(cluster.tags, id: \.self) { tag in
                let tagStyle = cluster.tagColorStyle(for: tag)
                Text(tag)
                    .font(.system(size: largeRhodesText ? 14 : 11,
                                  weight: CardTagColorPalette.textWeight(for: tag, overrides: cluster.tagColorOverrides).fontWeight))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .modifier(CardTagInkModifier(style: tagStyle))
                    .background {
                        cardTagBackground(for: tagStyle)
                    }
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.32), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func cardTagBackground(for style: CardTagColorStyle) -> some View {
        if style.isMulticolor {
            LinearGradient(
                stops: tagGradientStops(for: style, opacity: 0.86),
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(Capsule())
        } else {
            Capsule()
                .fill(Color(hex: style.leadingHex).opacity(0.86))
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
        .fixedSize(horizontal: false, vertical: true)
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
                        .font(largeRhodesText ? .system(size: 15, weight: .bold) : .caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
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

private func tagGradientStops(for style: CardTagColorStyle, opacity: Double = 1) -> [Gradient.Stop] {
    guard style.segmentHexes.count > 1 else { return [] }
    let segmentCount = Double(style.segmentHexes.count)

    return style.segmentHexes.enumerated().flatMap { index, hex in
        let start = Double(index) / segmentCount
        let end = Double(index + 1) / segmentCount
        let color = Color(hex: hex).opacity(opacity)
        return [
            Gradient.Stop(color: color, location: start),
            Gradient.Stop(color: color, location: end),
        ]
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

    private var flipProgress: CGFloat {
        CGFloat(abs(sin(angle * .pi / 180)))
    }

    func body(content: Content) -> some View {
        ZStack {
            if angle <= 90 {
                content
            } else {
                back
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .padding(.vertical, verticalOverscan)
        .scaleEffect(1 - 0.055 * flipProgress)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
    }
}
