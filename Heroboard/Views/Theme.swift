import SwiftUI

/// Shared visual styling for the app UI.
enum HBTheme {
    /// Brand gradient for selected / active controls (replaces the system blue accent).
    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.96), Color(red: 0.91, green: 0.33, blue: 0.78)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Solid accent applied app-wide (e.g. checkboxes) so default controls aren't system blue.
    static let accent = Color(red: 0.66, green: 0.40, blue: 0.92)
}
