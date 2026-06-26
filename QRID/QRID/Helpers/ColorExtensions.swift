import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Returns black or white depending on background brightness, for UI elements that need to be visible.
    var uiContrastColor: Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }

    var isDarkForUI: Bool {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance <= 0.5
    }
}

extension UIImage {
    func topAreaLuminance(sampleSize: Int = 24, heightRatio: CGFloat = 0.22) -> CGFloat? {
        guard let cgImage else { return nil }

        let cropHeight = max(1, Int(CGFloat(cgImage.height) * heightRatio))
        let cropRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cropHeight)
        guard let croppedImage = cgImage.cropping(to: cropRect) else { return nil }

        guard let bitmapContext = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        bitmapContext.interpolationQuality = .low
        bitmapContext.draw(croppedImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        guard let data = bitmapContext.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)

        var luminance: CGFloat = 0
        for index in 0..<(sampleSize * sampleSize) {
            let offset = index * 4
            let r = CGFloat(pixels[offset]) / 255
            let g = CGFloat(pixels[offset + 1]) / 255
            let b = CGFloat(pixels[offset + 2]) / 255
            luminance += 0.299 * r + 0.587 * g + 0.114 * b
        }

        return luminance / CGFloat(sampleSize * sampleSize)
    }
}
