import SwiftUI

@main
struct CircleToSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let settingsStore = SettingsStore()
        let appModel = AppModel(
            settingsStore: settingsStore,
            hotkeyService: GlobalHotkeyService(),
            overlayCoordinator: ScreenTranslationOverlayCoordinator(),
            screenCaptureService: ScreenCaptureService(),
            ocrProvider: VisionOCRProvider(),
            textReplacementRenderer: TextReplacementRenderer(),
            settingsWindowController: SettingsWindowController()
        )

        _appModel = State(initialValue: appModel)

        Task { @MainActor in
            appModel.start()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView(appModel: appModel)
                .frame(width: 520)
        }
    }
}
