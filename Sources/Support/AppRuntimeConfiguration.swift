import Foundation

struct ManagedTranslationConnection {
    let baseURL: String
    let bearerToken: String?
}

enum AppRuntimeConfiguration {
    private static let productionManagedTranslationBaseURL = "https://translate.circle2search.app"
    private static let debugManagedTranslationBaseURL = "http://127.0.0.1:8080"

    static var allowsManagedTranslationDebugOverrides: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    @MainActor
    static func managedTranslationConnection(
        debugStore: ManagedTranslationDebugStore?
    ) -> ManagedTranslationConnection {
        #if DEBUG
        let baseURL = debugStore?.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBaseURL = (baseURL?.isEmpty == false ? baseURL : nil) ?? debugManagedTranslationBaseURL
        let bearerToken = debugStore?.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)

        return ManagedTranslationConnection(
            baseURL: resolvedBaseURL,
            bearerToken: bearerToken?.isEmpty == false ? bearerToken : nil
        )
        #else
        return ManagedTranslationConnection(
            baseURL: productionManagedTranslationBaseURL,
            bearerToken: nil
        )
        #endif
    }
}
