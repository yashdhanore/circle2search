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
                Section("Run On This Mac") {
                    SecureField(
                        "Google Translate API key",
                        text: Binding(
                            get: { appModel.selfHostedBackendManager.googleAPIKey },
                            set: { appModel.selfHostedBackendManager.googleAPIKey = $0 }
                        )
                    )

                    Text("Paste your Google Translate API key once. CircleToSearch will use it only for the local backend running on this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: localBackendStatusSymbolName)
                            .foregroundStyle(localBackendStatusColor)

                        Text(appModel.selfHostedBackendManager.statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    if let logLine = appModel.selfHostedBackendManager.lastLogLine, !logLine.isEmpty {
                        Text(logLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Button(
                            appModel.selfHostedBackendManager.canStopLocalBackend
                                ? "Restart Local Backend"
                                : "Start Local Backend"
                        ) {
                            appModel.startLocalSelfHostedBackend()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!appModel.selfHostedBackendManager.canStartLocalBackend)

                        Button("Check Status") {
                            appModel.refreshSelfHostedBackendStatus()
                        }
                        .disabled(appModel.selfHostedBackendManager.localBackendState == .starting)

                        if appModel.selfHostedBackendManager.canStopLocalBackend {
                            Button("Stop") {
                                appModel.stopLocalSelfHostedBackend()
                            }
                        }

                        Button("Open Backend Folder") {
                            appModel.openLocalBackendFolder()
                        }
                    }

                    Text("When the local backend is running, CircleToSearch automatically uses http://127.0.0.1:8080.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !appModel.selfHostedBackendManager.isNodeRuntimeAvailable {
                        Button("Download Node.js") {
                            appModel.openNodeDownloadPage()
                        }

                        Text("Node.js 20 or newer is required to run the local backend on your Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let error = appModel.selfHostedBackendManager.lastPersistenceError, !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.red)
                    }

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
        switch appModel.selfHostedBackendManager.localBackendState {
        case .running:
            return "checkmark.circle.fill"
        case .starting:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .notConfigured, .readyToStart:
            return "circle.dashed"
        }
    }

    private var localBackendStatusColor: Color {
        switch appModel.selfHostedBackendManager.localBackendState {
        case .running:
            return .green
        case .starting:
            return .orange
        case .failed:
            return .red
        case .notConfigured, .readyToStart:
            return .secondary
        }
    }
}
