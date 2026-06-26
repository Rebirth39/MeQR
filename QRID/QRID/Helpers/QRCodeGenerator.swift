import SwiftUI
import CoreImage.CIFilterBuiltins
import Vision

struct QRCodeGenerator {
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

    /// Generates a QR code with colored modules and an opaque quiet zone for scan reliability.
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

        bitmapContext.setFillColor(UIColor.white.cgColor)
        bitmapContext.fill(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))

        // Draw raw QR mask
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

                // Raw QR: black = module, white = background
                // After scaling, edge pixels are gray
                // Threshold at middle brightness
                let brightness = (Int(r) + Int(g) + Int(b)) / 3

                if x >= quietZone && x < quietZone + width && y >= quietZone && y < quietZone + height && brightness < 128 {
                    // Dark pixel = QR module -> foreground color
                    pixels[offset] = red
                    pixels[offset + 1] = green
                    pixels[offset + 2] = blue
                    pixels[offset + 3] = alpha
                } else {
                    // Preserve an opaque light background so the quiet zone remains scannable.
                    pixels[offset] = 255
                    pixels[offset + 1] = 255
                    pixels[offset + 2] = 255
                    pixels[offset + 3] = 255
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
