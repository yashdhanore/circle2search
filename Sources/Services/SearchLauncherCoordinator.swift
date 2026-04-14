import AppKit
import SwiftUI

@MainActor
final class SearchLauncherCoordinator {
    private(set) var isPresented = false

    private var panelController: SearchLauncherPanelController?
    private var closeHandler: (() -> Void)?

    func present(
        appModel: AppModel,
        onClose: @escaping () -> Void
    ) {
        guard let screen = targetScreenUnderCursor() else {
            AppLogger.launcher.error("Could not determine a target screen for the launcher panel.")
            return
        }

        closeHandler = onClose
        isPresented = true

        if let panelController {
            AppLogger.launcher.info("Reusing existing launcher panel.")
            panelController.refresh(appModel: appModel, screen: screen)
            NSApp.activate(ignoringOtherApps: true)
            panelController.showWindow()
            return
        }

        AppLogger.launcher.info(
            "Presenting launcher panel on screen \(NSStringFromRect(screen.visibleFrame))."
        )

        let controller = SearchLauncherPanelController(
            screen: screen,
            appModel: appModel,
            onClose: { [weak self] in
                self?.requestClose()
            }
        )

        panelController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow()
    }

    func dismiss() {
        if isPresented {
            AppLogger.launcher.info("Dismissing launcher panel.")
        }

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

    private func targetScreenUnderCursor() -> NSScreen? {
        let cursorLocation = NSEvent.mouseLocation

        return NSScreen.screens.first(where: { $0.frame.contains(cursorLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

@MainActor
private final class SearchLauncherPanelController: NSObject, NSWindowDelegate {
    private let panelSize = NSSize(width: 700, height: 360)
    private let panel: SearchLauncherPanel
    private var isClosing = false

    init(
        screen: NSScreen,
        appModel: AppModel,
        onClose: @escaping () -> Void
    ) {
        self.panel = SearchLauncherPanel(
            contentRect: Self.panelFrame(on: screen, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        super.init()

        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        panel.animationBehavior = .utilityWindow
        panel.cancelHandler = onClose
        panel.delegate = self
        panel.setContentSize(panelSize)
        panel.contentViewController = NSHostingController(
            rootView: launcherRootView(appModel: appModel)
        )
    }

    func refresh(appModel: AppModel, screen: NSScreen) {
        panel.setFrame(Self.panelFrame(on: screen, size: panelSize), display: false)

        if let hostingController = panel.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = launcherRootView(appModel: appModel)
        }
    }

    func showWindow() {
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        isClosing = true
        panel.orderOut(nil)
        panel.close()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isClosing else {
            return
        }

        panel.cancelHandler?()
    }

    private func launcherRootView(appModel: AppModel) -> AnyView {
        AnyView(
            SearchLauncherView(appModel: appModel)
                .frame(width: panelSize.width, height: panelSize.height)
        )
    }

    private static func panelFrame(on screen: NSScreen, size: NSSize) -> CGRect {
        let visibleFrame = screen.visibleFrame

        return CGRect(
            x: round(visibleFrame.midX - (size.width / 2)),
            y: round(visibleFrame.midY - (size.height / 2)),
            width: size.width,
            height: size.height
        )
    }
}

@MainActor
private final class SearchLauncherPanel: NSPanel {
    var cancelHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelHandler?()
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        cancelHandler?()
    }
}
