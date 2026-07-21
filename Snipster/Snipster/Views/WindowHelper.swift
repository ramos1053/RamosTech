//
//  WindowHelper.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI
import AppKit

class WindowHelper {
    static func openSnippetDetailWindow(mode: SnippetDetailView.Mode, viewModel: SnippetViewModel) {
        let detailView = SnippetDetailView(mode: mode)
            .environmentObject(viewModel)
            .environmentObject(viewModel.tagStore)

        let hostingController = NSHostingController(rootView: detailView)

        let panel = DetailWindow(contentViewController: hostingController)
        panel.title = mode.title
        panel.setContentSize(NSSize(width: 500, height: 600))
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.orderFront(nil)

        // Store window reference to keep it alive
        WindowManager.shared.addWindow(panel)
    }

    static func openStorageLocationWindow(viewModel: SnippetViewModel) {
        let pickerView = StorageLocationPicker()
            .environmentObject(viewModel)

        let hostingController = NSHostingController(rootView: pickerView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Storage Location"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        // Store window reference to keep it alive
        WindowManager.shared.addWindow(window)
    }

    static func openSettingsWindow(viewModel: SnippetViewModel) {
        // Snipster is an LSUIElement (accessory) app, so a regular window needs
        // an explicit activate or it can fail to come forward/become key —
        // especially the first time a window is shown after launch.
        NSApp.activate(ignoringOtherApps: true)

        // Check if settings window is already open
        if let existingWindow = WindowManager.shared.windows.first(where: { $0.title == "Settings" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(viewModel)
            .environmentObject(viewModel.tagStore)

        let hostingController = NSHostingController(rootView: settingsView)

        // Use a regular window (not a non-activating panel) so NSSwitch-backed
        // toggles and other native controls render their full appearance.
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        // Store window reference to keep it alive
        WindowManager.shared.addWindow(window)
    }

    static func openTagEditWindow(tag: Tag?, onSave: @escaping (Tag) -> Void) {
        let tagEditView = TagEditView(tag: tag, onSave: onSave)
        let hostingController = NSHostingController(rootView: tagEditView)

        // Use a regular window (not NonActivatingWindow) so ColorPicker works properly
        let window = NSWindow(contentViewController: hostingController)
        window.title = tag == nil ? "New Tag" : "Edit Tag"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 350))
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        // Store window reference to keep it alive
        WindowManager.shared.addWindow(window)
    }
}

// Detail window for editing snippets - interactive but doesn't dismiss popover
class DetailWindow: NSPanel {
    convenience init(contentViewController: NSViewController) {
        self.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Custom window that dismisses when clicking outside
class DismissableWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupDismissOnClickOutside()
    }

    convenience init(contentViewController: NSViewController) {
        self.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.contentViewController = contentViewController
    }

    private func setupDismissOnClickOutside() {
        // Monitor for clicks outside the window
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            let windowFrame = self.frame
            let screenClickLocation = NSEvent.mouseLocation

            // Check if click is outside window bounds
            if !windowFrame.contains(screenClickLocation) {
                self.close()
            }

            return event
        }
    }
}

// Singleton to manage window references
class WindowManager {
    static let shared = WindowManager()
    var windows: [NSWindow] = []

    private init() {}

    func addWindow(_ window: NSWindow) {
        // Remove any closed windows
        windows.removeAll { !$0.isVisible }

        // Add new window
        windows.append(window)

        // Set up notification to remove window when closed
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            if let closedWindow = notification.object as? NSWindow {
                self?.windows.removeAll { $0 == closedWindow }
            }
        }
    }
}
