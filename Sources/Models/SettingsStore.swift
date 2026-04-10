import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var searchEngineTemplate: String {
        didSet { persist(searchEngineTemplate, for: Keys.searchEngineTemplate) }
    }

    var targetLanguage: String {
        didSet { persist(targetLanguage, for: Keys.targetLanguage) }
    }

    var translationProvider: TranslationProviderKind {
        didSet { persist(translationProvider.rawValue, for: Keys.translationProvider) }
    }

    var opperBaseURL: String {
        didSet { persist(opperBaseURL, for: Keys.opperBaseURL) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.searchEngineTemplate = defaults.string(forKey: Keys.searchEngineTemplate)
            ?? "https://www.google.com/search?q={query}"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage)
            ?? "English"
        self.translationProvider = TranslationProviderKind(
            rawValue: defaults.string(forKey: Keys.translationProvider) ?? ""
        ) ?? .opper
        self.opperBaseURL = defaults.string(forKey: Keys.opperBaseURL)
            ?? "https://api.opper.ai"
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let searchEngineTemplate = "settings.searchEngineTemplate"
        static let targetLanguage = "settings.targetLanguage"
        static let translationProvider = "settings.translationProvider"
        static let opperBaseURL = "settings.opperBaseURL"
    }

    private func persist(_ value: String, for key: String) {
        defaults.set(value, forKey: key)
    }
}
