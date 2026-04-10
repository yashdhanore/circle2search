import SwiftUI

struct SelectionOverlayView: View {
    let screenFrame: CGRect
    let backgroundImage: CGImage?
    let imageScale: CGFloat
    let onSelection: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                backgroundLayer
                    .ignoresSafeArea()

                dimmingLayer

                if let selectionRect = selectionRect {
                    selectionShape(in: selectionRect)
                }

                instructionCard
                    .opacity(selectionRect == nil ? 1 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        dragStart = dragStart ?? value.startLocation
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        dragCurrent = value.location

                        guard let selectionRect, selectionRect.width > 8, selectionRect.height > 8 else {
                            resetSelection()
                            return
                        }

                        onSelection(convertToScreenCoordinates(selectionRect, viewHeight: proxy.size.height))
                        resetSelection()
                    }
            )
            .onTapGesture(count: 2) {
                onCancel()
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let backgroundImage {
            Image(decorative: backgroundImage, scale: imageScale, orientation: .up)
                .resizable()
                .interpolation(.high)
        } else {
            Color.black
        }
    }

    private var dimmingLayer: some View {
        ZStack {
            Color.black.opacity(0.38)

            if let selectionRect {
                Rectangle()
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(x: selectionRect.midX, y: selectionRect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    private var selectionRect: CGRect? {
        guard let dragStart, let dragCurrent else {
            return nil
        }

        return CGRect(
            x: min(dragStart.x, dragCurrent.x),
            y: min(dragStart.y, dragCurrent.y),
            width: abs(dragCurrent.x - dragStart.x),
            height: abs(dragCurrent.y - dragStart.y)
        )
    }

    @ViewBuilder
    private func selectionShape(in rect: CGRect) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private var instructionCard: some View {
        VStack(spacing: 8) {
            Text("Drag to choose an area")
                .font(.headline)

            Text("Press Esc to cancel. Double-click anywhere to dismiss the overlay.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func convertToScreenCoordinates(_ localRect: CGRect, viewHeight: CGFloat) -> CGRect {
        CGRect(
            x: screenFrame.minX + localRect.minX,
            y: screenFrame.minY + (viewHeight - localRect.maxY),
            width: localRect.width,
            height: localRect.height
        )
    }

    private func resetSelection() {
        dragStart = nil
        dragCurrent = nil
    }
}
