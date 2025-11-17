import Foundation
import AppKit

struct AuthenticationResponse: Codable {
    let result: String
    let data: AuthenticationData?
}

struct AuthenticationData: Codable {
    let apiKey: String
    let userEmail: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case userEmail = "user_email"
    }
}

class AuthenticationManager {
    static let shared = AuthenticationManager()

    private let authBaseURL = "https://heroboard.app/desktop/auth"
    private let apiBaseURL = "https://api.heroboard.app/api/v1/desktop/auth_decisions/api_key"
    private let pollInterval: TimeInterval = 1.0 // 1 second
    private let pollDuration: TimeInterval = 60.0 // 1 minute

    private var pollingTimer: Timer?
    private var pollingStartTime: Date?

    private init() {}

    /// Starts the authentication flow
    /// - Parameter completion: Called when authentication completes (success or failure)
    func authenticate(completion: @escaping (Result<AuthenticationData, Error>) -> Void) {
        // Generate UUID for this authentication session
        let desktopHash = UUID().uuidString

        // Open browser with auth URL
        openAuthenticationURL(desktopHash: desktopHash)

        // Start polling for authentication result
        startPolling(desktopHash: desktopHash, completion: completion)
    }

    /// Opens the authentication URL in the default browser
    private func openAuthenticationURL(desktopHash: String) {
        guard let url = URL(string: "\(authBaseURL)?desktop_hash=\(desktopHash)") else {
            Logging.default.log("Failed to create authentication URL", type: .error)
            return
        }

        NSWorkspace.shared.open(url)
        Logging.default.log("Opened authentication URL in browser", type: .info)
    }

    /// Starts polling the API for authentication status
    private func startPolling(desktopHash: String, completion: @escaping (Result<AuthenticationData, Error>) -> Void) {
        pollingStartTime = Date()

        // Poll immediately first time
        checkAuthenticationStatus(desktopHash: desktopHash, completion: completion)

        // Then set up timer for subsequent polls
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // Check if we've exceeded the poll duration
            if let startTime = self.pollingStartTime,
               Date().timeIntervalSince(startTime) > self.pollDuration {
                self.stopPolling()
                completion(.failure(AuthenticationError.timeout))
                return
            }

            self.checkAuthenticationStatus(desktopHash: desktopHash, completion: completion)
        }
    }

    /// Checks the authentication status via API
    private func checkAuthenticationStatus(desktopHash: String, completion: @escaping (Result<AuthenticationData, Error>) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)?desktop_hash=\(desktopHash)") else {
            Logging.default.log("Failed to create API URL", type: .error)
            completion(.failure(AuthenticationError.invalidURL))
            stopPolling()
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            // Check for network errors
            if let error = error {
                // Don't stop polling on network errors, just log them
                Logging.default.log("Network error while checking auth status: \(error.localizedDescription)", type: .error)
                return
            }

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                Logging.default.log("Invalid response type", type: .error)
                return
            }

            // If we get 404 or similar, the auth decision isn't ready yet - keep polling
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode != 404 {
                    Logging.default.log("Auth status check returned status code: \(httpResponse.statusCode)", type: .default)
                }
                return
            }

            // Parse response
            guard let data = data else {
                Logging.default.log("No data in response", type: .error)
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(AuthenticationResponse.self, from: data)

                if response.result == "success", let authData = response.data {
                    // Success! Stop polling and return the data
                    self.stopPolling()
                    DispatchQueue.main.async {
                        completion(.success(authData))
                    }
                    Logging.default.log("Authentication successful for user: \(authData.userEmail)", type: .info)
                } else {
                    // Unexpected response format, keep polling
                    Logging.default.log("Unexpected response format: \(response.result)", type: .default)
                }
            } catch {
                Logging.default.log("Failed to decode authentication response: \(error.localizedDescription)", type: .error)
                // Keep polling in case of decode errors
            }
        }

        task.resume()
    }

    /// Stops the polling timer
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        pollingStartTime = nil
    }

    /// Cancels any ongoing authentication attempts
    func cancelAuthentication() {
        stopPolling()
        Logging.default.log("Authentication cancelled", type: .info)
    }
}

enum AuthenticationError: LocalizedError {
    case timeout
    case invalidURL
    case networkError(String)

    var errorDescription: String? {
        switch self {
            case .timeout:
                return "Authentication timed out. Please try again."
            case .invalidURL:
                return "Invalid authentication URL."
            case .networkError(let message):
                return "Network error: \(message)"
        }
    }
}
