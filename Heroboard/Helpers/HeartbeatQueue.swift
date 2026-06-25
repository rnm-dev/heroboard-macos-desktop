import Foundation

/// Disk-backed FIFO queue of heartbeats that failed to send (offline / server error), so they can
/// be retried later. Stored as JSON in the app's resources folder (`~/.heroboard[-dev]/`). Each
/// entry is a heartbeat body that already carries its own `time`, so replayed beats attribute to
/// when they actually happened. Bounded by count and age to avoid unbounded growth.
final class HeartbeatQueue {
    private let fileURL: URL
    private let lock = NSLock()
    private var items: [[String: Any]]

    private let maxItems = 1000
    private let maxAgeSeconds: TimeInterval = 7 * 24 * 3600

    init() {
        let dir = NSString.path(withComponents: ConfigFile.resourcesFolder)
        fileURL = URL(fileURLWithPath: dir).appendingPathComponent("heartbeat-queue.json")
        items = HeartbeatQueue.load(fileURL)
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return items.isEmpty
    }

    func enqueue(_ body: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        items.append(body)
        prune()
        persist()
    }

    func first() -> [String: Any]? {
        lock.lock(); defer { lock.unlock() }
        return items.first
    }

    func removeFirst() {
        lock.lock(); defer { lock.unlock() }
        if !items.isEmpty { items.removeFirst() }
        persist()
    }

    // MARK: Private (call sites already hold the lock)

    private func prune() {
        let cutoff = Date().timeIntervalSince1970 - maxAgeSeconds
        items = items.filter { item in
            guard let time = item["time"] as? Int else { return true }
            return Double(time) >= cutoff
        }
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: items)
            try data.write(to: fileURL)
        } catch {
            Logging.default.log("Failed to persist heartbeat queue: \(error.localizedDescription)")
        }
    }

    private static func load(_ url: URL) -> [[String: Any]] {
        guard
            let data = try? Data(contentsOf: url),
            let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return array
    }
}
