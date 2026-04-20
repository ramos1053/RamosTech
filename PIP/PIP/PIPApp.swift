//
//  PIPApp.swift
//  PIP - Plain Text Editor
//
//  Created by A. Ramos on 2025.
//  Copyright © 2025 RamosTech. All rights reserved.
//

import SwiftUI

@main
struct PIPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var preferences = AppPreferences.shared

    var body: some Scene {
        WindowGroup {
            ContentViewWrapper()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Custom About menu
            CommandGroup(replacing: .appInfo) {
                Button("About PIP") {
                    let creditsText = "Plain. Intuitive. Powerful.\n\nA modern plain text editor for macOS"

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center

                    let creditsAttributed = NSAttributedString(string: creditsText, attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: paragraphStyle
                    ])

                    let aboutOptions: [NSApplication.AboutPanelOptionKey: Any] = [
                        .applicationName: "PIP",
                        .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                        .credits: creditsAttributed
                    ]

                    NSApplication.shared.orderFrontStandardAboutPanel(options: aboutOptions)
                }
            }

            // Replace Help menu to avoid "Help isn't available" dialog
            CommandGroup(replacing: .help) {
                Button("PIP Help") {
                    NotificationCenter.default.post(name: .showHelpWindow, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) {
                Button("New") {
                    NotificationCenter.default.post(name: .newDocument, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openDocument, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // Window management commands
            CommandGroup(after: .newItem) {
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeActiveTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

                Button("Close") {
                    NotificationCenter.default.post(name: .closeDocument, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Minimize") {
                    NSApp.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: .command)
            }

            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    NotificationCenter.default.post(name: .printDocument, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As...") {
                    NotificationCenter.default.post(name: .saveDocumentAs, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Menu("Export As...") {
                    Button("Plain Text (.txt)") {
                        NotificationCenter.default.post(name: .exportDocument, object: FileFormat.plainText)
                    }

                    Button("Shell Script (.sh)") {
                        NotificationCenter.default.post(name: .exportDocument, object: FileFormat.shell)
                    }
                }
            }

            // Find menu items (adds to Edit menu)
            CommandGroup(after: .textEditing) {
                Button("Find...") {
                    NotificationCenter.default.post(name: .showFindPanel, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("Use Selection for Find") {
                    NotificationCenter.default.post(name: .useSelectionForFind, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Jump to Line...") {
                    NotificationCenter.default.post(name: .showGoToLine, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button("Character Inspector...") {
                    NotificationCenter.default.post(name: .showCharacterInspector, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

            // View menu items (adds to existing View menu)
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Divider()

                Button(preferences.showLineNumbers ? "✓ Line Numbers" : "Line Numbers") {
                    preferences.showLineNumbers.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button(preferences.wrapLines ? "✓ Wrap Lines" : "Wrap Lines") {
                    preferences.wrapLines.toggle()
                }

                Button(preferences.showInvisibles ? "✓ Invisibles" : "Invisibles") {
                    preferences.showInvisibles.toggle()
                }

                Divider()

                Button(preferences.showToolbarLabels ? "✓ Toolbar Labels" : "Toolbar Labels") {
                    preferences.showToolbarLabels.toggle()
                }

                Divider()

                Button("Toggle Log") {
                    NotificationCenter.default.post(name: .toggleLog, object: nil)
                }
            }


            // Script menu
            CommandMenu("Script") {
                Button("Run Unix Command...") {
                    NotificationCenter.default.post(name: .runUnixCommand, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Divider()

                Button("Run Script") {
                    NotificationCenter.default.post(name: .runScript, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Stop Script") {
                    NotificationCenter.default.post(name: .stopScript, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)

                Divider()

                Button("Clear Output") {
                    NotificationCenter.default.post(name: .clearLog, object: nil)
                }

                Button("Export Output...") {
                    NotificationCenter.default.post(name: .exportLog, object: nil)
                }
            }
        }

        // Preferences window
        Settings {
            PreferencesWindow()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newDocument = Notification.Name("newDocument")
    static let openDocument = Notification.Name("openDocument")
    static let saveDocument = Notification.Name("saveDocument")
    static let saveDocumentAs = Notification.Name("saveDocumentAs")
    static let exportDocument = Notification.Name("exportDocument")
    static let runScript = Notification.Name("runScript")
    static let runUnixCommand = Notification.Name("runUnixCommand")
    static let stopScript = Notification.Name("stopScript")
    static let clearLog = Notification.Name("clearLog")
    static let exportLog = Notification.Name("exportLog")
    static let toggleLog = Notification.Name("toggleLog")
    static let convertLineEnding = Notification.Name("convertLineEnding")
    static let closeActiveTab = Notification.Name("closeActiveTab")
    static let closeDocument = Notification.Name("closeDocument")
    static let showGoToLine = Notification.Name("showGoToLine")
    static let useSelectionForFind = Notification.Name("useSelectionForFind")
    static let printDocument = Notification.Name("printDocument")
    static let showCharacterInspector = Notification.Name("showCharacterInspector")
    static let showFindPanel = Notification.Name("showFindPanel")
    static let findNext = Notification.Name("findNext")
    static let showDebugConsole = Notification.Name("showDebugConsole")
    static let findPrevious = Notification.Name("findPrevious")
    static let replaceNext = Notification.Name("replaceNext")
    static let replaceAll = Notification.Name("replaceAll")
    static let updateFindMatchInfo = Notification.Name("updateFindMatchInfo")
    static let clearSearchHighlights = Notification.Name("clearSearchHighlights")
    static let showReplaceNotification = Notification.Name("showReplaceNotification")
    static let autoSaveTriggered = Notification.Name("autoSaveTriggered")
    static let transformUppercase = Notification.Name("transformUppercase")
    static let transformLowercase = Notification.Name("transformLowercase")
    static let convertTabsToSpaces = Notification.Name("convertTabsToSpaces")
    static let convertSpacesToTabs = Notification.Name("convertSpacesToTabs")
    static let undoEdit = Notification.Name("undoEdit")
    static let redoEdit = Notification.Name("redoEdit")
    static let allowWindowClose = Notification.Name("allowWindowClose")
    static let saveCompleted = Notification.Name("saveCompleted")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let showHelpWindow = Notification.Name("showHelpWindow")
}

// MARK: - Custom Window Delegate

class CustomWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = CustomWindowDelegate()
    private var pendingCloseWindow: NSWindow?
    weak var managedWindow: NSWindow?

    /// Handles closing a specific tab with save dialog if needed.
    @MainActor
    func handleCloseTab(_ tab: TabDocument, tabManager: TabManager, closeWindow: Bool = false) -> Bool {
        // If the tab is modified, show save dialog
        if tab.isModified {
            // Show NSAlert directly
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes you made to \"\(tab.fullDisplayName)\"?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn: // Save
                // Make this tab active if it isn't already
                if tabManager.activeTabID != tab.id {
                    tabManager.switchToTab(tab.id)
                }
                // Post notification to trigger save
                NotificationCenter.default.post(name: .saveDocument, object: nil)
                // Listen for save completion
                NotificationCenter.default.addObserver(
                    forName: .saveCompleted,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Close the tab after save
                    DispatchQueue.main.async {
                        tabManager.performCloseTab(tab)
                    }
                }
                return false // Don't close window yet

            case .alertSecondButtonReturn: // Don't Save
                tabManager.performCloseTab(tab)
                return closeWindow && tabManager.tabs.isEmpty

            default: // Cancel
                return false
            }
        } else {
            // Not modified, close directly
            tabManager.performCloseTab(tab)
            return closeWindow && tabManager.tabs.isEmpty
        }
    }

    /// Handles closing the active tab with save dialog if needed. Returns true if window should close.
    @MainActor
    func handleCloseActiveTab(closeWindow: Bool = false) -> Bool {
        // Get the workspace manager
        guard let workspaceManager = AppDelegate.workspaceManager,
              let activeWorkspace = workspaceManager.activeWorkspace else {
            return closeWindow
        }

        let tabManager = activeWorkspace.tabManager
        guard let activeTab = tabManager.activeTab else {
            return closeWindow // No tabs
        }

        return handleCloseTab(activeTab, tabManager: tabManager, closeWindow: closeWindow)
    }

    @MainActor
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // CRITICAL: Only handle close for the specific window we're managing
        // If this isn't our managed window, allow it to close normally
        guard sender === managedWindow else {
            return true // Not our window, allow it to close
        }

        // Don't interfere with panels (alerts, dialogs)
        if sender is NSPanel {
            return true // Allow it to close normally
        }

        // This is our managed main window with documents, handle close with save dialog
        return handleCloseActiveTab(closeWindow: true)
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static var workspaceManager: WorkspaceManager?
    private var debugConsoleWindow: NSWindow?
    private var helpWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Initialize debug logger early
        _ = DebugLogger.shared

        print("DEBUG: applicationWillFinishLaunching called")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.shared.info("PIP application launched", category: "Application")

        // Only set delegate on the main application window (first non-panel window)
        // Don't set it on all windows to avoid interfering with preferences/dialogs
        if let mainWindow = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
            let delegate = CustomWindowDelegate.shared
            delegate.managedWindow = mainWindow
            mainWindow.delegate = delegate
        }

        // Set up debug console notification observer
        NotificationCenter.default.addObserver(
            forName: .showDebugConsole,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showDebugConsole()
            }
        }

        // Set up help window notification observer
        NotificationCenter.default.addObserver(
            forName: .showHelpWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showHelpWindow()
            }
        }
    }

    private func showDebugConsole() {
        // Check if window exists and is visible
        if let window = debugConsoleWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Clean up old window if it exists but is not visible
        if let oldWindow = debugConsoleWindow {
            oldWindow.contentView = nil
            debugConsoleWindow = nil
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Debug Console"
        window.contentView = NSHostingView(rootView: DebugConsoleWindow())
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        window.isReleasedWhenClosed = false
        debugConsoleWindow = window

        // Observe window close to clean up
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let window = notification.object as? NSWindow else { return }
                // Clean up the content view to break SwiftUI retain cycles
                window.contentView = nil
                self?.debugConsoleWindow = nil
            }
        }
    }

    // Action method for Help menu item
    @objc func showHelpAction(_ sender: Any?) {
        print("DEBUG: Help menu item clicked!")
        DebugLogger.shared.info("PIP Help menu item clicked", category: "Help")
        showHelpWindow()
    }

    private func showHelpWindow() {
        // Check if window exists and is visible
        if let window = helpWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Clean up old window if it exists but is not visible
        if let oldWindow = helpWindow {
            oldWindow.contentView = nil
            helpWindow = nil
        }

        // Create new help window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PIP Help"
        window.center()
        window.contentView = NSHostingView(rootView: HelpWindow())
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        helpWindow = window

        // Observe window close to clean up
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let window = notification.object as? NSWindow else { return }
                // Clean up the content view to break SwiftUI retain cycles
                window.contentView = nil
                self?.helpWindow = nil
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let manager = AppDelegate.workspaceManager else {
            return .terminateNow
        }

        // Check if there are any unsaved documents
        let unsavedDocs = manager.allUnsavedDocuments

        if unsavedDocs.isEmpty {
            return .terminateNow
        }

        // Show alert for each unsaved document
        for (workspace, document) in unsavedDocs {
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes you made to the document?"
            alert.informativeText = "Workspace: \(workspace.name)\nDocument: \(document.fullDisplayName)\n\nYour changes will be lost if you don't save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn: // Save
                // Try to save the document
                if let docInfo = document.documentInfo {
                    // Save to existing location
                    Task {
                        do {
                            let formatHandler = FileFormatHandler()
                            try await formatHandler.exportFile(
                                content: document.textEngine.text,
                                to: docInfo.url,
                                format: docInfo.format,
                                encoding: docInfo.encoding
                            )
                            document.isModified = false
                        } catch {
                            // Show error but continue
                            print("Error saving document: \(error)")
                        }
                    }
                } else {
                    // Show save panel
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = document.fullDisplayName
                    savePanel.allowedContentTypes = [.plainText]

                    let panelResponse = savePanel.runModal()
                    if panelResponse == .OK, let url = savePanel.url {
                        Task {
                            do {
                                let formatHandler = FileFormatHandler()
                                try await formatHandler.exportFile(
                                    content: document.textEngine.text,
                                    to: url,
                                    format: .plainText,
                                    encoding: .utf8
                                )
                                document.isModified = false
                            } catch {
                                print("Error saving document: \(error)")
                            }
                        }
                    } else {
                        // User cancelled save panel
                        return .terminateCancel
                    }
                }

            case .alertSecondButtonReturn: // Don't Save
                // Continue to next document
                continue

            case .alertThirdButtonReturn: // Cancel
                return .terminateCancel

            default:
                return .terminateCancel
            }
        }

        return .terminateNow
    }
}
