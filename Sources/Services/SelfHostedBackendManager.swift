import AppKit
import Foundation
import Observation

enum SelfHostedBackendState {
    case notConfigured
    case readyToStart
    case starting
    case running
    case failed
}

enum SelfHostedBackendError: LocalizedError {
    case missingGoogleAPIKey
    case missingBundledBackendTemplate
    case missingBundledBackendRuntime
    case nodeRuntimeUnavailable
    case workingDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .missingGoogleAPIKey:
            return "Paste your Google Translate API key before starting the local backend."
        case .missingBundledBackendTemplate:
            return "This app build does not include the local backend files. Rebuild the Open Source app and try again."
        case .missingBundledBackendRuntime:
            return "This build does not include the packaged local backend runtime. Install Node.js for a source build, or use the packaged Open Source app."
        case .nodeRuntimeUnavailable:
            return "This source build needs Node.js 20 or newer because it does not include the packaged local backend runtime."
        case .workingDirectoryUnavailable:
            return "The local backend working directory could not be prepared."
        }
    }
}

@MainActor
@Observable
final class SelfHostedBackendManager {
    var googleAPIKey: String {
        didSet {
            persistGoogleAPIKey()
            handleGoogleAPIKeyChange()
        }
    }

    var statusMessage: String
    var lastErrorMessage: String?
    var lastPersistenceError: String?
    var lastLogLine: String?
    var isNodeRuntimeAvailable = false
    var localBackendState: SelfHostedBackendState

    private let keychainStore: KeychainStore
    private let fileManager: FileManager
    private let bundle: Bundle
    private let urlSession: URLSession
    private var autoStartTask: Task<Void, Never>?
    private var backendProcess: Process?
    private var backendOutputPipe: Pipe?
    private var stopWasRequested = false

    private enum Keys {
        static let googleAPIKeyAccount = "openSource.selfHosted.googleAPIKey"
    }

    private struct LaunchSpec {
        let executableURL: URL
        let arguments: [String]
        let workingDirectoryURL: URL
    }

    init(
        keychainStore: KeychainStore,
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        urlSession: URLSession = .shared
    ) {
        self.keychainStore = keychainStore
        self.fileManager = fileManager
        self.bundle = bundle
        self.urlSession = urlSession
        self.googleAPIKey = (try? keychainStore.string(for: Keys.googleAPIKeyAccount)) ?? ""
        self.statusMessage = "Paste your Google Translate API key to set up the local backend."
        self.localBackendState = .notConfigured

        updateStatusForCurrentState()
    }

    var localBackendBaseURL: String {
        "http://127.0.0.1:8080"
    }

    private var hasBundledBackendRuntime: Bool {
        bundledRuntimeExecutableURL() != nil
    }

    func start() {
        Task {
            await refreshStatus(allowAutoStart: true)
        }
    }

    func refreshStatus() async {
        await refreshStatus(allowAutoStart: false)
    }

    func refreshStatus(allowAutoStart: Bool) async {
        let launchSpecAvailable: Bool
        if hasBundledBackendRuntime {
            isNodeRuntimeAvailable = true
            launchSpecAvailable = true
        } else {
            isNodeRuntimeAvailable = await detectNodeRuntimeAvailability()
            launchSpecAvailable = (try? currentLaunchSpec()) != nil
        }

        if await isLocalBackendReachable() {
            localBackendState = .running
            statusMessage = "Local backend is running on this Mac."
            lastErrorMessage = nil
            return
        }

        if localBackendState == .starting {
            return
        }

        if backendProcess?.isRunning == true {
            localBackendState = .running
            statusMessage = "Local backend is starting on this Mac..."
            return
        }

        if allowAutoStart {
            let trimmedAPIKey = googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedAPIKey.isEmpty, launchSpecAvailable {
                await startLocalBackend()
                return
            }
        }

        updateStatusForCurrentState()
    }

    func startLocalBackend() async {
        let trimmedAPIKey = googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            localBackendState = .failed
            lastErrorMessage = SelfHostedBackendError.missingGoogleAPIKey.localizedDescription
            statusMessage = "A Google Translate API key is required."
            return
        }

        if await isLocalBackendReachable(), backendProcess?.isRunning != true {
            localBackendState = .running
            statusMessage = "Local backend is already running on this Mac."
            lastErrorMessage = nil
            AppLogger.backend.info("Detected an already-running local self-hosted backend.")
            return
        }

        if !hasBundledBackendRuntime {
            isNodeRuntimeAvailable = await detectNodeRuntimeAvailability()
        } else {
            isNodeRuntimeAvailable = true
        }

        let launchSpec: LaunchSpec
        do {
            launchSpec = try currentLaunchSpec()
        } catch {
            localBackendState = .failed
            lastErrorMessage = error.localizedDescription
            statusMessage = "Local backend is unavailable in this build."
            AppLogger.backend.error("Could not resolve a local backend runtime: \(error.localizedDescription)")
            return
        }

        localBackendState = .starting
        lastErrorMessage = nil
        statusMessage = "Starting the local backend on this Mac..."
        AppLogger.backend.info("Preparing the local self-hosted backend.")

        do {
            try launchLocalBackend(using: launchSpec, googleAPIKey: trimmedAPIKey)

            let becameHealthy = await waitForLocalBackendHealth(timeoutSeconds: 8)
            if becameHealthy {
                localBackendState = .running
                statusMessage = "Local backend is running on this Mac."
                lastErrorMessage = nil
                AppLogger.backend.info("Local self-hosted backend is healthy.")
            } else {
                localBackendState = .failed
                lastErrorMessage = "The local backend was launched, but it did not become ready."
                statusMessage = "The local backend did not become ready."
                AppLogger.backend.error("Local self-hosted backend did not become healthy in time.")
            }
        } catch {
            localBackendState = .failed
            lastErrorMessage = error.localizedDescription
            statusMessage = "Local backend start failed."
            AppLogger.backend.error("Local self-hosted backend failed to start: \(error.localizedDescription)")
        }
    }

    func stopLocalBackend() {
        guard let backendProcess else {
            updateStatusForCurrentState()
            return
        }

        stopWasRequested = true
        if backendProcess.isRunning {
            AppLogger.backend.info("Stopping the local self-hosted backend.")
            backendProcess.terminate()
        } else {
            cleanupProcessReferences()
            updateStatusForCurrentState()
        }
    }

    func openNodeDownloadPage() {
        guard let url = URL(string: "https://nodejs.org/en/download") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openLocalBackendFolder() {
        guard let backendDirectory = try? workingBackendDirectory() else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([backendDirectory])
    }

    private func persistGoogleAPIKey() {
        do {
            let trimmedKey = googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedKey.isEmpty {
                try keychainStore.removeValue(for: Keys.googleAPIKeyAccount)
            } else {
                try keychainStore.set(trimmedKey, for: Keys.googleAPIKeyAccount)
            }

            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
            AppLogger.backend.error("Failed to persist the self-hosted Google API key: \(error.localizedDescription)")
        }
    }

    private func handleGoogleAPIKeyChange() {
        autoStartTask?.cancel()

        let trimmedKey = googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            if backendProcess?.isRunning == true {
                stopLocalBackend()
            }
            updateStatusForCurrentState()
            return
        }

        if localBackendState != .starting {
            updateStatusForCurrentState()
        }

        autoStartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self else {
                return
            }

            if Task.isCancelled {
                return
            }

            await self.startLocalBackend()
        }
    }

    private func prepareBundledBackend() throws -> URL {
        guard let templateDirectory = bundledBackendTemplateDirectory() else {
            throw SelfHostedBackendError.missingBundledBackendTemplate
        }

        let workingDirectory = try workingBackendDirectory()
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        try syncDirectory(from: templateDirectory, to: workingDirectory)
        return workingDirectory
    }

    private func bundledBackendTemplateDirectory() -> URL? {
        let resourceCandidates = [
            bundle.resourceURL?.appendingPathComponent("backend", isDirectory: true),
            bundle.url(forResource: "backend", withExtension: nil),
        ]

        for candidate in resourceCandidates.compactMap({ $0 }) {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }

        return nil
    }

    private func bundledRuntimeExecutableURL() -> URL? {
        let resourceCandidates = [
            bundle.resourceURL?.appendingPathComponent("OpenSourceRuntime", isDirectory: true)
                .appendingPathComponent("circle2search-local-backend", isDirectory: false),
            bundle.resourceURL?.appendingPathComponent("circle2search-local-backend", isDirectory: false),
        ]

        for candidate in resourceCandidates.compactMap({ $0 }) {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func currentLaunchSpec() throws -> LaunchSpec {
        if let bundledRuntimeExecutableURL = bundledRuntimeExecutableURL() {
            return LaunchSpec(
                executableURL: bundledRuntimeExecutableURL,
                arguments: [],
                workingDirectoryURL: bundledRuntimeExecutableURL.deletingLastPathComponent()
            )
        }

        guard let backendDirectory = try? prepareBundledBackend() else {
            throw SelfHostedBackendError.missingBundledBackendTemplate
        }

        let nodeRuntimeAvailable = awaitableNodeRuntimeAvailabilityCache()
        guard nodeRuntimeAvailable else {
            throw SelfHostedBackendError.nodeRuntimeUnavailable
        }

        return LaunchSpec(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["node", "src/server.js"],
            workingDirectoryURL: backendDirectory
        )
    }

    private func workingBackendDirectory() throws -> URL {
        guard let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SelfHostedBackendError.workingDirectoryUnavailable
        }

        return applicationSupportDirectory
            .appendingPathComponent(AppRuntimeConfiguration.bundleIdentifier, isDirectory: true)
            .appendingPathComponent("SelfHostedBackend", isDirectory: true)
            .appendingPathComponent("backend", isDirectory: true)
    }

    private func syncDirectory(from sourceDirectory: URL, to destinationDirectory: URL) throws {
        let sourceItems = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for sourceItem in sourceItems {
            let destinationItem = destinationDirectory.appendingPathComponent(sourceItem.lastPathComponent, isDirectory: false)
            let resourceValues = try sourceItem.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                try fileManager.createDirectory(at: destinationItem, withIntermediateDirectories: true)
                try syncDirectory(from: sourceItem, to: destinationItem)
                continue
            }

            if fileManager.fileExists(atPath: destinationItem.path) {
                try fileManager.removeItem(at: destinationItem)
            }

            try fileManager.copyItem(at: sourceItem, to: destinationItem)
        }
    }

    private func launchLocalBackend(using launchSpec: LaunchSpec, googleAPIKey: String) throws {
        if backendProcess?.isRunning == true {
            stopWasRequested = true
            backendProcess?.terminate()
            backendProcess?.waitUntilExit()
            cleanupProcessReferences()
        } else {
            cleanupProcessReferences()
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = launchSpec.executableURL
        process.arguments = launchSpec.arguments
        process.currentDirectoryURL = launchSpec.workingDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.environment = makeBackendEnvironment(googleAPIKey: googleAPIKey)

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else {
                return
            }

            Task { @MainActor in
                self?.consumeBackendOutput(output)
            }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleBackendTermination(process)
            }
        }

        try process.run()
        backendProcess = process
        backendOutputPipe = outputPipe
        stopWasRequested = false
        AppLogger.backend.info("Launched local self-hosted backend process.")
    }

    private func makeBackendEnvironment(googleAPIKey: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PORT"] = "8080"
        environment["GOOGLE_TRANSLATE_API_KEY"] = googleAPIKey
        environment["GOOGLE_TRANSLATE_BASIC_ENDPOINT"] = "translation.googleapis.com"
        environment["GOOGLE_TRANSLATE_LABELS_JSON"] = #"{"app":"circle2search","surface":"screen_translate"}"#
        environment["TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH"] = "true"
        environment["TRANSLATE_SHARED_SECRET"] = ""
        environment["APP_STORE_EXPECTED_BUNDLE_ID"] = AppRuntimeConfiguration.bundleIdentifier
        return environment
    }

    private func awaitableNodeRuntimeAvailabilityCache() -> Bool {
        isNodeRuntimeAvailable
    }

    private func consumeBackendOutput(_ output: String) {
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else {
            return
        }

        lastLogLine = lastLine
        AppLogger.backend.debug(lastLine)
    }

    private func handleBackendTermination(_ process: Process) {
        cleanupProcessReferences()

        if stopWasRequested {
            stopWasRequested = false
            lastErrorMessage = nil
            updateStatusForCurrentState()
            AppLogger.backend.info("Local self-hosted backend stopped cleanly.")
            return
        }

        localBackendState = .failed
        statusMessage = "Local backend stopped unexpectedly."
        lastErrorMessage = lastLogLine ?? "The local backend exited with status \(process.terminationStatus)."
        AppLogger.backend.error("Local self-hosted backend exited unexpectedly with status \(process.terminationStatus).")
    }

    private func cleanupProcessReferences() {
        backendOutputPipe?.fileHandleForReading.readabilityHandler = nil
        backendOutputPipe = nil
        backendProcess = nil
    }

    private func updateStatusForCurrentState() {
        let trimmedAPIKey = googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedAPIKey.isEmpty {
            localBackendState = .notConfigured
            statusMessage = "Paste your Google Translate API key to set up the local backend."
            return
        }

        if bundledRuntimeExecutableURL() != nil {
            localBackendState = .readyToStart
            statusMessage = "CircleToSearch will start the local backend automatically on this Mac."
            return
        }

        if !isNodeRuntimeAvailable {
            localBackendState = .failed
            statusMessage = "This source build needs Node.js because no packaged local backend runtime is bundled."
            return
        }

        localBackendState = .readyToStart
        statusMessage = "This source build will start the local backend automatically using Node.js."
    }

    private func detectNodeRuntimeAvailability() async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", "--version"]
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    private func waitForLocalBackendHealth(timeoutSeconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if await isLocalBackendReachable() {
                return true
            }

            try? await Task.sleep(for: .milliseconds(250))
        }

        return false
    }

    private func isLocalBackendReachable() async -> Bool {
        guard let url = URL(string: "\(localBackendBaseURL)/healthz") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.httpMethod = "GET"

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}
