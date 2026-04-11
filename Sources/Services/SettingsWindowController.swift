import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var windowController: NSWindowController?

    func show(appModel: AppModel) {
        if let window = windowController?.window {
            AppLogger.settings.info("Reusing existing settings window.")
            refreshRootView(of: window, appModel: appModel)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(
            rootView: settingsRootView(appModel: appModel)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 560, height: 420))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        windowController = controller

        AppLogger.settings.info("Created settings window.")
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        if window === windowController?.window {
            AppLogger.settings.debug("Hiding settings window.")
            window.orderOut(nil)
        }
    }

    private func refreshRootView(of window: NSWindow, appModel: AppModel) {
        guard let hostingController = window.contentViewController as? NSHostingController<AnyView> else {
            return
        }

        hostingController.rootView = settingsRootView(appModel: appModel)
    }

    private func settingsRootView(appModel: AppModel) -> AnyView {
        AnyView(
            SettingsView(appModel: appModel)
                .frame(width: 520)
        )
    }
}
