import SwiftUI

/// Supported in-app language options
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }
}

/// Persists and publishes the user's language preference
@MainActor
@Observable
final class AppLanguageManager {
    static let shared = AppLanguageManager()

    private static let storageKey = "com.kapsel.appLanguage"

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale {
        selectedLanguage.locale
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        selectedLanguage = AppLanguage(rawValue: stored) ?? .system
    }

    func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: locale)
    }
}
