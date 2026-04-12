import SwiftUI

struct ScreenTranslationOverlayView: View {
    let appModel: AppModel

    var body: some View {
        Group {
            if let session = appModel.currentScreenSession {
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        backgroundImage(for: session)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        ActiveCaptureEdgeGlowView(
                            isBusy: session.phase == .analyzing || session.phase == .translating
                        )
                        .allowsHitTesting(false)

                        if session.displayMode == .translated {
                            translatedLayer(session.renderedBlocks)
                                .allowsHitTesting(false)
                        }

                        hud(for: session)
                            .padding(.top, 18)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                }
            } else {
                Color.clear
            }
        }
    }

    private func backgroundImage(for session: ScreenTranslationSession) -> some View {
        Image(
            decorative: session.snapshot.image,
            scale: session.snapshot.pointPixelScale,
            orientation: .up
        )
        .resizable()
        .interpolation(.high)
        .ignoresSafeArea()
    }

    private func translatedLayer(_ blocks: [RenderableTranslationBlock]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(blocks) { block in
                RenderedTranslationBlockView(block: block)
            }
        }
        .ignoresSafeArea()
    }

    private func hud(for session: ScreenTranslationSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Translate") {
                    appModel.activateTranslatedScreen()
                }
                .buttonStyle(session.displayMode == .translated ? .borderedProminent : .borderedProminent)

                Button("Original") {
                    appModel.showOriginalScreen()
                }
                .buttonStyle(.bordered)
                .disabled(!session.hasRenderedTranslation)

                Button("Close") {
                    appModel.closeCurrentScreenSession()
                }
                .buttonStyle(.bordered)

                Text(appModel.settingsStore.targetLanguage.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 8) {
                if session.phase == .analyzing || session.phase == .translating {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(statusText(for: session))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: session))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
    }

    private func statusText(for session: ScreenTranslationSession) -> String {
        if let errorMessage = session.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        switch session.phase {
        case .analyzing:
            return "Analyzing the visible screen."
        case .ready:
            return session.hasRecognizedText
                ? "Ready to translate \(session.recognizedBlocks.count) text blocks."
                : "No text was recognized on the visible screen."
        case .translating:
            return "Translating the visible screen."
        case .translated:
            return session.displayMode == .translated
                ? "Showing translated text in place."
                : "Showing the original screen."
        }
    }

    private func statusColor(for session: ScreenTranslationSession) -> Color {
        if let errorMessage = session.errorMessage, !errorMessage.isEmpty {
            return .red
        }

        return .secondary
    }
}

private struct ActiveCaptureEdgeGlowView: View {
    let isBusy: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private let glowColor = Color(nsColor: .controlAccentColor)
    private let hairlineColor = Color.white.opacity(0.16)

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = min(max(min(proxy.size.width, proxy.size.height) * 0.018, 18), 28)
            let pulseDuration = isBusy ? 1.15 : 1.8

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(hairlineColor.opacity(hairlineOpacity), lineWidth: 0.6)
                .blur(radius: isBusy ? 0.18 : 0.08)
                .padding(6)
                .shadow(color: glowColor.opacity(primaryGlowOpacity), radius: primaryGlowRadius)
                .shadow(color: glowColor.opacity(secondaryGlowOpacity), radius: secondaryGlowRadius)
                .opacity(containerOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onAppear {
                    updatePulseState(duration: pulseDuration)
                }
                .onChange(of: reduceMotion) { _, _ in
                    updatePulseState(duration: pulseDuration)
                }
                .onChange(of: isBusy) { _, _ in
                    updatePulseState(duration: pulseDuration)
                }
        }
        .ignoresSafeArea()
    }

    private func updatePulseState(duration: Double) {
        if reduceMotion || !isBusy {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private var hairlineOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.28 : 0.16
        }

        if isBusy {
            return isPulsing ? 0.34 : 0.16
        }

        return 0.08
    }

    private var primaryGlowOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.22 : 0.12
        }

        if isBusy {
            return isPulsing ? 0.26 : 0.10
        }

        return 0.06
    }

    private var secondaryGlowOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.12 : 0.06
        }

        if isBusy {
            return isPulsing ? 0.14 : 0.05
        }

        return 0.03
    }

    private var primaryGlowRadius: CGFloat {
        if reduceMotion {
            return isBusy ? 20 : 12
        }

        if isBusy {
            return isPulsing ? 24 : 12
        }

        return 10
    }

    private var secondaryGlowRadius: CGFloat {
        if reduceMotion {
            return isBusy ? 32 : 18
        }

        if isBusy {
            return isPulsing ? 38 : 18
        }

        return 14
    }

    private var containerOpacity: Double {
        if reduceMotion {
            return 0.96
        }

        return isBusy ? 0.94 : 0.78
    }
}

private struct RenderedTranslationBlockView: View {
    let block: RenderableTranslationBlock

    var body: some View {
        RoundedRectangle(cornerRadius: block.cornerRadius, style: .continuous)
            .fill(Color(nsColor: block.backgroundColor))
            .overlay(alignment: .topLeading) {
                Text(block.translatedText)
                    .font(.system(size: block.fontSize, weight: .medium, design: .default))
                    .foregroundStyle(Color(nsColor: block.foregroundColor))
                    .multilineTextAlignment(.leading)
                    .lineLimit(block.maximumLineCount)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .padding(.horizontal, block.horizontalPadding)
                    .padding(.vertical, block.verticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: block.rect.width, height: block.rect.height)
            .position(x: block.rect.midX, y: block.rect.midY)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
    }
}
