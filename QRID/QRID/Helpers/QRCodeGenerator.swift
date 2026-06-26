import SwiftUI
import CoreImage.CIFilterBuiltins
import Vision

struct QRCodeGenerator {
    static func trimQuietZoneForDisplay(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 32, height > 32 else { return image }

        guard let bitmapContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        bitmapContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = bitmapContext.data else { return image }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
                guard alpha > 0 else { continue }

                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return image }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    static func quietZoneCompensationScale(for image: UIImage) -> CGFloat {
        let finalWidth = image.size.width
        guard finalWidth > 32 else { return 1.0 }

        let contentRatio: CGFloat
        if finalWidth > 224 {
            contentRatio = 6.0 / 7.0
        } else {
            contentRatio = max((finalWidth - 32) / finalWidth, 0.01)
        }

        return 1.0 / contentRatio
    }

    static func generate(from string: String, foreground: Color, background: Color) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Apply foreground/background colors via CIFalseColor
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = outputImage
        colorFilter.color0 = CIColor(color: UIColor(foreground))
        colorFilter.color1 = CIColor(color: UIColor(background))

        guard let coloredImage = colorFilter.outputImage else { return nil }

        // Scale up for crisp display
        let scale = 20.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = coloredImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Generates a QR code with colored modules on a transparent background.
    static func generateTransparent(from string: String, foreground: Color) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the RAW QR (black modules on white background)
        let scale = 20.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledQR = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledQR, from: scaledQR.extent) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let quietZone = max(16, width / 12)
        let finalWidth = width + quietZone * 2
        let finalHeight = height + quietZone * 2

        // Create RGBA bitmap context
        guard let bitmapContext = CGContext(
            data: nil,
            width: finalWidth,
            height: finalHeight,
            bitsPerComponent: 8,
            bytesPerRow: finalWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        bitmapContext.clear(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))
        bitmapContext.draw(cgImage, in: CGRect(x: quietZone, y: quietZone, width: width, height: height))

        guard let data = bitmapContext.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: finalWidth * finalHeight * 4)

        let uiColor = UIColor(foreground)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        guard uiColor.getRed(&fr, green: &fg, blue: &fb, alpha: &fa) else { return nil }
        let red = UInt8(fr * 255)
        let green = UInt8(fg * 255)
        let blue = UInt8(fb * 255)
        let alpha = UInt8(fa * 255)

        for y in 0..<finalHeight {
            for x in 0..<finalWidth {
                let offset = (y * finalWidth + x) * 4
                let r = pixels[offset]
                let g = pixels[offset + 1]
                let b = pixels[offset + 2]

                let brightness = (Int(r) + Int(g) + Int(b)) / 3

                if x >= quietZone && x < quietZone + width && y >= quietZone && y < quietZone + height && brightness < 128 {
                    pixels[offset] = red
                    pixels[offset + 1] = green
                    pixels[offset + 2] = blue
                    pixels[offset + 3] = alpha
                } else {
                    pixels[offset] = 0
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 0
                    pixels[offset + 3] = 0
                }
            }
        }

        guard let newCgImage = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: newCgImage)
    }

    /// Decodes a QR code from a UIImage and returns the payload string
    static func decode(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw QRDecodeError.invalidImage
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let results = request.results,
              let first = results.first,
              let payload = first.payloadStringValue else {
            throw QRDecodeError.noQRCodeFound
        }

        return payload
    }

    enum QRDecodeError: Error, LocalizedError {
        case invalidImage
        case noQRCodeFound

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Could not process the image."
            case .noQRCodeFound:
                return "No QR code found in this image."
            }
        }
    }
}
