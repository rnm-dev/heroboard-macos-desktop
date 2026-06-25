import Foundation

/// The signed-in session as reported by the backend on each heartbeat (HB-370): identity, today's
/// tracked time, and hero stats. Seeded from the cached config email so the UI isn't empty before
/// the first heartbeat; thereafter the backend response is the source of truth.
final class Session: ObservableObject {
    struct User {
        let email: String
        let name: String?
        let handle: String?
    }
    struct Today {
        let day: String
        let minutes: Int
    }
    struct Hero {
        let level: Int
        // swiftlint:disable:next identifier_name
        let xp: Int
        let gold: Int
        let streakDays: Int
    }

    static let shared = Session()

    @Published private(set) var user: User?
    @Published private(set) var today: Today?
    @Published private(set) var hero: Hero?

    private init() {
        if let email = ConfigFile.getSetting(section: "settings", key: "user_email"), !email.isEmpty {
            user = User(email: email, name: nil, handle: nil)
        }
    }

    /// Apply a heartbeat response body (POST or GET /api/heartbeat).
    func apply(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        var parsedUser: User?
        if let object = json["user"] as? [String: Any], let email = object["email"] as? String {
            parsedUser = User(email: email, name: object["name"] as? String, handle: object["handle"] as? String)
        } else if let email = json["user_email"] as? String {
            parsedUser = User(email: email, name: nil, handle: nil)
        }

        var parsedToday: Today?
        if let object = json["today"] as? [String: Any], let minutes = object["minutes"] as? Int {
            parsedToday = Today(day: object["day"] as? String ?? "", minutes: minutes)
        }

        var parsedHero: Hero?
        if let object = json["hero"] as? [String: Any] {
            parsedHero = Hero(
                level: object["level"] as? Int ?? 0,
                xp: object["xp"] as? Int ?? 0,
                gold: object["gold"] as? Int ?? 0,
                streakDays: object["streakDays"] as? Int ?? 0
            )
        }

        DispatchQueue.main.async {
            if let parsedUser {
                self.user = parsedUser
                ConfigFile.setSetting(section: "settings", key: "user_email", val: parsedUser.email)
            }
            if let parsedToday { self.today = parsedToday }
            if let parsedHero { self.hero = parsedHero }
        }
    }

    /// Seed identity immediately after a sign-in (before the first heartbeat response arrives).
    func setEmail(_ email: String) {
        DispatchQueue.main.async {
            self.user = User(email: email, name: self.user?.name, handle: self.user?.handle)
        }
    }

    /// The API key was rejected (401) — clear identity so the UI prompts re-sign-in.
    func signOut() {
        DispatchQueue.main.async {
            self.user = nil
            self.today = nil
            self.hero = nil
        }
    }
}
