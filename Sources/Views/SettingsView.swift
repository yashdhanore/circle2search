import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Global Shortcut", value: GlobalHotkeyService.defaultShortcutDescription)

                Text("Use the shortcut or the menu bar icon to open instant translate mode for the visible screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Translation") {
                Picker(
                    "Provider",
                    selection: Binding(
                        get: { appModel.settingsStore.translationProvider },
                        set: { appModel.settingsStore.translationProvider = $0 }
                    )
                ) {
                    ForEach(TranslationProviderKind.allCases) { provider in
                        Text(provider.displayName)
                            .tag(provider)
                    }
                }

                TextField(
                    "English",
                    text: Binding(
                        get: { appModel.settingsStore.targetLanguage },
                        set: { appModel.settingsStore.targetLanguage = $0 }
                    )
                )

                Text(appModel.settingsStore.translationProvider.helperText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Opper") {
                TextField(
                    "https://api.opper.ai",
                    text: Binding(
                        get: { appModel.settingsStore.opperBaseURL },
                        set: { appModel.settingsStore.opperBaseURL = $0 }
                    )
                )

                SecureField(
                    "OPPER_API_KEY",
                    text: Binding(
                        get: { appModel.credentialStore.opperAPIKey },
                        set: { appModel.credentialStore.opperAPIKey = $0 }
                    )
                )

                Text("The API key is stored in the macOS Keychain. The app calls Opper directly and does not require a proxy backend in this version.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let error = appModel.credentialStore.lastPersistenceError, !error.isEmpty {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
