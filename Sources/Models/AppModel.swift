import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let managedTranslationDebugStore: ManagedTranslationDebugStore
    let selfHostedBackendManager: SelfHostedBackendManager

    var statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription)."
    var lastErrorMessage: String?
    var currentScreenSession: ScreenTranslationSession?
    var isSessionPreparationInFlight = false

    private let hotkeyService: GlobalHotkeyService
    private let overlayCoordinator: ScreenTranslationOverlayCoordinator
    private let screenCaptureService: ScreenCaptureService
    private let ocrProvider: VisionOCRProvider
    private let textReplacementRenderer: TextReplacementRenderer
    private let settingsWindowController: SettingsWindowController
    private var statusItemController: StatusItemController?

    init(
        settingsStore: SettingsStore,
        managedTranslationDebugStore: ManagedTranslationDebugStore,
        selfHostedBackendManager: SelfHostedBackendManager,
        hotkeyService: GlobalHotkeyService,
        overlayCoordinator: ScreenTranslationOverlayCoordinator,
        screenCaptureService: ScreenCaptureService,
        ocrProvider: VisionOCRProvider,
        textReplacementRenderer: TextReplacementRenderer,
        settingsWindowController: SettingsWindowController
    ) {
        self.settingsStore = settingsStore
        self.managedTranslationDebugStore = managedTranslationDebugStore
        self.selfHostedBackendManager = selfHostedBackendManager
        self.hotkeyService = hotkeyService
        self.overlayCoordinator = overlayCoordinator
        self.screenCaptureService = screenCaptureService
        self.ocrProvider = ocrProvider
        self.textReplacementRenderer = textReplacementRenderer
        self.settingsWindowController = settingsWindowController
    }

    func start() {
        hotkeyService.onTrigger = { [weak self] in
            self?.beginFullScreenTranslateSession()
        }

        if statusItemController == nil {
            statusItemController = StatusItemController(
                onPrimaryAction: { [weak self] in
                    self?.beginFullScreenTranslateSession()
                },
                onOpenSettings: { [weak self] in
                    self?.openSettings()
                }
            )
        }

        do {
            try hotkeyService.registerDefaultShortcut()
            AppLogger.app.info("Registered global shortcut.")
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Hotkey registration failed."
            AppLogger.app.error("Hotkey registration failed: \(error.localizedDescription)")
        }

        if AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration {
            selfHostedBackendManager.start()
        }
    }

    func beginFullScreenTranslateSession() {
        guard currentScreenSession == nil, !overlayCoordinator.isPresented, !isSessionPreparationInFlight else {
            AppLogger.app.debug("Ignored translate-session trigger because a session is already active or preparing.")
            return
        }

        Task {
            await prepareFullScreenTranslateSession()
        }
    }

    func activateTranslatedScreen() {
        guard let session = currentScreenSession else {
            AppLogger.translation.debug("Ignored translate action because no screen session is active.")
            return
        }

        if session.hasRenderedTranslation {
            var updatedSession = session
            updatedSession.displayMode = .translated
            updatedSession.errorMessage = nil
            currentScreenSession = updatedSession
            statusMessage = "Showing translated overlay."
            AppLogger.translation.info("Reused cached translated overlay for session \(session.id.uuidString).")
            return
        }

        Task {
            await translateCurrentScreen()
        }
    }

    func showOriginalScreen() {
        guard var session = currentScreenSession, session.hasRenderedTranslation else {
            AppLogger.overlay.debug("Ignored request to show original screen because no translated overlay is active.")
            return
        }

        session.displayMode = .original
        currentScreenSession = session
        statusMessage = "Showing the original screen."
        AppLogger.overlay.info("Showing original frozen screen for session \(session.id.uuidString).")
    }

    func closeCurrentScreenSession() {
        if let session = currentScreenSession {
            AppLogger.overlay.info("Closing screen translation session \(session.id.uuidString).")
        }
        overlayCoordinator.dismiss()
        currentScreenSession = nil
        statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription)."
    }

    func openSettings() {
        AppLogger.settings.info("Opening settings window.")
        settingsWindowController.show(appModel: self)
    }

    func startLocalSelfHostedBackend() {
        guard AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration else {
            return
        }

        Task {
            await selfHostedBackendManager.startLocalBackend()

            if selfHostedBackendManager.localBackendState == .running {
                managedTranslationDebugStore.baseURL = selfHostedBackendManager.localBackendBaseURL
                managedTranslationDebugStore.bearerToken = ""
                AppLogger.settings.info("Configured the app to use the local self-hosted backend.")
            }
        }
    }

    func stopLocalSelfHostedBackend() {
        guard AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration else {
            return
        }

        selfHostedBackendManager.stopLocalBackend()
    }

    func refreshSelfHostedBackendStatus() {
        guard AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration else {
            return
        }

        Task {
            await selfHostedBackendManager.refreshStatus()
        }
    }

    func openNodeDownloadPage() {
        selfHostedBackendManager.openNodeDownloadPage()
    }

    func openLocalBackendFolder() {
        selfHostedBackendManager.openLocalBackendFolder()
    }

    private func prepareFullScreenTranslateSession() async {
        guard currentScreenSession == nil, !overlayCoordinator.isPresented, !isSessionPreparationInFlight else {
            return
        }

        isSessionPreparationInFlight = true
        lastErrorMessage = nil
        statusMessage = "Capturing the visible screen..."

        defer {
            isSessionPreparationInFlight = false
        }

        do {
            let snapshot = try await screenCaptureService.captureDisplayUnderCursor()
            let session = ScreenTranslationSession(snapshot: snapshot)

            currentScreenSession = session
            AppLogger.app.info(
                "Prepared screen session \(session.id.uuidString) for display ID \(snapshot.displayID)."
            )
            overlayCoordinator.present(
                snapshot: snapshot,
                appModel: self,
                onClose: { [weak self] in
                    self?.closeCurrentScreenSession()
                }
            )

            statusMessage = "Analyzing the visible screen..."
            await analyzeCurrentScreen(sessionID: session.id, snapshot: snapshot)
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Screen capture failed."
            AppLogger.capture.error("Screen capture failed: \(error.localizedDescription)")
        }
    }

    private func analyzeCurrentScreen(
        sessionID: UUID,
        snapshot: CapturedDisplaySnapshot
    ) async {
        do {
            let result = try await ocrProvider.extractText(from: snapshot.image)
            let recognizedBlocks = makeRecognizedBlocks(from: result, snapshot: snapshot)

            guard var session = validatedSession(withID: sessionID) else {
                AppLogger.ocr.debug(
                    "Discarded OCR result because session \(sessionID.uuidString) is no longer active."
                )
                return
            }

            session.phase = .ready
            session.recognizedBlocks = recognizedBlocks
            session.errorMessage = recognizedBlocks.isEmpty
                ? "No text was recognized on the visible screen."
                : nil

            currentScreenSession = session
            lastErrorMessage = session.errorMessage
            statusMessage = recognizedBlocks.isEmpty
                ? "No text recognized on the visible screen."
                : "Ready to translate \(recognizedBlocks.count) text blocks."
            AppLogger.ocr.info(
                "OCR is ready for session \(sessionID.uuidString) with \(recognizedBlocks.count) renderable block(s)."
            )

            if session.queuedTranslateRequest {
                AppLogger.translation.info(
                    "Starting queued translation immediately after OCR for session \(sessionID.uuidString)."
                )
                await translateCurrentScreen(for: sessionID)
            }
        } catch {
            guard var session = validatedSession(withID: sessionID) else {
                AppLogger.ocr.debug(
                    "Discarded OCR failure because session \(sessionID.uuidString) is no longer active."
                )
                return
            }

            session.phase = .ready
            session.errorMessage = error.localizedDescription
            currentScreenSession = session
            lastErrorMessage = error.localizedDescription
            statusMessage = "Text recognition failed."
            AppLogger.ocr.error("OCR failed: \(error.localizedDescription)")
        }
    }

    private func translateCurrentScreen() async {
        guard let session = currentScreenSession else {
            return
        }

        await translateCurrentScreen(for: session.id)
    }

    private func translateCurrentScreen(for sessionID: UUID) async {
        guard var session = validatedSession(withID: sessionID) else {
            AppLogger.translation.debug(
                "Ignored translation request because session \(sessionID.uuidString) is no longer active."
            )
            return
        }

        if session.phase == .translating {
            AppLogger.translation.debug(
                "Ignored translation request because session \(sessionID.uuidString) is already translating."
            )
            return
        }

        if session.hasRenderedTranslation {
            session.displayMode = .translated
            session.errorMessage = nil
            currentScreenSession = session
            statusMessage = "Showing translated overlay."
            AppLogger.translation.info("Showing cached translated overlay for session \(sessionID.uuidString).")
            return
        }

        if session.phase == .analyzing {
            session.queuedTranslateRequest = true
            session.errorMessage = nil
            currentScreenSession = session
            statusMessage = "Finishing text recognition before translation."
            AppLogger.translation.info(
                "Queued translation until OCR finishes for session \(sessionID.uuidString)."
            )
            return
        }

        guard session.hasRecognizedText else {
            session.errorMessage = "No text was recognized on the visible screen."
            currentScreenSession = session
            lastErrorMessage = session.errorMessage
            statusMessage = "No text recognized on the visible screen."
            return
        }

        session.phase = .translating
        session.errorMessage = nil
        currentScreenSession = session
        lastErrorMessage = nil
        statusMessage = "Translating the visible screen..."
        AppLogger.translation.info(
            "Starting translation for session \(sessionID.uuidString) with \(session.recognizedBlocks.count) recognized block(s)."
        )

        do {
            let translatedResponse = try await translateWithConfiguredProvider(
                blocks: session.recognizedBlocks
            )

            guard var activeSession = validatedSession(withID: sessionID) else {
                AppLogger.translation.debug(
                    "Discarded translation response because session \(sessionID.uuidString) is no longer active."
                )
                return
            }

            let translatedBlocksByID = Dictionary(
                uniqueKeysWithValues: translatedResponse.items.map { item in
                    (
                        item.id,
                        item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            )

            let translatedBlocks = activeSession.recognizedBlocks.compactMap { block -> TranslatedTextBlock? in
                guard
                    let translatedText = translatedBlocksByID[block.id],
                    !translatedText.isEmpty
                else {
                    return nil
                }

                return TranslatedTextBlock(
                    id: block.id,
                    sourceText: block.sourceText,
                    translatedText: translatedText,
                    confidence: block.confidence,
                    localRect: block.localRect,
                    imageRect: block.imageRect
                )
            }

            activeSession.renderedBlocks = textReplacementRenderer.render(
                snapshot: activeSession.snapshot,
                translatedBlocks: translatedBlocks
            )
            activeSession.phase = .translated
            activeSession.displayMode = .translated
            activeSession.queuedTranslateRequest = false
            activeSession.errorMessage = activeSession.renderedBlocks.isEmpty
                ? "The translation completed, but nothing could be drawn in place."
                : nil

            currentScreenSession = activeSession
            lastErrorMessage = activeSession.errorMessage
            statusMessage = activeSession.renderedBlocks.isEmpty
                ? "Translation completed without an overlay result."
                : "Translated the visible screen with \(translatedResponse.providerName)."
            AppLogger.translation.info(
                "Translation finished for session \(sessionID.uuidString) with \(activeSession.renderedBlocks.count) renderable block(s)."
            )
        } catch {
            guard var activeSession = validatedSession(withID: sessionID) else {
                AppLogger.translation.debug(
                    "Discarded translation failure because session \(sessionID.uuidString) is no longer active."
                )
                return
            }

            activeSession.phase = .ready
            activeSession.queuedTranslateRequest = false
            activeSession.errorMessage = error.localizedDescription
            currentScreenSession = activeSession
            lastErrorMessage = error.localizedDescription
            statusMessage = "Translation failed."
            AppLogger.translation.error("Translation failed: \(error.localizedDescription)")
        }
    }

    private func translateWithConfiguredProvider(
        blocks: [RecognizedTextBlock]
    ) async throws -> BatchTranslationResponse {
        let batchRequest = BatchTranslationRequest(
            items: blocks.map { block in
                BatchTranslationItem(
                    id: block.id,
                    text: block.sourceText
                )
            },
            targetLanguageCode: settingsStore.targetLanguage.rawValue
        )

        let connection = try AppRuntimeConfiguration.managedTranslationConnection(
            debugStore: managedTranslationDebugStore
        )
        let provider = ManagedTranslationProvider(
            baseURL: connection.baseURL,
            authorization: connection.authorization
        )

        return try await provider.translateBatch(batchRequest)
    }

    private func validatedSession(withID sessionID: UUID) -> ScreenTranslationSession? {
        guard let session = currentScreenSession, session.id == sessionID else {
            return nil
        }

        return session
    }

    private func makeRecognizedBlocks(
        from result: OCRResult,
        snapshot: CapturedDisplaySnapshot
    ) -> [RecognizedTextBlock] {
        let visibleContentRect = snapshot.visibleContentLocalRect

        return result.observations.compactMap { observation -> RecognizedTextBlock? in
            let sourceText = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !sourceText.isEmpty else {
                return nil
            }

            let localRect = snapshot.localRect(for: observation.normalizedBoundingBox)
            let clippedLocalRect = localRect.intersection(visibleContentRect).integral

            guard !clippedLocalRect.isNull else {
                return nil
            }

            let originalArea = max(localRect.width * localRect.height, 1)
            let visibleArea = clippedLocalRect.width * clippedLocalRect.height

            guard visibleArea / originalArea >= 0.7 else {
                return nil
            }

            let imageRect = snapshot.imageRect(for: clippedLocalRect)

            guard
                observation.confidence >= 0.2,
                clippedLocalRect.width >= 14,
                clippedLocalRect.height >= 8,
                !imageRect.isNull
            else {
                return nil
            }

            return RecognizedTextBlock(
                id: observation.id,
                sourceText: sourceText,
                confidence: observation.confidence,
                localRect: clippedLocalRect,
                imageRect: imageRect
            )
        }
    }
}
