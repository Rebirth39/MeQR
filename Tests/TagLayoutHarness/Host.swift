import SwiftUI

// Fixtures only; the harness compiles the production tag renderer and color helpers.
enum CardTagTextWeight { case regular, medium, bold }
struct CardTagColorOverride: Equatable { var textWeight: CardTagTextWeight = .regular }
struct CardTagColorStyle {
    let segmentHexes: [String]
    var leadingHex: String { segmentHexes[0] }
}
enum CardTagColorPalette {
    static func textWeight(for tag: String, overrides: [String: CardTagColorOverride]) -> CardTagTextWeight {
        overrides[tag]?.textWeight ?? .regular
    }
    static func colorStyle(for tag: String, overrides: [String: CardTagColorOverride]) -> CardTagColorStyle {
        let colors: [String: [String]] = [
            "Project SEKAI": ["39C5BB", "00A0E9", "88DD44", "FF9900", "EE1166", "884499"],
            "Wonderlands x Showtime": ["FF9900", "FFCC11", "FF66BB", "33CC99", "BB88EE"],
            "MyGO!!!!!": ["3388AA"], "Tomori": ["3388AA", "77BBDD"],
            "maimai": ["FFFFFF", "22BBEE", "FFFFFF"], "maimai 14500+": ["E6D466", "FFFAC5"]
        ]
        return CardTagColorStyle(segmentHexes: colors[tag] ?? ["33BBBB"])
    }
}
enum L {
    static let qrDestination = "Destination", urlOrText = "QR Content", qrReviewTitle = "Open QR Link?", qrOpen = "Open"
    static let qrReviewWarning = "Check the complete content before opening.", qrFormatWarning = "Check the platform format."
    static let qrDestinationWarning = "Check the destination.", qrOfficialImportHint = "Import the official personal QR code."
    static let tagReport = "Report Tag Issue", tagReportReason = "Issue Type", tagReportName = "Name or Translation"
    static let tagReportColor = "Incorrect Colors", tagReportDuplicate = "Duplicate Tag", tagReportOther = "Other Issue"
    static let tagReportDescription = "Description", tagReportContact = "Contact (Optional)", tagReportSubmit = "Submit"
    static let tagReportSent = "Submitted", tagReportTicket = "Ticket ID", tagReportFailed = "Failed; retry."
    static let tagReportLimited = "Too many submissions", tagReportDiscard = "Discard This Report?"
    static let cancel = "Cancel", done = "Done"
    static let delete = "Delete"
    static let tagMoveUp = "Move up"
    static let tagMoveDown = "Move down"
}
enum CardTagIndex { static func normalizedKey(_ tag: String) -> String { tag.lowercased() } }
enum RemoteTagCatalogSnapshot {
    struct Entry { let id: String }
    static func entry(matchingNormalizedKey: String) -> Entry? { Entry(id: "tag-0001") }
}
struct RemoteTagCatalog {
    static let shared = RemoteTagCatalog()
    let revision = "test-catalog", sourceName = "bundled"
}

@main struct TagLayoutHost: App {
    var body: some Scene { WindowGroup {
        if ProcessInfo.processInfo.arguments.contains("qr-review") { QRReviewFixture() }
        else { Editor() }
    } }
}
struct QRReviewFixture: View {
    @State private var showing = false
    @State private var opened = "none"
    var body: some View {
        VStack {
            Button("Review") { showing = true }
            Text(opened).accessibilityIdentifier("opened")
        }.sheet(isPresented: $showing) {
            QRLinkReviewView(content: ProcessInfo.processInfo.arguments.contains("unsafe")
                ? "javascript:alert(1)" : "https://example.com/path?qq.com") { url in opened = url.absoluteString }
        }
    }
}
struct Editor: View {
    @State private var weightIndex = 0
    @State private var selections = 0
    @State private var tags = ["Hatsune Miku", "Project SEKAI", "Wonderlands x Showtime", "MyGO!!!!!", "Tomori", "maimai", "maimai 14500+"]
    @State private var draft = ""
    private var narrow: Bool { ProcessInfo.processInfo.arguments.contains("narrow") }
    var body: some View {
        NavigationStack {
            Form {
                Section("Card information") {
                    if ProcessInfo.processInfo.arguments.contains("report") {
                        Button("Project SEKAI") { selections += 1 }
                            .modifier(CardTagReportMenu(tag: "Project SEKAI", submitReport: { payload in
                                guard payload["tag_id"] == "tag-0001", payload["description"] == "Wrong colors" else {
                                    throw CardTagReportClient.Failure.invalidResponse
                                }
                                return "MEQR-20260907-ABCDEF"
                            }))
                        Text("Selections: \(selections)").accessibilityIdentifier("selections")
                    }
                    Text("Rebirth")
                    Text("Profile introduction\nSecond line\nThird line")
                    VStack(alignment: .leading, spacing: 8) {
                        CardTagReorderView(tags: tags, colorOverrides: Dictionary(uniqueKeysWithValues: tags.map {
                            ($0, CardTagColorOverride(textWeight: [CardTagTextWeight.regular, .medium, .bold][weightIndex]))
                        }), onReorder: { tags = $0 }, onRemove: { tag in tags.removeAll { $0 == tag } })
                        if ProcessInfo.processInfo.arguments.contains("weights") {
                            Button("Weight \(weightIndex)") { weightIndex = (weightIndex + 1) % 3 }
                                .accessibilityIdentifier("weight-cycle")
                        }
                        TextField("Tag", text: $draft).accessibilityIdentifier("draft")
                        Text("Bundled library - 2026.09.06.1").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section { Text("Tag colors").accessibilityIdentifier("following") }
                Section("Order") { Text(tags.joined(separator: "|" )).accessibilityIdentifier("order") }
            }
            .navigationTitle("Edit card")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: narrow ? 320 : .infinity)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("large") ? .accessibility1 : .large)
        .preferredColorScheme(.light)
    }
}
