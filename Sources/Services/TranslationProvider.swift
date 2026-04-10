import Foundation

struct TranslationRequest {
    let text: String
    let targetLanguage: String
}

struct TranslationResponse {
    let text: String
    let providerName: String
    let detectedSourceLanguage: String?
}

protocol TextTranslationProvider {
    var providerName: String { get }
    func translate(_ request: TranslationRequest) async throws -> TranslationResponse
}

struct OpperTranslationProvider: TextTranslationProvider {
    let baseURL: String
    let apiKey: String

    var providerName: String { "Opper" }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        guard let baseURL = URL(string: baseURL) else {
            throw TranslationProviderError.invalidBaseURL
        }

        let endpoint = baseURL
            .appendingPathComponent("v3")
            .appendingPathComponent("call")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(
            CallRequest(
                name: "circle_to_search_translate",
                instructions: """
                Translate the input text into \(request.targetLanguage).
                Preserve the tone and formatting where practical.
                Return only the translated text in the translation field.
                """,
                input: request.text
            )
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.invalidResponse("Opper did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            throw TranslationProviderError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: body
            )
        }

        let decoded = try JSONDecoder().decode(CallResponse.self, from: data)
        let payload = decoded.data ?? decoded.output

        guard let translation = payload?.translation, !translation.isEmpty else {
            throw TranslationProviderError.invalidResponse("Opper returned a response without translation text.")
        }

        return TranslationResponse(
            text: translation,
            providerName: providerName,
            detectedSourceLanguage: payload?.detectedSourceLanguage
        )
    }
}

enum TranslationProviderError: LocalizedError {
    case missingAPIKey(String)
    case invalidBaseURL
    case invalidResponse(String)
    case httpFailure(statusCode: Int, message: String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case let .missingAPIKey(message):
            return message
        case .invalidBaseURL:
            return "The configured Opper base URL is not valid."
        case let .invalidResponse(message):
            return message
        case let .httpFailure(statusCode, message):
            return "The translation provider returned HTTP \(statusCode): \(message)"
        case let .unsupported(message):
            return message
        }
    }
}

private struct CallRequest: Encodable {
    let name: String
    let instructions: String
    let input: String
    let outputSchema = OutputSchema()

    enum CodingKeys: String, CodingKey {
        case name
        case instructions
        case input
        case outputSchema = "output_schema"
    }
}

private struct OutputSchema: Encodable {
    let type = "object"
    let properties = [
        "translation": SchemaProperty(type: "string"),
        "detected_source_language": SchemaProperty(type: "string"),
    ]
    let required = ["translation"]
}

private struct SchemaProperty: Encodable {
    let type: String
}

private struct CallResponse: Decodable {
    let data: TranslationPayload?
    let output: TranslationPayload?
}

private struct TranslationPayload: Decodable {
    let translation: String?
    let detectedSourceLanguage: String?

    enum CodingKeys: String, CodingKey {
        case translation
        case detectedSourceLanguage = "detected_source_language"
    }
}
