import AppKit
import SwiftUI

/// Multiline plain-text editor backed by NSTextView (SwiftUI's TextEditor needs macOS 11).
/// Used for the browser allow/deny regex list.
struct FilterTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView, textView.string != text else { return }

        textView.string = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: FilterTextEditor
        init(_ parent: FilterTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            parent.text = textView.string
        }
    }
}
