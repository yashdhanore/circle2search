import SwiftUI

struct MenuBarMenuView: View {
    let appModel: AppModel

    var body: some View {
        let isBusy = appModel.isSelectionPreparationInFlight || appModel.isOCRInFlight

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CircleToSearch")
                    .font(.headline)

                Text(appModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    appModel.beginSelection()
                } label: {
                    Label(
                        appModel.isSelectionPreparationInFlight ? "Capturing..." : "Start Selection",
                        systemImage: "viewfinder"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)

                Button {
                    appModel.loadClipboardText()
                } label: {
                    Label("Load Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .disabled(appModel.isSelectionPreparationInFlight)
            }

            HStack(spacing: 10) {
                Button {
                    appModel.searchCurrentText()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(appModel.lastRecognizedText.isEmpty || isBusy)

                Button {
                    Task {
                        await appModel.translateCurrentText()
                    }
                } label: {
                    Label(
                        appModel.isTranslationInFlight ? "Translating..." : "Translate",
                        systemImage: "globe"
                    )
                }
                .disabled(appModel.lastRecognizedText.isEmpty || appModel.isTranslationInFlight || isBusy)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                detailBlock(
                    title: "Selection",
                    body: appModel.lastSelectionSummary
                )

                detailBlock(
                    title: "Current Text",
                    body: appModel.lastRecognizedText.isEmpty
                        ? "No OCR text recognized yet. Start a selection or load text from the clipboard."
                        : appModel.lastRecognizedText
                )

                if !appModel.lastTranslatedText.isEmpty {
                    detailBlock(
                        title: "Translation",
                        body: appModel.lastTranslatedText
                    )
                }

                if let error = appModel.lastErrorMessage, !error.isEmpty {
                    detailBlock(
                        title: "Error",
                        body: error,
                        color: .red
                    )
                }
            }

            Divider()

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func detailBlock(title: String, body: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(body)
                .font(.callout)
                .foregroundStyle(color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
