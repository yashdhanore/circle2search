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
            let labels = prioritizedLabels(from: observations)

            guard !labels.isEmpty else {
                throw VisualQueryError.noRecognizedSubject
            }

            AppLogger.app.info(
                "Vision image classification produced \(labels.count) search label(s): \(labels.joined(separator: ", "))"
            )

            return VisualQueryResult(labels: labels)
        }.value
    }

    private func prioritizedLabels(from observations: [VNClassificationObservation]) -> [String] {
        let suppressedLabels: Set<String> = [
            "screenshot",
            "web site",
            "website",
            "font",
            "display",
            "electronic device",
            "graphic design",
            "text",
            "screen",
            "monitor",
            "television"
        ]

        let candidates = observations.compactMap { observation -> (String, Float)? in
            let normalizedLabel = observation.identifier
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedLabel.isEmpty else {
                return nil
            }

            let dedupeKey = normalizedLabel.lowercased()
            guard !suppressedLabels.contains(dedupeKey) else {
                return nil
            }

            return (normalizedLabel, observation.confidence)
        }

        var labels: [String] = []
        var seenLabels = Set<String>()

        for minimumConfidence in [Float(0.16), Float(0.1), Float(0.06)] {
            for (label, confidence) in candidates where confidence >= minimumConfidence {
                let dedupeKey = label.lowercased()
                guard seenLabels.insert(dedupeKey).inserted else {
                    continue
                }

                labels.append(label)

                if labels.count == 3 {
                    return labels
                }
            }
        }

        return labels
    }
}
