import AppKit
import CoreGraphics
import Foundation

/// Emits presence heartbeats (HB-357) so desktop time merges with the plugin on the shared
/// per-user clock and never double-counts. Beats ~every 60s while the user is actively present
/// (any input within the idle window); stops when idle. The POST is done by HeartbeatClient.
///
/// A menu-bar app is never the frontmost app, so presence is gated on machine activity, not window
/// focus. Cadence stays ~60s: sub-0.9-min gaps round to 0 minutes and time is lost.
final class PresenceManager {
    private let cadence: TimeInterval = 60
    private let idleThreshold: TimeInterval = 5 * 60
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

        var body: [String: Any] = ["type": "presence"]
        if let projectKey = activeProjectKey, !projectKey.isEmpty {
            body["projectKey"] = projectKey
        }
        HeartbeatClient.shared.send(body)
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

    /// Currently-selected Heroboard project, if any. Desktop has no project context today, so this
    /// is nil and the server records presence as unattributed/personal. Hook for future attribution.
    private var activeProjectKey: String? { nil }
}
