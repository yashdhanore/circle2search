import AppKit
import CoreGraphics
import Foundation
@preconcurrency import Vision

struct CapturedDisplaySnapshot {
    let displayID: CGDirectDisplayID
    let frameInScreenCoordinates: CGRect
    let visibleFrameInScreenCoordinates: CGRect
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

    var visibleContentLocalRect: CGRect {
        localRect(forScreenRect: visibleFrameInScreenCoordinates)
    }

    private func localRect(forScreenRect screenRect: CGRect) -> CGRect {
        let clampedRect = screenRect.intersection(frameInScreenCoordinates)

        guard !clampedRect.isNull else {
            return .null
        }

        return CGRect(
            x: clampedRect.minX - frameInScreenCoordinates.minX,
            y: frameInScreenCoordinates.maxY - clampedRect.maxY,
            width: clampedRect.width,
            height: clampedRect.height
        ).integral
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

enum ScreenTranslationScope: Equatable {
    case screen
    case selection
}

enum ScreenSelectionMode: Equatable {
    case rectangle
    case textCluster
}

struct ScreenSelection: Equatable {
    var rect: CGRect
    var mode: ScreenSelectionMode
}

struct SelectedTextContext {
    let blocks: [RecognizedTextBlock]
    let queryText: String
    let unionRect: CGRect
}

struct ScreenTranslationSession: Identifiable {
    let id = UUID()
    let snapshot: CapturedDisplaySnapshot
    var phase: ScreenTranslationPhase = .analyzing
    var displayMode: ScreenTranslationDisplayMode = .original
    var translationScope: ScreenTranslationScope?
    var selection: ScreenSelection?
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

    var hasSelection: Bool {
        selection != nil
    }
}
