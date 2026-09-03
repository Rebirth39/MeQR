import SwiftUI
import WebKit

struct AnnouncementBanner: View {
    @ObservedObject var manager: AnnouncementManager
    @State private var showing = false
    var body: some View {
        if let announcement = manager.latest {
            Button { showing = true } label: {
                HStack { Image(systemName: "bell.badge"); Text(announcement.summary).lineLimit(2); Spacer(); Image(systemName: "chevron.right") }
                    .font(.subheadline).padding(.vertical, 16).padding(.horizontal, 16).frame(minHeight: 72).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
            }.buttonStyle(.plain).sheet(isPresented: $showing) { WebAnnouncementView(url: announcement.url).onDisappear { manager.markRead() } }
        }
    }
}
struct WebAnnouncementView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ view: WKWebView, context: Context) { if view.url == nil { view.load(URLRequest(url: url)) } }
}
