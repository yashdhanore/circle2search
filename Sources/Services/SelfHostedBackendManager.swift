import Foundation
import Observation

enum SelfHostedBackendState {
    case unknown
    case reachable
    case unreachable
}

@MainActor
@Observable
final class SelfHostedBackendManager {
    var statusMessage = "Run ./script/run_backend.sh, then click Check Status."
    var lastErrorMessage: String?
    var state: SelfHostedBackendState = .unknown

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    var localBackendBaseURL: String {
        "http://127.0.0.1:8080"
    }

    func start() {
        Task {
            await refreshStatus()
        }
    }

    func refreshStatus() async {
        if await isLocalBackendReachable() {
            state = .reachable
            statusMessage = "Local backend is reachable on \(localBackendBaseURL)."
            lastErrorMessage = nil
            AppLogger.backend.info("Detected a reachable local backend on \(localBackendBaseURL).")
            return
        }

        state = .unreachable
        statusMessage = "Local backend is not reachable. Run ./script/run_backend.sh from the repo root, then click Check Status."
        lastErrorMessage = nil
        AppLogger.backend.debug("Local backend is not reachable on \(localBackendBaseURL).")
    }

    private func isLocalBackendReachable() async -> Bool {
        guard let url = URL(string: "\(localBackendBaseURL)/healthz") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5

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
