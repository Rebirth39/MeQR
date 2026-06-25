import Foundation
import SwiftUI

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: String {
        get {
            UserDefaults.standard.string(forKey: "app_language") ?? "zh"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "app_language")
        }
    }

    var isChinese: Bool { language == "zh" }

    func toggleLanguage() {
        language = isChinese ? "en" : "zh"
    }

    var iCloudSyncEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "icloud_sync_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "icloud_sync_enabled")
        }
    }

    private init() {}
}

struct SettingsEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppSettings.shared
}

extension EnvironmentValues {
    var appSettings: AppSettings {
        get { self[SettingsEnvironmentKey.self] }
        set { self[SettingsEnvironmentKey.self] = newValue }
    }
}
