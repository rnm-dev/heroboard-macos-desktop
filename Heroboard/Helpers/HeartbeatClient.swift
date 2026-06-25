import AppKit
import Foundation

/// In-process heartbeat transport (replaces the bundled heroboard-cli). POSTs to
/// `{BASE}/api/heartbeat` with the signed-in credential as `X-Api-Key`.
///
/// Universal contract (HB-367/369): every beat carries `type`, `time`, `client:"macos"`, and is
/// human-initiated (no `initiator`):
///   - `presence` — focus ping (`host`, `v`, `client`, optional `projectKey`), ~every 60s while active.
///   - `activity` — enriched with what the user is doing (entity, entity_type, category, app,
///     app_version, is_write, and when available language). macOS is the sole enrichment producer.
///
/// Offline-safe: on a network error or 5xx the beat is persisted to `HeartbeatQueue` and retried;
/// a successful send drains the backlog (oldest first). 4xx (bad key / rejected payload) is dropped
/// rather than retried, so the queue can't fill with beats the server will never accept.
final class HeartbeatClient {
    static let shared = HeartbeatClient()

    private let session = URLSession(configuration: .ephemeral)
    private let queue = HeartbeatQueue()
    private let serial = DispatchQueue(label: "com.heroboard.HeartbeatClient")
    private var flushing = false

    private enum SendResult { case success, retry, drop }

    /// Sends a heartbeat. `time` is stamped if absent so it survives offline replay.
    func send(_ fields: [String: Any]) {
        var body = fields
        if body["time"] == nil { body["time"] = Int(Date().timeIntervalSince1970) }

        post(body) { [weak self] result in
            guard let self else { return }

            switch result {
                case .success: self.flush()
                case .retry: self.queue.enqueue(body)
                case .drop: break
            }
        }
    }

    /// Retry queued heartbeats, oldest first, until one fails (then stop and wait).
    func flush() {
        serial.async {
            guard !self.flushing, !self.queue.isEmpty else { return }

            self.flushing = true
            self.flushStep()
        }
    }

    // Always runs on `serial`.
    private func flushStep() {
        guard let item = queue.first() else {
            flushing = false
            return
        }

        post(item) { [weak self] result in
            guard let self else { return }

            self.serial.async {
                switch result {
                    case .success, .drop:
                        self.queue.removeFirst()
                        self.flushStep()
                    case .retry:
                        self.flushing = false
                }
            }
        }
    }

    private func post(_ body: [String: Any], completion: @escaping (SendResult) -> Void) {
        guard
            let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key"),
            !apiKey.isEmpty
        else {
            completion(.drop)
            return
        }

        guard let url = URL(string: "\(AppEnvironment.current.webBaseURL)/api/heartbeat") else {
            completion(.drop)
            return
        }

        var enriched = body
        enriched["client"] = "macos"
        enriched["host"] = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        enriched["v"] = Bundle.main.version

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: enriched)

        session.dataTask(with: request) { data, response, error in
            if let error {
                Logging.default.log("Heartbeat failed, queued for retry: \(error.localizedDescription)")
                completion(.retry)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.retry)
                return
            }

            switch http.statusCode {
                case 200:
                    HeartbeatStats.shared.recordSent()
                    if let data { Session.shared.apply(data) }
                    completion(.success)
                case 401:
                    Logging.default.log("Heartbeat unauthorized (401) — signing out")
                    Session.shared.signOut()
                    completion(.drop)
                case 500...599:
                    Logging.default.log("Heartbeat server error \(http.statusCode), queued for retry")
                    completion(.retry)
                default:
                    Logging.default.log("Heartbeat rejected (\(http.statusCode)), dropped")
                    completion(.drop)
            }
        }.resume()
    }

    /// On-demand refresh of identity / today / hero via `GET /api/heartbeat` (no beat recorded).
    /// Used on window focus and after sign-in.
    func refresh() {
        guard
            let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key"),
            !apiKey.isEmpty,
            let url = URL(string: "\(AppEnvironment.current.webBaseURL)/api/heartbeat")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        session.dataTask(with: request) { data, response, _ in
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 200, let data {
                Session.shared.apply(data)
            } else if http.statusCode == 401 {
                Session.shared.signOut()
            }
        }.resume()
    }
}
