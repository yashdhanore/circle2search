import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onPrimaryAction: @MainActor () -> Void
    private let onOpenSettings: @MainActor () -> Void

    private lazy var menu: NSMenu = {
        let menu = NSMenu()

        let translateItem = NSMenuItem(
            title: "Search or Translate Screen",
            action: #selector(performPrimaryAction),
            keyEquivalent: ""
        )
        translateItem.target = self
        menu.addItem(translateItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Circle to Search",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }()

    init(
        onPrimaryAction: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void
    ) {
        self.onPrimaryAction = onPrimaryAction
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: "magnifyingglass.circle",
            accessibilityDescription: "Circle to Search"
        )
        button.image?.isTemplate = true
        button.toolTip = "Search or translate the visible screen"
        button.target = self
        button.action = #selector(handleStatusItemPress(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc
    private func handleStatusItemPress(_ sender: NSStatusBarButton) {
        let currentEvent = NSApp.currentEvent
        let isSecondaryClick = currentEvent?.type == .rightMouseUp
            || currentEvent?.modifierFlags.contains(.control) == true

        if isSecondaryClick {
            AppLogger.menuBar.info("Opened status item context menu.")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }

        performPrimaryAction()
    }

    @objc
    private func performPrimaryAction() {
        AppLogger.menuBar.info("Triggered screen search overlay from status item.")
        Task { @MainActor in
            onPrimaryAction()
        }
    }

    @objc
    private func openSettings() {
        AppLogger.settings.info("Opening settings from status item.")
        Task { @MainActor in
            onOpenSettings()
        }
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
