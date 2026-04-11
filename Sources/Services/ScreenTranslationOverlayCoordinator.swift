import AppKit
import SwiftUI

@MainActor
final class ScreenTranslationOverlayCoordinator {
    private(set) var isPresented = false

    private var panelController: ScreenTranslationPanelController?
    private var closeHandler: (() -> Void)?

    func present(
        snapshot: CapturedDisplaySnapshot,
        appModel: AppModel,
        onClose: @escaping () -> Void
    ) {
        dismiss()

        guard let screen = targetScreen(for: snapshot.displayID) else {
            return
        }

        closeHandler = onClose
        isPresented = true

        NSApp.activate(ignoringOtherApps: true)

        let controller = ScreenTranslationPanelController(
            screen: screen,
            appModel: appModel,
            onClose: { [weak self] in
                self?.requestClose()
            }
        )

        panelController = controller
        controller.showWindow()
    }

    func dismiss() {
        panelController?.close()
        panelController = nil
        closeHandler = nil
        isPresented = false
    }

    private func requestClose() {
        let handler = closeHandler
        dismiss()
        handler?()
    }

    private func targetScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first(where: { $0.displayID == displayID })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

@MainActor
private final class ScreenTranslationPanelController {
    private let panel: ScreenTranslationPanel

    init(
        screen: NSScreen,
        appModel: AppModel,
        onClose: @escaping () -> Void
    ) {
        self.panel = ScreenTranslationPanel(
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
        panel.cancelHandler = onClose
        panel.contentView = NSHostingView(
            rootView: ScreenTranslationOverlayView(appModel: appModel)
        )
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
private final class ScreenTranslationPanel: NSPanel {
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
