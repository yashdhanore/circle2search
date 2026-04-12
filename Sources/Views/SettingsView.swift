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
                    "Target Language",
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

                Text("Screen text is recognized locally on the Mac, then translated by the managed Google Cloud NMT backend.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Translation Service") {
                TextField(
                    "http://127.0.0.1:8080",
                    text: Binding(
                        get: { appModel.settingsStore.managedTranslationBaseURL },
                        set: { appModel.settingsStore.managedTranslationBaseURL = $0 }
                    )
                )

                Text("Use a local URL while developing the backend. Production builds should point at the managed translation service.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
