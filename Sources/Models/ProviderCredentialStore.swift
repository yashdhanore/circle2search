import Foundation
import Observation

@MainActor
@Observable
final class ProviderCredentialStore {
    var opperAPIKey: String {
        didSet {
            persistOpperAPIKey()
        }
    }

    var lastPersistenceError: String?

    private let keychainStore: KeychainStore
    private let opperAPIKeyAccount = "opper.api.key"

    init(keychainStore: KeychainStore) {
        self.keychainStore = keychainStore
        self.opperAPIKey = (try? keychainStore.string(for: opperAPIKeyAccount)) ?? ""
    }

    private func persistOpperAPIKey() {
        do {
            if opperAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try keychainStore.removeValue(for: opperAPIKeyAccount)
            } else {
                try keychainStore.set(opperAPIKey, for: opperAPIKeyAccount)
            }

            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
            AppLogger.app.error("Failed to persist Opper API key: \(error.localizedDescription)")
        }
    }
}
