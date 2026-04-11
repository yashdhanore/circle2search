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

struct BatchTranslationItem: Identifiable, Sendable {
    let id: UUID
    let text: String
}

struct BatchTranslationRequest: Sendable {
    let items: [BatchTranslationItem]
    let targetLanguage: String
}

struct BatchTranslationResponseItem: Identifiable, Sendable {
    let id: UUID
    let text: String
    let detectedSourceLanguage: String?
}

struct BatchTranslationResponse: Sendable {
    let items: [BatchTranslationResponseItem]
    let providerName: String
}

protocol TextTranslationProvider {
    var providerName: String { get }
    func translate(_ request: TranslationRequest) async throws -> TranslationResponse
}

extension TextTranslationProvider {
    func translateBatch(_ request: BatchTranslationRequest) async throws -> BatchTranslationResponse {
        var translatedItems: [BatchTranslationResponseItem] = []
        translatedItems.reserveCapacity(request.items.count)

        for item in request.items {
            let response = try await translate(
                TranslationRequest(
                    text: item.text,
                    targetLanguage: request.targetLanguage
                )
            )

            translatedItems.append(
                BatchTranslationResponseItem(
                    id: item.id,
                    text: response.text,
                    detectedSourceLanguage: response.detectedSourceLanguage
                )
            )
        }

        return BatchTranslationResponse(
            items: translatedItems,
            providerName: providerName
        )
    }
}

struct OpperTranslationProvider: TextTranslationProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    var providerName: String { "Opper" }
    private let preferredBatchSize = 16

    func translateBatch(_ request: BatchTranslationRequest) async throws -> BatchTranslationResponse {
        let chunks = request.items.chunked(into: preferredBatchSize)
        var allItems: [BatchTranslationResponseItem] = []
        allItems.reserveCapacity(request.items.count)

        for (index, chunk) in chunks.enumerated() {
            AppLogger.translation.info(
                "Submitting Opper translation chunk \(index + 1)/\(chunks.count) with \(chunk.count) block(s) using model \(model)."
            )

            let translatedChunk = try await executeBatchChunk(
                items: chunk,
                targetLanguage: request.targetLanguage
            )
            allItems.append(contentsOf: translatedChunk)
        }

        AppLogger.translation.info(
            "Completed batched Opper translation with \(allItems.count) translated block(s)."
        )

        return BatchTranslationResponse(
            items: allItems,
            providerName: providerName
        )
    }

    private func executeBatchChunk(
        items: [BatchTranslationItem],
        targetLanguage: String
    ) async throws -> [BatchTranslationResponseItem] {
        do {
            return try await performBatchChunk(
                items: items,
                targetLanguage: targetLanguage
            )
        } catch let error as TranslationProviderError {
            if case let .httpFailure(statusCode, _) = error, statusCode == 500, items.count > 1 {
                let midpoint = items.count / 2
                let leftItems = Array(items[..<midpoint])
                let rightItems = Array(items[midpoint...])

                AppLogger.translation.error(
                    "Opper returned HTTP 500 for \(items.count) block(s). Retrying smaller chunks: \(leftItems.count) and \(rightItems.count)."
                )

                let leftResult = try await executeBatchChunk(
                    items: leftItems,
                    targetLanguage: targetLanguage
                )
                let rightResult = try await executeBatchChunk(
                    items: rightItems,
                    targetLanguage: targetLanguage
                )

                return leftResult + rightResult
            }

            throw error
        }
    }

    private func performBatchChunk(
        items: [BatchTranslationItem],
        targetLanguage: String
    ) async throws -> [BatchTranslationResponseItem] {
        guard let baseURL = URL(string: baseURL) else {
            throw TranslationProviderError.invalidBaseURL
        }

        let endpoint = baseURL
            .appendingPathComponent("v3")
            .appendingPathComponent("call")

        AppLogger.translation.info(
            "Submitting batched Opper translation request for \(items.count) block(s)."
        )
        AppLogger.translation.debug("Opper batch endpoint: \(endpoint.absoluteString)")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(
            BatchCallRequest(
                name: "circle_to_search_translate_batch",
                model: model,
                instructions: """
                Translate each item's text into \(targetLanguage).
                Return one translation result per input item.
                Preserve each item's id exactly as provided.
                Keep the same ordering when practical.
                Return only the translated text for each item.
                """,
                input: BatchInput(
                    items: items.map { item in
                        BatchInputItem(
                            id: item.id.uuidString,
                            text: item.text
                        )
                    }
                )
            )
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let payload = try parsePayload(from: data, response: response)

        guard let translations = payload?.batchTranslations?.translations, !translations.isEmpty else {
            throw TranslationProviderError.invalidResponse(
                "Opper returned a response without translation items."
            )
        }

        let translationItems = translations.compactMap { item -> BatchTranslationResponseItem? in
            guard
                let uuid = UUID(uuidString: item.id),
                let text = item.translation?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                !text.isEmpty
            else {
                return nil
            }

            return BatchTranslationResponseItem(
                id: uuid,
                text: text,
                detectedSourceLanguage: item.detectedSourceLanguage
            )
        }

        AppLogger.translation.info(
            "Completed batched Opper translation request with \(translationItems.count) translated block(s)."
        )

        return translationItems
    }

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
                model: model,
                instructions: """
                Translate the input text into \(request.targetLanguage).
                Preserve the tone and formatting where practical.
                Return only the translated text in the translation field.
                """,
                input: request.text
            )
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let payload = try parsePayload(from: data, response: response)

        guard let translation = payload?.translation, !translation.isEmpty else {
            throw TranslationProviderError.invalidResponse("Opper returned a response without translation text.")
        }

        return TranslationResponse(
            text: translation,
            providerName: providerName,
            detectedSourceLanguage: payload?.detectedSourceLanguage
        )
    }

    private func parsePayload(
        from data: Data,
        response: URLResponse
    ) throws -> TranslationPayload? {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.invalidResponse("Opper did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            AppLogger.translation.error(
                "Opper returned HTTP \(httpResponse.statusCode) with body: \(body)"
            )
            throw TranslationProviderError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: body
            )
        }

        let decoded = try JSONDecoder().decode(CallResponse.self, from: data)
        AppLogger.translation.debug("Decoded Opper response successfully.")
        return decoded.data ?? decoded.output
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return isEmpty ? [] : [self]
        }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }

        return chunks
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
    let model: String
    let instructions: String
    let input: String
    let outputSchema = OutputSchema()

    enum CodingKeys: String, CodingKey {
        case name
        case model
        case instructions
        case input
        case outputSchema = "output_schema"
    }
}

private struct BatchCallRequest: Encodable {
    let name: String
    let model: String
    let instructions: String
    let inputSchema = BatchInputSchema()
    let outputSchema = BatchOutputSchema()
    let input: BatchInput

    enum CodingKeys: String, CodingKey {
        case name
        case model
        case instructions
        case inputSchema = "input_schema"
        case outputSchema = "output_schema"
        case input
    }
}

private struct BatchInput: Encodable {
    let items: [BatchInputItem]
}

private struct BatchInputItem: Encodable {
    let id: String
    let text: String
}

private struct OutputSchema: Encodable {
    let type = "object"
    let properties = [
        "translation": SchemaProperty(type: "string"),
        "detected_source_language": SchemaProperty(type: "string"),
    ]
    let required = ["translation"]
}

private struct BatchInputSchema: Encodable {
    let type = "object"
    let properties = [
        "items": SchemaProperty(
            type: "array",
            description: "Ordered items to translate",
            items: SchemaItems(
                type: "object",
                properties: [
                    "id": SchemaProperty(type: "string", description: "Stable input item id"),
                    "text": SchemaProperty(type: "string", description: "Input text to translate"),
                ],
                required: ["id", "text"]
            )
        ),
    ]
    let required = ["items"]
}

private struct BatchOutputSchema: Encodable {
    let type = "object"
    let properties = [
        "translations": SchemaProperty(
            type: "array",
            description: "Translated results keyed by original item id",
            items: SchemaItems(
                type: "object",
                properties: [
                    "id": SchemaProperty(type: "string", description: "Original input item id"),
                    "translation": SchemaProperty(type: "string", description: "Translated text"),
                    "detected_source_language": SchemaProperty(type: "string"),
                ],
                required: ["id", "translation"]
            )
        ),
    ]
    let required = ["translations"]
}

private struct SchemaProperty: Encodable {
    let type: String
    let description: String?
    let items: SchemaItems?

    init(
        type: String,
        description: String? = nil,
        items: SchemaItems? = nil
    ) {
        self.type = type
        self.description = description
        self.items = items
    }
}

private struct SchemaItems: Encodable {
    let type: String
    let properties: [String: SchemaProperty]?
    let required: [String]?

    init(
        type: String,
        properties: [String: SchemaProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

private struct CallResponse: Decodable {
    let data: TranslationPayload?
    let output: TranslationPayload?
}

private struct TranslationPayload: Decodable {
    let translation: String?
    let detectedSourceLanguage: String?
    let batchTranslations: BatchTranslationsPayload?

    enum CodingKeys: String, CodingKey {
        case translation
        case detectedSourceLanguage = "detected_source_language"
        case batchTranslations = "translations"
    }
}

private struct BatchTranslationsPayload: Decodable {
    let translations: [BatchTranslationPayload]

    init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()

        if let directArray = try? singleValueContainer.decode([BatchTranslationPayload].self) {
            self.translations = directArray
        } else {
            self.translations = []
        }
    }
}

private struct BatchTranslationPayload: Decodable {
    let id: String
    let translation: String?
    let detectedSourceLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case translation
        case detectedSourceLanguage = "detected_source_language"
    }
}
