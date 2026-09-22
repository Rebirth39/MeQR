import SwiftUI
import WebKit

struct AnnouncementBanner: View {
    @ObservedObject var manager: AnnouncementManager
    @State private var showing = false
    var body: some View {
        if let announcement = manager.latest {
            Button { showing = true } label: {
                HStack { Image(systemName: "bell.badge"); Text(announcement.localizedSummary).lineLimit(1).truncationMode(.tail); Spacer(); Image(systemName: "chevron.right") }
                    .font(.subheadline).padding(.horizontal, 14).frame(height: 52).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
            }.buttonStyle(.plain).sheet(isPresented: $showing) {
                NavigationStack {
                    AnnouncementWebView(url: announcement.url) { loaded in
                        if loaded { manager.markRead() }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(announcement.localizedTitle)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct AnnouncementWebView: UIViewRepresentable {
    let url: URL
    let onLoaded: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoaded: onLoaded) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        if Self.isTrusted(url) {
            view.load(URLRequest(url: url))
        } else {
            context.coordinator.loaded = false
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url == nil && Self.isTrusted(url) {
            view.load(URLRequest(url: url))
        }
    }

    static func isTrusted(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https",
              let host = url.host?.lowercased() else { return false }
        return host == "meqrcode.cn" || host.hasSuffix(".meqrcode.cn")
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoaded: (Bool) -> Void
        var loaded = false

        init(onLoaded: @escaping (Bool) -> Void) { self.onLoaded = onLoaded }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let target = navigationAction.request.url, !AnnouncementWebView.isTrusted(target) {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !loaded {
                loaded = true
                onLoaded(true)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoaded(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoaded(false)
        }
    }
}
