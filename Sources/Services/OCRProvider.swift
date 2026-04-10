@preconcurrency import CoreGraphics
import Foundation
@preconcurrency import Vision

struct OCRLine: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct OCRResult: Sendable {
    let lines: [OCRLine]

    var combinedText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

protocol OCRProvider {
    func extractText(from image: CGImage) async throws -> OCRResult
}

struct VisionOCRProvider: OCRProvider {
    func extractText(from image: CGImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> OCRLine? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return OCRLine(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }

            return OCRResult(lines: lines)
        }.value
    }
}
