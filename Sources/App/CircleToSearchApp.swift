import SwiftUI

@main
struct CircleToSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let settingsStore = SettingsStore()
        let keychainStore = KeychainStore(serviceName: AppRuntimeConfiguration.keychainServiceName)
        let debugStore = ManagedTranslationDebugStore(
            keychainStore: keychainStore
        )
        let selfHostedBackendManager = SelfHostedBackendManager()
        let appModel = AppModel(
            settingsStore: settingsStore,
            managedTranslationDebugStore: debugStore,
            selfHostedBackendManager: selfHostedBackendManager,
            hotkeyService: GlobalHotkeyService(),
            overlayCoordinator: ScreenTranslationOverlayCoordinator(),
            screenCaptureService: ScreenCaptureService(),
            ocrProvider: VisionOCRProvider(),
            visualSearchProvider: VisionVisualQueryProvider(),
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
