import SwiftUI

struct SearchLauncherView: View {
    let appModel: AppModel

    @FocusState private var isQueryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            searchField
            actionRow
            footer
        }
        .padding(22)
        .background(launcherBackground)
        .onAppear {
            Task { @MainActor in
                isQueryFocused = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Search without leaving your screen")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Type a question, search the web, or jump straight into screen search and translation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(GlobalHotkeyService.defaultShortcutDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Ask Google or search the web",
                text: Binding(
                    get: { appModel.launcherQuery },
                    set: { appModel.launcherQuery = $0 }
                )
            )
            .textFieldStyle(.plain)
            .focused($isQueryFocused)
            .font(.title3)
            .onSubmit {
                appModel.submitLauncherSearch()
            }

            Button("Search Web") {
                appModel.submitLauncherSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedQuery.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            LauncherActionButton(
                title: "Search Screen",
                subtitle: "Drag to select text, images, or UI from the current display.",
                systemImage: "viewfinder.circle"
            ) {
                appModel.launchScreenSearchFromLauncher()
            }

            LauncherActionButton(
                title: "Translate Screen",
                subtitle: "Translate visible text in place without switching apps.",
                systemImage: "character.bubble"
            ) {
                appModel.launchScreenTranslateFromLauncher()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Search opens in your browser. Screen actions stay on the current display.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button("Close") {
                appModel.dismissLauncher(resetQuery: false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var launcherBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .shadow(color: .black.opacity(0.22), radius: 30, y: 16)
    }

    private var trimmedQuery: String {
        appModel.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LauncherActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
