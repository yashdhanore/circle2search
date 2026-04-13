import Foundation

struct ManagedTranslationConnection {
    let baseURL: String
    let authorization: ManagedTranslationAuthorization?
}

enum ManagedTranslationAuthorization {
    case bearerToken(String)
    case appStoreReceipt(String)
}

enum RuntimeConfigurationError: LocalizedError {
    case missingManagedTranslationBaseURL
    case missingAppStoreReceipt
    case unreadableAppStoreReceipt(String)

    var errorDescription: String? {
        switch self {
        case .missingManagedTranslationBaseURL:
            return "The app bundle is missing its managed translation service URL."
        case .missingAppStoreReceipt:
            return "The release app is missing its App Store receipt."
        case let .unreadableAppStoreReceipt(message):
            return "The App Store receipt could not be loaded: \(message)"
        }
    }
}

enum AppRuntimeConfiguration {
    private static let defaultBundleIdentifier = "com.circle2search.app"
    private static let managedTranslationBaseURLInfoKey = "ManagedTranslationBaseURL"
    private static let managedTranslationAllowsUserConfigurationInfoKey = "ManagedTranslationAllowsUserConfiguration"
    private static let debugManagedTranslationBaseURL = "http://127.0.0.1:8080"

    static var allowsManagedTranslationUserConfiguration: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: managedTranslationAllowsUserConfigurationInfoKey)

        switch value {
        case let bool as Bool:
            return bool
        case let string as String:
            return ["1", "true", "yes"].contains(string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        default:
            return false
        }
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
        debugStore: ManagedTranslationDebugStore?,
        appStoreReceiptProvider: AppStoreReceiptProvider = AppStoreReceiptProvider()
    ) throws -> ManagedTranslationConnection {
        if allowsManagedTranslationUserConfiguration {
            let defaultBaseURL = bundledManagedTranslationBaseURL ?? debugManagedTranslationBaseURL
            let baseURL = debugStore?.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedBaseURL = (baseURL?.isEmpty == false ? baseURL : nil) ?? defaultBaseURL
            let bearerToken = debugStore?.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let authorization: ManagedTranslationAuthorization?

            if let bearerToken, !bearerToken.isEmpty {
                authorization = .bearerToken(bearerToken)
            } else {
                authorization = nil
            }

            return ManagedTranslationConnection(
                baseURL: resolvedBaseURL,
                authorization: authorization
            )
        }

        guard let bundledManagedTranslationBaseURL else {
            AppLogger.settings.error(
                "Missing \(managedTranslationBaseURLInfoKey) in the app bundle configuration."
            )
            throw RuntimeConfigurationError.missingManagedTranslationBaseURL
        }

        let receipt: String
        do {
            receipt = try appStoreReceiptProvider.base64EncodedReceipt()
        } catch AppStoreReceiptError.missingReceiptURL {
            AppLogger.settings.error("The release app is missing its App Store receipt.")
            throw RuntimeConfigurationError.missingAppStoreReceipt
        } catch let AppStoreReceiptError.unreadableReceipt(message) {
            AppLogger.settings.error("The App Store receipt could not be read: \(message)")
            throw RuntimeConfigurationError.unreadableAppStoreReceipt(message)
        } catch AppStoreReceiptError.emptyReceipt {
            AppLogger.settings.error("The release app contains an empty App Store receipt.")
            throw RuntimeConfigurationError.unreadableAppStoreReceipt("The receipt file is empty.")
        } catch {
            AppLogger.settings.error("Unexpected App Store receipt error: \(error.localizedDescription)")
            throw RuntimeConfigurationError.unreadableAppStoreReceipt(error.localizedDescription)
        }

        return ManagedTranslationConnection(
            baseURL: bundledManagedTranslationBaseURL,
            authorization: .appStoreReceipt(receipt)
        )
    }
}
