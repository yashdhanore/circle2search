import SwiftUI

struct SettingsView: View {
    let appModel: AppModel

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Global Shortcut", value: GlobalHotkeyService.defaultShortcutDescription)

                Text("Use the shortcut or the menu bar icon to open the search box, then search the web or jump into screen search and translation.")
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
                Section("Local Backend") {
                    Text("For source builds, add your Google Translate API key to `backend/.env`, run `./script/run_backend.sh`, then use `Check Status`.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: localBackendStatusSymbolName)
                            .foregroundStyle(localBackendStatusColor)

                        Text(appModel.selfHostedBackendManager.statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    Button("Check Status") {
                        appModel.refreshSelfHostedBackendStatus()
                    }

                    Text("The open-source scheme expects a local backend on http://127.0.0.1:8080 by default.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let error = appModel.selfHostedBackendManager.lastErrorMessage, !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    DisclosureGroup("Advanced") {
                        Text("Only use these settings if you host the translation backend somewhere other than this Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        TextField(
                            "http://127.0.0.1:8080",
                            text: Binding(
                                get: { appModel.managedTranslationDebugStore.baseURL },
                                set: { appModel.managedTranslationDebugStore.baseURL = $0 }
                            )
                        )

                        SecureField(
                            "Access token (optional)",
                            text: Binding(
                                get: { appModel.managedTranslationDebugStore.bearerToken },
                                set: { appModel.managedTranslationDebugStore.bearerToken = $0 }
                            )
                        )

                        if let error = appModel.managedTranslationDebugStore.lastPersistenceError, !error.isEmpty {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var localBackendStatusSymbolName: String {
        switch appModel.selfHostedBackendManager.state {
        case .reachable:
            return "checkmark.circle.fill"
        case .unreachable:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "circle.dashed"
        }
    }

    private var localBackendStatusColor: Color {
        switch appModel.selfHostedBackendManager.state {
        case .reachable:
            return .green
        case .unreachable:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
