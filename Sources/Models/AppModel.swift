import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let credentialStore: ProviderCredentialStore

    var statusMessage = "Ready. Press \(GlobalHotkeyService.defaultShortcutDescription)."
    var lastErrorMessage: String?
    var lastSelectionSummary = "No screen selection yet."
    var lastRecognizedText = ""
    var lastTranslatedText = ""
    var isTranslationInFlight = false
    var isSelectionPreparationInFlight = false
    var isOCRInFlight = false

    private let hotkeyService: GlobalHotkeyService
    private let overlayCoordinator: SelectionOverlayCoordinator
    private let searchService: SearchService
    private let screenCaptureService: ScreenCaptureService
    private let ocrProvider: VisionOCRProvider
    private var activeCaptureSession: SelectionCaptureSession?

    init(
        settingsStore: SettingsStore,
        credentialStore: ProviderCredentialStore,
        hotkeyService: GlobalHotkeyService,
        overlayCoordinator: SelectionOverlayCoordinator,
        searchService: SearchService,
        screenCaptureService: ScreenCaptureService,
        ocrProvider: VisionOCRProvider
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.hotkeyService = hotkeyService
        self.overlayCoordinator = overlayCoordinator
        self.searchService = searchService
        self.screenCaptureService = screenCaptureService
        self.ocrProvider = ocrProvider
    }

    func start() {
        hotkeyService.onTrigger = { [weak self] in
            self?.beginSelection()
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

    func beginSelection() {
        guard !overlayCoordinator.isPresented, !isSelectionPreparationInFlight else {
            return
        }

        Task {
            await prepareSelection()
        }
    }

    private func prepareSelection() async {
        guard !overlayCoordinator.isPresented, !isSelectionPreparationInFlight else {
            return
        }

        isSelectionPreparationInFlight = true
        activeCaptureSession = nil
        lastErrorMessage = nil
        lastRecognizedText = ""
        lastTranslatedText = ""
        statusMessage = "Capturing screens..."

        defer {
            isSelectionPreparationInFlight = false
        }

        do {
            let captureSession = try await screenCaptureService.captureSelectionSession()
            activeCaptureSession = captureSession
            statusMessage = "Selection mode active."

            overlayCoordinator.presentSelection(
                snapshots: captureSession.snapshots,
                onSelection: { [weak self] selection in
                    guard let self else { return }

                    Task {
                        await self.handleSelection(selection)
                    }
                },
                onCancel: { [weak self] in
                    guard let self else { return }

                    self.activeCaptureSession = nil
                    self.statusMessage = "Selection cancelled."
                    AppLogger.app.info("Selection cancelled.")
                }
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Screen capture failed."
            AppLogger.app.error("Screen capture failed: \(error.localizedDescription)")
        }
    }

    private func handleSelection(_ selection: ScreenSelection) async {
        lastSelectionSummary = selection.summary
        lastErrorMessage = nil
        isOCRInFlight = true
        statusMessage = "Running OCR..."

        defer {
            isOCRInFlight = false
            activeCaptureSession = nil
        }

        do {
            let image = try await imageForSelection(selection)
            let result = try await ocrProvider.extractText(from: image)
            let text = result.combinedText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                lastRecognizedText = ""
                statusMessage = "No text recognized in the selected area."
                return
            }

            lastRecognizedText = text
            lastTranslatedText = ""
            statusMessage = "Recognized \(result.lines.count) text item(s)."
            AppLogger.app.info("OCR completed with \(result.lines.count) lines.")
        } catch {
            lastRecognizedText = ""
            lastErrorMessage = error.localizedDescription
            statusMessage = "OCR failed."
            AppLogger.app.error("OCR failed: \(error.localizedDescription)")
        }
    }

    func loadClipboardText() {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            lastErrorMessage = "Clipboard does not currently contain text."
            return
        }

        lastRecognizedText = value
        lastTranslatedText = ""
        lastErrorMessage = nil
        statusMessage = "Loaded text from the clipboard."
    }

    func searchCurrentText() {
        do {
            try searchService.search(
                query: currentTextForActions,
                template: settingsStore.searchEngineTemplate
            )
            lastErrorMessage = nil
            statusMessage = "Opened search in the default browser."
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Search failed."
        }
    }

    func translateCurrentText() async {
        guard !isTranslationInFlight else {
            return
        }

        let text = currentTextForActions
        guard !text.isEmpty else {
            lastErrorMessage = "No text is available yet. Use clipboard text until OCR is wired."
            return
        }

        isTranslationInFlight = true
        lastErrorMessage = nil
        statusMessage = "Translating..."

        defer {
            isTranslationInFlight = false
        }

        do {
            let response = try await translateWithConfiguredProvider(text: text)

            lastTranslatedText = response.text
            statusMessage = "Translated with \(response.providerName)."
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = "Translation failed."
        }
    }

    private var currentTextForActions: String {
        lastRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func imageForSelection(_ selection: ScreenSelection) async throws -> CGImage {
        if let image = activeCaptureSession?.croppedImage(for: selection) {
            return image
        }

        return try await screenCaptureService.captureImage(in: selection.rectInScreenCoordinates)
    }

    private func translateWithConfiguredProvider(text: String) async throws -> TranslationResponse {
        switch settingsStore.translationProvider {
        case .opper:
            let apiKey = credentialStore.opperAPIKey
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !apiKey.isEmpty else {
                throw TranslationProviderError.missingAPIKey("Add an Opper API key in Settings before translating.")
            }

            let provider = OpperTranslationProvider(
                baseURL: settingsStore.opperBaseURL,
                apiKey: apiKey
            )
            return try await provider.translate(
                .init(
                    text: text,
                    targetLanguage: settingsStore.targetLanguage
                )
            )
        case .appleTranslation:
            throw TranslationProviderError.unsupported("Apple Translation is planned but not wired in this first milestone.")
        }
    }
}
