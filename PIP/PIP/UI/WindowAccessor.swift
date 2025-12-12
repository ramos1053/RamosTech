import SwiftUI
import AppKit

/// Helper to access and configure the NSWindow
struct WindowAccessor: NSViewRepresentable {
    var opacity: Binding<Double>? = nil

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.configureWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        // Set our custom delegate to handle window close events
        window.delegate = CustomWindowDelegate.shared
    }
}
