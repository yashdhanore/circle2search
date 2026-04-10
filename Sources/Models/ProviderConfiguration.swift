import Foundation

enum TranslationProviderKind: String, CaseIterable, Codable, Identifiable {
    case opper
    case appleTranslation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opper:
            return "Opper"
        case .appleTranslation:
            return "Apple Translation"
        }
    }

    var helperText: String {
        switch self {
        case .opper:
            return "Calls Opper directly with the user's API key."
        case .appleTranslation:
            return "Reserved for future local translation support."
        }
    }
}
