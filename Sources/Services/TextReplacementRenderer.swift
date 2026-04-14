import AppKit
import CoreGraphics
import Foundation

struct TextReplacementRenderer {
    func render(
        snapshot: CapturedDisplaySnapshot,
        translatedBlocks: [TranslatedTextBlock],
        clipRect: CGRect? = nil
    ) -> [RenderableTranslationBlock] {
        translatedBlocks.compactMap { block in
            let trimmedTranslation = block.translatedText
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                !trimmedTranslation.isEmpty,
                block.localRect.width >= 18,
                block.localRect.height >= 10
            else {
                return nil
            }

            let horizontalPadding = max(4, min(block.localRect.width * 0.08, 14))
            let verticalPadding = max(2, min(block.localRect.height * 0.2, 8))
            let unclippedRect = block.localRect
                .insetBy(dx: -horizontalPadding, dy: -verticalPadding)
                .integral
            let renderRect = clipRect.map { unclippedRect.intersection($0).integral } ?? unclippedRect

            guard
                !renderRect.isNull,
                renderRect.width >= 16,
                renderRect.height >= 10
            else {
                return nil
            }

            let backgroundColor = averageBackgroundColor(
                in: snapshot.imageRect(for: renderRect),
                from: snapshot.image
            ) ?? NSColor(calibratedWhite: 0.95, alpha: 0.98)

            let resolvedBackgroundColor = backgroundColor.withAlphaComponent(0.98)
            let foregroundColor = preferredForegroundColor(for: resolvedBackgroundColor)
            let fontSize = max(12, min(block.localRect.height * 0.78, 36))
            let maximumLineCount = max(1, Int((renderRect.height / max(fontSize * 1.12, 1)).rounded(.up)))
            let cornerRadius = min(12, max(4, renderRect.height * 0.24))
            let resolvedHorizontalPadding = min(horizontalPadding, max(3, renderRect.width * 0.14))
            let resolvedVerticalPadding = min(verticalPadding, max(2, renderRect.height * 0.18))

            return RenderableTranslationBlock(
                id: block.id,
                translatedText: trimmedTranslation,
                rect: renderRect,
                backgroundColor: resolvedBackgroundColor,
                foregroundColor: foregroundColor,
                fontSize: fontSize,
                horizontalPadding: resolvedHorizontalPadding,
                verticalPadding: resolvedVerticalPadding,
                cornerRadius: cornerRadius,
                maximumLineCount: maximumLineCount
            )
        }
    }

    private func averageBackgroundColor(
        in imageRect: CGRect,
        from image: CGImage
    ) -> NSColor? {
        guard let croppedImage = image.cropping(to: imageRect) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)

        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return NSColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: CGFloat(pixel[3]) / 255
        )
    }

    private func preferredForegroundColor(for backgroundColor: NSColor) -> NSColor {
        let resolvedColor = backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor
        let luminance = (0.2126 * resolvedColor.redComponent)
            + (0.7152 * resolvedColor.greenComponent)
            + (0.0722 * resolvedColor.blueComponent)

        return luminance >= 0.6 ? .black : .white
    }
}
