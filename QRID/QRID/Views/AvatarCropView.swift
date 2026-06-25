import SwiftUI

struct CroppableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AvatarCropView: View {
    let sourceImage: UIImage
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: cropSize * 2, height: cropSize * 2)
                        .scaleEffect(scale)
                        .offset(offset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    OverlayMask(cropSize: cropSize)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    CropOverlay(cropSize: cropSize)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, minScale), maxScale)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            snapBack()
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let proposed = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            offset = clampOffset(proposed, allowOverScroll: true)
                        }
                        .onEnded { _ in
                            snapBack()
                        }
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                HStack {
                    Button(L.cancel, action: onCancel)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(L.choose) {
                        cropImage()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
    }

    private func displaySize() -> CGSize {
        guard sourceImage.size.height > 0, sourceImage.size.width > 0 else {
            return CGSize(width: cropSize * 2, height: cropSize * 2)
        }
        let imageRatio = sourceImage.size.width / sourceImage.size.height
        let frameSize = cropSize * 2
        // .aspectRatio(.fit) inside a square frame
        if imageRatio >= 1 {
            // Wide image: width fills the frame, height is scaled down
            return CGSize(width: frameSize, height: frameSize / imageRatio)
        } else {
            // Tall image: height fills the frame, width is scaled down
            return CGSize(width: frameSize * imageRatio, height: frameSize)
        }
    }

    private func clampOffset(_ proposed: CGSize, allowOverScroll: Bool = false) -> CGSize {
        let size = displaySize()
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale
        let diffX = scaledWidth - cropSize
        let diffY = scaledHeight - cropSize

        let limitX: CGFloat = max(0, diffX / 2)
        let limitY: CGFloat = max(0, diffY / 2)

        if allowOverScroll {
            return CGSize(
                width: rubberBand(proposed.width, limit: limitX),
                height: rubberBand(proposed.height, limit: limitY)
            )
        } else {
            return CGSize(
                width: min(max(proposed.width, -limitX), limitX),
                height: min(max(proposed.height, -limitY), limitY)
            )
        }
    }

    private func snapBack() {
        let targetOffset = clampOffset(offset, allowOverScroll: false)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            offset = targetOffset
        }
        lastOffset = targetOffset
    }

    private func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        if limit == 0 {
            return value * 0.35
        }
        if abs(value) <= limit {
            return value
        }
        let overshoot = abs(value) - limit
        let resisted = overshoot * 0.65
        return (value > 0 ? 1 : -1) * (limit + resisted)
    }

    private func cropImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        let cropped = renderer.image { context in
            let circlePath = UIBezierPath(
                arcCenter: CGPoint(x: cropSize / 2, y: cropSize / 2),
                radius: cropSize / 2,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            circlePath.addClip()

            let size = displaySize()
            let drawWidth = size.width * scale
            let drawHeight = size.height * scale
            let drawRect = CGRect(
                x: (cropSize - drawWidth) / 2 + offset.width,
                y: (cropSize - drawHeight) / 2 + offset.height,
                width: drawWidth,
                height: drawHeight
            )
            sourceImage.draw(in: drawRect)
        }

        onDone(cropped)
    }
}

private struct OverlayMask: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height))

                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let radius = cropSize / 2
                path.addEllipse(in: CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: cropSize,
                    height: cropSize
                ))
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }
}

private struct CropOverlay: View {
    let cropSize: CGFloat
    private let cornerLength: CGFloat = 24
    private let lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: lineWidth)
                .frame(width: cropSize, height: cropSize)

            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let radius = cropSize / 2
                let left = centerX - radius
                let top = centerY - radius

                Path { path in
                    // Top-left corner
                    path.move(to: CGPoint(x: left + cornerLength, y: top))
                    path.addLine(to: CGPoint(x: left, y: top))
                    path.addLine(to: CGPoint(x: left, y: top + cornerLength))

                    // Top-right corner
                    path.move(to: CGPoint(x: left + cropSize - cornerLength, y: top))
                    path.addLine(to: CGPoint(x: left + cropSize, y: top))
                    path.addLine(to: CGPoint(x: left + cropSize, y: top + cornerLength))

                    // Bottom-left corner
                    path.move(to: CGPoint(x: left, y: top + cropSize - cornerLength))
                    path.addLine(to: CGPoint(x: left, y: top + cropSize))
                    path.addLine(to: CGPoint(x: left + cornerLength, y: top + cropSize))

                    // Bottom-right corner
                    path.move(to: CGPoint(x: left + cropSize, y: top + cropSize - cornerLength))
                    path.addLine(to: CGPoint(x: left + cropSize, y: top + cropSize))
                    path.addLine(to: CGPoint(x: left + cropSize - cornerLength, y: top + cropSize))
                }
                .stroke(Color.white, lineWidth: lineWidth + 0.5)
            }
        }
        .frame(width: cropSize, height: cropSize)
    }
}
