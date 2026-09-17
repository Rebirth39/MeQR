import SwiftUI
import WebKit

struct AnnouncementBanner: View {
    @ObservedObject var manager: AnnouncementManager
    @State private var showing = false
    var body: some View {
        if let announcement = manager.latest {
            Button { showing = true } label: {
                HStack { Image(systemName: "bell.badge"); Text(announcement.summary).lineLimit(1).truncationMode(.tail); Spacer(); Image(systemName: "chevron.right") }
                    .font(.subheadline).padding(.horizontal, 14).frame(height: 52).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
            }.buttonStyle(.plain).sheet(isPresented: $showing) { NavigationStack { WebAnnouncementView(url: announcement.url).ignoresSafeArea(edges: .bottom) }.presentationDetents([.medium, .large]).onDisappear { manager.markRead() } }
        }
    }
}
struct WebAnnouncementView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ view: WKWebView, context: Context) { if view.url == nil { view.load(URLRequest(url: url)) } }
}
