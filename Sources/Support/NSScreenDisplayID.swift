import AppKit
import CoreGraphics

extension NSScreen {
    var displayID: CGDirectDisplayID {
        guard let value = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }

        return CGDirectDisplayID(value.uint32Value)
    }
}
