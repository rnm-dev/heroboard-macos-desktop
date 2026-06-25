import Foundation

/// Live, day-scoped count of successfully sent heartbeats, shown in the app window. Persists across
/// restarts within the same day (UserDefaults) and resets at the local day boundary.
final class HeartbeatStats: ObservableObject {
    static let shared = HeartbeatStats()

    @Published private(set) var sentToday: Int
    /// When the most recent successful heartbeat was sent (drives the interval arc).
    @Published private(set) var lastSentAt: Date?

    private var day: String
    private let dayKey = "hb_stats_day"
    private let countKey = "hb_stats_sent_today"

    private init() {
        let today = Self.today()
        let storedDay = UserDefaults.standard.string(forKey: dayKey)
        if storedDay == today {
            day = today
            sentToday = UserDefaults.standard.integer(forKey: countKey)
        } else {
            day = today
            sentToday = 0
            persist()
        }
    }

    /// Records one successful send. Safe to call from any thread.
    func recordSent() {
        DispatchQueue.main.async {
            let today = Self.today()
            if self.day != today {
                self.day = today
                self.sentToday = 0
            }
            self.sentToday += 1
            self.lastSentAt = Date()
            self.persist()
        }
    }

    private func persist() {
        UserDefaults.standard.set(day, forKey: dayKey)
        UserDefaults.standard.set(sentToday, forKey: countKey)
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
