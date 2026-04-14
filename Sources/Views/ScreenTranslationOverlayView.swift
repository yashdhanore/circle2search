import SwiftUI

struct ScreenTranslationOverlayView: View {
    let appModel: AppModel

    var body: some View {
        Group {
            if let session = appModel.currentScreenSession {
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        CaptureCanvasView(
                            appModel: appModel,
                            session: session
                        )
                        .id(session.id)

                        BottomSearchPanelView(
                            appModel: appModel,
                            session: session
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(20, proxy.size.height - session.snapshot.visibleContentLocalRect.maxY + 20))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                }
            } else {
                Color.clear
            }
        }
    }
}

private struct CaptureCanvasView: View {
    let appModel: AppModel
    let session: ScreenTranslationSession

    @State private var dragContext: SelectionDragContext?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                backgroundImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Color.black.opacity(baseDimOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if session.displayMode == .translated {
                    translatedLayer(session.renderedBlocks)
                        .allowsHitTesting(false)
                }

                if let selection = session.selection {
                    SelectionFocusMaskView(
                        canvasSize: proxy.size,
                        selectionRect: selection.rect
                    )
                    .allowsHitTesting(false)

                    SelectionOutlineView(selection: selection)
                        .allowsHitTesting(false)
                }

                ActiveCaptureEdgeGlowView(
                    isBusy: session.phase == .analyzing || session.phase == .translating
                )
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(selectionGesture(in: session.snapshot.visibleContentLocalRect))
            .clipped()
        }
    }

    private var backgroundImage: some View {
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

    private var baseDimOpacity: Double {
        session.selection == nil ? 0.04 : 0.02
    }

    private func selectionGesture(in visibleRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if dragContext == nil {
                    dragContext = SelectionDragContext(
                        startLocation: value.startLocation,
                        currentSelection: session.selection
                    )
                }

                guard let dragContext else {
                    return
                }

                appModel.updateSelectionRect(
                    dragContext.selectionRect(for: value.location, visibleRect: visibleRect),
                    mode: dragContext.selectionMode
                )
            }
            .onEnded { value in
                defer {
                    dragContext = nil
                }

                guard let dragContext else {
                    return
                }

                let totalTravel = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )

                if totalTravel < 4 {
                    switch dragContext.dragMode {
                    case .create:
                        if !appModel.selectTextCluster(near: value.startLocation) {
                            appModel.clearSelection()
                        }
                    case .move, .resize:
                        break
                    }
                    return
                }

                appModel.updateSelectionRect(
                    dragContext.selectionRect(for: value.location, visibleRect: visibleRect),
                    mode: dragContext.selectionMode
                )
            }
    }
}

private struct BottomSearchPanelView: View {
    let appModel: AppModel
    let session: ScreenTranslationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let selectionContext = appModel.selectedTextContext(for: session) {
                    Text("\(selectionContext.blocks.count) blocks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }

                Button("Search") {
                    appModel.activateSearchSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSearch(session))
                .keyboardShortcut(.defaultAction)

                if canTranslateSelection(session) {
                    Button("Translate Selection") {
                        appModel.activateTranslatedSelection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canTranslateSelection(session))
                }

                Button("Translate Screen") {
                    appModel.activateTranslatedScreen()
                }
                .buttonStyle(.bordered)
                .disabled(!canTranslateScreen(session))

                if session.hasRenderedTranslation {
                    Button("Original") {
                        appModel.showOriginalScreen()
                    }
                    .buttonStyle(.bordered)
                    .disabled(session.displayMode == .original)
                }

                Button("Close") {
                    appModel.closeCurrentScreenSession()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)

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

                Text(primaryStatusText(for: session))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: session))
                    .lineLimit(2)
            }

            if let previewText = appModel.selectionPreviewText(for: session) {
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.disabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 760)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 26, y: 12)
        .animation(.easeInOut(duration: 0.18), value: session.phase)
        .animation(.easeInOut(duration: 0.18), value: session.displayMode)
        .animation(.easeInOut(duration: 0.18), value: session.selection?.rect)
    }

    private func primaryStatusText(for session: ScreenTranslationSession) -> String {
        if let errorMessage = session.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        switch session.phase {
        case .analyzing:
            return session.hasSelection
                ? "Analyzing the visible screen. Search and translation will unlock when text is ready."
                : "Drag to select or wait for text recognition."
        case .ready:
            if let selectionContext = appModel.selectedTextContext(for: session) {
                return "Ready to search or translate \(selectionContext.blocks.count) text blocks."
            }

            if session.hasSelection {
                return "Selection does not contain readable text."
            }

            return session.hasRecognizedText
                ? "Drag to select or click text."
                : "No text was recognized on the visible screen."
        case .translating:
            return session.translationScope == .selection
                ? "Translating the selected text."
                : "Translating the visible screen."
        case .translated:
            return session.displayMode == .translated
                ? (session.translationScope == .selection
                    ? "Showing translated text in the selected area."
                    : "Showing translated text in place. You can still search a selection.")
                : "Showing the original screen."
        }
    }

    private func statusColor(for session: ScreenTranslationSession) -> Color {
        if let errorMessage = session.errorMessage, !errorMessage.isEmpty {
            return .red
        }

        return .secondary
    }

    private func canSearch(_ session: ScreenTranslationSession) -> Bool {
        guard session.phase != .analyzing, session.phase != .translating else {
            return false
        }

        return appModel.selectedTextContext(for: session) != nil
    }

    private func canTranslateScreen(_ session: ScreenTranslationSession) -> Bool {
        guard session.phase != .analyzing, session.phase != .translating else {
            return false
        }

        guard session.hasRecognizedText else {
            return false
        }

        return session.translationScope != .screen || session.displayMode != .translated || !session.hasRenderedTranslation
    }

    private func canTranslateSelection(_ session: ScreenTranslationSession) -> Bool {
        guard session.phase != .analyzing, session.phase != .translating else {
            return false
        }

        guard appModel.selectedTextContext(for: session) != nil else {
            return false
        }

        return session.translationScope != .selection || session.displayMode != .translated || !session.hasRenderedTranslation
    }
}

private struct SelectionFocusMaskView: View {
    let canvasSize: CGSize
    let selectionRect: CGRect

    var body: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: canvasSize))
            path.addRoundedRect(
                in: selectionRect,
                cornerSize: CGSize(width: 16, height: 16)
            )
        }
        .fill(Color.black.opacity(0.24), style: FillStyle(eoFill: true))
        .ignoresSafeArea()
    }
}

private struct SelectionOutlineView: View {
    let selection: ScreenSelection

    private let accentColor = Color(nsColor: .controlAccentColor)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(selection.mode == .textCluster ? 0.05 : 0.03))
                .frame(width: selection.rect.width, height: selection.rect.height)
                .position(x: selection.rect.midX, y: selection.rect.midY)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accentColor.opacity(0.95), lineWidth: 1.4)
                .frame(width: selection.rect.width, height: selection.rect.height)
                .position(x: selection.rect.midX, y: selection.rect.midY)
                .shadow(color: accentColor.opacity(0.28), radius: 18)

            ForEach(SelectionHandle.allCases, id: \.self) { handle in
                Circle()
                    .fill(.white)
                    .overlay {
                        Circle()
                            .strokeBorder(accentColor.opacity(0.9), lineWidth: 1.4)
                    }
                    .frame(width: 11, height: 11)
                    .position(handle.position(in: selection.rect))
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 1)
            }
        }
    }
}

private enum SelectionHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case trailing
    case bottomRight
    case bottom
    case bottomLeft
    case leading

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .trailing:
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .leading:
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    func hitRect(in rect: CGRect) -> CGRect {
        let handleSize: CGFloat = 22
        return CGRect(
            origin: CGPoint(
                x: position(in: rect).x - (handleSize / 2),
                y: position(in: rect).y - (handleSize / 2)
            ),
            size: CGSize(width: handleSize, height: handleSize)
        )
    }
}

private struct SelectionDragContext {
    let startLocation: CGPoint
    let dragMode: SelectionDragMode
    let selectionMode: ScreenSelectionMode

    init(startLocation: CGPoint, currentSelection: ScreenSelection?) {
        self.startLocation = startLocation

        if let currentSelection {
            if let handle = SelectionHandle.allCases.first(where: { $0.hitRect(in: currentSelection.rect).contains(startLocation) }) {
                self.dragMode = .resize(handle, currentSelection.rect)
                self.selectionMode = currentSelection.mode
                return
            }

            if currentSelection.rect.contains(startLocation) {
                self.dragMode = .move(currentSelection.rect, startLocation)
                self.selectionMode = currentSelection.mode
                return
            }
        }

        self.dragMode = .create(startLocation)
        self.selectionMode = .rectangle
    }

    func selectionRect(for currentLocation: CGPoint, visibleRect: CGRect) -> CGRect? {
        switch dragMode {
        case let .create(origin):
            return CGRect(
                x: min(origin.x, currentLocation.x),
                y: min(origin.y, currentLocation.y),
                width: abs(currentLocation.x - origin.x),
                height: abs(currentLocation.y - origin.y)
            )
        case let .move(initialRect, gestureOrigin):
            let deltaX = currentLocation.x - gestureOrigin.x
            let deltaY = currentLocation.y - gestureOrigin.y
            var movedRect = initialRect.offsetBy(dx: deltaX, dy: deltaY)

            if movedRect.minX < visibleRect.minX {
                movedRect.origin.x = visibleRect.minX
            }

            if movedRect.maxX > visibleRect.maxX {
                movedRect.origin.x = visibleRect.maxX - movedRect.width
            }

            if movedRect.minY < visibleRect.minY {
                movedRect.origin.y = visibleRect.minY
            }

            if movedRect.maxY > visibleRect.maxY {
                movedRect.origin.y = visibleRect.maxY - movedRect.height
            }

            return movedRect
        case let .resize(handle, initialRect):
            return resizedRect(
                from: initialRect,
                using: handle,
                currentLocation: currentLocation
            )
        }
    }

    private func resizedRect(
        from initialRect: CGRect,
        using handle: SelectionHandle,
        currentLocation: CGPoint
    ) -> CGRect {
        var minX = initialRect.minX
        var maxX = initialRect.maxX
        var minY = initialRect.minY
        var maxY = initialRect.maxY

        switch handle {
        case .topLeft:
            minX = currentLocation.x
            minY = currentLocation.y
        case .top:
            minY = currentLocation.y
        case .topRight:
            maxX = currentLocation.x
            minY = currentLocation.y
        case .trailing:
            maxX = currentLocation.x
        case .bottomRight:
            maxX = currentLocation.x
            maxY = currentLocation.y
        case .bottom:
            maxY = currentLocation.y
        case .bottomLeft:
            minX = currentLocation.x
            maxY = currentLocation.y
        case .leading:
            minX = currentLocation.x
        }

        return CGRect(
            x: min(minX, maxX),
            y: min(minY, maxY),
            width: abs(maxX - minX),
            height: abs(maxY - minY)
        )
    }
}

private enum SelectionDragMode {
    case create(CGPoint)
    case move(CGRect, CGPoint)
    case resize(SelectionHandle, CGRect)
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
