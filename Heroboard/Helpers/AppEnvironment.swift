import Foundation

/// Single source of truth for environment-dependent backend endpoints.
///
/// The environment is selected at compile time: Debug builds target the dev
/// stack (`dev.heroboard.app`), Release builds target production. There is no
/// runtime switch — change the build configuration to change environments.
///
/// Note: the `api.` subdomain has been retired. The REST API is served from the
/// web host under `/api/v1`.
enum AppEnvironment {
    case development
    case production

    #if DEBUG
    static let current: AppEnvironment = .development
    #else
    static let current: AppEnvironment = .production
    #endif

    /// Product web app: desktop auth pages, dashboard, and the REST API.
    var webBaseURL: String {
        switch self {
            case .development: return "https://dev.heroboard.app"
            case .production: return "https://heroboard.app"
        }
    }

    /// Marketing site (`.com`): plugin install pages and the user-agents endpoint.
    /// In dev everything is served from `dev.heroboard.app`.
    var siteBaseURL: String {
        switch self {
            case .development: return "https://dev.heroboard.app"
            case .production: return "https://heroboard.com"
        }
    }

    /// Custom URL scheme for deep links. Must match `HEROBOARD_URL_SCHEME` in project.yml (and thus
    /// the registered scheme in Info.plist) so Debug and Release don't fight over the same scheme.
    var urlScheme: String {
        switch self {
            case .development: return "heroboard-dev"
            case .production: return "heroboard"
        }
    }

    /// REST API base on the product web host, e.g. `<host>/api/v1`.
    var apiBaseURL: String { "\(webBaseURL)/api/v1" }

    /// REST API base on the marketing site, e.g. `<host>/api/v1`.
    var siteApiBaseURL: String { "\(siteBaseURL)/api/v1" }
}
