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

struct VisionOCRProvider: OCRProvider, Sendable {
    func extractText(from image: CGImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
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

            return OCRResult(observations: orderedObservations)
        }.value
    }
}
