import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var targetLanguageCode: String {
        didSet { persist(targetLanguageCode, for: Keys.targetLanguageCode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultLanguage = TranslationLanguage.english.rawValue
        self.targetLanguageCode = defaults.string(forKey: Keys.targetLanguageCode)
            ?? defaultLanguage
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let targetLanguageCode = "settings.targetLanguageCode"
    }

    private func persist(_ value: String, for key: String) {
        defaults.set(value, forKey: key)
    }

    var targetLanguage: TranslationLanguage {
        get {
            TranslationLanguage.from(languageCode: targetLanguageCode) ?? .fallback
        }
        set {
            targetLanguageCode = newValue.rawValue
        }
    }
}
