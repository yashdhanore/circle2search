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

            Section("Always Translate To") {
                Picker(
                    "Language",
                    selection: Binding(
                        get: { appModel.settingsStore.targetLanguage },
                        set: { appModel.settingsStore.targetLanguage = $0 }
                    )
                ) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }

                Text("Every captured screen is translated into this language by default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if AppRuntimeConfiguration.allowsManagedTranslationUserConfiguration {
                Section("Self-Hosted Translation Service") {
                    TextField(
                        "http://127.0.0.1:8080",
                        text: Binding(
                            get: { appModel.managedTranslationDebugStore.baseURL },
                            set: { appModel.managedTranslationDebugStore.baseURL = $0 }
                        )
                    )

                    Text("If your backend is running on the same Mac, you can usually leave the URL as http://127.0.0.1:8080.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    SecureField(
                        "Access token (optional)",
                        text: Binding(
                            get: { appModel.managedTranslationDebugStore.bearerToken },
                            set: { appModel.managedTranslationDebugStore.bearerToken = $0 }
                        )
                    )

                    Text("Leave the access token blank if your backend is only running on your own Mac. Add one if your backend requires it or is hosted somewhere else.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let error = appModel.managedTranslationDebugStore.lastPersistenceError, !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
