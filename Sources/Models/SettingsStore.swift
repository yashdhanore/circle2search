import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var searchEngineTemplate: String {
        didSet { persist(searchEngineTemplate, for: Keys.searchEngineTemplate) }
    }

    var targetLanguageCode: String {
        didSet { persist(targetLanguageCode, for: Keys.targetLanguageCode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.searchEngineTemplate = defaults.string(forKey: Keys.searchEngineTemplate)
            ?? "https://www.google.com/search?q={query}"
        let defaultLanguage = TranslationLanguage.english.rawValue
        self.targetLanguageCode = defaults.string(forKey: Keys.targetLanguageCode)
            ?? defaultLanguage
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let searchEngineTemplate = "settings.searchEngineTemplate"
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
