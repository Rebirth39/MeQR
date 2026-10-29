import SwiftUI
import Photos
import PhotosUI
import CoreImage

// MARK: - 画幅

enum ShareCardAspect: String, CaseIterable, Identifiable {
    case portrait34, landscape43, square, portrait916, landscape169

    var id: String { rawValue }

    /// Export pixel size; the canvas is designed in points equal to pixels (scale 1).
    var pixelSize: CGSize {
        switch self {
        case .portrait34: return CGSize(width: 1080, height: 1440)
        case .landscape43: return CGSize(width: 1440, height: 1080)
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait916: return CGSize(width: 1080, height: 1920)
        case .landscape169: return CGSize(width: 1920, height: 1080)
        }
    }

    var isLandscape: Bool { pixelSize.width > pixelSize.height }

    var label: String {
        switch self {
        case .portrait34: return "3:4 · " + L.shareCardPortrait
        case .landscape43: return "4:3 · " + L.shareCardLandscape
        case .square: return "1:1"
        case .portrait916: return "9:16 · " + L.shareCardPortrait
        case .landscape169: return "16:9 · " + L.shareCardLandscape
        }
    }
}

// MARK: - 装饰摆放的独立存储（与主卡片 cardDecorations 无关）

struct ShareCardDecorationLayout: Codable, Equatable {
    var slot: Int
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double
    var hidden: Bool = false

    static func `default`(for slot: Int) -> ShareCardDecorationLayout {
        let point = CardDecorationLayout.defaultPoint(for: slot)
        return ShareCardDecorationLayout(slot: slot, x: point.x, y: point.y, scale: 1, rotation: 0)
    }

    init(slot: Int, x: Double, y: Double, scale: Double, rotation: Double, hidden: Bool = false) {
        self.slot = slot
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.hidden = hidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slot = try container.decode(Int.self, forKey: .slot)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        scale = try container.decode(Double.self, forKey: .scale)
        rotation = try container.decode(Double.self, forKey: .rotation)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }
}

enum ShareCardDecorationStore {
    private static func key(for clusterID: UUID) -> String {
        "meqr.sharecard.decorationLayout.\(clusterID.uuidString)"
    }

    static func layouts(for clusterID: UUID) -> [Int: ShareCardDecorationLayout] {
        guard let data = UserDefaults.standard.data(forKey: key(for: clusterID)),
              let list = try? JSONDecoder().decode([ShareCardDecorationLayout].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.slot, $0) })
    }

    static func save(_ layouts: [Int: ShareCardDecorationLayout], for clusterID: UUID) {
        let list = layouts.values.sorted { $0.slot < $1.slot }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key(for: clusterID))
        }
    }
}

// MARK: - 卡面样式（纯白 / 毛玻璃）

enum ShareCardPanelStyle: String, CaseIterable, Identifiable {
    case solid, glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: return L.shareCardPanelSolid
        case .glass: return L.shareCardPanelGlass
        }
    }

    private static let storageKey = "meqr.sharecard.panelStyle"
    private static let opacityKey = "meqr.sharecard.panelOpacity"

    static func load() -> ShareCardPanelStyle {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ShareCardPanelStyle.init(rawValue:)) ?? .solid
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    /// 毛玻璃浓度（0.25–0.95，越高越接近实色卡面），默认 0.6。
    static func loadOpacity() -> Double {
        let stored = UserDefaults.standard.object(forKey: opacityKey) as? Double
        return stored ?? 0.6
    }

    static func saveOpacity(_ value: Double) {
        UserDefaults.standard.set(value, forKey: opacityKey)
    }
}

// MARK: - 背景（三选：主题渐变 / 卡片背景图 / 自定义图片）

enum ShareCardBackground: String, CaseIterable, Identifiable {
    case gradient, cardImage, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gradient: return L.shareCardBgGradient
        case .cardImage: return L.shareCardBgCardImage
        case .custom: return L.shareCardBgCustom
        }
    }
}

/// 图片背景的取景（缩放 + 偏移），按卡片独立存储；渐变背景不使用。
struct ShareCardBackgroundTransform: Codable, Equatable {
    var scale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0

    static let minScale = 1.0
    static let maxScale = 3.0
}

enum ShareCardBackgroundStore {
    private static var fileURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("meqr-sharecard-background.jpg")
    }

    private static func transformKey(for clusterID: UUID) -> String {
        "meqr.sharecard.backgroundTransform.\(clusterID.uuidString)"
    }

    static func transform(for clusterID: UUID) -> ShareCardBackgroundTransform {
        guard let data = UserDefaults.standard.data(forKey: transformKey(for: clusterID)),
              let value = try? JSONDecoder().decode(ShareCardBackgroundTransform.self, from: data) else {
            return ShareCardBackgroundTransform()
        }
        return value
    }

    static func saveTransform(_ transform: ShareCardBackgroundTransform, for clusterID: UUID) {
        if let data = try? JSONEncoder().encode(transform) {
            UserDefaults.standard.set(data, forKey: transformKey(for: clusterID))
        }
    }

    /// 按目标画幅对原图做中心裁剪（切画幅后重新取景用）。
    static func centerCropped(_ image: UIImage, ratio: CGFloat) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let current = width / height
        let rect: CGRect
        if current > ratio {
            let newWidth = height * ratio
            rect = CGRect(x: (width - newWidth) / 2, y: 0, width: newWidth, height: height)
        } else {
            let newHeight = width / ratio
            rect = CGRect(x: 0, y: (height - newHeight) / 2, width: width, height: newHeight)
        }
        guard let cropped = cg.cropping(to: rect.integral) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    static func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func saveImage(_ image: UIImage?) {
        let fileManager = FileManager.default
        if let image, let data = image.jpegData(compressionQuality: 0.9) {
            try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        } else {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

// MARK: - 可渲染的扩列图

struct ShareCardView: View {
    let cluster: QRCluster
    let profile: QRProfile
    let aspect: ShareCardAspect
    let showTags: Bool
    let qrImage: UIImage?
    /// nil 表示导出/纯展示；编辑器传入 binding 以拖拽摆放。
    var decorationLayouts: Binding<[Int: ShareCardDecorationLayout]>?
    /// 预览用拟合尺寸；导出时传 nil 用全分辨率。
    var canvasOverride: CGSize? = nil
    var background: ShareCardBackground = .gradient
    var customBackground: UIImage? = nil
    var showPlatformName = true
    /// 图片背景取景；nil 表示导出/纯展示（从存储读取）。
    var backgroundTransform: Binding<ShareCardBackgroundTransform>?
    var panelStyle: ShareCardPanelStyle = .solid
    var panelOpacity: Double = 0.6
    /// 手动毛玻璃：全画布模糊背景图（与背景层同位置同缩放）。nil 时玻璃模式退化为纯罩。
    var blurredBackground: UIImage? = nil
    /// 预解码的图片（编辑器缓存后传入，避免每次 body 求值重复 decode）；nil 时现场解。
    var decodedAvatar: UIImage? = nil
    var decodedCardBackground: UIImage? = nil

    private var canvas: CGSize { canvasOverride ?? aspect.pixelSize }

    private var decorations: [CardDecoration] { cluster.cardDecorations }

    var body: some View {
        ZStack {
            backgroundGradient
            Group {
                if aspect.isLandscape { landscapeContent } else { portraitContent }
            }
            // Only the noninteractive content uses export typography/layout. The canvas,
            // background and decoration gestures stay in fitted preview coordinates.
            .scaleEffect(contentScale)
            .frame(width: canvas.width, height: canvas.height)
            decorationLayer
            watermark
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
        .coordinateSpace(name: ShareCardView.canvasCoordinateSpace)
    }

    static let canvasCoordinateSpace = "shareCardCanvas"

    private var backgroundGradient: some View {
        ShareCardBackgroundView(
            cluster: cluster,
            background: background,
            cardImage: decodedCardBackground ?? cluster.backgroundImageData.flatMap(UIImage.init(data:)),
            customBackground: customBackground,
            transform: backgroundTransform,
            storedTransform: storedTransform,
            canvas: canvas,
            scrim: imageScrim
        )
    }

    /// 图片背景上的柔光罩，保证文字和卡片的可读性。
    private var imageScrim: Color {
        (ShareCardView.ink(on: cluster.backgroundColorHex) == .white ? Color.black : Color.white)
            .opacity(0.42)
    }

    private var watermark: some View {
        VStack {
            Spacer()
            Text("喜劳转扩 MeQR · meqrcode.cn")
                .font(.system(size: min(canvas.width, canvas.height) * 0.018, weight: .medium))
                .foregroundStyle(ShareCardView.ink(on: cluster.backgroundColorHex).opacity(0.55))
                .padding(.bottom, canvas.height * 0.018)
        }
    }

    // MARK: 布局

    private var contentCanvas: CGSize { aspect.pixelSize }
    private var contentScale: CGFloat { canvas.width / contentCanvas.width }
    private var unit: CGFloat { min(contentCanvas.width, contentCanvas.height) * (aspect == .portrait916 ? 1.12 : 1) }
    private var ink: Color { Self.ink(on: cluster.backgroundColorHex) }

    // All candidates contain the complete profile and every tag. Only typography changes
    // when a particularly long profile needs more space.
    private var portraitContent: some View {
        ViewThatFits(in: .vertical) {
            ForEach([1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.05], id: \.self) { density in
                VStack(alignment: .leading, spacing: unit * 0.035 * density) {
                    identityBlock(density: density)
                    if showTags && !cluster.tags.isEmpty { tagsBlock(density: density) }
                    if !cluster.subtitle.isEmpty { subtitleBlock(density: density) }
                    qrBlock
                        .frame(maxWidth: .infinity)
                        .padding(.top, unit * 0.015)
                }
                .padding(unit * 0.055)
                .background(panel)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, unit * 0.065)
        .padding(.top, contentCanvas.height * 0.045)
        .padding(.bottom, contentCanvas.height * 0.065)
        .frame(width: contentCanvas.width, height: contentCanvas.height)
    }

    private var panel: some View {
        let veil = ink == .white ? Color.black : Color.white
        let shape = RoundedRectangle(cornerRadius: unit * 0.045, style: .continuous)
        return ZStack {
            if panelStyle == .glass {
                if let blurredBackground {
                    // 全画布模糊图按画布坐标摆放，面板区域裁出与背景对齐的一片。
                    GeometryReader { geo in
                        let frame = geo.frame(in: .named(ShareCardView.canvasCoordinateSpace))
                        Image(uiImage: blurredBackground)
                            .resizable()
                            .frame(width: contentCanvas.width, height: contentCanvas.height)
                            .offset(x: -frame.minX / contentScale, y: -frame.minY / contentScale)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                            .clipped()
                    }
                } else {
                    shape.fill(veil.opacity(0.25 + panelOpacity * 0.5))
                }
                shape.fill(veil.opacity(panelOpacity * 0.5))
            } else {
                shape.fill(ink == .white ? Color.black.opacity(0.18) : Color.white.opacity(0.55))
            }
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(.white.opacity(0.45), lineWidth: unit * 0.0015)
        }
        .shadow(color: .black.opacity(0.06), radius: unit * 0.035, y: unit * 0.018)
    }

    private var landscapeContent: some View {
        HStack(spacing: unit * 0.065) {
            ViewThatFits(in: .vertical) {
                ForEach([1.0, 0.85, 0.7, 0.55, 0.4, 0.3, 0.2, 0.1, 0.05], id: \.self) { density in
                    VStack(alignment: .leading, spacing: unit * 0.035 * density) {
                        identityBlock(density: density)
                        if showTags && !cluster.tags.isEmpty { tagsBlock(density: density) }
                        if !cluster.subtitle.isEmpty { subtitleBlock(density: density) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            qrBlock
        }
        .padding(unit * 0.065)
        .background(panel)
        .padding(.horizontal, contentCanvas.width * 0.055)
        .padding(.vertical, contentCanvas.height * 0.09)
        .frame(width: contentCanvas.width, height: contentCanvas.height)
    }

    private func identityBlock(density: CGFloat) -> some View {
        HStack(spacing: unit * 0.028) {
            avatarImage
                .frame(width: unit * 0.14 * density, height: unit * 0.14 * density)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: unit * 0.004))
            Text(cluster.name.isEmpty ? L.qrID : cluster.name)
                .font(.system(size: unit * 0.052 * density, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// userinfo（签名等详细内容），排在 tag 区下方。
    private func subtitleBlock(density: CGFloat) -> some View {
        Text(cluster.subtitle)
            .font(.system(size: unit * 0.029 * density, weight: .medium))
            .lineSpacing(unit * 0.008 * density)
            .foregroundStyle(ink.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let image = decodedAvatar ?? cluster.avatarImageData.flatMap(UIImage.init(data:)) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(0.5))
                Image(systemName: "person.fill")
                    .resizable().scaledToFit().padding(contentCanvas.width * 0.03)
                    .foregroundStyle(ShareCardView.ink(on: cluster.backgroundColorHex).opacity(0.5))
            }
        }
    }

    private func tagsBlock(density: CGFloat) -> some View {
        ShareCardTagFlowLayout(spacing: unit * 0.012 * density, rowSpacing: unit * 0.014 * density) {
            ForEach(Array(cluster.tags.enumerated()), id: \.offset) { _, tag in
                tagPill(tag, density: density)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tagPill(_ tag: String, density: CGFloat) -> some View {
        let tagStyle = cluster.tagColorStyle(for: tag)
        return Group {
            if let pair = tagStyle.pairing { CardTagPairLabel(pair: pair) }
            else { Text(tag).modifier(CardTagInkModifier(style: tagStyle)) }
        }
        .font(.system(size: unit * 0.027 * density,
                      weight: CardTagColorPalette.textWeight(for: tag, overrides: cluster.tagColorOverrides).fontWeight))
        .lineLimit(1)
        .minimumScaleFactor(0.2)
        .padding(.horizontal, unit * 0.019 * density)
        .padding(.vertical, unit * 0.011 * density)
        .background { tagPillBackground(for: tagStyle) }
        .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: unit * 0.002 * density))
        .shadow(color: .black.opacity(0.1), radius: unit * 0.003, y: unit * 0.003)
    }

    @ViewBuilder
    private func tagPillBackground(for style: CardTagColorStyle) -> some View {
        if let pair = style.pairing { CardTagPairBackground(pair: pair) }
        else if style.isWhiteBackground { CardTagWhiteBackground(style: style) }
        else if style.isMulticolor {
            LinearGradient(colors: style.segmentHexes.map { Color(hex: $0).opacity(0.86) },
                           startPoint: .leading, endPoint: .trailing)
                .clipShape(Capsule())
        } else {
            Capsule().fill(Color(hex: style.leadingHex).opacity(0.86))
        }
    }

    private var qrBlock: some View {
        let side = unit * (aspect.isLandscape ? 0.34 : (aspect == .square ? 0.26 : (aspect == .portrait916 ? 0.39 : 0.34)))
        return VStack(spacing: contentCanvas.height * 0.012) {
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.09, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: side * 0.05, y: side * 0.02)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(side * 0.075)
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: side * 0.4))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: side, height: side)
            if showPlatformName {
                Text(profile.platformDisplayName)
                    .font(.system(size: unit * 0.024, weight: .semibold))
                    .foregroundStyle(ShareCardView.ink(on: cluster.backgroundColorHex).opacity(0.85))
            }
        }
    }

    // MARK: 装饰层（复用主卡片素材，位置独立存储）

    private var decorationLayer: some View {
        ForEach(decorations) { decoration in
            let layout = decorationLayouts != nil
                ? Binding(
                    get: { decorationLayouts!.wrappedValue[decoration.slot] ?? .default(for: decoration.slot) },
                    set: { decorationLayouts!.wrappedValue[decoration.slot] = $0 }
                )
                : .constant(storedLayout(for: decoration.slot))
            if !layout.wrappedValue.hidden {
                ShareCardDecorationView(
                    decoration: decoration,
                    layout: layout,
                    canvas: canvas,
                    interactive: decorationLayouts != nil
                )
            }
        }
    }

    private func storedLayout(for slot: Int) -> ShareCardDecorationLayout {
        ShareCardDecorationStore.layouts(for: cluster.id)[slot] ?? .default(for: slot)
    }

    private var storedTransform: ShareCardBackgroundTransform {
        ShareCardBackgroundStore.transform(for: cluster.id)
    }

    // MARK: 颜色工具

    static func ink(on hex: String) -> Color {
        Color(hex: hex).isDarkForUI ? .white : .black
    }

    static func lightened(_ hex: String, _ amount: Double) -> Color {
        shift(hex, amount: amount)
    }

    static func darkened(_ hex: String, _ amount: Double) -> Color {
        shift(hex, amount: -amount)
    }

    private static func shift(_ hex: String, amount: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(Color(hex: hex)).getRed(&r, green: &g, blue: &b, alpha: &a) else { return Color(hex: hex) }
        func clamp(_ v: CGFloat) -> CGFloat { min(1, max(0, v + amount)) }
        return Color(red: clamp(r), green: clamp(g), blue: clamp(b))
    }
}

// Measures each sticker against the available row width, including long catalog labels.
private struct ShareCardTagFlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    private func positions(width: CGFloat, subviews: Subviews) -> (items: [CGRect], height: CGFloat) {
        let width = max(1, width)
        var items: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            items.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (items, y + rowHeight)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1080
        return CGSize(width: width, height: positions(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, rect) in positions(width: bounds.width, subviews: subviews).items.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                                  proposal: ProposedViewSize(rect.size))
        }
    }
}

// MARK: - 单个装饰（编辑器内可拖拽）

private struct ShareCardDecorationView: View {
    let decoration: CardDecoration
    @Binding var layout: ShareCardDecorationLayout
    let canvas: CGSize
    let interactive: Bool

    /// 手势进行中只动本地状态，结束时一次性写回绑定，避免逐帧整卡重渲染。
    @State private var liveOffset: CGSize = .zero
    @State private var liveMagnification: CGFloat = 1

    static let minScale = 0.3
    static let maxScale = 2.5

    var body: some View {
        if let image = CardDecorationImages.image(decoration.imageData) {
            let side = canvas.width * 0.22 * layout.scale * liveMagnification
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side)
                .rotationEffect(.degrees(layout.rotation))
                .position(
                    x: layout.x * canvas.width + liveOffset.width,
                    y: layout.y * canvas.height + liveOffset.height
                )
                .gesture(interactive ? drag : nil)
                .simultaneousGesture(interactive ? magnify : nil)
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                liveOffset = value.translation
            }
            .onEnded { value in
                layout.x = min(1, max(0, layout.x + value.translation.width / canvas.width))
                layout.y = min(1, max(0, layout.y + value.translation.height / canvas.height))
                liveOffset = .zero
            }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                liveMagnification = value.magnification
            }
            .onEnded { value in
                layout.scale = min(Self.maxScale, max(Self.minScale, layout.scale * value.magnification))
                liveMagnification = 1
            }
    }
}

// MARK: - 背景图（可缩放/拖动取景）

private struct ShareCardBackgroundImage: View {
    let image: UIImage
    let canvas: CGSize
    @Binding var transform: ShareCardBackgroundTransform
    let interactive: Bool

    @State private var liveOffset: CGSize = .zero
    @State private var liveMagnification: CGFloat = 1

    private var scale: CGFloat {
        transform.scale * liveMagnification
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(
                x: (transform.offsetX * canvas.width) + liveOffset.width,
                y: (transform.offsetY * canvas.height) + liveOffset.height
            )
            .contentShape(Rectangle())
            .gesture(interactive ? drag : nil)
            .simultaneousGesture(interactive ? magnify : nil)
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in liveOffset = value.translation }
            .onEnded { value in
                transform.offsetX = clampedOffset(transform.offsetX + value.translation.width / canvas.width)
                transform.offsetY = clampedOffset(transform.offsetY + value.translation.height / canvas.height)
                liveOffset = .zero
            }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in liveMagnification = value.magnification }
            .onEnded { value in
                transform.scale = min(ShareCardBackgroundTransform.maxScale,
                                      max(ShareCardBackgroundTransform.minScale,
                                          transform.scale * value.magnification))
                transform.offsetX = clampedOffset(transform.offsetX)
                transform.offsetY = clampedOffset(transform.offsetY)
                liveMagnification = 1
            }
    }

    /// 缩放后偏移限制在图片仍能铺满画布的范围内。
    private func clampedOffset(_ value: Double) -> Double {
        let limit = max(0, (transform.scale * liveMagnification - 1) / 2)
        return min(limit, max(-limit, value))
    }
}

// MARK: - 背景层（独立成 view，供画面显示与离屏模糊共用）

private struct ShareCardBackgroundView: View {
    let cluster: QRCluster
    let background: ShareCardBackground
    let cardImage: UIImage?
    let customBackground: UIImage?
    let transform: Binding<ShareCardBackgroundTransform>?
    let storedTransform: ShareCardBackgroundTransform
    let canvas: CGSize
    let scrim: Color

    private var gradient: some View {
        LinearGradient(
            colors: [ShareCardView.lightened(cluster.backgroundColorHex, 0.06),
                     ShareCardView.darkened(cluster.backgroundColorHex, 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        switch background {
        case .gradient:
            gradient
        case .cardImage, .custom:
            if let image = background == .cardImage ? cardImage : customBackground {
                ShareCardBackgroundImage(
                    image: image,
                    canvas: canvas,
                    transform: transform ?? .constant(storedTransform),
                    interactive: transform != nil
                )
                .frame(width: canvas.width, height: canvas.height)
                .clipped()
                .overlay(scrim)
            } else {
                gradient
            }
        }
    }
}

// MARK: - 手动毛玻璃（ImageRenderer + CIGaussianBlur，所见即所得）

enum ShareCardBlur {
    static func make(cluster: QRCluster, background: ShareCardBackground,
                     cardImage: UIImage?, customBackground: UIImage?,
                     transform: ShareCardBackgroundTransform,
                     canvas: CGSize) -> UIImage? {
        let view = ShareCardBackgroundView(
            cluster: cluster, background: background,
            cardImage: cardImage, customBackground: customBackground,
            transform: nil, storedTransform: transform, canvas: canvas, scrim: .clear
        )
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(canvas)
        renderer.scale = 1
        guard let image = renderer.uiImage, let cgImage = image.cgImage else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = CIImage(cgImage: cgImage)
        filter.radius = Float(canvas.width * 0.018)
        guard let output = filter.outputImage else { return nil }
        guard let blurred = CIContext().createCGImage(output, from: CGRect(origin: .zero, size: canvas)) else { return nil }
        return UIImage(cgImage: blurred)
    }
}

// MARK: - 确认页（实时预览编辑）

struct ShareCardGeneratorView: View {
    let cluster: QRCluster
    @Environment(\.dismiss) private var dismiss

    @State private var aspect: ShareCardAspect = .portrait916
    @State private var showTags = true
    @State private var selectedProfileID: UUID?
    @State private var layouts: [Int: ShareCardDecorationLayout]
    @State private var background: ShareCardBackground = .gradient
    @State private var customBackgroundImage: UIImage?
    @State private var customPhotoItem: PhotosPickerItem?
    @State private var customOriginalImage: UIImage?
    @State private var cropRequest: CropRequest?
    @State private var showPlatformName = true
    @State private var backgroundTransform = ShareCardBackgroundTransform()
    @State private var panelStyle = ShareCardPanelStyle.load()
    @State private var panelOpacity = ShareCardPanelStyle.loadOpacity()
    @State private var blurredBackground: UIImage?
    @State private var decodedAvatar: UIImage?
    @State private var decodedCardBackground: UIImage?
    @State private var isSaving = false

    /// 选图与裁切弹窗的单一数据源：item 驱动 fullScreenCover，捕获的一定是本次选中的图。
    private struct CropRequest: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var showSaved = false
    @State private var saveError: String?
    @State private var showSaveError = false

    init(cluster: QRCluster) {
        self.cluster = cluster
        _layouts = State(initialValue: ShareCardDecorationStore.layouts(for: cluster.id))
        let stored = ShareCardBackgroundStore.loadImage()
        _customOriginalImage = State(initialValue: stored)
        _customBackgroundImage = State(initialValue: stored.map {
            ShareCardBackgroundStore.centerCropped($0, ratio: ShareCardAspect.portrait916.pixelSize.width / ShareCardAspect.portrait916.pixelSize.height)
        })
        _decodedAvatar = State(initialValue: cluster.avatarImageData.flatMap(UIImage.init(data:)))
        _decodedCardBackground = State(initialValue: cluster.backgroundImageData.flatMap(UIImage.init(data:)))
        _backgroundTransform = State(initialValue: ShareCardBackgroundStore.transform(for: cluster.id))
    }

    private var profiles: [QRProfile] {
        cluster.profiles.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedProfile: QRProfile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    /// 缓存的二维码图；仅在平台选择或卡片换色时重新生成。
    @State private var qrImage: UIImage?

    private func regenerateQR() {
        guard let content = selectedProfile?.qrContent, !content.isEmpty else {
            qrImage = nil
            return
        }
        qrImage = QRCodeGenerator.generate(from: content, foreground: cluster.qrColor, background: .white)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewArea
                controls
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L.shareCardTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .alert(L.savedToPhotos, isPresented: $showSaved) {
                Button(L.ok, role: .cancel) {}
            }
            .alert(L.couldNotSave, isPresented: $showSaveError) {
                Button(L.ok, role: .cancel) {}
            } message: {
                Text(saveError ?? L.tryAgain)
            }
            .onAppear { regenerateQR(); regenerateBlur() }
            .onChange(of: selectedProfileID) { _, _ in regenerateQR() }
            .onChange(of: background) { _, _ in regenerateBlur() }
            .onChange(of: aspect) { _, _ in regenerateBlur() }
            .onChange(of: panelStyle) { _, _ in regenerateBlur() }
            .onChange(of: backgroundTransform) { _, _ in regenerateBlur() }
            .onChange(of: customBackgroundImage) { _, _ in regenerateBlur() }
        }
    }

    private var previewArea: some View {
        GeometryReader { geo in
            let design = aspect.pixelSize
            let scale = min(geo.size.width / design.width, geo.size.height / design.height) * 0.96
            let fitted = CGSize(width: design.width * scale, height: design.height * scale)
            ShareCardView(
                cluster: cluster,
                profile: selectedProfile ?? QRProfile(platformType: "custom", qrContent: ""),
                aspect: aspect,
                showTags: showTags,
                qrImage: qrImage,
                decorationLayouts: $layouts,
                canvasOverride: fitted,
                background: background,
                customBackground: customBackgroundImage,
                showPlatformName: showPlatformName,
                backgroundTransform: background == .gradient ? nil : $backgroundTransform,
                panelStyle: panelStyle,
                panelOpacity: panelOpacity,
                blurredBackground: blurredBackground,
                decodedAvatar: decodedAvatar,
                decodedCardBackground: decodedCardBackground
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        Form {
            Section(L.shareCardAspect) {
                Picker(L.shareCardAspect, selection: $aspect) {
                    ForEach(ShareCardAspect.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(L.shareCardPlatform) {
                Picker(L.shareCardPlatform, selection: Binding(
                    get: { selectedProfile?.id ?? UUID() },
                    set: { selectedProfileID = $0 }
                )) {
                    ForEach(profiles) { profile in
                        Text(profile.platformDisplayName).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
            }
            Section(L.shareCardBackground) {
                Picker(L.shareCardBackground, selection: $background) {
                    ForEach(ShareCardBackground.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                if background == .custom {
                    HStack(spacing: 12) {
                        if let customBackgroundImage {
                            Image(uiImage: customBackgroundImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        PhotosPicker(selection: $customPhotoItem, matching: .images) {
                            Text(customBackgroundImage == nil ? L.selectQRImage : L.changeQRImage)
                        }
                    }
                }
            }
            .onChange(of: customPhotoItem) { _, item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    customOriginalImage = image
                    ShareCardBackgroundStore.saveImage(image)
                    // 让状态先落定，再触发弹窗，规避 "already presenting" 竞态
                    try? await Task.sleep(for: .milliseconds(80))
                    cropRequest = CropRequest(image: image)
                }
            }
            .onChange(of: aspect) { _, newAspect in
                guard let original = customOriginalImage else { return }
                let ratio = newAspect.pixelSize.width / newAspect.pixelSize.height
                customBackgroundImage = ShareCardBackgroundStore.centerCropped(original, ratio: ratio)
            }
            .fullScreenCover(item: $cropRequest) { request in
                BackgroundCropView(
                    sourceImage: request.image,
                    cropAspectRatio: aspect.pixelSize.width / aspect.pixelSize.height,
                    onDone: { cropped in
                        customBackgroundImage = cropped
                        cropRequest = nil
                    },
                    onCancel: {
                        cropRequest = nil
                        if customBackgroundImage == nil, let original = customOriginalImage {
                            let ratio = aspect.pixelSize.width / aspect.pixelSize.height
                            customBackgroundImage = ShareCardBackgroundStore.centerCropped(original, ratio: ratio)
                        }
                    }
                )
            }
            Section {
                Toggle(L.shareCardShowTags, isOn: $showTags)
                Toggle(L.shareCardShowPlatformName, isOn: $showPlatformName)
            }
            Section(L.shareCardPanelStyle) {
                Picker(L.shareCardPanelStyle, selection: $panelStyle) {
                    ForEach(ShareCardPanelStyle.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: panelStyle) { _, value in value.save() }
                if panelStyle == .glass {
                    HStack {
                        Text(L.shareCardPanelOpacity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .leading)
                        Slider(value: $panelOpacity, in: 0.25...0.95, onEditingChanged: { editing in
                            if !editing { ShareCardPanelStyle.saveOpacity(panelOpacity) }
                        })
                    }
                }
            }
            if !cluster.cardDecorations.isEmpty {
                Section {
                    ForEach(cluster.cardDecorations) { decoration in
                        let layout = Binding(
                            get: { layouts[decoration.slot] ?? .default(for: decoration.slot) },
                            set: { layouts[decoration.slot] = $0 }
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                if let image = CardDecorationImages.image(decoration.imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                }
                                Toggle(L.shareCardShowDecoration, isOn: Binding(
                                    get: { !layout.wrappedValue.hidden },
                                    set: { var value = layout.wrappedValue; value.hidden = !$0; layout.wrappedValue = value }
                                ))
                            }
                            if !layout.wrappedValue.hidden {
                                HStack {
                                    Text(L.shareCardDecorationSize)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 34, alignment: .leading)
                                    Slider(value: Binding(
                                        get: { layout.wrappedValue.scale },
                                        set: { var value = layout.wrappedValue; value.scale = $0; layout.wrappedValue = value }
                                    ), in: 0.3...2.5, onEditingChanged: { editing in
                                        if !editing { ShareCardDecorationStore.save(layouts, for: cluster.id) }
                                    })
                                }
                                HStack {
                                    Text(L.shareCardDecorationRotation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 34, alignment: .leading)
                                    Slider(value: Binding(
                                        get: { layout.wrappedValue.rotation },
                                        set: { var value = layout.wrappedValue; value.rotation = $0; layout.wrappedValue = value }
                                    ), in: -180...180, onEditingChanged: { editing in
                                        if !editing { ShareCardDecorationStore.save(layouts, for: cluster.id) }
                                    })
                                }
                            }
                        }
                    }
                } header: {
                    Text(L.shareCardDecorations)
                } footer: {
                    Text(L.shareCardDecorationsHint)
                        .font(.caption)
                }
            }
        }
        .frame(height: 300)
    }

    private var saveBar: some View {
        Button {
            Task { await exportAndSave() }
        } label: {
            Label(L.shareCardSave, systemImage: "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
        .disabled(isSaving || selectedProfile == nil)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func regenerateBlur() {
        guard panelStyle == .glass else {
            blurredBackground = nil
            return
        }
        blurredBackground = ShareCardBlur.make(
            cluster: cluster, background: background,
            cardImage: decodedCardBackground, customBackground: customBackgroundImage,
            transform: backgroundTransform, canvas: aspect.pixelSize
        )
    }

    private func exportAndSave() async {
        guard let profile = selectedProfile, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        ShareCardDecorationStore.save(layouts, for: cluster.id)
        ShareCardBackgroundStore.saveTransform(backgroundTransform, for: cluster.id)
        regenerateBlur()
        let exportView = ShareCardView(
            cluster: cluster,
            profile: profile,
            aspect: aspect,
            showTags: showTags,
            qrImage: qrImage,
            decorationLayouts: nil,
            background: background,
            customBackground: customBackgroundImage,
            showPlatformName: showPlatformName,
            panelStyle: panelStyle,
            panelOpacity: panelOpacity,
            blurredBackground: blurredBackground,
            decodedAvatar: decodedAvatar,
            decodedCardBackground: decodedCardBackground
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.proposedSize = ProposedViewSize(aspect.pixelSize)
        renderer.scale = 1
        guard let image = renderer.uiImage else {
            saveError = L.tryAgain
            showSaveError = true
            return
        }
        do {
            try await saveToPhotos(image)
            showSaved = true
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    private func saveToPhotos(_ image: UIImage) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited: granted = true
        case .notDetermined:
            granted = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
                }
            }
        default: granted = false
        }
        guard granted else { throw ShareCardSaveError.photoPermissionDenied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: ShareCardSaveError.writeFailed) }
            }
        }
    }

    private enum ShareCardSaveError: LocalizedError {
        case photoPermissionDenied
        case writeFailed
        var errorDescription: String? {
            switch self {
            case .photoPermissionDenied: return L.photoPermissionNeeded
            case .writeFailed: return L.tryAgain
            }
        }
    }
}
