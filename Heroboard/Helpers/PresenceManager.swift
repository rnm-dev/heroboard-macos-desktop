import AppKit
import CoreGraphics
import Foundation

/// Sends presence heartbeats to Heroboard (HB-357) so desktop time merges with the plugin on the
/// shared per-user clock and never double-counts. Contract owned by the backend `/api/heartbeat`:
///
///   POST {BASE}/api/heartbeat
///   X-Api-Key: hb_…                       (the user's MCP key — set in Settings, stored in Keychain)
///   { "kind": "heartbeat", "host": "<machine>", "v": "<version>", "projectKey": "<optional>" }
///
/// Presence semantics (must match the plugin so the apps are interchangeable):
/// - Beat only while the user is actively present — any input within `idleThreshold`. Stop when idle.
///   (A menu-bar app is never the frontmost app, so we gate on machine presence, not window focus.)
/// - Cadence ~60s. Do not drop toward 30s: sub-0.9-min gaps round to 0 minutes and time is lost.
final class PresenceManager {
    /// Keychain account under which the MCP API key is stored.
    static let mcpKeyAccount = "mcp_api_key"

    private let cadence: TimeInterval = 60
    private let idleThreshold: TimeInterval = 5 * 60
    private let session = URLSession(configuration: .ephemeral)
    private var timer: Timer?

    func start() {
        stop()
        let timer = Timer(timeInterval: cadence, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Logging.default.log("Presence heartbeat started (cadence \(Int(cadence))s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isUserPresent else { return }
        guard let apiKey = KeychainStore.get(Self.mcpKeyAccount), !apiKey.isEmpty else {
            Logging.default.log("Presence heartbeat skipped: no MCP key set")
            return
        }
        send(apiKey: apiKey)
    }

    /// True when any input event occurred within the idle window.
    private var isUserPresent: Bool {
        secondsSinceLastInput() < idleThreshold
    }

    private func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }

    private func send(apiKey: String) {
        guard let url = URL(string: "\(AppEnvironment.current.webBaseURL)/api/heartbeat") else { return }

        var body: [String: Any] = [
            "kind": "heartbeat",
            "host": Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            "v": Bundle.main.version,
        ]
        // Desktop has no cwd/repo; attribute to a project only when one is known (none yet).
        if let projectKey = activeProjectKey, !projectKey.isEmpty {
            body["projectKey"] = projectKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { _, response, error in
            if let error {
                Logging.default.log("Presence heartbeat failed: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse else { return }

            switch http.statusCode {
                case 200: break
                case 401: Logging.default.log("Presence heartbeat unauthorized (401) — check MCP key")
                default: Logging.default.log("Presence heartbeat unexpected status \(http.statusCode)")
            }
        }.resume()
    }

    /// Currently-selected Heroboard project, if any. Desktop has no project context today, so this is
    /// nil and the server records presence as unattributed/personal. Hook for future attribution.
    private var activeProjectKey: String? { nil }
}
