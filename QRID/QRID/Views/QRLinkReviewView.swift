import SwiftUI

struct QRLinkReviewView: View {
    let content: String
    let onOpen: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let url = QRLinkPolicy.webURL(content) {
                    Section(L.qrDestination) { Text(url.host ?? "").textSelection(.enabled) }
                }
                Section(L.urlOrText) { Text(content).textSelection(.enabled) }
                Section { QRContentWarning(content: content, platform: QRLinkPolicy.platformID(content) ?? "custom") }
                Section { Text(L.qrReviewWarning).foregroundStyle(.secondary) }
            }
            .navigationTitle(L.qrReviewTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.cancel) { dismiss() } }
                if let url = QRLinkPolicy.webURL(content) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.qrOpen) { dismiss(); onOpen(url) }
                    }
                }
            }
        }
    }
}

struct QRContentWarning: View {
    let content: String
    let platform: String
    var body: some View {
        if let key = QRLinkPolicy.warningKey(content, platform: platform) {
            Label(key == "qrFormatWarning" ? L.qrFormatWarning : L.qrDestinationWarning, systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(.orange)
        }
        if platform == "qq" || platform == "wechat" {
            Text(L.qrOfficialImportHint).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
