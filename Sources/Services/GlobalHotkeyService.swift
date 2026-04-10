import Carbon
import Foundation

final class GlobalHotkeyService {
    static let defaultShortcutDescription = "Control-Shift-Space"

    var onTrigger: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func registerDefaultShortcut() throws {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            throw GlobalHotkeyError.installFailed(status)
        }

        let hotKeyID = EventHotKeyID(signature: fourCharCode(from: "C2SR"), id: 1)
        let modifiers = UInt32(controlKey) | UInt32(shiftKey)

        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            throw GlobalHotkeyError.registerFailed(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    @MainActor
    fileprivate func handleTrigger() {
        onTrigger?()
    }

    deinit {
        unregister()
    }
}

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else {
        return noErr
    }

    let opaqueAddress = UInt(bitPattern: userData)

    Task { @MainActor in
        guard let pointer = UnsafeMutableRawPointer(bitPattern: opaqueAddress) else {
            return
        }

        let service = Unmanaged<GlobalHotkeyService>
            .fromOpaque(pointer)
            .takeUnretainedValue()
        service.handleTrigger()
    }

    return noErr
}

private func fourCharCode(from string: String) -> OSType {
    string.utf8.reduce(0) { partialResult, scalar in
        (partialResult << 8) + OSType(scalar)
    }
}

enum GlobalHotkeyError: LocalizedError {
    case installFailed(OSStatus)
    case registerFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .installFailed(status):
            return "The app could not install the global hotkey handler. OSStatus: \(status)."
        case let .registerFailed(status):
            return "The app could not register the global hotkey. OSStatus: \(status)."
        }
    }
}
