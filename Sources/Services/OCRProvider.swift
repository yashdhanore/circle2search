@preconcurrency import CoreGraphics
import Foundation
@preconcurrency import Vision

struct OCRObservation: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let confidence: Float
    let normalizedBoundingBox: CGRect
}

struct OCRResult: Sendable {
    let observations: [OCRObservation]

    var combinedText: String {
        observations.map(\.text).joined(separator: "\n")
    }
}

protocol OCRProvider: Sendable {
    func extractText(from image: CGImage) async throws -> OCRResult
}

struct VisualQueryResult: Sendable {
    let labels: [String]

    var query: String {
        labels.joined(separator: " ")
    }
}

protocol VisualQueryProvider: Sendable {
    func makeQuery(from image: CGImage) async throws -> VisualQueryResult
}

enum VisualQueryError: LocalizedError {
    case noRecognizedSubject

    var errorDescription: String? {
        switch self {
        case .noRecognizedSubject:
            return "The selected image could not be identified well enough to search."
        }
    }
}

struct VisionOCRProvider: OCRProvider, Sendable {
    func extractText(from image: CGImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            AppLogger.ocr.info(
                "Starting Vision OCR for image \(image.width)x\(image.height)."
            )
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            let extractedObservations = observations.compactMap { observation -> OCRObservation? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                let rawText = candidate.string
                let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedText.isEmpty else {
                    return nil
                }

                let normalizedBoundingBox: CGRect
                let fullRange = rawText.startIndex..<rawText.endIndex

                if let preciseBoundingBox = try? candidate.boundingBox(for: fullRange) {
                    normalizedBoundingBox = preciseBoundingBox.boundingBox
                } else {
                    normalizedBoundingBox = observation.boundingBox
                }

                return OCRObservation(
                    text: trimmedText,
                    confidence: candidate.confidence,
                    normalizedBoundingBox: normalizedBoundingBox
                )
            }

            let orderedObservations = extractedObservations.sorted { lhs, rhs in
                let verticalDelta = abs(lhs.normalizedBoundingBox.maxY - rhs.normalizedBoundingBox.maxY)

                if verticalDelta > 0.02 {
                    return lhs.normalizedBoundingBox.maxY > rhs.normalizedBoundingBox.maxY
                }

                return lhs.normalizedBoundingBox.minX < rhs.normalizedBoundingBox.minX
            }

            AppLogger.ocr.info(
                "Vision OCR completed with \(orderedObservations.count) ordered observation(s)."
            )

            return OCRResult(observations: orderedObservations)
        }.value
    }
}

struct VisionVisualQueryProvider: VisualQueryProvider, Sendable {
    func makeQuery(from image: CGImage) async throws -> VisualQueryResult {
        try await Task.detached(priority: .userInitiated) {
            AppLogger.app.info(
                "Starting Vision image classification for crop \(image.width)x\(image.height)."
            )

            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            var labels: [String] = []
            var seenLabels = Set<String>()

            for observation in observations {
                guard observation.confidence >= 0.08 else {
                    continue
                }

                let normalizedLabel = observation.identifier
                    .replacingOccurrences(of: "_", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !normalizedLabel.isEmpty else {
                    continue
                }

                let dedupeKey = normalizedLabel.lowercased()
                guard seenLabels.insert(dedupeKey).inserted else {
                    continue
                }

                labels.append(normalizedLabel)

                if labels.count == 4 {
                    break
                }
            }

            guard !labels.isEmpty else {
                throw VisualQueryError.noRecognizedSubject
            }

            AppLogger.app.info(
                "Vision image classification produced \(labels.count) search label(s): \(labels.joined(separator: ", "))"
            )

            return VisualQueryResult(labels: labels)
        }.value
    }
}
