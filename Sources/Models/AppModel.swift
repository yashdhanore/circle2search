import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let credentialStore: ProviderCredentialStore

    var statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription)."
    var lastErrorMessage: String?
    var currentScreenSession: ScreenTranslationSession?
    var isSessionPreparationInFlight = false

    private let hotkeyService: GlobalHotkeyService
    private let overlayCoordinator: ScreenTranslationOverlayCoordinator
    private let screenCaptureService: ScreenCaptureService
    private let ocrProvider: VisionOCRProvider
    private let textReplacementRenderer: TextReplacementRenderer
    private var statusItemController: StatusItemController?

    init(
        settingsStore: SettingsStore,
        credentialStore: ProviderCredentialStore,
        hotkeyService: GlobalHotkeyService,
        overlayCoordinator: ScreenTranslationOverlayCoordinator,
        screenCaptureService: ScreenCaptureService,
        ocrProvider: VisionOCRProvider,
        textReplacementRenderer: TextReplacementRenderer
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.hotkeyService = hotkeyService
        self.overlayCoordinator = overlayCoordinator
        self.screenCaptureService = screenCaptureService
        self.ocrProvider = ocrProvider
        self.textReplacementRenderer = textReplacementRenderer
    }

    func start() {
        hotkeyService.onTrigger = { [weak self] in
            self?.beginFullScreenTranslateSession()
        }

        if statusItemController == nil {
            statusItemController = StatusItemController { [weak self] in
                self?.beginFullScreenTranslateSession()
            }
        }

        do {
            try hotkeyService.registerDefaultShortcut()
            AppLogger.app.info("Registered global shortcut.")
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Hotkey registration failed."
            AppLogger.app.error("Hotkey registration failed: \(error.localizedDescription)")
        }
    }

    func beginFullScreenTranslateSession() {
        guard currentScreenSession == nil, !overlayCoordinator.isPresented, !isSessionPreparationInFlight else {
            return
        }

        Task {
            await prepareFullScreenTranslateSession()
        }
    }

    func activateTranslatedScreen() {
        guard let session = currentScreenSession else {
            return
        }

        if session.hasRenderedTranslation {
            var updatedSession = session
            updatedSession.displayMode = .translated
            updatedSession.errorMessage = nil
            currentScreenSession = updatedSession
            statusMessage = "Showing translated overlay."
            return
        }

        Task {
            await translateCurrentScreen()
        }
    }

    func showOriginalScreen() {
        guard var session = currentScreenSession, session.hasRenderedTranslation else {
            return
        }

        session.displayMode = .original
        currentScreenSession = session
        statusMessage = "Showing the original screen."
    }

    func closeCurrentScreenSession() {
        overlayCoordinator.dismiss()
        currentScreenSession = nil
        statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription)."
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
            AppLogger.app.error("Screen capture failed: \(error.localizedDescription)")
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

            if session.queuedTranslateRequest {
                await translateCurrentScreen(for: sessionID)
            }
        } catch {
            guard var session = validatedSession(withID: sessionID) else {
                return
            }

            session.phase = .ready
            session.errorMessage = error.localizedDescription
            currentScreenSession = session
            lastErrorMessage = error.localizedDescription
            statusMessage = "Text recognition failed."
            AppLogger.app.error("OCR failed: \(error.localizedDescription)")
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
            return
        }

        if session.phase == .translating {
            return
        }

        if session.hasRenderedTranslation {
            session.displayMode = .translated
            session.errorMessage = nil
            currentScreenSession = session
            statusMessage = "Showing translated overlay."
            return
        }

        if session.phase == .analyzing {
            session.queuedTranslateRequest = true
            session.errorMessage = nil
            currentScreenSession = session
            statusMessage = "Finishing text recognition before translation."
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

        do {
            let translatedResponse = try await translateWithConfiguredProvider(
                blocks: session.recognizedBlocks
            )

            guard var activeSession = validatedSession(withID: sessionID) else {
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
        } catch {
            guard var activeSession = validatedSession(withID: sessionID) else {
                return
            }

            activeSession.phase = .ready
            activeSession.queuedTranslateRequest = false
            activeSession.errorMessage = error.localizedDescription
            currentScreenSession = activeSession
            lastErrorMessage = error.localizedDescription
            statusMessage = "Translation failed."
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
            targetLanguage: settingsStore.targetLanguage
        )

        switch settingsStore.translationProvider {
        case .opper:
            let apiKey = credentialStore.opperAPIKey
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !apiKey.isEmpty else {
                throw TranslationProviderError.missingAPIKey(
                    "Add an Opper API key in Settings before translating."
                )
            }

            let provider = OpperTranslationProvider(
                baseURL: settingsStore.opperBaseURL,
                apiKey: apiKey
            )

            return try await provider.translateBatch(batchRequest)
        case .appleTranslation:
            throw TranslationProviderError.unsupported(
                "Apple Translation is not wired yet in this milestone."
            )
        }
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
        result.observations.compactMap { observation in
            let sourceText = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !sourceText.isEmpty else {
                return nil
            }

            let localRect = snapshot.localRect(for: observation.normalizedBoundingBox)
            let imageRect = snapshot.imageRect(for: localRect)

            guard
                observation.confidence >= 0.2,
                localRect.width >= 14,
                localRect.height >= 8,
                !imageRect.isNull
            else {
                return nil
            }

            return RecognizedTextBlock(
                id: observation.id,
                sourceText: sourceText,
                confidence: observation.confidence,
                localRect: localRect,
                imageRect: imageRect
            )
        }
    }
}
