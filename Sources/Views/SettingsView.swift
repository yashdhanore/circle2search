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

            #if DEBUG
            Section("Debug Translation Service") {
                TextField(
                    "http://127.0.0.1:8080",
                    text: Binding(
                        get: { appModel.managedTranslationDebugStore.baseURL },
                        set: { appModel.managedTranslationDebugStore.baseURL = $0 }
                    )
                )

                Text("Use this only while developing against a local or non-production backend.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SecureField(
                    "Bearer token (debug only)",
                    text: Binding(
                        get: { appModel.managedTranslationDebugStore.bearerToken },
                        set: { appModel.managedTranslationDebugStore.bearerToken = $0 }
                    )
                )

                Text("Release builds authenticate with the App Store receipt automatically. The debug bearer token is stored in the macOS Keychain and is not shown in release builds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let error = appModel.managedTranslationDebugStore.lastPersistenceError, !error.isEmpty {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
