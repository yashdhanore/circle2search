import AppKit
import CoreGraphics
import Foundation
@preconcurrency import Vision

struct CapturedDisplaySnapshot {
    let displayID: CGDirectDisplayID
    let frameInScreenCoordinates: CGRect
    let pointPixelScale: CGFloat
    let image: CGImage

    func localRect(for normalizedVisionRect: CGRect) -> CGRect {
        let imageRect = VNImageRectForNormalizedRect(
            normalizedVisionRect,
            Int(image.width),
            Int(image.height)
        )
        let flippedY = CGFloat(image.height) - imageRect.maxY

        return CGRect(
            x: imageRect.minX / pointPixelScale,
            y: flippedY / pointPixelScale,
            width: imageRect.width / pointPixelScale,
            height: imageRect.height / pointPixelScale
        ).integral
    }

    func imageRect(for localRect: CGRect) -> CGRect {
        let imageRect = CGRect(
            x: localRect.minX * pointPixelScale,
            y: localRect.minY * pointPixelScale,
            width: localRect.width * pointPixelScale,
            height: localRect.height * pointPixelScale
        )

        let bounds = CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height
        )

        return imageRect.integral.intersection(bounds)
    }
}

struct RecognizedTextBlock: Identifiable, Sendable {
    let id: UUID
    let sourceText: String
    let confidence: Float
    let localRect: CGRect
    let imageRect: CGRect
}

struct TranslatedTextBlock: Identifiable, Sendable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let confidence: Float
    let localRect: CGRect
    let imageRect: CGRect
}

struct RenderableTranslationBlock: Identifiable {
    let id: UUID
    let translatedText: String
    let rect: CGRect
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    let maximumLineCount: Int
}

enum ScreenTranslationPhase: Equatable {
    case analyzing
    case ready
    case translating
    case translated
}

enum ScreenTranslationDisplayMode: Equatable {
    case original
    case translated
}

struct ScreenTranslationSession: Identifiable {
    let id = UUID()
    let snapshot: CapturedDisplaySnapshot
    var phase: ScreenTranslationPhase = .analyzing
    var displayMode: ScreenTranslationDisplayMode = .original
    var recognizedBlocks: [RecognizedTextBlock] = []
    var renderedBlocks: [RenderableTranslationBlock] = []
    var errorMessage: String?
    var queuedTranslateRequest = false

    var hasRecognizedText: Bool {
        !recognizedBlocks.isEmpty
    }

    var hasRenderedTranslation: Bool {
        !renderedBlocks.isEmpty
    }
}
