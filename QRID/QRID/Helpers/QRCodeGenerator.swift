import SwiftUI
import CoreImage.CIFilterBuiltins

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
}
