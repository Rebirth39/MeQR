import SwiftUI
import CoreImage.CIFilterBuiltins
import Vision

struct QRCodeGenerator {
    struct DecodedCode {
        let payload: String
        let colorAvatarJPEG: Data?
    }

    private static let colorLayerMagic = Data([0x4D, 0x43, 0x51, 0x52])
    private static let colorLayerVersion: UInt8 = 1
    private static let colorLayerAvatarType: UInt8 = 1
    private static let colorLayerHeaderBytes = 12
    private static let colorLayerScale = 16
    private static let colorLayerQuietZone = 4
    private static let darkPalette: [UIColor] = [
        UIColor(red: 0.07, green: 0.20, blue: 0.47, alpha: 1),
        UIColor(red: 0.02, green: 0.38, blue: 0.33, alpha: 1),
        UIColor(red: 0.44, green: 0.08, blue: 0.25, alpha: 1),
        UIColor(red: 0.29, green: 0.12, blue: 0.50, alpha: 1)
    ]
    private static let lightPalette: [UIColor] = [
        UIColor(red: 0.75, green: 0.85, blue: 1.00, alpha: 1),
        UIColor(red: 0.72, green: 0.95, blue: 0.91, alpha: 1),
        UIColor(red: 1.00, green: 0.80, blue: 0.87, alpha: 1),
        UIColor(red: 0.89, green: 0.80, blue: 1.00, alpha: 1)
    ]

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

    static func generate(from string: String, foreground: Color, background: Color, correctionLevel: String = "M") -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correctionLevel

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

    static func colorLayerPayloadCapacity(from string: String, correctionLevel: String = "M") -> Int {
        guard let matrix = qrMatrix(from: string, correctionLevel: correctionLevel) else { return 0 }
        let encodedGroups = (matrix.count * matrix.count) / 5
        let decodedBytes = (encodedGroups * 3) / 4
        return max(decodedBytes - colorLayerHeaderBytes, 0)
    }

    static func paddedForColorLayer(
        _ string: String,
        minimumPayloadCapacity: Int,
        correctionLevel: String = "M"
    ) -> String {
        guard colorLayerPayloadCapacity(from: string, correctionLevel: correctionLevel) < minimumPayloadCapacity else {
            return string
        }
        let fragmentIndex = string.firstIndex(of: "#") ?? string.endIndex
        let prefix = String(string[..<fragmentIndex])
        let fragment = String(string[fragmentIndex...])
        let separator = prefix.contains("?") ? "&" : "?"
        let paddingPrefix = prefix + separator + "mcqr="
        var bestCandidate = string

        for length in stride(from: 64, through: 1_600, by: 64) {
            let candidate = paddingPrefix + String(repeating: "A", count: length) + fragment
            bestCandidate = candidate
            if colorLayerPayloadCapacity(from: candidate, correctionLevel: correctionLevel) >= minimumPayloadCapacity {
                return candidate
            }
        }
        return bestCandidate
    }

    static func generateColorLayered(
        from string: String,
        avatarJPEG: Data?,
        correctionLevel: String = "M"
    ) -> UIImage? {
        guard let matrix = qrMatrix(from: string, correctionLevel: correctionLevel) else { return nil }
        guard let avatarJPEG,
              !avatarJPEG.isEmpty,
              avatarJPEG.count <= colorLayerPayloadCapacity(from: string, correctionLevel: correctionLevel),
              let packet = colorLayerPacket(payload: avatarJPEG, type: colorLayerAvatarType) else {
            return generate(from: string, foreground: .black, background: .white, correctionLevel: correctionLevel)
        }

        let moduleCount = matrix.count
        let finalModuleCount = moduleCount + colorLayerQuietZone * 2
        let pixelSide = finalModuleCount * colorLayerScale
        guard let context = CGContext(
            data: nil,
            width: pixelSide,
            height: pixelSide,
            bitsPerComponent: 8,
            bytesPerRow: pixelSide * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelSide, height: pixelSide))
        let symbols = colorLayerSymbols(packet: packet, count: moduleCount * moduleCount)

        for row in 0..<moduleCount {
            for column in 0..<moduleCount {
                let symbol = Int(symbols[row * moduleCount + column])
                let color = matrix[row][column] ? darkPalette[symbol] : lightPalette[symbol]
                context.setFillColor(color.cgColor)
                context.fill(CGRect(
                    x: (column + colorLayerQuietZone) * colorLayerScale,
                    y: (moduleCount - row - 1 + colorLayerQuietZone) * colorLayerScale,
                    width: colorLayerScale,
                    height: colorLayerScale
                ))
            }
        }

        guard let image = context.makeImage() else { return nil }
        return UIImage(cgImage: image)
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

    static func decodeEnhanced(from image: UIImage) async throws -> DecodedCode {
        guard let normalizedImage = image.normalizedForMeQR,
              let cgImage = normalizedImage.cgImage else {
            throw QRDecodeError.invalidImage
        }

        do {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])
            if let observation = request.results?.first,
               let payload = observation.payloadStringValue {
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                let point: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * width, y: $0.y * height) }
                let avatar = decodeColorLayer(
                    from: cgImage,
                    payload: payload,
                    topLeft: point(observation.topLeft),
                    topRight: point(observation.topRight),
                    bottomLeft: point(observation.bottomLeft),
                    bottomRight: point(observation.bottomRight)
                )
                return DecodedCode(payload: payload, colorAvatarJPEG: avatar)
            }
        } catch {}

        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: context,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ),
        let feature = detector.features(in: CIImage(cgImage: cgImage)).first as? CIQRCodeFeature,
        let payload = feature.messageString else {
            throw QRDecodeError.noQRCodeFound
        }
        let avatar = decodeColorLayer(
            from: cgImage,
            payload: payload,
            topLeft: feature.topLeft,
            topRight: feature.topRight,
            bottomLeft: feature.bottomLeft,
            bottomRight: feature.bottomRight
        )
        return DecodedCode(payload: payload, colorAvatarJPEG: avatar)
    }

    /// Decodes a QR code from a UIImage and returns the payload string
    static func decode(from image: UIImage) async throws -> String {
        try await decodeEnhanced(from: image).payload
    }

    private static func qrMatrix(from string: String, correctionLevel: String) -> [[Bool]]? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correctionLevel
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        let side = Int(extent.width)
        guard side > 0, side == Int(extent.height) else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(output, from: extent),
              let pixels = rgbaPixels(from: cgImage) else { return nil }
        let rawMatrix = (0..<side).map { row in
            (0..<side).map { column in
                pixels[(row * side + column) * 4] < 128
            }
        }
        let darkRows = (0..<side).filter { row in rawMatrix[row].contains(true) }
        let darkColumns = (0..<side).filter { column in
            (0..<side).contains { row in rawMatrix[row][column] }
        }
        guard let firstRow = darkRows.first,
              let lastRow = darkRows.last,
              let firstColumn = darkColumns.first,
              let lastColumn = darkColumns.last,
              lastRow - firstRow == lastColumn - firstColumn else { return nil }
        return (firstRow...lastRow).map { row in
            Array(rawMatrix[row][firstColumn...lastColumn])
        }
    }

    private static func colorLayerPacket(payload: Data, type: UInt8) -> Data? {
        guard payload.count <= Int(UInt16.max) else { return nil }
        var packet = Data()
        packet.append(colorLayerMagic)
        packet.append(colorLayerVersion)
        packet.append(type)
        packet.append(UInt8((payload.count >> 8) & 0xFF))
        packet.append(UInt8(payload.count & 0xFF))
        let checksum = crc32(payload)
        packet.append(UInt8((checksum >> 24) & 0xFF))
        packet.append(UInt8((checksum >> 16) & 0xFF))
        packet.append(UInt8((checksum >> 8) & 0xFF))
        packet.append(UInt8(checksum & 0xFF))
        packet.append(payload)
        return packet
    }

    private static func colorLayerSymbols(packet: Data, count: Int) -> [UInt8] {
        let bytes = [UInt8](packet)
        var rawSymbols = [UInt8]()
        rawSymbols.reserveCapacity(bytes.count * 4)
        for byte in bytes {
            rawSymbols.append((byte >> 6) & 0x03)
            rawSymbols.append((byte >> 4) & 0x03)
            rawSymbols.append((byte >> 2) & 0x03)
            rawSymbols.append(byte & 0x03)
        }
        while rawSymbols.count % 3 != 0 {
            rawSymbols.append(0)
        }

        var symbols = [UInt8]()
        symbols.reserveCapacity(count)
        for index in stride(from: 0, to: rawSymbols.count, by: 3) {
            symbols.append(contentsOf: encodeColorFEC(
                rawSymbols[index],
                rawSymbols[index + 1],
                rawSymbols[index + 2]
            ))
        }
        while symbols.count < count {
            symbols.append(UInt8(symbols.count & 0x03))
        }
        return Array(symbols.prefix(count))
    }

    private static func decodeColorLayer(
        from source: CGImage,
        payload: String,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> Data? {
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: source)
        filter.topLeft = topLeft
        filter.topRight = topRight
        filter.bottomLeft = bottomLeft
        filter.bottomRight = bottomRight
        guard let corrected = filter.outputImage else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let correctedImage = context.createCGImage(corrected, from: corrected.extent),
              let pixels = rgbaPixels(from: correctedImage) else { return nil }

        let imageWidth = correctedImage.width
        let imageHeight = correctedImage.height
        let preferredSide = qrMatrix(from: payload, correctionLevel: "M")?.count
        var candidateSides = preferredSide.map { [$0] } ?? []
        candidateSides.append(contentsOf: (1...40).map { 17 + $0 * 4 }.filter { $0 != preferredSide })

        for side in candidateSides {
            let sampled = (0..<side * side).map { index -> UInt8 in
                let row = index / side
                let column = index % side
                let x = min(max(Int((CGFloat(column) + 0.5) * CGFloat(imageWidth) / CGFloat(side)), 0), imageWidth - 1)
                let y = min(max(Int((CGFloat(row) + 0.5) * CGFloat(imageHeight) / CGFloat(side)), 0), imageHeight - 1)
                let offset = (y * imageWidth + x) * 4
                return nearestPaletteSymbol(
                    red: pixels[offset],
                    green: pixels[offset + 1],
                    blue: pixels[offset + 2]
                )
            }

            for mirrored in [false, true] {
                for rotation in 0..<4 {
                    let symbols = transformedSymbols(sampled, side: side, rotation: rotation, mirrored: mirrored)
                    if let avatar = parseColorLayer(symbols: symbols, expectedType: colorLayerAvatarType) {
                        return avatar
                    }
                }
            }
        }
        return nil
    }

    private static func transformedSymbols(_ symbols: [UInt8], side: Int, rotation: Int, mirrored: Bool) -> [UInt8] {
        (0..<side * side).map { index in
            let targetRow = index / side
            let targetColumn = index % side
            var row = targetRow
            var column = targetColumn
            for _ in 0..<rotation {
                (row, column) = (side - column - 1, row)
            }
            if mirrored { column = side - column - 1 }
            return symbols[row * side + column]
        }
    }

    private static func parseColorLayer(symbols: [UInt8], expectedType: UInt8) -> Data? {
        var decodedSymbols = [UInt8]()
        decodedSymbols.reserveCapacity((symbols.count / 5) * 3)
        for index in stride(from: 0, through: symbols.count - symbols.count % 5 - 5, by: 5) {
            guard let decoded = decodeColorFEC(Array(symbols[index..<(index + 5)])) else { return nil }
            decodedSymbols.append(contentsOf: decoded)
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(decodedSymbols.count / 4)
        var index = 0
        while index + 3 < decodedSymbols.count {
            bytes.append(
                (decodedSymbols[index] << 6)
                    | (decodedSymbols[index + 1] << 4)
                    | (decodedSymbols[index + 2] << 2)
                    | decodedSymbols[index + 3]
            )
            index += 4
        }
        guard bytes.count >= colorLayerHeaderBytes,
              Data(bytes.prefix(4)) == colorLayerMagic,
              bytes[4] == colorLayerVersion,
              bytes[5] == expectedType else { return nil }
        let payloadLength = Int(bytes[6]) << 8 | Int(bytes[7])
        guard payloadLength > 0, colorLayerHeaderBytes + payloadLength <= bytes.count else { return nil }
        let expectedCRC = UInt32(bytes[8]) << 24 | UInt32(bytes[9]) << 16 | UInt32(bytes[10]) << 8 | UInt32(bytes[11])
        let payload = Data(bytes[colorLayerHeaderBytes..<(colorLayerHeaderBytes + payloadLength)])
        return crc32(payload) == expectedCRC ? payload : nil
    }

    private static func encodeColorFEC(_ first: UInt8, _ second: UInt8, _ third: UInt8) -> [UInt8] {
        let parityBase = first ^ third
        let fifth = second ^ third ^ multiplyGF4(2, parityBase)
        let fourth = parityBase ^ fifth
        return [first, second, third, fourth, fifth]
    }

    private static func decodeColorFEC(_ values: [UInt8]) -> [UInt8]? {
        guard values.count == 5 else { return nil }
        var corrected = values.map { $0 & 0x03 }
        let syndromeFirst = corrected[0] ^ corrected[2] ^ corrected[3] ^ corrected[4]
        let syndromeSecond = corrected[1]
            ^ corrected[2]
            ^ multiplyGF4(2, corrected[3])
            ^ multiplyGF4(3, corrected[4])

        if syndromeFirst != 0 || syndromeSecond != 0 {
            let errorIndex: Int
            let magnitude: UInt8
            if syndromeSecond == 0 {
                errorIndex = 0
                magnitude = syndromeFirst
            } else if syndromeFirst == 0 {
                errorIndex = 1
                magnitude = syndromeSecond
            } else if syndromeSecond == syndromeFirst {
                errorIndex = 2
                magnitude = syndromeFirst
            } else if syndromeSecond == multiplyGF4(2, syndromeFirst) {
                errorIndex = 3
                magnitude = syndromeFirst
            } else if syndromeSecond == multiplyGF4(3, syndromeFirst) {
                errorIndex = 4
                magnitude = syndromeFirst
            } else {
                return nil
            }
            corrected[errorIndex] ^= magnitude
        }
        return Array(corrected.prefix(3))
    }

    private static func multiplyGF4(_ lhs: UInt8, _ rhs: UInt8) -> UInt8 {
        let left = lhs & 0x03
        let right = rhs & 0x03
        if left == 0 || right == 0 { return 0 }
        if left == 1 { return right }
        if right == 1 { return left }
        if left == 2 && right == 2 { return 3 }
        if left == 3 && right == 3 { return 2 }
        return 1
    }

    private static func nearestPaletteSymbol(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
        let color = UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let targetHues: [CGFloat] = [0.61, 0.47, 0.93, 0.75]
        let distances = targetHues.map { target -> CGFloat in
            let direct = abs(hue - target)
            return min(direct, 1 - direct)
        }
        return UInt8(distances.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0)
    }

    private static func rgbaPixels(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
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

private extension UIImage {
    var normalizedForMeQR: UIImage? {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
