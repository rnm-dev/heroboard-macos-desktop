import AppKit
import SwiftUI

/// NSView host for the SwiftUI settings/main window. Preserves the API used by
/// SettingsWindowController and AppDelegate (`delegate`, `setBrowserVisibility`, `adjustWindowSize`).
final class SettingsView: NSView {
    var delegate: StatusBarDelegate? {
        didSet { model.delegate = delegate }
    }

    private let model = SettingsModel()
    private lazy var hostingView = NSHostingView(rootView: SettingsContentView(model: model))

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 460, height: 560))

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Called when the window is about to show; recompute state (apps, browser) and resize.
    func setBrowserVisibility() {
        model.refresh()
        adjustWindowSize(animate: false)
    }

    func adjustWindowSize(animate: Bool) {
        // Fixed comfortable size; the SwiftUI ScrollView handles overflow (the app list can be long).
        window?.setContentSize(NSSize(width: 460, height: 620))
    }
}
