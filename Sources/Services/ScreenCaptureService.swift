import AppKit
import CoreGraphics
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

@MainActor
struct ScreenCaptureService {
    func captureDisplayUnderCursor() async throws -> CapturedDisplaySnapshot {
        try ensureScreenCaptureAccess()

        let shareableContent = try await currentShareableContent()
        let excludedApplications = shareableContent.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }

        guard let screen = screenUnderCursor() else {
            throw ScreenCaptureError.noDisplaysAvailable
        }

        return try await captureDisplaySnapshot(
            for: screen,
            shareableContent: shareableContent,
            excludedApplications: excludedApplications
        )
    }

    private func captureDisplaySnapshot(
        for screen: NSScreen,
        shareableContent: SCShareableContent,
        excludedApplications: [SCRunningApplication]
    ) async throws -> CapturedDisplaySnapshot {
        guard let display = shareableContent.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw ScreenCaptureError.displayUnavailable(screen.localizedName)
        }

        let scale = max(screen.backingScaleFactor, 1)
        let configuration = SCStreamConfiguration()
        configuration.width = size_t((screen.frame.width * scale).rounded())
        configuration.height = size_t((screen.frame.height * scale).rounded())
        configuration.showsCursor = false

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let image = try await captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return CapturedDisplaySnapshot(
            displayID: display.displayID,
            frameInScreenCoordinates: screen.frame,
            pointPixelScale: scale,
            image: image
        )
    }

    private func screenUnderCursor() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation

        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func currentShareableContent() async throws -> SCShareableContent {
        let shareableContent = try await SCShareableContent.current

        guard !shareableContent.displays.isEmpty else {
            throw ScreenCaptureError.unavailableContent
        }

        return shareableContent
    }

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: contentFilter,
                configuration: configuration
            ) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenCaptureError.emptyImage)
                }
            }
        }
    }

    private func ensureScreenCaptureAccess() throws {
        if CGPreflightScreenCaptureAccess() {
            return
        }

        _ = CGRequestScreenCaptureAccess()

        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case noDisplaysAvailable
    case displayUnavailable(String)
    case unavailableContent
    case emptyImage

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Grant Screen Recording access in System Settings, then retry the selection."
        case .noDisplaysAvailable:
            return "The app could not find any displays to capture."
        case let .displayUnavailable(name):
            return "The display \(name) is not available for capture."
        case .unavailableContent:
            return "ScreenCaptureKit did not return shareable screen content."
        case .emptyImage:
            return "ScreenCaptureKit returned an empty image."
        }
    }
}
