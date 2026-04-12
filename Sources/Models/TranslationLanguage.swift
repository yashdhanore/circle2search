import Foundation

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case chineseSimplified = "zh-CN"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case finnish = "fi"
    case french = "fr"
    case german = "de"
    case hindi = "hi"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case norwegian = "no"
    case polish = "pl"
    case portuguese = "pt"
    case spanish = "es"
    case swedish = "sv"
    case turkish = "tr"
    case ukrainian = "uk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arabic: return "Arabic"
        case .chineseSimplified: return "Chinese (Simplified)"
        case .danish: return "Danish"
        case .dutch: return "Dutch"
        case .english: return "English"
        case .finnish: return "Finnish"
        case .french: return "French"
        case .german: return "German"
        case .hindi: return "Hindi"
        case .italian: return "Italian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .norwegian: return "Norwegian"
        case .polish: return "Polish"
        case .portuguese: return "Portuguese"
        case .spanish: return "Spanish"
        case .swedish: return "Swedish"
        case .turkish: return "Turkish"
        case .ukrainian: return "Ukrainian"
        }
    }

    static var fallback: TranslationLanguage { .english }

    static func from(languageCode: String) -> TranslationLanguage? {
        allCases.first { $0.rawValue.caseInsensitiveCompare(languageCode) == .orderedSame }
    }

    static func preferredDefault() -> TranslationLanguage {
        for identifier in Locale.preferredLanguages {
            let locale = Locale(identifier: identifier)
            if let languageCode = locale.language.languageCode?.identifier,
               let supported = from(languageCode: languageCode) {
                return supported
            }
        }

        return .fallback
    }
}
