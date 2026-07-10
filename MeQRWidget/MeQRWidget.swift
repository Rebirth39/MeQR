import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

struct WidgetCluster: Codable {
    let id: String
    let name: String
    let subtitle: String
    let backgroundColorHex: String
    let borderColorHex: String
    let textColorHex: String
    let avatarBase64: String?
    let profileCount: Int
    let qrContent: String?
    let qrColorHex: String?
    let useClusterBackground: Bool
    let widgetOpacity: Double
    let widgetBackgroundImageBase64: String?
    let widgetTextColorHex: String
    let widgetSmallOffsetX: Double
    let widgetSmallOffsetY: Double
    let widgetMediumOffsetX: Double
    let widgetMediumOffsetY: Double
    let widgetLargeOffsetX: Double
    let widgetLargeOffsetY: Double
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), clusters: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), clusters: loadClusters())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), clusters: loadClusters())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadClusters() -> [WidgetCluster] {
        let appGroupID = "group.com.lucasli.qrid"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return []
        }
        let fileURL = containerURL.appendingPathComponent("clusters.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let clusters = try? JSONDecoder().decode([WidgetCluster].self, from: data) else { return [] }
        return clusters
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let clusters: [WidgetCluster]
}

struct MeQRWidgetEntryView: View {
    var entry: Provider.Entry
    var family: WidgetFamily

    var body: some View {
        let cluster = entry.clusters.first

        switch family {
        case .accessoryCircular:
            accessoryCircularView(cluster: cluster)
        case .systemMedium:
            mediumView(cluster: cluster)
        case .systemLarge:
            largeView(cluster: cluster)
        default:
            smallView(cluster: cluster)
        }
    }

    private func accessoryCircularView(cluster: WidgetCluster?) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if let cluster = cluster {
                Text(cluster.name.prefix(1))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: cluster.widgetTextColorHex))
            } else {
                Image(systemName: "qrcode")
                    .font(.title2)
            }
        }
        .widgetURL(URL(string: "meqr://open"))
    }

    @ViewBuilder
    private func widgetBackgroundContent(cluster: WidgetCluster?) -> some View {
        if let cluster = cluster,
           let bgBase64 = cluster.widgetBackgroundImageBase64,
           let data = Data(base64Encoded: bgBase64, options: .ignoreUnknownCharacters),
           let uiImage = UIImage(data: data) {
            let scaled = scaleImageForWidget(uiImage, family: family)
            let (offsetX, offsetY) = backgroundOffset(for: cluster, family: family)
            Image(uiImage: scaled)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .offset(x: offsetX, y: offsetY)
                .opacity(cluster.widgetOpacity)
        } else if let cluster = cluster {
            let bgHex = cluster.useClusterBackground ? cluster.backgroundColorHex : "#FFFFFF"
            Rectangle()
                .fill(Color(hex: bgHex))
                .opacity(cluster.widgetOpacity)
        } else {
            Color.clear
        }
    }

    private func backgroundOffset(for cluster: WidgetCluster, family: WidgetFamily) -> (CGFloat, CGFloat) {
        switch family {
        case .systemSmall:
            return (CGFloat(cluster.widgetSmallOffsetX), CGFloat(cluster.widgetSmallOffsetY))
        case .systemMedium:
            return (CGFloat(cluster.widgetMediumOffsetX), CGFloat(cluster.widgetMediumOffsetY))
        case .systemLarge:
            return (CGFloat(cluster.widgetLargeOffsetX), CGFloat(cluster.widgetLargeOffsetY))
        default:
            return (0, 0)
        }
    }

    private func scaleImageForWidget(_ image: UIImage, family: WidgetFamily) -> UIImage {
        let maxDim: CGFloat
        switch family {
        case .systemSmall: maxDim = 300
        case .systemMedium: maxDim = 400
        default: maxDim = 800
        }
        let size = image.size
        if size.width <= maxDim && size.height <= maxDim {
            return image
        }
        let ratio = min(maxDim / size.width, maxDim / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func smallView(cluster: WidgetCluster?) -> some View {
        Group {
            if let cluster = cluster {
                VStack(alignment: .leading, spacing: 8) {
                    avatarView(cluster: cluster, size: 48)
                    Text(cluster.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: cluster.widgetTextColorHex))
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    widgetBackgroundContent(cluster: cluster)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 24))
                    Text("喜劳转扩")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    Color.clear
                }
            }
        }
    }

    private func mediumView(cluster: WidgetCluster?) -> some View {
        Group {
            if let cluster = cluster {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        avatarView(cluster: cluster, size: 52)
                        Text(cluster.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: cluster.widgetTextColorHex))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let qrContent = cluster.qrContent {
                        qrCodeView(content: qrContent, colorHex: cluster.qrColorHex ?? "#000000", size: 110)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    widgetBackgroundContent(cluster: cluster)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 24))
                    Text("喜劳转扩")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    Color.clear
                }
            }
        }
    }

    private func largeView(cluster: WidgetCluster?) -> some View {
        Group {
            if let cluster = cluster {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        avatarView(cluster: cluster, size: 56)
                        Text(cluster.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(hex: cluster.widgetTextColorHex))
                    }

                    if let qrContent = cluster.qrContent {
                        HStack {
                            qrCodeView(content: qrContent, colorHex: cluster.qrColorHex ?? "#000000", size: 200)
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    widgetBackgroundContent(cluster: cluster)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 32))
                    Text("喜劳转扩")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "meqr://open"))
                .containerBackground(for: .widget) {
                    Color.clear
                }
            }
        }
    }

    private func avatarView(cluster: WidgetCluster, size: CGFloat) -> some View {
        Group {
            if let avatarBase64 = cluster.avatarBase64,
               let data = Data(base64Encoded: avatarBase64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: cluster.borderColorHex).opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(Color(hex: cluster.widgetTextColorHex))
                    )
            }
        }
    }

    private func qrCodeView(content: String, colorHex: String, size: CGFloat) -> some View {
        Group {
            if let qrImage = generateQRImage(content: content, colorHex: colorHex) {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .scaleEffect(qrQuietZoneCompensationScale(for: qrImage))
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
    }

    private func qrQuietZoneCompensationScale(for image: UIImage) -> CGFloat {
        let finalWidth = image.size.width
        guard finalWidth > 32 else { return 1.0 }

        if finalWidth > 224 {
            return 7.0 / 6.0
        }
        return finalWidth / max(finalWidth - 32, 1)
    }

    private func generateQRImage(content: String, colorHex: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let color = UIColor(Color(hex: colorHex))
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        guard color.getRed(&fr, green: &fg, blue: &fb, alpha: &fa) else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let quietZone = max(16, width / 12)
        let finalWidth = width + quietZone * 2
        let finalHeight = height + quietZone * 2

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

        let red = UInt8(fr * 255)
        let green = UInt8(fg * 255)
        let blue = UInt8(fb * 255)
        let alpha = UInt8(fa * 255)

        for y in 0..<finalHeight {
            for x in 0..<finalWidth {
                let offset = (y * finalWidth + x) * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let brightness = (r + g + b) / 3
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
}

struct MeQRSmallWidget: Widget {
    let kind: String = "MeQRWidgetSmall"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MeQRWidgetEntryView(entry: entry, family: .systemSmall)
        }
        .configurationDisplayName("喜劳转扩")
        .description("快速查看你的 QR Cluster")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct MeQRMediumWidget: Widget {
    let kind: String = "MeQRWidgetMedium"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MeQRWidgetEntryView(entry: entry, family: .systemMedium)
        }
        .configurationDisplayName("喜劳转扩")
        .description("快速查看你的 QR Cluster")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct MeQRLargeWidget: Widget {
    let kind: String = "MeQRWidgetLarge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MeQRWidgetEntryView(entry: entry, family: .systemLarge)
        }
        .configurationDisplayName("喜劳转扩")
        .description("快速查看你的 QR Cluster")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct MeQRLockScreenWidget: Widget {
    let kind: String = "MeQRWidgetLock"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MeQRWidgetEntryView(entry: entry, family: .accessoryCircular)
        }
        .configurationDisplayName("喜劳转扩")
        .description("快速查看你的 QR Cluster")
        .supportedFamilies([.accessoryCircular])
        .contentMarginsDisabled()
    }
}

@main
struct MeQRWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeQRSmallWidget()
        MeQRMediumWidget()
        MeQRLargeWidget()
        MeQRLockScreenWidget()
    }
}

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
}

#if MEQR_WIDGET_PREVIEWS
#Preview(as: .systemSmall) {
    MeQRSmallWidget()
} timeline: {
    SimpleEntry(date: .now, clusters: [
        WidgetCluster(
            id: "1",
            name: "个人名片",
            subtitle: "",
            backgroundColorHex: "#FFFFFF",
            borderColorHex: "#000000",
            textColorHex: "#000000",
            avatarBase64: nil,
            profileCount: 3,
            qrContent: "https://example.com",
            qrColorHex: "#000000",
            useClusterBackground: true,
            widgetOpacity: 0.8,
            widgetBackgroundImageBase64: nil,
            widgetTextColorHex: "#000000",
            widgetSmallOffsetX: 0,
            widgetSmallOffsetY: 0,
            widgetMediumOffsetX: 0,
            widgetMediumOffsetY: 0,
            widgetLargeOffsetX: 0,
            widgetLargeOffsetY: 0
        )
    ])
}
#endif
