import AppKit
import SwiftUI

/// The single app window: a borderless dark panel with a centered title bar, a heartbeat counter +
/// dashboard link, the account, the monitored-apps list (browser options expand inline), and
/// general settings.
struct SettingsContentView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject private var stats = HeartbeatStats.shared
    @ObservedObject private var session = Session.shared

    private let secondary = Color.white.opacity(0.55)

    // Tweak to nudge the centered title's vertical alignment with the traffic lights.
    private let titleBarHeight: CGFloat = 36

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.14), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Color.clear.frame(height: titleBarHeight)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        topRow
                        accountSection
                        monitoredAppsSection
                        generalSection
                        footer
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Pinned to the very top (safe area ignored) so it v-centers with the traffic lights.
            titleBar
                .frame(maxWidth: .infinity)
                .frame(height: titleBarHeight)
        }
        .edgesIgnoringSafeArea(.all)
        .frame(width: 460)
        .accentColor(HBTheme.accent)
    }

    private var titleBar: some View {
        HStack(spacing: 7) {
            if let icon = NSImage(named: NSImage.Name("Heroboard")) {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .foregroundColor(.white)
            }
            Text("Heroboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: Sections

    private var topRow: some View {
        HStack(spacing: 11) {
            HeartbeatIndicator()
            Text("Heartbeats sent today: \(stats.sentToday)")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.75))
            Spacer()
            dashboardButton
        }
    }

    private var dashboardButton: some View {
        Button(action: { model.openDashboard() }) {
            HStack(spacing: 5) {
                Text("Dashboard").font(.system(size: 12, weight: .medium))
                Text("↗").font(.system(size: 12, weight: .semibold)).opacity(0.7)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.14)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var accountSection: some View {
        section("ACCOUNT") {
            if let user = session.user {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name ?? "Signed in").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        Text(user.email).font(.system(size: 11)).foregroundColor(secondary)
                        if let hero = session.hero {
                            Text("Level \(hero.level) · \(hero.streakDays)-day streak · \(hero.gold) gold")
                                .font(.system(size: 11)).foregroundColor(HBTheme.accent.opacity(0.95))
                        }
                    }
                    Spacer()
                    Button(model.isAuthenticating ? "…" : "Re-authenticate") { model.authenticate() }
                        .disabled(model.isAuthenticating)
                }
            } else {
                Button(model.isAuthenticating ? "Signing in…" : "Sign in with Heroboard") { model.authenticate() }
                    .disabled(model.isAuthenticating)
            }
        }
    }

    private var monitoredAppsSection: some View {
        section("MONITORED APPS") {
            VStack(spacing: 0) {
                if model.apps.isEmpty {
                    Text("No apps found yet.")
                        .font(.system(size: 12)).foregroundColor(secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                ForEach(model.apps) { app in
                    appRow(app)
                    if app.id != model.apps.last?.id {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
        }
    }

    private func appRow(_ app: SettingsModel.MonitoredAppRow) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                Text(app.name).font(.system(size: 13)).foregroundColor(.white).lineLimit(1)
                Spacer()
                if app.hasPlugin {
                    Button("Install plugin") { model.installPlugin(bundleId: app.id) }
                } else {
                    Toggle("", isOn: Binding(
                        get: { app.isMonitored },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                model.setMonitored(bundleId: app.id, on: newValue)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(GradientToggleStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Browser tracking options live inside the browser's own row, shown when it's enabled.
            if app.isBrowser && app.isMonitored {
                browserSettings
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    private var browserSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.white.opacity(0.08))

            labeled("What to record") {
                GradientSegmented(selection: $model.domainPreference, options: [
                    ("Domain only", .domain),
                    ("Full URL", .url),
                ])
            }

            labeled("Filter") {
                GradientSegmented(selection: $model.filterType, options: [
                    ("Denylist", .denylist),
                    ("Allowlist", .allowlist),
                ])

                Text(model.filterType == .denylist
                     ? "Sites to exclude — one regex per line."
                     : "Only these sites — one regex per line.")
                    .font(.system(size: 11))
                    .foregroundColor(secondary)

                FilterTextEditor(text: $model.filterText)
                    .frame(height: 90)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12)))
            }
        }
    }

    private var generalSection: some View {
        section("GENERAL") {
            VStack(alignment: .leading, spacing: 12) {
                toggle("Launch at login", $model.launchAtLogin)
                toggle("Show today’s time in the status bar", $model.showTodayInStatusBar)
                toggle("Track Xcode activity (needs Accessibility permission)", $model.requestA11y)
                toggle("Write a debug log file", $model.logToFile)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("Version \(model.version)").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggle(_ label: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(label).font(.system(size: 13)).foregroundColor(.white)
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.8))
            content()
        }
    }
}
