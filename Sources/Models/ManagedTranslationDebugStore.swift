import Foundation
import Observation

@MainActor
@Observable
final class ManagedTranslationDebugStore {
    var baseURL: String {
        didSet {
            defaults.set(baseURL, forKey: Keys.baseURL)
        }
    }

    var bearerToken: String {
        didSet {
            persistBearerToken()
        }
    }

    var lastPersistenceError: String?

    private let defaults: UserDefaults
    private let keychainStore: KeychainStore

    private enum Keys {
        static let baseURL = "debug.managedTranslation.baseURL"
        static let bearerTokenAccount = "debug.managedTranslation.bearerToken"
    }

    init(
        defaults: UserDefaults = .standard,
        keychainStore: KeychainStore
    ) {
        self.defaults = defaults
        self.keychainStore = keychainStore
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? "http://127.0.0.1:8080"
        self.bearerToken = (try? keychainStore.string(for: Keys.bearerTokenAccount)) ?? ""
    }

    private func persistBearerToken() {
        do {
            let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedToken.isEmpty {
                try keychainStore.removeValue(for: Keys.bearerTokenAccount)
            } else {
                try keychainStore.set(trimmedToken, for: Keys.bearerTokenAccount)
            }

            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
            AppLogger.settings.error("Failed to persist debug bearer token: \(error.localizedDescription)")
        }
    }
}
