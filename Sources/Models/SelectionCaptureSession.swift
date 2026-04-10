import CoreGraphics
import Foundation

struct CapturedDisplaySnapshot {
    let displayID: CGDirectDisplayID
    let frameInScreenCoordinates: CGRect
    let pointPixelScale: CGFloat
    let image: CGImage
}

struct SelectionCaptureSession {
    let snapshots: [CapturedDisplaySnapshot]

    func croppedImage(for selection: ScreenSelection) -> CGImage? {
        guard
            let snapshot = snapshots.first(where: { $0.displayID == selection.displayID })
        else {
            return nil
        }

        let selectionRect = selection.rectInScreenCoordinates
        let displayFrame = snapshot.frameInScreenCoordinates

        guard displayFrame.intersects(selectionRect) else {
            return nil
        }

        let relativeRect = CGRect(
            x: selectionRect.minX - displayFrame.minX,
            y: displayFrame.maxY - selectionRect.maxY,
            width: selectionRect.width,
            height: selectionRect.height
        )

        let rawPixelRect = CGRect(
            x: relativeRect.minX * snapshot.pointPixelScale,
            y: relativeRect.minY * snapshot.pointPixelScale,
            width: relativeRect.width * snapshot.pointPixelScale,
            height: relativeRect.height * snapshot.pointPixelScale
        )

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: snapshot.image.width,
            height: snapshot.image.height
        )

        let cropRect = rawPixelRect.integral.intersection(imageBounds)

        guard !cropRect.isNull, cropRect.width > 1, cropRect.height > 1 else {
            return nil
        }

        return snapshot.image.cropping(to: cropRect)
    }
}
