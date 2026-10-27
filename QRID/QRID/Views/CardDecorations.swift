import SwiftUI
import UIKit
import PhotosUI
import ImageIO

enum CardDecorationImages {
    private static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func image(_ data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }

    nonisolated static func prepare(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}

enum CardDecorationLayout {
    /// Default anchors used when a decoration has no free position yet.
    static func defaultPoint(for slot: Int) -> CGPoint {
        switch slot {
        case 0: return CGPoint(x: 0.08, y: 0.04)
        case 1: return CGPoint(x: 0.85, y: 0.02)
        default: return CGPoint(x: 0.88, y: 0.92)
        }
    }

    static func point(for decoration: CardDecoration) -> CGPoint {
        let fallback = defaultPoint(for: decoration.slot)
        return CGPoint(x: decoration.x ?? fallback.x, y: decoration.y ?? fallback.y)
    }
}

struct CardDecorationSurface: ViewModifier {
    let decorations: [CardDecoration]
    let template: ClusterTemplateStyle
    @State private var cardSize: CGSize = .zero

    private var baseSize: CGFloat { min(180, cardSize.width * 0.22) }
    // Reserve just enough vertical room for the top/bottom decorations to draw outside the card
    // without being clipped, while the negative offset keeps the card itself in place.
    private var inset: CGFloat { decorations.isEmpty ? 0 : min(baseSize * 0.9 + 8, 120) }

    func body(content: Content) -> some View {
        content
            // Measured before padding: these are the real card dimensions.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
            .overlay {
                GeometryReader { geo in
                    let s = baseSize
                    ZStack(alignment: .topLeading) {
                        ForEach(decorations) { decoration in
                            if let image = CardDecorationImages.image(decoration.imageData) {
                                let side = s * decoration.scale
                                let point = CardDecorationLayout.point(for: decoration)
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: side, height: side)
                                    .rotationEffect(.degrees(decoration.rotation))
                                    .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)
                                    .position(x: geo.size.width * point.x, y: geo.size.height * point.y)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(.vertical, inset)
            .offset(y: -inset)
            .zIndex(2)
    }

}


enum CardZoneKind: String, CaseIterable, Identifiable {
    case header, qr, platform, tags

    var id: String { rawValue }

    var label: String {
        switch self {
        case .header: return "头图"
        case .qr: return "二维码"
        case .platform: return "选择器"
        case .tags: return "Tag"
        }
    }
}

struct CardZonePreferenceKey: PreferenceKey {
    static var defaultValue: [CardZoneKind: CGRect] = [:]
    static func reduce(value: inout [CardZoneKind: CGRect], nextValue: () -> [CardZoneKind: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Reports this view's frame in the card coordinate space as a protected content zone.
    func cardZone(_ kind: CardZoneKind, enabled: Bool = true) -> some View {
        background {
            if enabled {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: CardZonePreferenceKey.self,
                        value: [kind: geometry.frame(in: .named("meqrCard"))]
                    )
                }
            }
        }
    }
}

enum CardSafeZones {
    static func ratio(center: CGPoint, side: CGFloat, cardSize: CGSize, zones: [CGRect]) -> Double {
        guard cardSize.width > 0, cardSize.height > 0, side > 0 else { return 0 }
        let rect = CGRect(x: center.x * cardSize.width - side / 2,
                          y: center.y * cardSize.height - side / 2,
                          width: side, height: side)
        var overlap: CGFloat = 0
        for zone in zones {
            let intersection = rect.intersection(zone)
            if !intersection.isNull {
                overlap += intersection.width * intersection.height
            }
        }
        return Double(min(1, max(0, overlap / (side * side))))
    }
}

extension Notification.Name {
    static let meqrEditDecorationsOnCard = Notification.Name("meqr.editDecorationsOnCard")
}

struct InlineCardDecorationEditor: View {
    @Binding var decorations: [CardDecoration]
    var zones: [CardZoneKind: CGRect] = [:]
    var onDone: () -> Void

    @State private var livePositions: [Int: CGPoint] = [:]
    @State private var dragStarts: [Int: CGPoint] = [:]
    @State private var selectedSlot: Int?
    @State private var overlap: Double = 0
    @State private var warning: String?
    @State private var liveScales: [Int: Double] = [:]
    @State private var liveRotations: [Int: Double] = [:]
    @State private var scaleStarts: [Int: Double] = [:]
    @State private var rotationStarts: [Int: Double] = [:]

    var body: some View {
        GeometryReader { geo in
            let cardSize = geo.size
            let side = min(180, cardSize.width * 0.22)
            ZStack(alignment: .topLeading) {
                ForEach(CardZoneKind.allCases) { kind in
                    if let rect = zones[kind] {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(0.16))
                            .overlay(alignment: .topLeading) {
                                Text(kind.label)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(3)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.orange.opacity(0.75), lineWidth: 1)
                            }
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                ForEach(decorations) { decoration in
                    if let image = CardDecorationImages.image(decoration.imageData) {
                        let point = livePositions[decoration.slot] ?? CardDecorationLayout.point(for: decoration)
                        let currentScale = liveScales[decoration.slot] ?? decoration.scale
                        let currentRotation = liveRotations[decoration.slot] ?? decoration.rotation
                        let dimension = side * currentScale
                        ZStack {
                            // Transparent halo: the visible sticker is small, so give the
                            // one-finger drag and two-finger pinch/rotate a finger-sized target.
                            Color.clear
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: dimension, height: dimension)
                                .rotationEffect(.degrees(currentRotation))
                                .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selectedSlot == decoration.slot ? Color.accentColor : .clear, lineWidth: 1.5)
                                }
                        }
                        .frame(width: dimension + 60, height: dimension + 60)
                        .contentShape(Rectangle())
                        .position(x: point.x * cardSize.width, y: point.y * cardSize.height)
                        .highPriorityGesture(dragGesture(for: decoration, side: side, cardSize: cardSize))
                        .simultaneousGesture(magnifyGesture(for: decoration, side: side, cardSize: cardSize))
                        .simultaneousGesture(rotateGesture(for: decoration))
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(L.done) { onDone() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(8)
        }
        .overlay(alignment: .bottom) {
            statusBar
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
    }

    private func dragGesture(for decoration: CardDecoration, side: CGFloat, cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedSlot = decoration.slot
                let start = dragStarts[decoration.slot]
                    ?? livePositions[decoration.slot]
                    ?? CardDecorationLayout.point(for: decoration)
                if dragStarts[decoration.slot] == nil { dragStarts[decoration.slot] = start }
                let x = min(1.05, max(-0.05, start.x + value.translation.width / cardSize.width))
                let y = min(1.05, max(-0.05, start.y + value.translation.height / cardSize.height))
                livePositions[decoration.slot] = CGPoint(x: x, y: y)
                let currentScale = liveScales[decoration.slot] ?? decoration.scale
                overlap = CardSafeZones.ratio(center: CGPoint(x: x, y: y),
                                              side: side * currentScale,
                                              cardSize: cardSize,
                                              zones: Array(zones.values))
                warning = nil
            }
            .onEnded { _ in
                let point = livePositions[decoration.slot] ?? CardDecorationLayout.point(for: decoration)
                let currentScale = liveScales[decoration.slot] ?? decoration.scale
                let ratio = CardSafeZones.ratio(center: point,
                                                side: side * currentScale,
                                                cardSize: cardSize,
                                                zones: Array(zones.values))
                if ratio > 0.30 {
                    withAnimation(.easeOut(duration: 0.18)) {
                        livePositions[decoration.slot] = dragStarts[decoration.slot]
                    }
                    warning = L.cardDecorationDropRejected
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } else {
                    commit(decoration.slot, point)
                    warning = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                overlap = ratio
                dragStarts[decoration.slot] = nil
            }
    }

    private func magnifyGesture(for decoration: CardDecoration, side: CGFloat, cardSize: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                selectedSlot = decoration.slot
                if scaleStarts[decoration.slot] == nil {
                    scaleStarts[decoration.slot] = liveScales[decoration.slot] ?? decoration.scale
                }
                let base = scaleStarts[decoration.slot] ?? decoration.scale
                let scale = min(1.25, max(0.6, base * value.magnification))
                liveScales[decoration.slot] = scale
                let point = livePositions[decoration.slot] ?? CardDecorationLayout.point(for: decoration)
                overlap = CardSafeZones.ratio(center: point,
                                              side: side * scale,
                                              cardSize: cardSize,
                                              zones: Array(zones.values))
                warning = nil
            }
            .onEnded { _ in
                let scale = liveScales[decoration.slot] ?? decoration.scale
                let point = livePositions[decoration.slot] ?? CardDecorationLayout.point(for: decoration)
                let ratio = CardSafeZones.ratio(center: point,
                                                side: side * scale,
                                                cardSize: cardSize,
                                                zones: Array(zones.values))
                if ratio > 0.30 {
                    liveScales[decoration.slot] = scaleStarts[decoration.slot] ?? decoration.scale
                    warning = L.cardDecorationDropRejected
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } else {
                    commitScale(decoration.slot, scale)
                    warning = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                overlap = ratio
                scaleStarts[decoration.slot] = nil
            }
    }

    private func rotateGesture(for decoration: CardDecoration) -> some Gesture {
        RotateGesture(minimumAngleDelta: .degrees(0.5))
            .onChanged { value in
                selectedSlot = decoration.slot
                if rotationStarts[decoration.slot] == nil {
                    rotationStarts[decoration.slot] = liveRotations[decoration.slot] ?? decoration.rotation
                }
                let base = rotationStarts[decoration.slot] ?? decoration.rotation
                liveRotations[decoration.slot] = min(180, max(-180, base + value.rotation.degrees))
            }
            .onEnded { _ in
                let angle = liveRotations[decoration.slot] ?? decoration.rotation
                commitRotation(decoration.slot, angle)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                rotationStarts[decoration.slot] = nil
            }
    }

    private func commitScale(_ slot: Int, _ value: Double) {
        guard let index = decorations.firstIndex(where: { $0.slot == slot }) else { return }
        decorations[index].scale = min(1.25, max(0.6, value))
        liveScales[slot] = nil
    }

    private func commitRotation(_ slot: Int, _ value: Double) {
        guard let index = decorations.firstIndex(where: { $0.slot == slot }) else { return }
        decorations[index].rotation = min(180, max(-180, value))
        liveRotations[slot] = nil
    }

    private func commit(_ slot: Int, _ point: CGPoint) {
        guard let index = decorations.firstIndex(where: { $0.slot == slot }) else { return }
        decorations[index].x = Double(min(1.1, max(-0.1, point.x)))
        decorations[index].y = Double(min(1.1, max(-0.1, point.y)))
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if let selectedSlot,
                      decorations.contains(where: { $0.slot == selectedSlot }) {
                Text("\(L.cardDecoration) \(selectedSlot + 1)")
                Text("\(L.cardDecorationOverlap) \(Int((overlap * 100).rounded()))%")
                    .foregroundStyle(overlap <= 0.30 ? Color.green : Color.orange)
                Text(L.cardDecorationOverlapLimit)
                    .foregroundStyle(.secondary)
            } else {
                Label(L.cardDecorationDragHint, systemImage: "hand.draw")
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct CardDecorationEditor: View {
    let cluster: QRCluster
    /// The persisted cluster being edited. `cluster` above is a preview draft with its own id.
    var sourceClusterID: UUID? = nil
    @Binding var decorations: [CardDecoration]
    @Binding var importing: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = false
    @State private var pickerItems: [PhotosPickerItem?] = [nil, nil, nil]
    @State private var loadingSlot: Int?
    @State private var importTask: Task<Void, Never>?
    @State private var importFailed = false
    // While a slider is being dragged we only update these local values, so the
    // preview follows the thumb immediately. The model is written once, on release.
    @State private var liveRotation: [Int: Double] = [:]
    @State private var liveScale: [Int: Double] = [:]

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                Button {
                    NotificationCenter.default.post(name: .meqrEditDecorationsOnCard, object: sourceClusterID ?? cluster.id)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Label(L.cardDecorationOnCard, systemImage: "hand.draw")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(decorations.isEmpty)

                ForEach(0..<3) { slot in
                    slotEditor(slot)
                }
            } label: {
                HStack(spacing: 8) {
                    Label(L.cardDecorations, systemImage: "sparkles")
                    Spacer()
                    if !decorations.isEmpty {
                        Text("\(decorations.count)/3")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 3) {
                Text(L.cardDecorationsHint)
                Text(L.cardDecorationHomeHint)
            }
        }
        .onDisappear { importTask?.cancel(); importing = false }
        .alert(L.cardDecorationImportFailed, isPresented: $importFailed) {
            Button(L.ok, role: .cancel) {}
        }
    }

    @ViewBuilder
    private func slotEditor(_ slot: Int) -> some View {
        let value = decorations.first(where: { $0.slot == slot })
        let rotation = liveRotation[slot] ?? value?.rotation ?? 0
        let scale = liveScale[slot] ?? value?.scale ?? 1

        HStack(alignment: .top, spacing: 12) {
            CardDecorationPreview(cluster: cluster, decoration: value, slot: slot, rotation: rotation, scale: scale)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(L.cardDecoration) \(slot + 1)")
                        .font(.subheadline.bold())
                    Spacer()
                    if loadingSlot == slot { ProgressView().controlSize(.small) }
                    PhotosPicker(selection: $pickerItems[slot], matching: .images) {
                        Text(L.tr("选择图片", "選擇圖片", "選擇圖片", "Choose Image", "画像を選択"))
                            .font(.caption)
                    }
                    .disabled(loadingSlot != nil)
                    .onChange(of: pickerItems[slot]) { _, item in importImage(item, slot: slot) }
                }

                if value != nil {
                    HStack(spacing: 6) {
                        Text(L.cardDecorationRotation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(rotation.rounded()))°")
                            .font(.caption2.monospacedDigit())
                        HStack(spacing: 4) {
                            Button { adjustRotation(slot, by: -1) } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 22, height: 20)
                            }
                            Button { adjustRotation(slot, by: 1) } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 22, height: 20)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .accessibilityLabel(L.cardDecorationRotation)
                    }
                    Slider(
                        value: liveRotationBinding(slot),
                        in: -180...180,
                        step: 10,
                        onEditingChanged: { editing in commitRotation(slot, editing: editing) }
                    )
                    .accessibilityLabel(L.cardDecorationRotation)

                    HStack {
                        Text(L.cardDecorationSize)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int((scale * 100).rounded()))%")
                            .font(.caption2.monospacedDigit())
                    }
                    Slider(
                        value: liveScaleBinding(slot),
                        in: 0.6...1.25,
                        step: 0.05,
                        onEditingChanged: { editing in commitScale(slot, editing: editing) }
                    )
                    .accessibilityLabel(L.cardDecorationSize)

                    HStack {
                        Button(L.cardDecorationReset) {
                            setRotation(slot, 0)
                            setScale(slot, 1)
                        }
                        Spacer()
                        Button(L.tr("移除图片", "移除圖片", "移除圖片", "Remove Image", "画像を削除"), role: .destructive) {
                            liveRotation[slot] = nil
                            liveScale[slot] = nil
                            decorations.removeAll { $0.slot == slot }
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                } else {
                    Text(L.cardDecorationEmptyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func liveRotationBinding(_ slot: Int) -> Binding<Double> {
        Binding {
            liveRotation[slot] ?? decorations.first { $0.slot == slot }?.rotation ?? 0
        } set: { newValue in
            liveRotation[slot] = min(180, max(-180, (newValue / 10).rounded() * 10))
        }
    }

    private func liveScaleBinding(_ slot: Int) -> Binding<Double> {
        Binding {
            liveScale[slot] ?? decorations.first { $0.slot == slot }?.scale ?? 1
        } set: { newValue in
            liveScale[slot] = min(1.25, max(0.6, (newValue / 0.05).rounded() * 0.05))
        }
    }

    private func commitRotation(_ slot: Int, editing: Bool) {
        guard !editing, let value = liveRotation[slot] else { return }
        setRotation(slot, value)
    }

    private func commitScale(_ slot: Int, editing: Bool) {
        guard !editing, let value = liveScale[slot] else { return }
        setScale(slot, value)
    }

    private func setRotation(_ slot: Int, _ value: Double) {
        liveRotation[slot] = nil
        guard let index = decorations.firstIndex(where: { $0.slot == slot }) else { return }
        decorations[index].rotation = min(180, max(-180, value.rounded()))
    }

    private func setScale(_ slot: Int, _ value: Double) {
        liveScale[slot] = nil
        guard let index = decorations.firstIndex(where: { $0.slot == slot }) else { return }
        decorations[index].scale = min(1.25, max(0.6, value))
    }

    private func adjustRotation(_ slot: Int, by delta: Double) {
        let current = liveRotation[slot] ?? decorations.first { $0.slot == slot }?.rotation ?? 0
        setRotation(slot, current + delta)
    }

    private func importImage(_ item: PhotosPickerItem?, slot: Int) {
        guard let item else { return }
        loadingSlot = slot
        importing = true
        importTask?.cancel()
        importTask = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let prepared = await Task.detached(priority: .userInitiated) {
                data.flatMap(CardDecorationImages.prepare)
            }.value
            guard !Task.isCancelled else { return }
            if let prepared, prepared.count <= 6 * 1024 * 1024 {
                if let index = decorations.firstIndex(where: { $0.slot == slot }) {
                    decorations[index].imageData = prepared
                } else {
                    decorations.append(CardDecoration(slot: slot, imageData: prepared))
                }
            } else {
                importFailed = true
            }
            loadingSlot = nil
            importing = false
            pickerItems[slot] = nil
        }
    }
}

private struct CardDecorationPreview: View {
    let cluster: QRCluster
    let decoration: CardDecoration?
    let slot: Int
    let rotation: Double
    let scale: Double

    private var image: UIImage? {
        decoration.flatMap { CardDecorationImages.image($0.imageData) }
    }

    private var cornerSymbol: String {
        switch slot {
        case 0: return "arrow.up.left"
        case 1: return "arrow.up.right"
        default: return "arrow.down.right"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cluster.backgroundColor.opacity(0.45))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.55), lineWidth: 1)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46 * scale, height: 46 * scale)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
            } else {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack {
                HStack {
                    Image(systemName: cornerSymbol)
                        .font(.system(size: 8, weight: .bold))
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                }
                Spacer()
                if decoration != nil {
                    HStack {
                        Spacer()
                        Text("\(Int(rotation.rounded()))°")
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .padding(5)
        }
        .frame(width: 86, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
