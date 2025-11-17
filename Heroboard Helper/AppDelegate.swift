import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    struct Constants {
        static let mainAppBundleID = "macos-heroboard.Heroboard"
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let userHome = FileManager.default.homeDirectoryForCurrentUser.pathComponents
        let logFilePath = NSString.path(withComponents: userHome + [".heroboard", "macos-heroboard-helper.log"])
        Logging.default.configure(filePath: logFilePath)

        Logging.default.log("Starting Heroboard Helper")

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == Constants.mainAppBundleID
        }

        if !isRunning {
            Logging.default.log("Heroboard is not running")
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            let fileURL = URL(fileURLWithPath: path as String)
            Logging.default.log("Attempting to open Heroboard at \"\(fileURL.absoluteString)\"")
            NSWorkspace.shared.openApplication(
                at: fileURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    Logging.default.log(error.localizedDescription)
                }
            }
        } else {
            Logging.default.log("Heroboard is already running")
        }
    }
}
