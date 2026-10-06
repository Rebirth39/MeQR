import SwiftUI
import SwiftData

@main struct WindowHost: App {
    let container: ModelContainer
    init() {
        let schema = Schema([QRCluster.self, QRProfile.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        AppSettings.shared.selectedLanguage = .zhHans
        URLProtocol.registerClass(WindowTransport.self)
    }
    var body: some Scene { WindowGroup { WindowRoot().modelContainer(container).environment(\.appSettings, AppSettings.shared) } }
}
struct WindowRoot: View {
    @State private var page = 0
    @State private var width: CGFloat = 375
    @State private var height: CGFloat = 800
    let cluster: QRCluster
    let arguments = ProcessInfo.processInfo.arguments
    init() {
        let args = ProcessInfo.processInfo.arguments
        cluster = QRCluster(name: "Window audit", subtitle: "Window fixture introduction", backgroundColorHex: "#DDEEF5", qrColorHex: args.contains("mint") ? "#39C5BB" : "#000000", tagListRawValue: "世界计划\n初音未来\n夜鹿Yorushika")
        cluster.templateStyle = args.contains("standard") ? .standard : .rhodesPass
        if args.contains("background") { cluster.backgroundImageData = try! Data(contentsOf: Bundle.main.url(forResource: "BG", withExtension: "jpg")!) }
        cluster.profiles = [QRProfile(platformType: "qq", qrContent: "https://qm.qq.com/q/lNrSSk9uFy"), QRProfile(platformType: "wechat", qrContent: "https://u.wechat.com/fixture"), QRProfile(platformType: "github", qrContent: "https://github.com/fixture")]
    }
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach([320,375,480,520,620,800,900], id: \.self) { w in
                    Button("W\(w)") { width = CGFloat(w) }
                }
                Button("Tall") { height = 800 }
                Button("Short") { height = 320 }
            }.font(.caption)
            Text("requested=\(Int(width))x\(Int(height))")
                .accessibilityIdentifier("fixture-size")
            Group {
                if arguments.contains("exchange") {
                    MeQRProfileCodeView(cluster: cluster)
                } else {
                    ClusterCardPager(clusters: [cluster], currentPage: $page) { _ in }
                }
            }
            .frame(width: width, height: height)
            .environment(\.horizontalSizeClass, arguments.contains("compact") ? .compact : .regular)
            .dynamicTypeSize(arguments.contains("large") ? .accessibility3 : .large)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("viewport")
            Spacer(minLength: 0)
        }
    }
}
final class WindowTransport: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
