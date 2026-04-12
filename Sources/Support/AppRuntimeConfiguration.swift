import Foundation

struct ManagedTranslationConnection {
    let baseURL: String
    let bearerToken: String?
}

enum RuntimeConfigurationError: LocalizedError {
    case missingManagedTranslationBaseURL

    var errorDescription: String? {
        switch self {
        case .missingManagedTranslationBaseURL:
            return "The app bundle is missing its managed translation service URL."
        }
    }
}

enum AppRuntimeConfiguration {
    private static let defaultBundleIdentifier = "com.circle2search.app"
    private static let managedTranslationBaseURLInfoKey = "ManagedTranslationBaseURL"
    private static let debugManagedTranslationBaseURL = "http://127.0.0.1:8080"

    static var allowsManagedTranslationDebugOverrides: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var keychainServiceName: String {
        bundleIdentifier
    }

    static var bundleIdentifier: String {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !bundleIdentifier.isEmpty
        else {
            return defaultBundleIdentifier
        }

        return bundleIdentifier
    }

    private static var bundledManagedTranslationBaseURL: String? {
        let baseURL = Bundle.main.object(forInfoDictionaryKey: managedTranslationBaseURLInfoKey) as? String
        let trimmedBaseURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedBaseURL?.isEmpty == false ? trimmedBaseURL : nil
    }

    @MainActor
    static func managedTranslationConnection(
        debugStore: ManagedTranslationDebugStore?
    ) throws -> ManagedTranslationConnection {
        #if DEBUG
        let baseURL = debugStore?.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBaseURL = (baseURL?.isEmpty == false ? baseURL : nil) ?? debugManagedTranslationBaseURL
        let bearerToken = debugStore?.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)

        return ManagedTranslationConnection(
            baseURL: resolvedBaseURL,
            bearerToken: bearerToken?.isEmpty == false ? bearerToken : nil
        )
        #else
        guard let bundledManagedTranslationBaseURL else {
            AppLogger.settings.error(
                "Missing \(managedTranslationBaseURLInfoKey) in the app bundle configuration."
            )
            throw RuntimeConfigurationError.missingManagedTranslationBaseURL
        }

        return ManagedTranslationConnection(
            baseURL: bundledManagedTranslationBaseURL,
            bearerToken: nil
        )
        #endif
    }
}
