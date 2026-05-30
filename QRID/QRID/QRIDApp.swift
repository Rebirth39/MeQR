import SwiftUI
import SwiftData

@main
struct QRIDApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: QRProfile.self)
    }
}
