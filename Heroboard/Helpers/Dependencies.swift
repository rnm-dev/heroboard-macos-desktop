import Foundation

// swiftlint:disable force_unwrapping
// swiftlint:disable force_try
class Dependencies {
    public static var twelveHours = 43200

    public static func installDependencies() {
        Task {
            if !(await isCLILatest()) {
                downloadCLI()
            }
        }
    }

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

    private static func isCLILatest() async -> Bool {
        let cli = NSString.path(
            withComponents: ConfigFile.resourcesFolder + ["heroboard-cli"]
        )
        // Simply check if CLI exists, using fixed version v1.131.0
        return FileManager.default.fileExists(atPath: cli)
    }

    private static func downloadCLI() {
        let dir = NSString.path(withComponents: ConfigFile.resourcesFolder)
        if !FileManager.default.fileExists(atPath: dir) {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logging.default.log(error.localizedDescription)
            }
        }

        let url = "\(AppEnvironment.current.cliDownloadBaseURL)/downloads/heroboard-cli/v1.131.0/heroboard-cli-darwin-\(architecture()).zip"
        let zipFile = NSString.path(withComponents: ConfigFile.resourcesFolder + ["heroboard-cli.zip"])
        let cli = NSString.path(withComponents: ConfigFile.resourcesFolder + ["heroboard-cli"])
        let cliReal = NSString.path(withComponents: ConfigFile.resourcesFolder + ["heroboard-cli-darwin-\(architecture())"])

        if FileManager.default.fileExists(atPath: zipFile) {
            do {
                try FileManager.default.removeItem(atPath: zipFile)
            } catch {
                Logging.default.log(error.localizedDescription)
                return
            }
        }

        URLSession.shared.downloadTask(with: URLRequest(url: URL(string: url)!)) { fileUrl, _, _ in
            guard let fileUrl else { return }

            do {
                // download heroboard-cli.zip
                try FileManager.default.moveItem(at: fileUrl, to: URL(fileURLWithPath: zipFile))

                if FileManager.default.fileExists(atPath: cliReal) {
                    do {
                        try FileManager.default.removeItem(atPath: cliReal)
                    } catch {
                        Logging.default.log(error.localizedDescription)
                        return
                    }
                }

                // unzip heroboard-cli.zip
                let process = Process()
                process.launchPath = "/usr/bin/unzip"
                process.arguments = [zipFile, "-d", dir]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.launch()
                process.waitUntilExit()

                // cleanup heroboard-cli.zip
                try! FileManager.default.removeItem(atPath: zipFile)

                // create ~/.heroboard/heroboard-cli symlink
                do {
                    try FileManager.default.removeItem(atPath: cli)
                } catch { }
                try! FileManager.default.createSymbolicLink(atPath: cli, withDestinationPath: cliReal)

            } catch {
                Logging.default.log(error.localizedDescription)
            }
        }.resume()
    }

    private static func architecture() -> String {
        var systeminfo = utsname()
        uname(&systeminfo)
        let machine = withUnsafeBytes(of: &systeminfo.machine) {bufPtr -> String in
            let data = Data(bufPtr)
            if let lastIndex = data.lastIndex(where: { $0 != 0 }) {
                return String(data: data[0...lastIndex], encoding: .isoLatin1)!
            } else {
                return String(data: data, encoding: .isoLatin1)!
            }
        }
        if machine == "x86_64" {
            return "amd64"
        }
        return "arm64"
    }
}
// swiftlint:enable force_unwrapping
// swiftlint:enable force_try
