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

    private let hotkeyService: GlobalHotkeyService
    private let overlayCoordinator: SelectionOverlayCoordinator
    private let searchService: SearchService

    init(
        settingsStore: SettingsStore,
        credentialStore: ProviderCredentialStore,
        hotkeyService: GlobalHotkeyService,
        overlayCoordinator: SelectionOverlayCoordinator,
        searchService: SearchService
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.hotkeyService = hotkeyService
        self.overlayCoordinator = overlayCoordinator
        self.searchService = searchService
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
        guard !overlayCoordinator.isPresented else {
            return
        }

        lastErrorMessage = nil
        lastTranslatedText = ""
        statusMessage = "Selection mode active."

        overlayCoordinator.presentSelection(
            onSelection: { [weak self] selection in
                guard let self else { return }

                self.lastSelectionSummary = selection.summary
                self.statusMessage = "Selection stored. Screen capture and OCR are the next slice."
                AppLogger.app.info("Selection captured: \(selection.summary)")
            },
            onCancel: { [weak self] in
                guard let self else { return }

                self.statusMessage = "Selection cancelled."
                AppLogger.app.info("Selection cancelled.")
            }
        )
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
