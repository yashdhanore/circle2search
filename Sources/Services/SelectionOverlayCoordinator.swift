import AppKit
import SwiftUI

@MainActor
final class SelectionOverlayCoordinator {
    private(set) var isPresented = false

    private var panelControllers: [SelectionOverlayPanelController] = []
    private var selectionHandler: ((ScreenSelection) -> Void)?
    private var cancelHandler: (() -> Void)?

    func presentSelection(
        onSelection: @escaping (ScreenSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard !isPresented else {
            return
        }

        selectionHandler = onSelection
        cancelHandler = onCancel
        isPresented = true

        NSApp.activate(ignoringOtherApps: true)

        let screens = NSScreen.screens
        panelControllers = screens.map { screen in
            SelectionOverlayPanelController(
                screen: screen,
                onSelection: { [weak self] selection in
                    self?.complete(with: selection)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )
        }

        panelControllers.forEach { $0.showWindow() }
    }

    func dismiss() {
        panelControllers.forEach { $0.close() }
        panelControllers.removeAll()
        selectionHandler = nil
        cancelHandler = nil
        isPresented = false
    }

    private func complete(with selection: ScreenSelection) {
        let handler = selectionHandler
        dismiss()
        handler?(selection)
    }

    private func cancel() {
        let handler = cancelHandler
        dismiss()
        handler?()
    }
}

@MainActor
private final class SelectionOverlayPanelController {
    private let panel: SelectionOverlayPanel

    init(
        screen: NSScreen,
        onSelection: @escaping (ScreenSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.panel = SelectionOverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.cancelHandler = onCancel

        let rootView = SelectionOverlayView(
            screenFrame: screen.frame,
            onSelection: { rectInScreenCoordinates in
                onSelection(
                    ScreenSelection(
                        displayID: screen.displayID,
                        rectInScreenCoordinates: rectInScreenCoordinates
                    )
                )
            },
            onCancel: onCancel
        )

        panel.contentView = NSHostingView(rootView: rootView)
    }

    func showWindow() {
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}

@MainActor
private final class SelectionOverlayPanel: NSPanel {
    var cancelHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelHandler?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        cancelHandler?()
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        guard let value = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }

        return CGDirectDisplayID(value.uint32Value)
    }
}
