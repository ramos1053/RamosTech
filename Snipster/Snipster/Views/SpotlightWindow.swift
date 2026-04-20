//
//  SpotlightWindow.swift
//  Snipster
//
//  Created by Alan Ramos on 1/8/26.
//

import SwiftUI
import Combine
import AppKit

/// A Spotlight-style floating window for quick snippet search
/// Similar to Clipy's popup menu interface
class SpotlightWindow: NSPanel {
    private var clickOutsideMonitor: Any?
    private static let positionKey = "SpotlightWindowPosition"

    convenience init(contentViewController: NSViewController) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController

        // Visual styling
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating

        // Behavior
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = true
        self.isMovableByWindowBackground = true

        // Allow keyboard interaction
        self.becomesKeyOnlyIfNeeded = false

        setupDismissHandlers()
        setupPositionSaving()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Show window at saved position or centered if no saved position
    func showCentered() {
        // Try to restore saved position
        if let savedOrigin = loadSavedPosition() {
            setFrameOrigin(savedOrigin)
        } else {
            // No saved position - center on screen
            guard let screen = NSScreen.main else { return }

            let screenFrame = screen.visibleFrame
            let windowFrame = frame

            let x = screenFrame.midX - (windowFrame.width / 2)
            let y = screenFrame.midY - (windowFrame.height / 2) + 100 // Slightly above center

            setFrameOrigin(NSPoint(x: x, y: y))
        }

        makeKeyAndOrderFront(nil)

        // Focus the search field
        makeFirstResponder(contentView)
    }

    /// Show window near the current cursor position
    func showNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = frame

        var x = mouseLocation.x - (windowFrame.width / 2)
        var y = mouseLocation.y - 50 // Below cursor

        // Ensure window stays on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            x = max(screenFrame.minX, min(x, screenFrame.maxX - windowFrame.width))
            y = max(screenFrame.minY, min(y, screenFrame.maxY - windowFrame.height))
        }

        setFrameOrigin(NSPoint(x: x, y: y))

        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)
    }

    /// Dismiss the window
    func dismiss() {
        // Save position before dismissing
        savePosition()
        orderOut(nil)
        close()
    }

    private func setupPositionSaving() {
        // Save position whenever window is moved
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.savePosition()
        }
    }

    private func savePosition() {
        let origin = frame.origin
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: SpotlightWindow.positionKey)
    }

    private func loadSavedPosition() -> NSPoint? {
        guard let positionString = UserDefaults.standard.string(forKey: SpotlightWindow.positionKey) else {
            return nil
        }

        let origin = NSPointFromString(positionString)

        // Validate that the position is still on screen
        guard let screen = NSScreen.main else { return nil }
        let screenFrame = screen.visibleFrame
        let windowFrame = NSRect(origin: origin, size: frame.size)

        // Check if window would be visible on screen
        if screenFrame.intersects(windowFrame) {
            return origin
        }

        return nil
    }

    private func setupDismissHandlers() {
        // Monitor for clicks outside the window
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }

            let clickLocation = NSEvent.mouseLocation
            let windowFrame = self.frame

            // Dismiss if click is outside window bounds
            if !windowFrame.contains(clickLocation) {
                self.dismiss()
            }
        }

        // Also monitor local events (within the app)
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            let clickLocation = NSEvent.mouseLocation
            let windowFrame = self.frame

            // Dismiss if click is outside window bounds
            if !windowFrame.contains(clickLocation) {
                self.dismiss()
            }

            return event
        }
    }

    deinit {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Manager for the Spotlight window - ensures only one instance exists
@MainActor
class SpotlightWindowManager: ObservableObject {
    static let shared = SpotlightWindowManager()

    private var window: SpotlightWindow?
    private var viewModel: SnippetViewModel?

    private init() {}

    /// Set the view model to use for the Spotlight window
    func setViewModel(_ viewModel: SnippetViewModel) {
        self.viewModel = viewModel
    }

    /// Toggle the Spotlight window (show if hidden, hide if shown)
    func toggle() {
        if let window = window, window.isVisible {
            window.dismiss()
            self.window = nil
        } else {
            show()
        }
    }

    /// Show the Spotlight window
    func show() {
        guard let viewModel = viewModel else {
            print("SpotlightWindowManager: ViewModel not set")
            return
        }

        // Close existing window if any
        if let existingWindow = window {
            existingWindow.close()
        }

        // Create new window with search view
        let searchView = SpotlightSearchView()
            .environmentObject(viewModel)
            .environmentObject(viewModel.tagStore)

        let hostingController = NSHostingController(rootView: searchView)

        let newWindow = SpotlightWindow(contentViewController: hostingController)
        newWindow.showCentered()

        self.window = newWindow
    }

    /// Hide the Spotlight window
    func hide() {
        window?.dismiss()
        window = nil
    }
}
