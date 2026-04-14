import Foundation
import OSLog

struct AppLogChannel {
    private let logger: Logger
    private let category: String

    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        emitToDebugger(level: "debug", message: message)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        emitToDebugger(level: "info", message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        emitToDebugger(level: "error", message: message)
    }

    private func emitToDebugger(level: String, message: String) {
        #if DEBUG
        fputs("[CircleToSearch][\(category)][\(level)] \(message)\n", stderr)
        #endif
    }
}

enum AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.circle2search.app"

    static let app = AppLogChannel(subsystem: subsystem, category: "app")
    static let backend = AppLogChannel(subsystem: subsystem, category: "backend")
    static let launcher = AppLogChannel(subsystem: subsystem, category: "launcher")
    static let menuBar = AppLogChannel(subsystem: subsystem, category: "menuBar")
    static let settings = AppLogChannel(subsystem: subsystem, category: "settings")
    static let capture = AppLogChannel(subsystem: subsystem, category: "capture")
    static let ocr = AppLogChannel(subsystem: subsystem, category: "ocr")
    static let overlay = AppLogChannel(subsystem: subsystem, category: "overlay")
    static let translation = AppLogChannel(subsystem: subsystem, category: "translation")
}
