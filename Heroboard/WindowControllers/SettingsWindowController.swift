import AppKit

class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    public let settingsView = SettingsView()

    convenience init() {
        self.init(window: nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Heroboard"
        // Borderless look: transparent title bar, content runs full height, traffic lights stay.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = settingsView
        self.window = window
        settingsView.adjustWindowSize(animate: false)
        window.center()
    }
}
