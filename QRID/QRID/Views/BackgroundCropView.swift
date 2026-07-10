import SwiftUI

struct BackgroundCropView: View {
    let sourceImage: UIImage
    var cropAspectRatio: CGFloat? = nil
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let outputWidth: CGFloat = 1080

    private var screenRatio: CGFloat {
        let bounds = UIScreen.main.bounds
        return bounds.height / bounds.width
    }

    private var cropSize: CGSize {
        let width = UIScreen.main.bounds.width - 32
        let height = cropAspectRatio.map { width / $0 } ?? (width * screenRatio)
        return CGSize(width: width, height: min(height, UIScreen.main.bounds.height - 180))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let size = cropSize
                let displaySize = fillDisplaySize(for: size)

                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    OverlayMask(cropSize: size, cornerRadius: 4)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    CropOverlay(cropSize: size, cornerRadius: 4)
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
                            offset = clampOffset(offset)
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
                            offset = clampOffset(proposed)
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

    private func fillDisplaySize(for frame: CGSize) -> CGSize {
        guard sourceImage.size.height > 0, sourceImage.size.width > 0 else { return frame }
        let imageRatio = sourceImage.size.width / sourceImage.size.height
        let frameRatio = frame.width / frame.height
        if imageRatio >= frameRatio {
            return CGSize(width: frame.height * imageRatio, height: frame.height)
        } else {
            return CGSize(width: frame.width, height: frame.width / imageRatio)
        }
    }

    private func clampOffset(_ proposed: CGSize) -> CGSize {
        let displaySize = fillDisplaySize(for: cropSize)
        let size = cropSize
        let diffX = displaySize.width * scale - size.width
        let diffY = displaySize.height * scale - size.height

        let limitX: CGFloat = max(0, diffX / 2)
        let limitY: CGFloat = max(0, diffY / 2)

        return CGSize(
            width: min(max(proposed.width, -limitX), limitX),
            height: min(max(proposed.height, -limitY), limitY)
        )
    }

    private func snapBack() {
        let targetOffset = clampOffset(offset)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            offset = targetOffset
        }
        lastOffset = targetOffset
    }

    private func cropImage() {
        let size = cropSize
        let outputHeight = outputWidth * (size.height / size.width)
        let displaySize = fillDisplaySize(for: size)
        let scaleFactor = outputWidth / size.width

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputWidth, height: outputHeight))

        let cropped = renderer.image { _ in
            let drawWidth = displaySize.width * scale * scaleFactor
            let drawHeight = displaySize.height * scale * scaleFactor
            let drawX = (outputWidth - drawWidth) / 2 + offset.width * scaleFactor
            let drawY = (outputHeight - drawHeight) / 2 + offset.height * scaleFactor

            let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
            sourceImage.draw(in: drawRect)
        }

        onDone(cropped)
    }
}

private struct OverlayMask: View {
    let cropSize: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height))

                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let halfWidth = cropSize.width / 2
                let halfHeight = cropSize.height / 2
                path.addRoundedRect(
                    in: CGRect(
                        x: centerX - halfWidth,
                        y: centerY - halfHeight,
                        width: cropSize.width,
                        height: cropSize.height
                    ),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }
}

private struct CropOverlay: View {
    let cropSize: CGSize
    let cornerRadius: CGFloat
    private let cornerLength: CGFloat = 28
    private let lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                .frame(width: cropSize.width, height: cropSize.height)

            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let halfW = cropSize.width / 2
                let halfH = cropSize.height / 2
                let left = centerX - halfW
                let top = centerY - halfH
                let right = left + cropSize.width
                let bottom = top + cropSize.height

                Path { path in
                    // Top-left
                    path.move(to: CGPoint(x: left + cornerLength, y: top))
                    path.addLine(to: CGPoint(x: left, y: top))
                    path.addLine(to: CGPoint(x: left, y: top + cornerLength))

                    // Top-right
                    path.move(to: CGPoint(x: right - cornerLength, y: top))
                    path.addLine(to: CGPoint(x: right, y: top))
                    path.addLine(to: CGPoint(x: right, y: top + cornerLength))

                    // Bottom-left
                    path.move(to: CGPoint(x: left, y: bottom - cornerLength))
                    path.addLine(to: CGPoint(x: left, y: bottom))
                    path.addLine(to: CGPoint(x: left + cornerLength, y: bottom))

                    // Bottom-right
                    path.move(to: CGPoint(x: right, y: bottom - cornerLength))
                    path.addLine(to: CGPoint(x: right, y: bottom))
                    path.addLine(to: CGPoint(x: right - cornerLength, y: bottom))
                }
                .stroke(Color.white, lineWidth: lineWidth)
            }
        }
        .frame(width: cropSize.width, height: cropSize.height)
    }
}
