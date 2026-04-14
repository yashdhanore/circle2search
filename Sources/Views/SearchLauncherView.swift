import SwiftUI

struct SearchLauncherView: View {
    let appModel: AppModel

    @FocusState private var isQueryFocused: Bool

    var body: some View {
        ZStack {
            Color.clear

            launcherShell
                .padding(18)
        }
        .onAppear {
            Task { @MainActor in
                isQueryFocused = true
            }
        }
    }

    private var launcherShell: some View {
        VStack(alignment: .leading, spacing: 22) {
            topBar
            hero
            searchField
            actionRail
            footer
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(launcherBackground)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 16) {
            Label("CircleToSearch", systemImage: "sparkle.magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(GlobalHotkeyService.defaultShortcutDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask, search, or grab anything on screen.")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Start with the web, or jump straight into screen search and translation without breaking your flow.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
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
            .font(.system(size: 21, weight: .medium, design: .rounded))
            .submitLabel(.search)
            .onSubmit {
                appModel.submitLauncherSearch()
            }

            Button {
                appModel.submitLauncherSearch()
            } label: {
                HStack(spacing: 8) {
                    Text("Search")
                        .font(.headline)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(trimmedQuery.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .white.opacity(0.06), radius: 18, y: -2)
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private var actionRail: some View {
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
            Text("Web queries open in your browser. Screen actions stay anchored to the current display.")
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
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color(nsColor: .controlAccentColor).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.11))
                    .frame(width: 240, height: 240)
                    .blur(radius: 86)
                    .offset(x: -34, y: -92)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .blur(radius: 70)
                    .offset(x: 46, y: 52)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 1)
            .shadow(color: .black.opacity(0.2), radius: 36, y: 20)
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
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))

                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .white.opacity(0.03), radius: 10, y: -1)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
