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
    private let highlightColor = Color.white

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius = min(max(min(proxy.size.width, proxy.size.height) * 0.018, 18), 28)
            let pulseDuration = isBusy ? 1.1 : 1.9
            let inset: CGFloat = 2.5
            let bandDepth: CGFloat = isBusy ? 42 : 32
            let cornerDiameter = cornerRadius * (isBusy ? 4.8 : 4.1)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .overlay {
                        ZStack {
                            EdgeGlowBand(
                                edge: .top,
                                color: glowColor,
                                highlightColor: highlightColor,
                                depth: bandDepth,
                                intensity: edgeBandIntensity
                            )

                            EdgeGlowBand(
                                edge: .bottom,
                                color: glowColor,
                                highlightColor: highlightColor,
                                depth: bandDepth,
                                intensity: edgeBandIntensity * 0.9
                            )

                            EdgeGlowBand(
                                edge: .leading,
                                color: glowColor,
                                highlightColor: highlightColor,
                                depth: bandDepth,
                                intensity: edgeBandIntensity * 0.85
                            )

                            EdgeGlowBand(
                                edge: .trailing,
                                color: glowColor,
                                highlightColor: highlightColor,
                                depth: bandDepth,
                                intensity: edgeBandIntensity * 0.85
                            )

                            CornerGlowLayer(
                                color: glowColor,
                                highlightColor: highlightColor,
                                cornerDiameter: cornerDiameter,
                                intensity: cornerGlowIntensity
                            )
                        }
                        .padding(inset)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlightColor.opacity(hairlineOpacity), lineWidth: 0.9)
                    .blur(radius: 0.18)
                    .padding(inset)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(glowColor.opacity(accentStrokeOpacity), lineWidth: 1.1)
                    .blur(radius: accentStrokeBlur)
                    .padding(inset)
                    .shadow(color: glowColor.opacity(primaryGlowOpacity), radius: primaryGlowRadius)
                    .shadow(color: glowColor.opacity(secondaryGlowOpacity), radius: secondaryGlowRadius)
            }
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
        if reduceMotion {
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
            return isBusy ? 0.52 : 0.38
        }

        if isBusy {
            return isPulsing ? 0.68 : 0.44
        }

        return isPulsing ? 0.5 : 0.3
    }

    private var accentStrokeOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.36 : 0.24
        }

        if isBusy {
            return isPulsing ? 0.42 : 0.22
        }

        return isPulsing ? 0.28 : 0.14
    }

    private var accentStrokeBlur: CGFloat {
        if reduceMotion {
            return isBusy ? 1.8 : 1.2
        }

        if isBusy {
            return isPulsing ? 2.8 : 1.4
        }

        return isPulsing ? 2.0 : 1.0
    }

    private var edgeBandIntensity: Double {
        if reduceMotion {
            return isBusy ? 0.32 : 0.22
        }

        if isBusy {
            return isPulsing ? 0.44 : 0.24
        }

        return isPulsing ? 0.3 : 0.16
    }

    private var cornerGlowIntensity: Double {
        if reduceMotion {
            return isBusy ? 0.34 : 0.24
        }

        if isBusy {
            return isPulsing ? 0.48 : 0.26
        }

        return isPulsing ? 0.34 : 0.18
    }

    private var primaryGlowOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.26 : 0.16
        }

        if isBusy {
            return isPulsing ? 0.34 : 0.14
        }

        return isPulsing ? 0.22 : 0.1
    }

    private var secondaryGlowOpacity: Double {
        if reduceMotion {
            return isBusy ? 0.16 : 0.1
        }

        if isBusy {
            return isPulsing ? 0.2 : 0.08
        }

        return isPulsing ? 0.14 : 0.06
    }

    private var primaryGlowRadius: CGFloat {
        if reduceMotion {
            return isBusy ? 24 : 16
        }

        if isBusy {
            return isPulsing ? 30 : 16
        }

        return isPulsing ? 22 : 12
    }

    private var secondaryGlowRadius: CGFloat {
        if reduceMotion {
            return isBusy ? 38 : 24
        }

        if isBusy {
            return isPulsing ? 52 : 26
        }

        return isPulsing ? 34 : 18
    }

    private var containerOpacity: Double {
        if reduceMotion {
            return 0.98
        }

        return isBusy ? 0.98 : 0.92
    }
}

private struct EdgeGlowBand: View {
    let edge: Edge.Set
    let color: Color
    let highlightColor: Color
    let depth: CGFloat
    let intensity: Double

    var body: some View {
        edgeGradient
            .frame(
                width: edge == .leading || edge == .trailing ? depth : nil,
                height: edge == .top || edge == .bottom ? depth : nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .blendMode(.plusLighter)
    }

    private var edgeGradient: LinearGradient {
        switch edge {
        case .top:
            return LinearGradient(
                colors: [
                    highlightColor.opacity(intensity * 0.55),
                    color.opacity(intensity),
                    color.opacity(intensity * 0.28),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bottom:
            return LinearGradient(
                colors: [
                    highlightColor.opacity(intensity * 0.4),
                    color.opacity(intensity * 0.86),
                    color.opacity(intensity * 0.24),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        case .leading:
            return LinearGradient(
                colors: [
                    highlightColor.opacity(intensity * 0.4),
                    color.opacity(intensity * 0.88),
                    color.opacity(intensity * 0.2),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .trailing:
            return LinearGradient(
                colors: [
                    highlightColor.opacity(intensity * 0.4),
                    color.opacity(intensity * 0.88),
                    color.opacity(intensity * 0.2),
                    .clear
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
        default:
            return LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
        }
    }

    private var alignment: Alignment {
        switch edge {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        default:
            return .center
        }
    }
}

private struct CornerGlowLayer: View {
    let color: Color
    let highlightColor: Color
    let cornerDiameter: CGFloat
    let intensity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                glow
                    .position(x: cornerDiameter * 0.34, y: cornerDiameter * 0.34)

                glow
                    .position(x: proxy.size.width - cornerDiameter * 0.34, y: cornerDiameter * 0.34)

                glow
                    .position(x: cornerDiameter * 0.34, y: proxy.size.height - cornerDiameter * 0.34)

                glow
                    .position(
                        x: proxy.size.width - cornerDiameter * 0.34,
                        y: proxy.size.height - cornerDiameter * 0.34
                    )
            }
        }
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        highlightColor.opacity(intensity * 0.8),
                        color.opacity(intensity),
                        color.opacity(intensity * 0.35),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: cornerDiameter * 0.5
                )
            )
            .frame(width: cornerDiameter, height: cornerDiameter)
            .blendMode(.plusLighter)
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
