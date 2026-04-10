import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Global Shortcut", value: GlobalHotkeyService.defaultShortcutDescription)

                Text("The first milestone keeps the shortcut fixed while capture and OCR are being wired.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Search") {
                TextField(
                    "https://www.google.com/search?q={query}",
                    text: Binding(
                        get: { appModel.settingsStore.searchEngineTemplate },
                        set: { appModel.settingsStore.searchEngineTemplate = $0 }
                    )
                )

                Text("Include a {query} token in the template.")
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
