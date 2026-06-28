import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case zhHantHK
    case zhHantTW
    case en
    case ja

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            let resolved = AppLanguage.preferredSystemLanguage()
            return "\(L.followSystem)（\(resolved.displayName)）"
        case .zhHans: return "简体中文"
        case .zhHantHK: return "繁體中文（香港）"
        case .zhHantTW: return "繁體中文（台灣）"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    static func preferredSystemLanguage() -> AppLanguage {
        for identifier in Locale.preferredLanguages {
            if let language = language(matching: identifier) {
                return language
            }
        }
        return .en
    }

    private static func language(matching identifier: String) -> AppLanguage? {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized.hasPrefix("en") {
            return .en
        }
        if normalized.hasPrefix("ja") {
            return .ja
        }
        if normalized.hasPrefix("zh") {
            if normalized.contains("hans") {
                return .zhHans
            }
            if normalized.contains("hant") {
                if normalized.contains("-tw") {
                    return .zhHantTW
                }
                return .zhHantHK
            }
            if normalized.contains("-hk") || normalized.contains("-mo") {
                return .zhHantHK
            }
            if normalized.contains("-tw") {
                return .zhHantTW
            }
            return .zhHans
        }
        return nil
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app_language")
        }
    }

    var selectedLanguage: AppLanguage {
        get {
            AppLanguage(rawValue: language) ?? .system
        }
        set {
            language = newValue.rawValue
        }
    }

    var resolvedLanguage: AppLanguage {
        selectedLanguage == .system ? AppLanguage.preferredSystemLanguage() : selectedLanguage
    }

    var isChinese: Bool {
        switch resolvedLanguage {
        case .zhHans, .zhHantHK, .zhHantTW:
            return true
        case .system, .en, .ja:
            return false
        }
    }

    func toggleLanguage() {
        selectedLanguage = resolvedLanguage == .en ? .zhHans : .en
    }

    private init() {
        language = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
    }
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
