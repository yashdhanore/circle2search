import SwiftUI

@main
struct CircleToSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let settingsStore = SettingsStore()
        let credentialStore = ProviderCredentialStore(
            keychainStore: KeychainStore(serviceName: "com.circle2search.app")
        )
        let appModel = AppModel(
            settingsStore: settingsStore,
            credentialStore: credentialStore,
            hotkeyService: GlobalHotkeyService(),
            overlayCoordinator: SelectionOverlayCoordinator(),
            searchService: SearchService()
        )

        _appModel = State(initialValue: appModel)

        Task { @MainActor in
            appModel.start()
        }
    }

    var body: some Scene {
        MenuBarExtra("Circle to Search", systemImage: "magnifyingglass.circle") {
            MenuBarMenuView(appModel: appModel)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
                .frame(width: 520)
        }
    }
}
