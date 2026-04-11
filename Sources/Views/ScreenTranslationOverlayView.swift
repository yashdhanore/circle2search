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

                Text(appModel.settingsStore.targetLanguage)
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

    private let glowColor = Color(red: 0.30, green: 0.81, blue: 0.98)
    private let innerStrokeColor = Color.white.opacity(0.72)

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = min(max(min(proxy.size.width, proxy.size.height) * 0.018, 18), 28)
            let pulseDuration = isBusy ? 1.1 : 1.8

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(innerStrokeColor, lineWidth: 1.6)
                    .padding(9)

                RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                    .strokeBorder(glowColor.opacity(glowOpacity), lineWidth: glowLineWidth)
                    .blur(radius: glowBlurRadius)
                    .padding(6)

                RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .strokeBorder(glowColor.opacity(secondaryGlowOpacity), lineWidth: 2.2)
                    .padding(7)
            }
            .scaleEffect(glowScale)
            .opacity(glowContainerOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onAppear {
                guard !reduceMotion else {
                    return
                }

                withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue {
                    isPulsing = false
                } else {
                    withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isBusy) { _, _ in
                guard !reduceMotion else {
                    return
                }

                isPulsing = false
                withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .ignoresSafeArea()
    }

    private var glowOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.58 : 0.42
        }

        return isPulsing ? (isBusy ? 0.92 : 0.70) : (isBusy ? 0.42 : 0.34)
    }

    private var secondaryGlowOpacity: Double {
        if reduceMotion {
            return 0.44
        }

        return isPulsing ? 0.68 : 0.30
    }

    private var glowLineWidth: CGFloat {
        if reduceMotion {
            return isBusy ? 9 : 7
        }

        return isPulsing ? (isBusy ? 11 : 8.5) : (isBusy ? 7.5 : 6.5)
    }

    private var glowBlurRadius: CGFloat {
        if reduceMotion {
            return isBusy ? 20 : 16
        }

        return isPulsing ? (isBusy ? 24 : 18) : (isBusy ? 16 : 14)
    }

    private var glowScale: CGFloat {
        guard !reduceMotion else {
            return 1
        }

        return isPulsing ? 1.0025 : 0.998
    }

    private var glowContainerOpacity: Double {
        guard !reduceMotion else {
            return 1
        }

        return isPulsing ? 1 : 0.9
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
