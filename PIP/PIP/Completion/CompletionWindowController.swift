import AppKit
import SwiftUI

/// Custom window that doesn't steal keyboard focus
private class CompletionWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Controller for managing the completion window
@MainActor
final class CompletionWindowController {
    // MARK: - Properties

    private var window: NSWindow?
    private var hostingView: NSHostingView<CompletionListView>?
    private(set) var selectedIndex: Int = 0
    private(set) var items: [CompletionItem] = []
    private weak var textView: NSTextView?

    // Callbacks
    var onSelect: ((CompletionItem) -> Void)?
    var onDismiss: (() -> Void)?

    // Observers
    private var focusObserver: NSObjectProtocol?
    private var keyboardMonitor: Any?
    private var tapObserver: NSObjectProtocol?

    init() {
        // Observe when the app loses focus to dismiss the window
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("DEBUG: App lost focus, dismissing completion window")
            self?.dismiss()
        }

        // Observe selection from SwiftUI view (tap) or keyboard (Enter)
        // This observer will just dismiss the window - the actual selection
        // is handled in EditorView via separate notification
        tapObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CompletionItemTapped"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let index = userInfo["index"] as? Int else {
                return
            }
            print("DEBUG: Tap notification received for index: \(index)")
            // Re-post as selection notification for consistency
            NotificationCenter.default.post(
                name: NSNotification.Name("CompletionItemSelected"),
                object: nil,
                userInfo: ["index": index]
            )
        }

        // Monitor keyboard events globally to intercept arrow keys and Enter
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isVisible == true else {
                return event
            }

            print("DEBUG: keyboardMonitor caught key: \(event.keyCode), chars: \(event.characters ?? "nil")")

            // Handle special keys
            switch event.keyCode {
            case 125: // Down arrow
                print("DEBUG: Down arrow intercepted")
                self.moveSelection(delta: 1)
                return nil // Consume the event

            case 126: // Up arrow
                print("DEBUG: Up arrow intercepted")
                self.moveSelection(delta: -1)
                return nil

            case 36: // Enter/Return
                print("DEBUG: Enter intercepted")
                // Get current selection index and post notification - NO CLOSURES!
                if self.selectedIndex < self.items.count {
                    print("DEBUG: Posting selection notification for index: \(self.selectedIndex)")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CompletionItemSelected"),
                        object: nil,
                        userInfo: ["index": self.selectedIndex]
                    )
                }
                return nil

            case 53: // Escape
                print("DEBUG: Escape intercepted")
                self.dismiss()
                return nil

            default:
                // Let other keys through (they'll update completions or be typed normally)
                // Don't dismiss - the completion system will handle updating
                return event
            }
        }
    }

    deinit {
        if let observer = focusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = tapObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Public Methods

    /// Show completion window with items
    func show(
        items: [CompletionItem],
        at cursorRect: NSRect,
        in textView: NSTextView
    ) {
        print("DEBUG: CompletionWindowController.show() called with \(items.count) items")
        if items.count > 0 {
            print("DEBUG: First 3 items in show(): \(items.prefix(3).map { $0.text })")
        }

        guard !items.isEmpty else {
            dismiss()
            return
        }

        // CRITICAL FIX: Close existing window without calling callbacks
        // SwiftUI view caching was causing stale items to display
        if window != nil {
            print("DEBUG: Closing existing window to force refresh")
            window?.orderOut(nil)
            window?.close()
            window = nil
            hostingView = nil
        }

        self.items = items
        self.textView = textView
        self.selectedIndex = 0

        print("DEBUG: Set self.items to \(self.items.count) items, selectedIndex=0")

        // Create or update SwiftUI view - NO CLOSURES to avoid autorelease pool issues!
        let listView = CompletionListView(
            items: items,
            selectedIndex: selectedIndex
        )

        if window == nil {
            // Create new floating window that won't steal keyboard focus
            let contentWindow = CompletionWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            contentWindow.isOpaque = false
            contentWindow.backgroundColor = .clear
            contentWindow.hasShadow = true
            contentWindow.level = .popUpMenu
            contentWindow.isMovableByWindowBackground = false
            contentWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Allow mouse events but keyboard focus stays on text view
            contentWindow.ignoresMouseEvents = false
            contentWindow.acceptsMouseMovedEvents = true
            contentWindow.hidesOnDeactivate = true

            hostingView = NSHostingView(rootView: listView)
            contentWindow.contentView = hostingView

            window = contentWindow
        } else {
            // Update existing window
            hostingView?.rootView = listView
        }

        // Position window near cursor
        positionWindow(near: cursorRect, in: textView)

        // Show window
        window?.orderFront(nil)
    }

    /// Dismiss completion window
    func dismiss() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        hostingView = nil
        selectedIndex = 0
        items = []

        // Post notification instead of calling closure
        NotificationCenter.default.post(
            name: NSNotification.Name("CompletionWindowDismissed"),
            object: nil
        )
    }

    /// Check if window is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - Selection Management

    /// Move selection by delta (-1 for up, +1 for down)
    func moveSelection(delta: Int) {
        print("DEBUG: moveSelection called with delta: \(delta)")
        guard !items.isEmpty else {
            print("DEBUG: moveSelection - items is empty")
            return
        }

        // Calculate new index with wrapping
        var newIndex = selectedIndex + delta

        if newIndex < 0 {
            newIndex = items.count - 1
        } else if newIndex >= items.count {
            newIndex = 0
        }

        print("DEBUG: moveSelection - changing from \(selectedIndex) to \(newIndex)")
        selectedIndex = newIndex
        updateView()
    }

    /// Get currently selected item
    func selectCurrent() -> CompletionItem? {
        print("DEBUG: selectCurrent called, selectedIndex: \(selectedIndex), items.count: \(items.count)")
        guard selectedIndex >= 0 && selectedIndex < items.count else {
            print("DEBUG: selectCurrent - invalid index")
            return nil
        }
        let item = items[selectedIndex]
        print("DEBUG: selectCurrent - returning item: \(item.text)")
        return item
    }

    // MARK: - Private Methods

    /// Update the SwiftUI view with new selection
    private func updateView() {
        guard let hostingView = hostingView else { return }

        // NO CLOSURES to avoid autorelease pool issues!
        let listView = CompletionListView(
            items: items,
            selectedIndex: selectedIndex
        )

        hostingView.rootView = listView
    }

    /// Position window near cursor
    private func positionWindow(near cursorRect: NSRect, in textView: NSTextView) {
        guard let window = window,
              let textViewWindow = textView.window else {
            return
        }

        // Convert cursor rect to screen coordinates
        let rectInWindow = textView.convert(cursorRect, to: nil)
        let rectInScreen = textViewWindow.convertToScreen(rectInWindow)

        // Calculate window height based on number of items
        let rowHeight: CGFloat = 28  // Approximate row height
        let maxHeight: CGFloat = 200
        let calculatedHeight = min(CGFloat(items.count) * rowHeight + 16, maxHeight)
        let windowWidth: CGFloat = 300

        // Position below cursor, slightly offset to the right
        var origin = NSPoint(
            x: rectInScreen.origin.x + 2,
            y: rectInScreen.origin.y - calculatedHeight - 5
        )

        // Get screen frame
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero

        // Adjust if window would go off bottom of screen → show above cursor instead
        if origin.y < screenFrame.origin.y {
            origin.y = rectInScreen.origin.y + rectInScreen.height + 5
        }

        // Adjust if window would go off right edge of screen
        if origin.x + windowWidth > screenFrame.maxX {
            origin.x = screenFrame.maxX - windowWidth - 10
        }

        // Adjust if window would go off left edge of screen
        if origin.x < screenFrame.origin.x {
            origin.x = screenFrame.origin.x + 10
        }

        // Set window frame
        window.setFrame(
            NSRect(x: origin.x, y: origin.y, width: windowWidth, height: calculatedHeight),
            display: true,
            animate: false
        )
    }
}
