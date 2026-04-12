import Foundation

struct TranslationRequest {
    let text: String
    let targetLanguageCode: String
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
    let targetLanguageCode: String
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
    func translateBatch(_ request: BatchTranslationRequest) async throws -> BatchTranslationResponse
}

struct ManagedTranslationProvider: TextTranslationProvider {
    let baseURL: String
    let authorization: ManagedTranslationAuthorization?

    var providerName: String { "Google Cloud NMT" }

    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let batchResponse = try await translateBatch(
            BatchTranslationRequest(
                items: [BatchTranslationItem(id: UUID(), text: request.text)],
                targetLanguageCode: request.targetLanguageCode
            )
        )

        guard let item = batchResponse.items.first else {
            throw TranslationProviderError.invalidResponse(
                "The managed translation service returned no translated items."
            )
        }

        return TranslationResponse(
            text: item.text,
            providerName: batchResponse.providerName,
            detectedSourceLanguage: item.detectedSourceLanguage
        )
    }

    func translateBatch(_ request: BatchTranslationRequest) async throws -> BatchTranslationResponse {
        guard let endpoint = endpointURL else {
            throw TranslationProviderError.invalidBaseURL
        }

        guard authorization != nil else {
            throw TranslationProviderError.missingAuthorization
        }

        let requestBlocks = request.items.compactMap { item -> ManagedTranslationRequestBlock? in
            let trimmedText = item.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedText.isEmpty else {
                return nil
            }

            return ManagedTranslationRequestBlock(
                id: item.id.uuidString,
                text: trimmedText
            )
        }

        guard !requestBlocks.isEmpty else {
            return BatchTranslationResponse(items: [], providerName: providerName)
        }

        AppLogger.translation.info(
            "Submitting managed translation request for \(requestBlocks.count) block(s) to \(endpoint.absoluteString)."
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch authorization {
        case let .bearerToken(appToken):
            urlRequest.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        case let .appStoreReceipt(receipt):
            urlRequest.setValue(receipt, forHTTPHeaderField: "X-Circle-To-Search-App-Receipt")
        case nil:
            break
        }

        urlRequest.httpBody = try JSONEncoder().encode(
            ManagedTranslationRequestPayload(
                targetLanguageCode: request.targetLanguageCode,
                sourceLanguageCode: nil,
                blocks: requestBlocks
            )
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let payload = try parsePayload(from: data, response: response)

        let translatedItems = payload.blocks.compactMap { block -> BatchTranslationResponseItem? in
            guard
                let id = UUID(uuidString: block.id),
                let translatedText = block.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                !translatedText.isEmpty
            else {
                return nil
            }

            return BatchTranslationResponseItem(
                id: id,
                text: translatedText,
                detectedSourceLanguage: block.detectedSourceLanguage
            )
        }

        AppLogger.translation.info(
            "Managed translation completed with \(translatedItems.count) translated block(s)."
        )

        return BatchTranslationResponse(
            items: translatedItems,
            providerName: payload.provider ?? providerName
        )
    }

    private var endpointURL: URL? {
        guard let baseURL = URL(string: baseURL) else {
            return nil
        }

        return baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("translate-screen")
    }

    private func parsePayload(
        from data: Data,
        response: URLResponse
    ) throws -> ManagedTranslationResponsePayload {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.invalidResponse(
                "The managed translation service did not return an HTTP response."
            )
        }

        let decoder = JSONDecoder()

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(ManagedTranslationErrorEnvelope.self, from: data) {
                AppLogger.translation.error(
                    "Managed translation backend returned HTTP \(httpResponse.statusCode): \(apiError.error.message)"
                )
                throw TranslationProviderError.httpFailure(
                    statusCode: httpResponse.statusCode,
                    message: apiError.error.message
                )
            }

            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            AppLogger.translation.error(
                "Managed translation backend returned HTTP \(httpResponse.statusCode): \(body)"
            )
            throw TranslationProviderError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: body
            )
        }

        do {
            return try decoder.decode(ManagedTranslationResponsePayload.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            AppLogger.translation.error(
                "Failed to decode managed translation response body: \(body)"
            )
            throw TranslationProviderError.invalidResponse(
                "The managed translation service returned an unexpected response."
            )
        }
    }
}

enum TranslationProviderError: LocalizedError {
    case invalidBaseURL
    case missingAuthorization
    case invalidResponse(String)
    case httpFailure(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The managed translation service URL is not valid."
        case .missingAuthorization:
            return "The managed translation service is not authorized. In debug builds, configure the debug bearer token or test with an App Store receipt-backed build."
        case let .invalidResponse(message):
            return message
        case let .httpFailure(statusCode, message):
            return "The translation service returned HTTP \(statusCode): \(message)"
        }
    }
}

private struct ManagedTranslationRequestPayload: Encodable {
    let targetLanguageCode: String
    let sourceLanguageCode: String?
    let blocks: [ManagedTranslationRequestBlock]
}

private struct ManagedTranslationRequestBlock: Encodable {
    let id: String
    let text: String
}

private struct ManagedTranslationResponsePayload: Decodable {
    let provider: String?
    let region: String?
    let blocks: [ManagedTranslationResponseBlock]
}

private struct ManagedTranslationResponseBlock: Decodable {
    let id: String
    let translatedText: String?
    let detectedSourceLanguage: String?
}

private struct ManagedTranslationErrorEnvelope: Decodable {
    let error: ManagedTranslationAPIError
}

private struct ManagedTranslationAPIError: Decodable {
    let code: String
    let message: String
}
