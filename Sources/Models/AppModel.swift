import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let managedTranslationDebugStore: ManagedTranslationDebugStore
    let selfHostedBackendManager: SelfHostedBackendManager

    var statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription) to search or translate."
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
            AppLogger.app.debug("Ignored capture-session trigger because a session is already active or preparing.")
            return
        }

        Task {
            await prepareFullScreenTranslateSession()
        }
    }

    func activateSearchSelection() {
        guard let session = currentScreenSession else {
            AppLogger.app.debug("Ignored search action because no screen session is active.")
            return
        }

        guard let context = selectedTextContext(for: session) else {
            AppLogger.app.debug("Ignored search action because there is no valid text selection.")
            return
        }

        guard let url = searchURL(for: context.queryText) else {
            AppLogger.app.error("Failed to build a search URL for the selected text.")
            lastErrorMessage = "The selected text could not be searched."
            statusMessage = "Search failed."
            return
        }

        statusMessage = "Opening search results..."
        lastErrorMessage = nil
        AppLogger.app.info(
            "Opening browser handoff search for \(context.blocks.count) selected block(s)."
        )
        NSWorkspace.shared.open(url)
        closeCurrentScreenSession()
    }

    func activateTranslatedScreen() {
        guard let session = currentScreenSession else {
            AppLogger.translation.debug("Ignored translate action because no screen session is active.")
            return
        }

        if session.hasRenderedTranslation, session.translationScope == .screen {
            var updatedSession = session
            updatedSession.displayMode = .translated
            updatedSession.errorMessage = nil
            currentScreenSession = updatedSession
            refreshStatusMessage(for: updatedSession)
            AppLogger.translation.info("Reused cached translated overlay for session \(session.id.uuidString).")
            return
        }

        Task {
            await translateCurrentScreen()
        }
    }

    func activateTranslatedSelection() {
        guard let session = currentScreenSession else {
            AppLogger.translation.debug("Ignored selection translation because no screen session is active.")
            return
        }

        guard let context = selectedTextContext(for: session) else {
            AppLogger.translation.debug("Ignored selection translation because there is no valid text selection.")
            return
        }

        Task {
            await translateSelectedBlocks(
                context.blocks,
                for: session.id,
                scope: .selection
            )
        }
    }

    func updateSelectionRect(_ rect: CGRect?, mode: ScreenSelectionMode = .rectangle) {
        guard var session = currentScreenSession else {
            return
        }

        session.selection = normalizedSelection(from: rect, in: session.snapshot).map {
            ScreenSelection(rect: $0, mode: mode)
        }
        session.errorMessage = nil
        currentScreenSession = session
        refreshStatusMessage(for: session)
    }

    func clearSelection() {
        guard var session = currentScreenSession else {
            return
        }

        session.selection = nil
        session.errorMessage = nil
        currentScreenSession = session
        refreshStatusMessage(for: session)
    }

    @discardableResult
    func selectTextCluster(near point: CGPoint) -> Bool {
        guard var session = currentScreenSession else {
            return false
        }

        guard session.phase != .analyzing, !session.recognizedBlocks.isEmpty else {
            return false
        }

        let relaxedHitInset = CGSize(width: 10, height: 6)
        let directHit = session.recognizedBlocks.first { block in
            block.localRect.insetBy(dx: -relaxedHitInset.width, dy: -relaxedHitInset.height).contains(point)
        }

        let nearestBlock = directHit ?? session.recognizedBlocks.min { lhs, rhs in
            distance(from: point, to: lhs.localRect) < distance(from: point, to: rhs.localRect)
        }

        guard let nearestBlock else {
            return false
        }

        let maximumSnapDistance: CGFloat = 44
        guard directHit != nil || distance(from: point, to: nearestBlock.localRect) <= maximumSnapDistance else {
            return false
        }

        let paddedRect = nearestBlock.localRect
            .insetBy(dx: -10, dy: -6)
            .intersection(session.snapshot.visibleContentLocalRect)
            .integral

        guard !paddedRect.isNull else {
            return false
        }

        session.selection = ScreenSelection(rect: paddedRect, mode: .textCluster)
        session.errorMessage = nil
        currentScreenSession = session
        refreshStatusMessage(for: session)
        AppLogger.app.info("Selected OCR text cluster near point \(NSStringFromPoint(point)).")
        return true
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
        statusMessage = "Ready. Click the menu bar icon or press \(GlobalHotkeyService.defaultShortcutDescription) to search or translate."
    }

    func openSettings() {
        AppLogger.settings.info("Opening settings window.")
        settingsWindowController.show(appModel: self)
    }

    func refreshSelfHostedBackendStatus() {
        guard AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration else {
            return
        }

        Task {
            await selfHostedBackendManager.refreshStatus()
        }
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
            refreshStatusMessage(for: session)
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

        await translateSelectedBlocks(
            session.recognizedBlocks,
            for: session.id,
            scope: .screen
        )
    }

    private func translateCurrentScreen(for sessionID: UUID) async {
        guard let session = validatedSession(withID: sessionID) else {
            return
        }

        await translateSelectedBlocks(
            session.recognizedBlocks,
            for: sessionID,
            scope: .screen
        )
    }

    private func translateSelectedBlocks(
        _ blocks: [RecognizedTextBlock],
        for sessionID: UUID,
        scope: ScreenTranslationScope
    ) async {
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

        if scope == .screen, session.hasRenderedTranslation, session.translationScope == .screen {
            session.displayMode = .translated
            session.errorMessage = nil
            currentScreenSession = session
            refreshStatusMessage(for: session)
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

        guard !blocks.isEmpty else {
            session.errorMessage = scope == .selection
                ? "Selection does not contain readable text."
                : "No text was recognized on the visible screen."
            currentScreenSession = session
            lastErrorMessage = session.errorMessage
            refreshStatusMessage(for: session)
            return
        }

        session.phase = .translating
        session.translationScope = scope
        session.errorMessage = nil
        currentScreenSession = session
        lastErrorMessage = nil
        statusMessage = scope == .selection
            ? "Translating the selected text..."
            : "Translating the visible screen..."
        AppLogger.translation.info(
            "Starting \(scope == .selection ? "selection" : "screen") translation for session \(sessionID.uuidString) with \(blocks.count) block(s)."
        )

        do {
            let translatedResponse = try await translateWithConfiguredProvider(
                blocks: blocks
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

            let translatedBlocks = blocks.compactMap { block -> TranslatedTextBlock? in
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
            activeSession.translationScope = scope
            activeSession.queuedTranslateRequest = false
            activeSession.errorMessage = activeSession.renderedBlocks.isEmpty
                ? (scope == .selection
                    ? "The selection translated, but nothing could be drawn in place."
                    : "The translation completed, but nothing could be drawn in place.")
                : nil

            currentScreenSession = activeSession
            refreshStatusMessage(for: activeSession)
            AppLogger.translation.info(
                "\(scope == .selection ? "Selection" : "Screen") translation finished for session \(sessionID.uuidString) with \(activeSession.renderedBlocks.count) renderable block(s)."
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
            statusMessage = scope == .selection ? "Selection translation failed." : "Translation failed."
            AppLogger.translation.error("Translation failed: \(error.localizedDescription)")
        }
    }

    func selectedTextContext(for session: ScreenTranslationSession) -> SelectedTextContext? {
        guard let selection = session.selection else {
            return nil
        }

        let selectedBlocks = session.recognizedBlocks.filter { block in
            let intersection = selection.rect.intersection(block.localRect)

            guard !intersection.isNull else {
                return false
            }

            let midpoint = CGPoint(x: block.localRect.midX, y: block.localRect.midY)
            let blockArea = max(block.localRect.width * block.localRect.height, 1)
            let intersectionArea = intersection.width * intersection.height

            return selection.rect.contains(midpoint) || intersectionArea / blockArea >= 0.35
        }

        guard !selectedBlocks.isEmpty else {
            return nil
        }

        let queryText = selectedBlocks
            .map { block in
                block.sourceText
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !queryText.isEmpty else {
            return nil
        }

        let unionRect = selectedBlocks.reduce(CGRect.null) { partialResult, block in
            partialResult.union(block.localRect)
        }

        return SelectedTextContext(
            blocks: selectedBlocks,
            queryText: queryText,
            unionRect: unionRect
        )
    }

    func selectionPreviewText(for session: ScreenTranslationSession) -> String? {
        guard let context = selectedTextContext(for: session) else {
            return nil
        }

        if context.queryText.count <= 96 {
            return context.queryText
        }

        let cutoffIndex = context.queryText.index(context.queryText.startIndex, offsetBy: 93)
        return "\(context.queryText[..<cutoffIndex])..."
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

    private func refreshStatusMessage(for session: ScreenTranslationSession) {
        lastErrorMessage = session.errorMessage

        if let errorMessage = session.errorMessage, !errorMessage.isEmpty {
            statusMessage = errorMessage
            return
        }

        switch session.phase {
        case .analyzing:
            statusMessage = "Analyzing the visible screen..."
        case .ready:
            if let selectedTextContext = selectedTextContext(for: session) {
                statusMessage = "Ready to search or translate \(selectedTextContext.blocks.count) text block(s)."
            } else if session.hasSelection {
                statusMessage = "Selection does not contain readable text."
            } else if session.hasRecognizedText {
                statusMessage = "Drag to select or click text."
            } else {
                statusMessage = "No text recognized on the visible screen."
            }
        case .translating:
            statusMessage = session.translationScope == .selection
                ? "Translating the selected text..."
                : "Translating the visible screen..."
        case .translated:
            if session.displayMode == .translated {
                statusMessage = session.translationScope == .selection
                    ? "Showing translated text in the selected area."
                    : "Showing translated text in place."
            } else {
                statusMessage = "Showing the original screen."
            }
        }
    }

    private func normalizedSelection(
        from rect: CGRect?,
        in snapshot: CapturedDisplaySnapshot
    ) -> CGRect? {
        guard let rect else {
            return nil
        }

        let clampedRect = rect.standardized
            .intersection(snapshot.visibleContentLocalRect)
            .integral

        guard
            !clampedRect.isNull,
            clampedRect.width >= 8,
            clampedRect.height >= 8
        else {
            return nil
        }

        return clampedRect
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)

        return sqrt((dx * dx) + (dy * dy))
    }

    private func searchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        return components.url
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
