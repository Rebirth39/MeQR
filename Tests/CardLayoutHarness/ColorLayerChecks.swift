import UIKit

@MainActor enum ColorLayerChecks {
    static func cachedCode() async -> String {
        do {
            let directory = URL(fileURLWithPath: "COLOR_FIXTURE_DIRECTORY")
            let record = try JSONDecoder().decode(MeQRExchangeCodeRecord.self, from: Data(contentsOf: directory.appendingPathComponent("record.json")))
            let capacity = QRCodeGenerator.colorLayerPayloadCapacity(from: record.payload)
            guard let avatar = record.avatarJPEG, UIImage(data: avatar) != nil,
                  avatar.count <= capacity else { return "FAIL cached avatar invalid or above capacity \(capacity)" }
            guard let image = QRCodeGenerator.generateColorLayered(from: record.payload, avatarJPEG: avatar) else { return "FAIL generation" }
            let decoded = try await QRCodeGenerator.decodeEnhanced(from: image)
            guard decoded.payload == record.payload, decoded.colorAvatarJPEG == avatar else { return "FAIL original cached code roundtrip" }
            try image.pngData()!.write(to: directory.appendingPathComponent("cached-code.png"))
            var captures = [String]()
            var capturesPassed = true
            for filename in ["ipad-screen.png", "iphone-preview.png"] {
                guard let capture = UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) else { continue }
                QRCodeGenerator.inspectCapture(capture, payload: record.payload, avatar: avatar, label: filename)
                do {
                    let result = try await QRCodeGenerator.decodeEnhanced(from: capture)
                    captures.append("\(filename): base=\(result.payload == record.payload), avatar=\(result.colorAvatarJPEG == avatar)")
                    capturesPassed = capturesPassed && result.payload == record.payload && result.colorAvatarJPEG == avatar
                } catch {
                    captures.append("\(filename): \(error)")
                    capturesPassed = false
                }
            }
            if !captures.isEmpty { return (capturesPassed ? "PASS" : "FAIL") + " captures: " + captures.joined(separator: "; ") }
            return "PASS unchanged cached avatar \(avatar.count)/\(capacity) bytes, JPEG valid, generated code roundtrip exact"
        } catch { return "FAIL \(error)" }
    }

    static func avatarRepair() async -> String {
        do {
            let directory = URL(fileURLWithPath: "COLOR_FIXTURE_DIRECTORY")
            let record = try JSONDecoder().decode(MeQRExchangeCodeRecord.self, from: Data(contentsOf: directory.appendingPathComponent("record.json")))
            let source = Data(base64Encoded: record.onlineProfile.avatarJPEGBase64!)!
            let capacity = QRCodeGenerator.colorLayerPayloadCapacity(from: record.payload)
            let avatar = MeQRExchangeProfile.colorLayerAvatarJPEG(from: source, maxBytes: capacity)
            guard let avatar, UIImage(data: avatar) != nil else { return "FAIL compact JPEG must fit \(capacity) bytes" }
            guard let minimumAvatar = MeQRExchangeProfile.colorLayerAvatarJPEG(from: source, maxBytes: 800),
                  minimumAvatar.count <= 800, UIImage(data: minimumAvatar) != nil,
                  MeQRExchangeProfile.colorLayerAvatarJPEG(from: source, maxBytes: 10) == nil else { return "FAIL minimum/impossible capacity handling" }
            let repaired = record.repairingColorAvatar(from: source)
            guard repaired.avatarJPEG == avatar, repaired.payload == record.payload,
                  repaired.fingerprint == record.fingerprint, repaired.sessionID == record.sessionID,
                  repaired.ownerToken == record.ownerToken, repaired.onlineProfile == record.onlineProfile,
                  repaired.eventID == record.eventID, repaired.synced == record.synced else { return "FAIL cache identity changed" }
            guard repaired.repairingColorAvatar(from: nil).avatarJPEG == avatar,
                  record.repairingColorAvatar(from: Data([1, 2, 3])).avatarJPEG == record.avatarJPEG else { return "FAIL valid cache or missing source handling" }
            let store = MeQRExchangeCodeStore(directory: directory.appendingPathComponent("repaired-cache"))
            try store.save(repaired, clusterID: record.onlineProfile.id)
            guard store.load(clusterID: record.onlineProfile.id, fingerprint: record.fingerprint)?.avatarJPEG == avatar else { return "FAIL repair persistence" }
            let image = QRCodeGenerator.generateColorLayered(from: record.payload, avatarJPEG: avatar)!
            let decoded = try await QRCodeGenerator.decodeEnhanced(from: image)
            guard decoded.colorAvatarJPEG == avatar else { return "FAIL repaired avatar roundtrip" }
            try image.pngData()!.write(to: directory.appendingPathComponent("repaired-code.png"))
            try avatar.write(to: directory.appendingPathComponent("repaired-avatar.jpg"))
            return "PASS real avatar compressed \(avatar.count)/\(capacity) bytes, JPEG valid, color roundtrip, cache persisted without session changes"
        } catch { return "FAIL \(error)" }
    }

    static func run() async -> String {
        let directory = URL(fileURLWithPath: "COLOR_FIXTURE_DIRECTORY")
        do {
            let avatar = try Data(contentsOf: directory.appendingPathComponent("avatar.jpg"))
            let android = UIImage(contentsOfFile: directory.appendingPathComponent("android-color.png").path)!
            let androidCode = try await QRCodeGenerator.decodeEnhanced(from: android)
            guard androidCode.colorAvatarJPEG == avatar else { return "FAIL Android to iOS avatar" }
            let payload = QRCodeGenerator.paddedForColorLayer(androidCode.payload, minimumPayloadCapacity: max(800, avatar.count))
            let current = QRCodeGenerator.generateColorLayered(from: payload, avatarJPEG: avatar)!
            try current.pngData()!.write(to: directory.appendingPathComponent("ios-color.png"))
            try Data(payload.utf8).write(to: directory.appendingPathComponent("ios-payload.txt"))
            let legacy = LegacyQRCodeGenerator.generateColorLayered(from: payload, avatarJPEG: avatar)!
            let androidLegacy = UIImage(contentsOfFile: directory.appendingPathComponent("android-legacy.png").path)!
            let variants: [(String, UIImage)] = [
                ("current", current), ("legacy iOS", legacy),
                ("rotated", UIImage(cgImage: current.cgImage!, scale: 1, orientation: .right)),
                ("mirrored", UIImage(cgImage: current.cgImage!, scale: 1, orientation: .upMirrored))
            ]
            for (label, image) in variants {
                let decoded = try await QRCodeGenerator.decodeEnhanced(from: image)
                guard decoded.payload == payload, decoded.colorAvatarJPEG == avatar else { return "FAIL \(label) roundtrip: base=\(decoded.payload == payload) avatar=\(decoded.colorAvatarJPEG?.count ?? 0) expected=\(avatar.count) capacity=\(QRCodeGenerator.colorLayerPayloadCapacity(from: payload))" }
            }
            let legacyAndroid = try await QRCodeGenerator.decodeEnhanced(from: androidLegacy)
            guard legacyAndroid.payload == androidCode.payload, legacyAndroid.colorAvatarJPEG == avatar else { return "FAIL legacy Android" }
            let oldReader = try await LegacyQRCodeGenerator.decodeEnhanced(from: current)
            guard oldReader.colorAvatarJPEG == avatar else { return "FAIL old reader/new palette" }
            let mono = QRCodeGenerator.generateColorLayered(from: payload, avatarJPEG: nil)!
            let plain = try await QRCodeGenerator.decodeEnhanced(from: mono)
            guard plain.payload == payload, plain.colorAvatarJPEG == nil else { return "FAIL mono fallback" }
            try current.pngData()!.write(to: directory.appendingPathComponent("ios-color.png"))
            return "PASS iOS/Android current and legacy palettes, old reader, rotation/mirror, mono fallback"
        } catch { return "FAIL \(error)" }
    }
}

extension QRCodeGenerator {
    static func inspectCapture(_ image: UIImage, payload: String, avatar: Data, label: String) {
        guard let source = image.cgImage, let matrix = qrMatrix(from: payload, correctionLevel: "M"),
              let packet = colorLayerPacket(payload: avatar, type: colorLayerAvatarType) else { return }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: source).perform([request])
        guard let observation = request.results?.first(where: { $0.payloadStringValue == payload }) else {
            print("CAPTURE \(label): expected barcode not detected")
            return
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: source)
        let point: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * CGFloat(source.width), y: $0.y * CGFloat(source.height)) }
        filter.topLeft = point(observation.topLeft)
        filter.topRight = point(observation.topRight)
        filter.bottomLeft = point(observation.bottomLeft)
        filter.bottomRight = point(observation.bottomRight)
        guard let corrected = filter.outputImage,
              let raster = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(corrected, from: corrected.extent),
              let pixels = rgbaPixels(from: raster) else { return }
        let side = matrix.count
        let count = ((12 + avatar.count) * 4 + 2) / 3 * 5
        let expected = colorLayerSymbols(packet: packet, count: side * side)
        var best = (errors: Int.max, detail: "")
        for mirrored in [false, true] {
            for rotation in 0..<4 {
                var errors = 0
                var wrongGroups = Set<Int>()
                var wrongHeader = 0
                for index in 0..<count {
                    var row = index / side
                    var column = index % side
                    for _ in 0..<rotation { (row, column) = (side - column - 1, row) }
                    if mirrored { column = side - column - 1 }
                    var red = 0
                    var green = 0
                    var blue = 0
                    for vertical in [0.32, 0.5, 0.68] {
                        for horizontal in [0.32, 0.5, 0.68] {
                            let pixelX = min(Int((Double(column) + horizontal) * Double(raster.width) / Double(side)), raster.width - 1)
                            let pixelY = min(Int((Double(row) + vertical) * Double(raster.height) / Double(side)), raster.height - 1)
                            let offset = (pixelY * raster.width + pixelX) * 4
                            red += Int(pixels[offset]); green += Int(pixels[offset + 1]); blue += Int(pixels[offset + 2])
                        }
                    }
                    if nearestPaletteSymbol(red: UInt8(red / 9), green: UInt8(green / 9), blue: UInt8(blue / 9)) != expected[index] {
                        errors += 1
                        wrongGroups.insert(index / 5)
                        if index < 80 { wrongHeader += 1 }
                    }
                }
                if errors < best.errors { best = (errors, "rotation=\(rotation) mirror=\(mirrored) headerErrors=\(wrongHeader) affectedGroups=\(wrongGroups.count)") }
            }
        }
        print("CAPTURE \(label): side=\(side) raster=\(raster.width)x\(raster.height) symbolErrors=\(best.errors)/\(count) \(best.detail)")
        let summary = "side=\(side), raster=\(raster.width)x\(raster.height), symbolErrors=\(best.errors)/\(count), \(best.detail)"
        try? summary.write(to: URL(fileURLWithPath: "COLOR_FIXTURE_DIRECTORY").appendingPathComponent(label + ".diagnostics.txt"), atomically: true, encoding: .utf8)
    }
}
