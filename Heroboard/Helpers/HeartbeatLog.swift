import Foundation

/// Append-only log of heartbeats that were successfully sent to the backend, kept for debugging.
/// Lives in the app's resources folder (`~/.heroboard/` for Release, `~/.heroboard-dev/` for Debug —
/// see `ConfigFile`), so a dev build and a prod build keep separate logs. Each line is
/// `<timestamp> <json>` where the JSON is the exact enriched body that went over the wire.
///
/// The active file is capped at `maxBytes` (3 MB): when the next write would exceed it, the file is
/// rotated to a single `.1` backup (overwriting any previous backup), bounding total disk use at
/// ~2× the cap while preserving a window of recent history.
final class HeartbeatLog {
    static let shared = HeartbeatLog()

    private let fileURL: URL
    private let rotatedURL: URL
    private let lock = NSLock()
    private let maxBytes = 3 * 1024 * 1024

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    init() {
        let dir = NSString.path(withComponents: ConfigFile.resourcesFolder)
        fileURL = URL(fileURLWithPath: dir).appendingPathComponent("heartbeats-sent.log")
        rotatedURL = URL(fileURLWithPath: dir).appendingPathComponent("heartbeats-sent.1.log")
    }

    /// Records one successfully sent heartbeat. Safe to call from any thread.
    func record(_ body: [String: Any]) {
        lock.lock(); defer { lock.unlock() }

        let timestamp = dateFormatter.string(from: Date())
        let json = (try? JSONSerialization.data(withJSONObject: body))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "<unserializable>"
        guard let line = "\(timestamp) \(json)\n".data(using: .utf8) else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            Logging.default.log("Failed to create heartbeat log dir: \(error.localizedDescription)")
            return
        }

        rotateIfNeeded(adding: line.count)

        if let handle = FileHandle(forWritingAtPath: fileURL.path) {
            handle.seekToEndOfFile()
            handle.write(line)
            handle.closeFile()
        } else {
            try? line.write(to: fileURL)
        }
    }

    // Caller holds the lock. Rotates when appending `bytes` would push the file past the cap.
    private func rotateIfNeeded(adding bytes: Int) {
        let fileManager = FileManager.default
        guard
            let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
            let size = attrs[.size] as? Int,
            size + bytes > maxBytes
        else { return }

        try? fileManager.removeItem(at: rotatedURL)
        try? fileManager.moveItem(at: fileURL, to: rotatedURL)
    }
}
