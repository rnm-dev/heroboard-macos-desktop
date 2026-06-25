import Foundation

// swiftlint:disable force_unwrapping
class Dependencies {
    public static var twelveHours = 43200

    public static var isLocalDevBuild: Bool {
        Bundle.main.version == "local-build"
    }

    public static func recentBrowserExtension() async -> String? {
        guard
            let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key"),
            !apiKey.isEmpty
        else { return nil }
        let url = "\(AppEnvironment.current.siteApiBaseURL)/users/current/user_agents?api_key=\(apiKey)"
        let request = URLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringCacheData)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else { return nil }

            struct Resp: Decodable {
                let data: [UserAgent]
            }
            struct UserAgent: Decodable {
                let isBrowserExtension: Bool
                let editor: String?
                let lastSeenAt: String?
                enum CodingKeys: String, CodingKey {
                    case isBrowserExtension = "is_browser_extension"
                    case editor
                    case lastSeenAt = "last_seen_at"
                }
            }

            let release = try JSONDecoder().decode(Resp.self, from: data)
            let now = Date()
            for agent in release.data {
                guard
                    agent.isBrowserExtension,
                    let editor = agent.editor,
                    !editor.isEmpty,
                    let lastSeenAt = agent.lastSeenAt
                else { continue }

                let isoDateFormatter = ISO8601DateFormatter()
                isoDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                isoDateFormatter.formatOptions = [.withInternetDateTime]
                if let lastSeen = isoDateFormatter.date(from: lastSeenAt) {
                    if Int(now.timeIntervalSince(lastSeen)) > twelveHours {
                        break
                    }
                }

                return agent.editor
            }
        } catch {
            Logging.default.log("Request error checking for conflicting browser extension: \(error)")
            return nil
        }
        return nil
    }
}
// swiftlint:enable force_unwrapping
