import AppKit
import Foundation

struct SearchService {
    func search(query: String, template: String) throws {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw SearchServiceError.emptyQuery
        }

        guard template.contains("{query}") else {
            throw SearchServiceError.invalidTemplate("The search template must contain a {query} token.")
        }

        guard let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw SearchServiceError.invalidQueryEncoding
        }

        let resolvedURLString = template.replacingOccurrences(of: "{query}", with: encodedQuery)

        guard let url = URL(string: resolvedURLString) else {
            throw SearchServiceError.invalidTemplate("The configured search template did not produce a valid URL.")
        }

        NSWorkspace.shared.open(url)
    }
}

enum SearchServiceError: LocalizedError {
    case emptyQuery
    case invalidQueryEncoding
    case invalidTemplate(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "There is no text available to search."
        case .invalidQueryEncoding:
            return "The selected text could not be encoded for a URL query."
        case let .invalidTemplate(message):
            return message
        }
    }
}
