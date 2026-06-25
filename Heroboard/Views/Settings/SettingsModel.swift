import AppKit
import SwiftUI

/// Bridges the SwiftUI settings UI to the UserDefaults-backed PropertiesManager, the auth flow,
/// and the status-bar delegate. didSet persists each change; didSet does not fire for the initial
/// values set in the property declarations, so loading has no side effects.
final class SettingsModel: ObservableObject {
    weak var delegate: StatusBarDelegate?

    @Published var userEmail: String = ConfigFile.getSetting(section: "settings", key: "user_email") ?? ""
    @Published var isAuthenticating = false
    @Published var isMonitoringBrowsing = MonitoringManager.isMonitoringBrowsing

    @Published var launchAtLogin: Bool = PropertiesManager.shouldLaunchOnLogin {
        didSet {
            PropertiesManager.shouldLaunchOnLogin = launchAtLogin
            if launchAtLogin { SettingsManager.registerAsLoginItem() } else { SettingsManager.unregisterAsLoginItem() }
        }
    }
    @Published var showTodayInStatusBar: Bool = PropertiesManager.shouldDisplayTodayInStatusBar {
        didSet {
            PropertiesManager.shouldDisplayTodayInStatusBar = showTodayInStatusBar
            delegate?.fetchToday()
        }
    }
    @Published var requestA11y: Bool = PropertiesManager.shouldRequestA11yPermission {
        didSet { PropertiesManager.shouldRequestA11yPermission = requestA11y }
    }
    @Published var logToFile: Bool = PropertiesManager.shouldLogToFile {
        didSet { PropertiesManager.shouldLogToFile = logToFile }
    }
    @Published var domainPreference: PropertiesManager.DomainPreferenceType = PropertiesManager.domainPreference {
        didSet { PropertiesManager.domainPreference = domainPreference }
    }
    @Published var filterType: PropertiesManager.FilterType = PropertiesManager.filterType {
        didSet {
            PropertiesManager.filterType = filterType
            filterText = PropertiesManager.currentFilterList
        }
    }
    @Published var filterText: String = PropertiesManager.currentFilterList {
        didSet {
            switch filterType {
                case .denylist: PropertiesManager.denylist = filterText
                case .allowlist: PropertiesManager.allowlist = filterText
            }
        }
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: Monitored apps

    struct MonitoredAppRow: Identifiable {
        let id: String          // bundle id
        let name: String
        let icon: NSImage
        let hasPlugin: Bool
        let isBrowser: Bool
        var isMonitored: Bool
    }

    @Published var apps: [MonitoredAppRow] = []

    func loadApps() {
        let bundleIds = Self.sortByName(
            Array(Set(MonitoredApp.allBundleIds + Self.runningRegularApps() + MonitoringManager.allMonitoredApps))
        )
        var rows: [MonitoredAppRow] = []
        for bundleId in bundleIds {
            appendRow(bundleId, into: &rows)
            appendRow(bundleId.appending("-setapp"), into: &rows)
        }
        apps = rows
    }

    private func appendRow(_ bundleId: String, into rows: inout [MonitoredAppRow]) {
        guard
            let icon = AppInfo.getIcon(bundleId: bundleId),
            let name = AppInfo.getAppName(bundleId: bundleId)
        else { return }

        rows.append(MonitoredAppRow(
            id: bundleId,
            name: name,
            icon: icon,
            hasPlugin: MonitoredApp.pluginAppIds[bundleId] != nil,
            isBrowser: MonitoringManager.isAppBrowser(for: bundleId),
            isMonitored: MonitoringManager.isAppMonitored(for: bundleId)
        ))
    }

    func setMonitored(bundleId: String, on: Bool) {
        MonitoringManager.set(monitoringState: on ? .on : .off, for: bundleId)
        if let index = apps.firstIndex(where: { $0.id == bundleId }) {
            apps[index].isMonitored = on
        }
        isMonitoringBrowsing = MonitoringManager.isMonitoringBrowsing
    }

    func installPlugin(bundleId: String) {
        guard
            let path = MonitoredApp.pluginAppIds[bundleId],
            let url = URL(string: "\(AppEnvironment.current.siteBaseURL)/\(path)")
        else { return }

        NSWorkspace.shared.open(url)
    }

    func openDashboard() {
        guard let url = URL(string: "\(AppEnvironment.current.webBaseURL)/") else { return }

        NSWorkspace.shared.open(url)
    }

    func refresh() {
        userEmail = ConfigFile.getSetting(section: "settings", key: "user_email") ?? ""
        isMonitoringBrowsing = MonitoringManager.isMonitoringBrowsing
        loadApps()
        HeartbeatClient.shared.refresh() // pull fresh identity / today / hero from the backend
    }

    func authenticate() {
        isAuthenticating = true
        AuthenticationManager.shared.authenticate { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                self.isAuthenticating = false
                switch result {
                    case .success(let data):
                        ConfigFile.setSetting(section: "settings", key: "api_key", val: data.apiKey)
                        ConfigFile.setSetting(section: "settings", key: "user_email", val: data.userEmail)
                        self.userEmail = data.userEmail
                        Session.shared.setEmail(data.userEmail)
                        HeartbeatClient.shared.refresh()
                        self.showAlert("Authentication successful", "You are now signed in as \(data.userEmail).")
                    case .failure(let error):
                        self.showAlert("Authentication failed", error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: Static helpers

    private static func runningRegularApps() -> [String] {
        var ids: [String] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier else { continue }

            let bundleId = id.replacingOccurrences(of: "-setapp$", with: "", options: .regularExpression)
            guard
                !MonitoredApp.unsupportedAppIds.contains(bundleId),
                !MonitoredApp.allBundleIds.contains(bundleId)
            else { continue }

            ids.append(bundleId)
        }
        return ids
    }

    private static func sortByName(_ bundleIds: [String]) -> [String] {
        bundleIds.sorted {
            let left = AppInfo.getAppName(bundleId: $0) ?? $0
            let right = AppInfo.getAppName(bundleId: $1) ?? $1
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }
}
