import SwiftUI

// MARK: - Printable Document View

class PrintableDocumentView: NSView {
    private let attributedString: NSAttributedString
    private var textStorage: NSTextStorage!
    private var layoutManager: NSLayoutManager!
    private var textContainers: [NSTextContainer] = []
    private var pageHeight: CGFloat = 0
    private var pageWidth: CGFloat = 0
    private var leftMargin: CGFloat = 0
    private var topMargin: CGFloat = 0
    private var paperSize: NSSize = .zero

    override var isFlipped: Bool {
        return true
    }

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        guard let printInfo = NSPrintOperation.current?.printInfo else {
            return false
        }

        // Ensure no scaling is applied - always 100%
        printInfo.scalingFactor = 1.0

        // Calculate page size from print info
        self.paperSize = printInfo.paperSize
        self.leftMargin = printInfo.leftMargin
        let rightMargin = printInfo.rightMargin
        self.topMargin = printInfo.topMargin
        let bottomMargin = printInfo.bottomMargin

        let printableWidth = paperSize.width - leftMargin - rightMargin
        let printableHeight = paperSize.height - topMargin - bottomMargin

        pageWidth = printableWidth
        pageHeight = printableHeight

        // Create text layout system with MULTIPLE containers (one per page)
        textStorage = NSTextStorage(attributedString: attributedString)
        layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // Create text containers - one per page
        // Text will flow from one container to the next automatically
        textContainers = []
        var moreTextToLayout = true

        while moreTextToLayout {
            let container = NSTextContainer(size: NSSize(width: printableWidth, height: printableHeight))
            container.widthTracksTextView = false
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            textContainers.append(container)

            // Check if all text has been laid out
            let glyphRange = layoutManager.glyphRange(for: container)
            if NSMaxRange(glyphRange) >= layoutManager.numberOfGlyphs {
                moreTextToLayout = false
            }

            // Safety limit to prevent infinite loop
            if textContainers.count > 1000 {
                moreTextToLayout = false
            }
        }

        let numberOfPages = textContainers.count

        // Set view frame to encompass all pages (with full paper height including margins)
        let totalHeight = CGFloat(numberOfPages) * paperSize.height
        self.frame = NSRect(x: 0, y: 0, width: paperSize.width, height: totalHeight)

        // Set page range
        range.pointee.location = 1
        range.pointee.length = max(1, numberOfPages)

        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        // Each page rect is positioned sequentially down the view
        // Use full paper height for proper spacing
        let rect = NSRect(
            x: 0,
            y: CGFloat(page - 1) * paperSize.height,
            width: paperSize.width,
            height: paperSize.height
        )

        return rect
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let layoutManager = layoutManager,
              let currentPage = NSPrintOperation.current?.currentPage,
              currentPage <= textContainers.count else {
            return
        }

        // Fill background
        NSColor.white.setFill()
        dirtyRect.fill()

        // Get the text container for this page (pages are 1-indexed)
        let container = textContainers[currentPage - 1]

        // Get the glyph range that was laid out in this container
        let glyphRange = layoutManager.glyphRange(for: container)

        // CRITICAL: Draw at the position within dirtyRect where this page's content should appear
        // dirtyRect.minY is the Y position of this page in the view's coordinate system
        // We add margins to position the text correctly on the page
        let drawPoint = NSPoint(x: dirtyRect.minX + leftMargin, y: dirtyRect.minY + topMargin)

        // Draw the glyphs for this page's container
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: drawPoint)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawPoint)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var workspaceManager: WorkspaceManager
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var scriptExecutor = ScriptExecutor()
    @ObservedObject var preferences = AppPreferences.shared

    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    // Find & Replace state
    @State private var showFindPanel: Bool = false
    @State private var searchText: String = ""
    @State private var replaceText: String = ""

    // Go to Line state
    @State private var showGoToLine: Bool = false

    // Character Inspector state
    struct InspectorData {
        let selectedText: String
        let font: NSFont?
        let id: UUID
    }
    @State private var showCharacterInspector: Bool = false
    @State private var inspectorData: InspectorData? = nil

    // Sidebar visibility
    @State private var showSidebar: Bool = true

    // Script output window
    @State private var showScriptOutput: Bool = false
    @State private var outputWindowHeight: CGFloat = 200

    // Replace notification
    @State private var showReplaceNotification: Bool = false
    @State private var replaceNotificationMessage: String = ""

    // Unix command execution
    @State private var showUnixCommandSheet: Bool = false
    @State private var unixCommand: String = ""

    // Window size tracking for dynamic toolbar behavior
    @State private var windowWidth: CGFloat = 1200
    @State private var userWantsLabels: Bool = true
    @State private var temporarilyHidingLabels: Bool = false

    // Character inspector window storage
    @State private var characterInspectorWindow: NSWindow? = nil

    var activeWorkspace: Workspace? {
        workspaceManager.activeWorkspace
    }

    var tabManager: TabManager? {
        activeWorkspace?.tabManager
    }

    var activeTab: TabDocument? {
        tabManager?.activeTab
    }

    // MARK: - Window Resize Handling

    private func handleWindowResize(newWidth: CGFloat) {
        windowWidth = newWidth

        // Get the main window to update its minSize dynamically
        guard let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) else { return }

        // Threshold where labels should be hidden to prevent wrapping/stacking
        let labelHideThreshold: CGFloat = 1240

        if newWidth < labelHideThreshold {
            // Window is too narrow for labels - hide them immediately
            if !temporarilyHidingLabels {
                temporarilyHidingLabels = true
                userWantsLabels = preferences.showToolbarLabels
                preferences.showToolbarLabels = false

                // Set minimum size for icon-only mode (narrower)
                window.minSize = NSSize(width: 680, height: 400)
            }
        } else {
            // Window is wide enough - restore labels if user originally wanted them
            if temporarilyHidingLabels {
                temporarilyHidingLabels = false
                preferences.showToolbarLabels = userWantsLabels

                // Set minimum size for labeled mode (wider to prevent immediate stacking)
                window.minSize = NSSize(width: 1240, height: 400)
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 0) {
            // Document editing tools (always visible when a tab is active)
            if activeTab != nil {
                HStack(spacing: 8) {
                    // Shebang insertion for scripts
                    Menu {
                        Button("#!/bin/bash") { insertShebang("#!/bin/bash") }
                        Button("#!/bin/sh") { insertShebang("#!/bin/sh") }
                        Button("#!/usr/bin/env python3") { insertShebang("#!/usr/bin/env python3") }
                        Button("#!/usr/bin/env python") { insertShebang("#!/usr/bin/env python") }
                        Button("#!/usr/bin/env ruby") { insertShebang("#!/usr/bin/env ruby") }
                        Button("#!/usr/bin/env perl") { insertShebang("#!/usr/bin/env perl") }
                        Button("#!/usr/bin/env php") { insertShebang("#!/usr/bin/env php") }
                        Button("#!/usr/bin/env node") { insertShebang("#!/usr/bin/env node") }
                        Button("#!/usr/bin/env zsh") { insertShebang("#!/usr/bin/env zsh") }

                        Divider()

                        Button("XML Header") {
                            insertShebang("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
                        }
                        Button("Plist Header") {
                            insertShebang("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t\n</dict>\n</plist>")
                        }
                    } label: {
                        Image(systemName: "number")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .help("Insert shebang or file header")

                    // Font size controls
                    ToolbarButton(icon: "textformat.size.larger", action: increaseFontSize, tooltip: "Increase font size", label: "Larger")
                    ToolbarButton(icon: "textformat.size.smaller", action: decreaseFontSize, tooltip: "Decrease font size", label: "Smaller")

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 6)

                    // Sidebar toggle
                    ToolbarButton(
                        icon: showSidebar ? "sidebar.left" : "sidebar.left",
                        action: { showSidebar.toggle() },
                        tooltip: "Toggle Sidebar (⌘⌃S)",
                        label: "Sidebar"
                    )

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 6)

                    // Character Inspector
                    ToolbarButton(icon: "info.circle", action: showCharacterInspectorForSelection, tooltip: "Character Inspector (⌘⌥I)", label: "Inspector")

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 6)

                    // Script Output Window Toggle
                    ToolbarButton(
                        icon: showScriptOutput ? "doc.plaintext.fill" : "doc.plaintext",
                        action: { showScriptOutput.toggle() },
                        tooltip: "Toggle Script Output (⌘⌥O)",
                        label: "Output"
                    )

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 6)

                    // Unix Command execution
                    ToolbarButton(
                        icon: "terminal.fill",
                        action: { showUnixCommandSheet = true },
                        tooltip: "Run Unix Command (⌘⇧U)",
                        label: "Command"
                    )

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 6)

                    // Text transformations
                    Menu {
                        Button("UPPERCASE") {
                            activeTab?.textEngine.transformToUppercase()
                        }

                        Button("lowercase") {
                            activeTab?.textEngine.transformToLowercase()
                        }

                        Divider()

                        Button("Convert Tabs to Spaces") {
                            activeTab?.textEngine.convertTabsToSpaces()
                        }

                        Button("Convert Spaces to Tabs") {
                            activeTab?.textEngine.convertSpacesToTabs()
                        }
                    } label: {
                        Image(systemName: "textformat")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .help("Text transformations")
                }
                .padding(.leading, 8)
            }

            Spacer()

            // Quick actions
            if activeTab?.isExecutable == true {
                HStack(spacing: 4) {
                    // Execution status indicator
                    if let status = scriptExecutor.lastExecutionStatus {
                        Circle()
                            .fill(status == .success ? Color.green : (status == .running ? Color.orange : Color.red))
                            .frame(width: 8, height: 8)
                            .help(status == .success ? "Last execution: Success" : (status == .running ? "Script running..." : "Last execution: Failed"))
                    }

                    Button(action: runScript) {
                        Label("Run", systemImage: scriptExecutor.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(scriptExecutor.isRunning ? .red : .blue)
                    .help(scriptExecutor.isRunning ? "Stop script (⌘R)" : "Run script (⌘R)")
                }
            }

            ToolbarButton(icon: "folder.fill", action: openFile, tooltip: "Open File (⌘O)", label: "Open")
            ToolbarButton(icon: "square.and.arrow.down.fill", action: saveFile, tooltip: "Save (⌘S)", label: "Save", disabled: activeTab == nil)

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 6)

            // Debug Console (combines debug toggle and console into one)
            DebugToggleButton(action: showDebugConsole)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(1.0))
    }

    @ViewBuilder
    private var statusBarView: some View {
        if let tab = activeTab {
            StatusBarView(tab: tab)
        }
    }

    private var scriptOutputView: some View {
        VStack(spacing: 0) {
            // Output window header
            HStack {
                Text("Script Output")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { scriptExecutor.clearOutput() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Clear output")

                Button(action: { showScriptOutput = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Hide output window")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Output text
            ScrollView {
                Text(scriptExecutor.output.isEmpty ? "No output" : scriptExecutor.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(scriptExecutor.output.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minHeight: 100, maxHeight: 400)
    }

    private func formatFileSize(_ text: String) -> String {
        let bytes = text.utf8.count

        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        } else if bytes < 1024 * 1024 * 1024 {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.2f MB", mb)
        } else {
            let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB", gb)
        }
    }

    @ViewBuilder
    private var replaceNotificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(replaceNotificationMessage)
                    .font(.body)
                    .fontWeight(.medium)

                Text("To undo this change use Undo or ⌘Z")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                withAnimation {
                    showReplaceNotification = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .padding()
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Workspace tabs
            WorkspaceBar(workspaceManager: workspaceManager)

            Divider()

            // Toolbar with solid background
            toolbarView

            Divider()

            // Main content area with sidebar and editor
            HStack(spacing: 0) {
                // Sidebar with file list (only if workspace has tabManager and sidebar is visible)
                if showSidebar, let tm = tabManager {
                    SidebarView(
                        tabManager: tm,
                        onNewFile: newDocument,
                        onOpenFile: openFile
                    )

                    Divider()
                }

                // Editor area
                VStack(spacing: 0) {
                    // Find & Replace panel
                    if showFindPanel, let tab = activeTab {
                        FindReplacePanel(
                            isVisible: $showFindPanel,
                            searchText: $searchText,
                            replaceText: $replaceText,
                            documentText: Binding(
                                get: { tab.textEngine.text },
                                set: { tab.textEngine.syncTextFromView($0) }
                            )
                        )

                        Divider()
                    }

                    // Main editor with optional script output window
                    if let tab = activeTab {
                        if showScriptOutput {
                            // Editor with output window (resizable)
                            GeometryReader { geometry in
                                VStack(spacing: 0) {
                                    // Editor
                                    EditorView(textEngine: tab.textEngine, documentInfo: tab.documentInfo)
                                        .id(tab.id) // Force new view instance for each tab
                                        .frame(height: geometry.size.height - outputWindowHeight)

                                    // Draggable divider
                                    Rectangle()
                                        .fill(Color(NSColor.separatorColor))
                                        .frame(height: 1)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(height: 8)
                                                .contentShape(Rectangle())
                                                .cursor(.resizeUpDown)
                                        )
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let newHeight = outputWindowHeight - value.translation.height
                                                    outputWindowHeight = max(100, min(400, newHeight))
                                                }
                                        )

                                    // Script output window
                                    scriptOutputView
                                        .frame(height: outputWindowHeight)
                                }
                            }
                        } else {
                            // Editor only
                            EditorView(textEngine: tab.textEngine, documentInfo: tab.documentInfo)
                                .id(tab.id) // Force new view instance for each tab
                        }
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No open documents")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                Button("New File") {
                                    newDocument()
                                }
                                .buttonStyle(.bordered)
                                .keyboardShortcut("n", modifiers: .command)

                                Button("Open File") {
                                    openFile()
                                }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut("o", modifiers: .command)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            Divider()

            // Status bar at bottom
            statusBarView
        }
        .overlay(alignment: .bottom) {
            if showReplaceNotification {
                replaceNotificationBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            mainContentView
                .onChange(of: geometry.size.width) { oldWidth, newWidth in
                    handleWindowResize(newWidth: newWidth)
                }
        }
        .modifier(AlertsModifier(
                showingError: $showingError,
                errorMessage: errorMessage,
                tabManager: tabManager
            ))
            .modifier(DocumentNotificationsModifier(
                newDocument: newDocument,
                openFile: openFile,
                saveFile: saveFile,
                saveFileAs: saveFileAs,
                exportAs: exportAs,
                saveAndCloseTab: saveAndCloseTab
            ))
            .modifier(ScriptNotificationsModifier(
                runScript: runScript,
                scriptExecutor: scriptExecutor
            ))
            .modifier(EditorNotificationsModifier(
                activeTab: activeTab,
                tabManager: tabManager
            ))
            // Find panel notifications
            .onReceive(NotificationCenter.default.publisher(for: .showFindPanel)) { _ in
                showFindPanel = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showGoToLine)) { _ in
                showGoToLine = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                showSidebar.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .runUnixCommand)) { _ in
                showUnixCommandSheet = true
            }
            // Replace notification
            .onReceive(NotificationCenter.default.publisher(for: .showReplaceNotification)) { notification in
                if let info = notification.object as? ReplaceNotificationInfo {
                    let message = info.count == 1
                        ? "Replaced 1 occurrence"
                        : "Replaced \(info.count) occurrences"
                    replaceNotificationMessage = message

                    withAnimation {
                        showReplaceNotification = true
                    }

                    // Auto-dismiss after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showReplaceNotification = false
                        }
                    }
                }
            }
            // Auto-save notification
            .onReceive(NotificationCenter.default.publisher(for: .autoSaveTriggered)) { _ in
                autoSaveModifiedDocuments()
            }
            // Print notification
            .onReceive(NotificationCenter.default.publisher(for: .printDocument)) { _ in
                printDocument()
            }
            .onAppear {
                // Initialize auto-save manager
                _ = AutoSaveManager.shared

                // Capture user's label preference
                userWantsLabels = preferences.showToolbarLabels

                // Set minimum window size based on current label state
                if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
                    if preferences.showToolbarLabels {
                        // Labels are on - set wider minimum to prevent label wrapping
                        window.minSize = NSSize(width: 1240, height: 400)
                    } else {
                        // Icons only - set narrower minimum to prevent icon stacking
                        window.minSize = NSSize(width: 680, height: 400)
                    }
                }
            }
            // Go to Line sheet
            .sheet(isPresented: $showGoToLine) {
                JumpToLineView(isPresented: $showGoToLine) { lineNumber in
                    jumpToLine(lineNumber)
                }
            }
            // Unix Command sheet
            .sheet(isPresented: $showUnixCommandSheet) {
                UnixCommandView(
                    isPresented: $showUnixCommandSheet,
                    command: $unixCommand,
                    onExecute: { command in
                        executeUnixCommand(command)
                    }
                )
            }
            // Character Inspector notification
            .onReceive(NotificationCenter.default.publisher(for: .showCharacterInspector)) { _ in
                showCharacterInspectorForSelection()
            }
            // Character Inspector window
            .onChange(of: showCharacterInspector) { oldValue, newValue in
                if newValue, let data = inspectorData {
                    showCharacterInspectorWindow(data: data)
                }
            }
    }

    private func showCharacterInspectorForSelection() {
        guard let tab = activeTab else { return }

        // Get current editor font
        let font = preferences.editorFont

        // Get selected text or character at cursor
        let selectedText: String
        if let range = tab.textEngine.selectionRange, range.lowerBound < range.upperBound {
            // User has selected text
            let text = tab.textEngine.text
            let start = text.index(text.startIndex, offsetBy: range.lowerBound)
            let end = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
            selectedText = String(text[start..<end])
        } else if tab.textEngine.cursorPosition < tab.textEngine.text.count {
            // No selection, get character at cursor
            let text = tab.textEngine.text
            let index = text.index(text.startIndex, offsetBy: tab.textEngine.cursorPosition)
            selectedText = String(text[index])
        } else {
            // Cursor at end of document or empty document
            selectedText = ""
        }

        // Create inspector data as single atomic unit
        inspectorData = InspectorData(
            selectedText: selectedText,
            font: font,
            id: UUID()
        )

        // Show the inspector immediately - data is already set
        showCharacterInspector = true
    }

    private func showCharacterInspectorWindow(data: InspectorData) {
        // Close existing window if open
        if let existingWindow = characterInspectorWindow {
            existingWindow.close()
            characterInspectorWindow = nil
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Inspector"
        window.contentView = NSHostingView(
            rootView: CharacterInspectorView(selectedText: data.selectedText, font: data.font)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        window.isReleasedWhenClosed = false  // Keep window alive

        // Store reference to keep window alive
        characterInspectorWindow = window

        // Observe window close to clean up reference
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            window.contentView = nil
        }

        // Reset the state so it can be triggered again
        showCharacterInspector = false
    }

    private func jumpToLine(_ lineNumber: Int) {
        guard let tab = activeTab else { return }
        let lines = tab.textEngine.text.components(separatedBy: .newlines)
        guard lineNumber > 0 && lineNumber <= lines.count else { return }

        // Calculate position at start of line
        var position = 0
        for i in 0..<(lineNumber - 1) {
            position += lines[i].count + 1 // +1 for newline
        }

        tab.textEngine.cursorPosition = position
        NotificationCenter.default.post(name: .jumpToLine, object: position)
    }

    private func autoSaveModifiedDocuments() {
        // Auto-save all modified documents that have a file path
        guard let tm = tabManager else { return }
        for tab in tm.tabs where tab.isModified && tab.documentInfo != nil {
            guard let docInfo = tab.documentInfo else { continue }

            documentManager.currentDocument = docInfo
            Task {
                do {
                    // Create backup if enabled
                    try AutoSaveManager.shared.createBackup(for: docInfo.url)

                    // Save the document
                    try await documentManager.save(content: tab.textEngine.text)
                    tab.markAsSaved()
                } catch {
                    // Silently fail for auto-save - don't interrupt user
                    print("Auto-save failed for \(docInfo.url.lastPathComponent): \(error)")
                }
            }
        }
    }

    private func printDocument() {
        print("🖨️ ╔════════════════════════════════════════╗")
        print("🖨️ ║   printDocument() CALLED              ║")
        print("🖨️ ╚════════════════════════════════════════╝")

        guard let tab = activeTab else {
            print("🖨️ ❌ ERROR: No active tab")
            return
        }

        print("🖨️ ✅ Active tab found: \(tab.fullDisplayName)")

        Task { @MainActor in
            // Get the text content
            let text = tab.textEngine.text
            let font = preferences.editorFont

            print("🖨️ Text length: \(text.count) characters")
            print("🖨️ Font: \(font)")

            // Create attributed string
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 2

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ]

            let attributedString = NSAttributedString(string: text, attributes: attributes)

            // Get document name
            let documentName = tab.documentInfo?.url.lastPathComponent ?? tab.fullDisplayName

            print("🖨️ Document name: \(documentName)")

            // Create printable view
            let printView = PrintableDocumentView(attributedString: attributedString)

            print("🖨️ ✅ PrintableDocumentView created")

            // Create print operation
            let printInfo = NSPrintInfo.shared
            let printOp = NSPrintOperation(view: printView, printInfo: printInfo)
            printOp.jobTitle = documentName
            printOp.showsPrintPanel = true
            printOp.showsProgressPanel = true

            print("🖨️ ✅ NSPrintOperation created")
            print("🖨️ Print info: \(printInfo)")
            print("🖨️ Job title: \(documentName)")

            // Run print operation
            if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
                print("🖨️ ✅ Found window: \(window)")
                print("🖨️ Calling printOp.runModal(for: window)")
                printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
                print("🖨️ printOp.runModal() returned")
            } else {
                print("🖨️ ⚠️ No window found, calling printOp.run()")
                printOp.run()
                print("🖨️ printOp.run() returned")
            }
        }
    }

    // MARK: - Actions

    private func newDocument() {
        tabManager?.createNewTab()
    }

    // MARK: - Debug Actions

    private func toggleDebugLogging() {
        Task { @MainActor in
            DebugLogger.shared.isEnabled.toggle()
            DebugLogger.shared.info("Debug logging \(DebugLogger.shared.isEnabled ? "enabled" : "disabled")", category: "System")
        }
    }

    private func showDebugConsole() {
        NotificationCenter.default.post(name: .showDebugConsole, object: nil)
    }

    private func openFile() {
        documentManager.openDocument { result in
            switch result {
            case .success(let (content, docInfo)):
                // Check preference for opening in new workspace
                if preferences.openDocumentsInNewWorkspace == .always {
                    // Create new workspace for this document
                    workspaceManager.createNewWorkspace()
                    if let newWorkspace = workspaceManager.workspaces.last {
                        workspaceManager.switchToWorkspace(newWorkspace.id)
                        newWorkspace.tabManager.openFile(content: content, documentInfo: docInfo)
                    }
                } else {
                    // Open in current workspace
                    guard let tm = tabManager else { return }
                    if tm.isFileOpen(docInfo.url) {
                        errorMessage = "File is already open"
                        showingError = true
                    } else {
                        tm.openFile(content: content, documentInfo: docInfo)
                    }
                }

            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func saveFile() {
        guard let tab = activeTab else { return }

        if let docInfo = tab.documentInfo {
            // Save to existing file
            documentManager.currentDocument = docInfo
            Task {
                do {
                    try await documentManager.save(content: tab.textEngine.text)
                    tab.markAsSaved()
                    // Notify that save completed
                    await MainActor.run {
                        NotificationCenter.default.post(name: .saveCompleted, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        } else {
            // No file associated, do Save As
            saveFileAs()
        }
    }

    private func saveFileAs() {
        guard let tab = activeTab else { return }

        documentManager.saveAs(content: tab.textEngine.text) { result in
            switch result {
            case .success(let docInfo):
                tab.documentInfo = docInfo
                tab.markAsSaved()
                // Notify that save completed
                NotificationCenter.default.post(name: .saveCompleted, object: nil)

            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func saveAndCloseTab(_ tabID: UUID) {
        guard let tab = tabManager?.getTab(byID: tabID) else { return }

        // Save first
        if let docInfo = tab.documentInfo {
            documentManager.currentDocument = docInfo
            Task {
                do {
                    try await documentManager.save(content: tab.textEngine.text)
                    tab.markAsSaved()
                    await MainActor.run {
                        tabManager?.performCloseTab(tab)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        } else {
            // Need to save as first
            documentManager.saveAs(content: tab.textEngine.text) { result in
                switch result {
                case .success(let docInfo):
                    tab.documentInfo = docInfo
                    tab.markAsSaved()
                    tabManager?.performCloseTab(tab)

                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func runScript() {
        guard let tab = activeTab else { return }

        if scriptExecutor.isRunning {
            scriptExecutor.stopExecution()
        } else {
            guard tab.isExecutable else {
                errorMessage = "Current file is not executable"
                showingError = true
                return
            }

            // Show output window and clear previous output
            showScriptOutput = true
            scriptExecutor.clearOutput()

            Task {
                do {
                    try await scriptExecutor.executeScript(
                        content: tab.textEngine.text,
                        format: tab.documentInfo?.format ?? .plainText,
                        url: tab.documentInfo?.url
                    )
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }

    private func executeUnixCommand(_ command: String) {
        // Show output window and clear previous output
        showScriptOutput = true
        scriptExecutor.clearOutput()

        Task {
            do {
                try await scriptExecutor.executeCommand(command)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func exportAs(format: FileFormat) {
        guard let tab = activeTab else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "export.\(format.fileExtension)"
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let formatHandler = FileFormatHandler()
                        try await formatHandler.exportFile(
                            content: tab.textEngine.text,
                            to: url,
                            format: format,
                            encoding: .utf8
                        )
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                }
            }
        }
    }

    private func insertShebang(_ shebang: String) {
        guard let tab = activeTab else { return }

        // Insert shebang/header at the beginning of the document
        let currentText = tab.textEngine.text

        // Trim whitespace to check if document is truly empty
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if there's already a header at the start
        let hasShebang = trimmedText.hasPrefix("#!")
        let hasXMLHeader = trimmedText.hasPrefix("<?xml")
        let hasExistingHeader = hasShebang || hasXMLHeader

        if trimmedText.isEmpty {
            // Document is empty - insert fresh header
            tab.textEngine.loadText(shebang + "\n")
            // Immediately set cursor to 0 to prevent scroll to right
            tab.textEngine.cursorPosition = 0

            // Position cursor and scroll after load completes
            DispatchQueue.main.async {
                // Scroll to top-left corner first
                NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)

                // Then position cursor correctly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    if shebang.contains("<dict>\n\t\n</dict>") {
                        // Find the position between <dict> and </dict> (after the tab)
                        if let dictStart = shebang.range(of: "<dict>\n\t") {
                            let cursorPos = shebang.distance(from: shebang.startIndex, to: dictStart.upperBound)
                            tab.textEngine.cursorPosition = cursorPos
                        }
                    } else {
                        // For other headers, position cursor at the end (on new line after header)
                        tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                    }
                    tab.textEngine.objectWillChange.send()
                }
            }
            return
        } else if !hasExistingHeader {
            // No existing header - insert at beginning of document
            tab.textEngine.insert(shebang + "\n", at: 0)
            // Immediately set cursor to 0 to prevent scroll to right
            tab.textEngine.cursorPosition = 0

            // Position cursor and scroll after insert completes
            DispatchQueue.main.async {
                // Scroll to top-left corner first
                NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)

                // Then position cursor correctly (on new line after shebang)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                    tab.textEngine.objectWillChange.send()
                }
            }
            return
        } else if hasExistingHeader {
            // Replace existing header
            // For XML/plist headers, we need to replace the entire header block
            if hasXMLHeader && shebang.hasPrefix("<?xml") {
                // Find the end of the plist/XML header (look for </plist> or just first line if simple XML)
                if currentText.contains("</plist>") {
                    if let plistEnd = currentText.range(of: "</plist>") {
                        let endIndex = currentText.distance(from: currentText.startIndex, to: plistEnd.upperBound)
                        // Find the newline after </plist>
                        let searchStart = currentText.index(currentText.startIndex, offsetBy: endIndex)
                        if let newlineAfterPlist = currentText[searchStart...].firstIndex(of: "\n") {
                            let deleteEnd = currentText.distance(from: currentText.startIndex, to: newlineAfterPlist) + 1
                            tab.textEngine.delete(range: 0..<deleteEnd)
                        } else {
                            tab.textEngine.delete(range: 0..<endIndex)
                        }
                    }
                } else {
                    // Simple XML header - just replace first line
                    if let firstNewline = currentText.firstIndex(of: "\n") {
                        let distance = currentText.distance(from: currentText.startIndex, to: firstNewline)
                        tab.textEngine.delete(range: 0..<(distance + 1))
                    }
                }
                tab.textEngine.insert(shebang + "\n", at: 0)
                // Immediately set cursor to 0 to prevent scroll to right
                tab.textEngine.cursorPosition = 0

                // Position cursor and scroll after insert completes
                DispatchQueue.main.async {
                    // Scroll to top-left corner first
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)

                    // Then position cursor correctly (on new line after shebang)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                        tab.textEngine.objectWillChange.send()
                    }
                }
                return
            } else if hasShebang && shebang.hasPrefix("#!") {
                // Replace existing shebang with new one
                if let firstNewline = currentText.firstIndex(of: "\n") {
                    let distance = currentText.distance(from: currentText.startIndex, to: firstNewline)
                    tab.textEngine.delete(range: 0..<(distance + 1))
                }
                tab.textEngine.insert(shebang + "\n", at: 0)
                // Immediately set cursor to 0 to prevent scroll to right
                tab.textEngine.cursorPosition = 0

                // Position cursor and scroll after insert completes
                DispatchQueue.main.async {
                    // Scroll to top-left corner first
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)

                    // Then position cursor correctly (on new line after shebang)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                        tab.textEngine.objectWillChange.send()
                    }
                }
                return
            } else {
                // Different header types - delete old header first, then insert new one
                if hasXMLHeader {
                    // Delete XML/plist header
                    if currentText.contains("</plist>") {
                        if let plistEnd = currentText.range(of: "</plist>") {
                            let endIndex = currentText.distance(from: currentText.startIndex, to: plistEnd.upperBound)
                            // Find the newline after </plist>
                            let searchStart = currentText.index(currentText.startIndex, offsetBy: endIndex)
                            if let newlineAfterPlist = currentText[searchStart...].firstIndex(of: "\n") {
                                let deleteEnd = currentText.distance(from: currentText.startIndex, to: newlineAfterPlist) + 1
                                tab.textEngine.delete(range: 0..<deleteEnd)
                            } else {
                                tab.textEngine.delete(range: 0..<endIndex)
                            }
                        }
                    } else {
                        // Simple XML header - delete first line
                        if let firstNewline = currentText.firstIndex(of: "\n") {
                            let distance = currentText.distance(from: currentText.startIndex, to: firstNewline)
                            tab.textEngine.delete(range: 0..<(distance + 1))
                        }
                    }
                } else if hasShebang {
                    // Delete shebang (first line)
                    if let firstNewline = currentText.firstIndex(of: "\n") {
                        let distance = currentText.distance(from: currentText.startIndex, to: firstNewline)
                        tab.textEngine.delete(range: 0..<(distance + 1))
                    }
                }
                // Now insert the new header
                tab.textEngine.insert(shebang + "\n", at: 0)
                // Immediately set cursor to 0 to prevent scroll to right
                tab.textEngine.cursorPosition = 0

                // Position cursor and scroll after insert completes
                DispatchQueue.main.async {
                    // Scroll to top-left corner first
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)

                    // Then position cursor correctly (on new line after shebang)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                        tab.textEngine.objectWillChange.send()
                    }
                }
            }
        }
    }

    private func increaseFontSize() {
        preferences.fontSize += 1
    }

    private func decreaseFontSize() {
        if preferences.fontSize > 8 {
            preferences.fontSize -= 1
        }
    }
}

// MARK: - Toolbar Button Component

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    var label: String? = nil
    var disabled: Bool = false

    @State private var isHovered: Bool = false
    @ObservedObject var preferences = AppPreferences.shared

    var body: some View {
        Button(action: action) {
            if preferences.showToolbarLabels, let labelText = label {
                Label(labelText, systemImage: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(buttonForegroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(buttonBackgroundColor)
                    .cornerRadius(6)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(buttonForegroundColor)
                    .frame(width: 32, height: 32)
                    .background(buttonBackgroundColor)
                    .cornerRadius(6)
            }
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .disabled(disabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var buttonBackgroundColor: Color {
        if disabled {
            return Color.clear
        } else if isHovered {
            return Color(NSColor.controlAccentColor).opacity(0.15)
        } else {
            return Color.clear
        }
    }

    private var buttonForegroundColor: Color {
        if disabled {
            return Color.secondary.opacity(0.5)
        } else if isHovered {
            return Color(NSColor.controlAccentColor)
        } else {
            return Color.primary
        }
    }
}

// MARK: - Debug Toggle Button

struct DebugToggleButton: View {
    let action: () -> Void
    @State private var isHovered: Bool = false
    @ObservedObject var logger = DebugLogger.shared
    @ObservedObject var preferences = AppPreferences.shared

    var body: some View {
        Button(action: action) {
            if preferences.showToolbarLabels {
                Label("Debug", systemImage: logger.isEnabled ? "ladybug.fill" : "ladybug")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(buttonForegroundColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(buttonBackgroundColor)
                    .cornerRadius(6)
            } else {
                Image(systemName: logger.isEnabled ? "ladybug.fill" : "ladybug")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(buttonForegroundColor)
                    .frame(width: 32, height: 32)
                    .background(buttonBackgroundColor)
                    .cornerRadius(6)
            }
        }
        .buttonStyle(.plain)
        .help(logger.isEnabled ? "Disable Debug Logging" : "Enable Debug Logging")
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var buttonBackgroundColor: Color {
        if isHovered {
            return Color(NSColor.controlAccentColor).opacity(0.15)
        } else {
            return Color.clear
        }
    }

    private var buttonForegroundColor: Color {
        if isHovered {
            return Color(NSColor.controlAccentColor)
        } else {
            return Color.primary
        }
    }
}

// MARK: - View Modifiers

struct AlertsModifier: ViewModifier {
    @Binding var showingError: Bool
    let errorMessage: String
    var tabManager: TabManager?

    func body(content: Content) -> some View {
        if let tm = tabManager {
            content
                .alert("Error", isPresented: $showingError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
                .alert("Save Changes?", isPresented: Binding(
                    get: { tm.showCloseConfirmation },
                    set: { tm.showCloseConfirmation = $0 }
                )) {
                    Button("Save") {
                        tm.saveAndCloseTab()
                    }
                    Button("Don't Save", role: .destructive) {
                        tm.discardAndCloseTab()
                    }
                    Button("Cancel", role: .cancel) {
                        tm.cancelClose()
                    }
                } message: {
                    if let tab = tm.tabToClose {
                        Text("Do you want to save the changes to \"\(tab.fullDisplayName)\"?")
                    }
                }
        } else {
            content
                .alert("Error", isPresented: $showingError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
        }
    }
}

struct DocumentNotificationsModifier: ViewModifier {
    let newDocument: () -> Void
    let openFile: () -> Void
    let saveFile: () -> Void
    let saveFileAs: () -> Void
    let exportAs: (FileFormat) -> Void
    let saveAndCloseTab: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .newDocument)) { _ in
                newDocument()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDocument)) { _ in
                openFile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocument)) { _ in
                saveFile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocumentAs)) { _ in
                saveFileAs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportDocument)) { notification in
                if let format = notification.object as? FileFormat {
                    exportAs(format)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveAndCloseTab)) { notification in
                if let tabID = notification.object as? UUID {
                    saveAndCloseTab(tabID)
                }
            }
    }
}

struct ScriptNotificationsModifier: ViewModifier {
    let runScript: () -> Void
    @ObservedObject var scriptExecutor: ScriptExecutor

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .runScript)) { _ in
                runScript()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopScript)) { _ in
                scriptExecutor.stopExecution()
            }
    }
}

struct EditorNotificationsModifier: ViewModifier {
    let activeTab: TabDocument?
    var tabManager: TabManager?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .convertLineEnding)) { notification in
                if let lineEnding = notification.object as? TextEngine.LineEnding,
                   let tab = activeTab {
                    tab.textEngine.convertLineEndings(to: lineEnding)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeActiveTab)) { _ in
                if let tab = activeTab {
                    tabManager?.closeTab(tab)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeDocument)) { _ in
                // Only handle close if the key window is the main document window
                // If it's preferences or another window, let the system handle it
                if let keyWindow = NSApplication.shared.keyWindow,
                   keyWindow === CustomWindowDelegate.shared.managedWindow {
                    // Use the shared delegate method to handle close with save dialog
                    _ = CustomWindowDelegate.shared.handleCloseActiveTab(closeWindow: false)
                } else {
                    // Not the main window, close it normally
                    NSApplication.shared.keyWindow?.performClose(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transformUppercase)) { _ in
                if let tab = activeTab {
                    tab.textEngine.transformToUppercase()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transformLowercase)) { _ in
                if let tab = activeTab {
                    tab.textEngine.transformToLowercase()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .convertTabsToSpaces)) { _ in
                if let tab = activeTab {
                    tab.textEngine.convertTabsToSpaces()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .convertSpacesToTabs)) { _ in
                if let tab = activeTab {
                    tab.textEngine.convertSpacesToTabs()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .undoEdit)) { _ in
                if let tab = activeTab {
                    tab.textEngine.undo()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .redoEdit)) { _ in
                if let tab = activeTab {
                    tab.textEngine.redo()
                }
            }
    }
}

// MARK: - Content View Wrapper

struct ContentViewWrapper: View {
    @StateObject private var workspaceManager = WorkspaceManager()
    @ObservedObject var preferences = AppPreferences.shared

    var body: some View {
        ZStack {
            // Window accessor to set window delegate
            WindowAccessor()

            ContentView()
                .environmentObject(workspaceManager)
        }
        .onAppear {
            AppDelegate.workspaceManager = workspaceManager
        }
    }
}

extension String.Encoding {
    var description: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf32: return "UTF-32"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO Latin 1"
        case .macOSRoman: return "Mac Roman"
        case .windowsCP1252: return "Windows-1252"
        default: return "Unknown"
        }
    }
}

#Preview("ContentView - With Open Files") {
    ContentViewWithFilesPreview()
}

#Preview("ContentView - Empty Workspace") {
    ContentViewEmptyPreview()
}

#Preview("ContentView - Multiple Workspaces") {
    ContentViewMultipleWorkspacesPreview()
}

struct ContentViewWithFilesPreview: View {
    @StateObject private var manager = WorkspaceManager()

    var body: some View {
        ContentView()
            .environmentObject(manager)
            .frame(width: 1000, height: 700)
            .onAppear {
                manager.createNewWorkspace()

                // Add some sample files to the workspace
                if let workspace = manager.activeWorkspace {
                    workspace.tabManager.createNewTab()
                    workspace.tabManager.tabs[0].textEngine.loadText("""
                    #!/usr/bin/env python3

                    def hello_world():
                        print("Hello, World!")
                        return True

                    if __name__ == "__main__":
                        hello_world()
                    """)
                    workspace.tabManager.tabs[0].documentInfo = DocumentManager.DocumentInfo(
                        url: URL(fileURLWithPath: "/Users/test/hello.py"),
                        format: .plainText,
                        encoding: .utf8,
                        isRemote: false
                    )

                    workspace.tabManager.openFile(content: """
                    #!/bin/bash

                    echo "Starting script..."

                    for i in {1..5}; do
                        echo "Iteration $i"
                    done

                    echo "Done!"
                    """, documentInfo: DocumentManager.DocumentInfo(
                        url: URL(fileURLWithPath: "/Users/test/script.sh"),
                        format: .shell,
                        encoding: .utf8,
                        isRemote: false
                    ))
                }
            }
    }
}

struct ContentViewEmptyPreview: View {
    @StateObject private var manager = WorkspaceManager()

    var body: some View {
        ContentView()
            .environmentObject(manager)
            .frame(width: 1000, height: 700)
            .onAppear {
                manager.createNewWorkspace()
            }
    }
}

struct ContentViewMultipleWorkspacesPreview: View {
    @StateObject private var manager = WorkspaceManager()

    var body: some View {
        ContentView()
            .environmentObject(manager)
            .frame(width: 1000, height: 700)
            .onAppear {
                manager.createNewWorkspace()
                manager.createNewWorkspace()

                // Add file to first workspace
                if let workspace = manager.workspaces.first {
                    workspace.tabManager.createNewTab()
                    workspace.tabManager.tabs[0].textEngine.loadText("print('Workspace 1')")
                    workspace.tabManager.tabs[0].isModified = true
                }
            }
    }
}

// MARK: - Status Bar View
struct StatusBarView: View {
    @ObservedObject var tab: TabDocument
    @ObservedObject var preferences = AppPreferences.shared

    var body: some View {
        HStack(spacing: 8) {
            // Line and Column
            Text("Line: \(tab.currentLine), Col: \(tab.currentColumn)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("•").font(.caption).foregroundColor(.secondary)

            // File size
            Text(tab.fileSize)
                .font(.caption)
                .foregroundColor(.secondary)

            // Character count
            if preferences.showCharacterCount {
                Text("•").font(.caption).foregroundColor(.secondary)
                Text("\(tab.characterCount) chars")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Word count
            if preferences.showWordCount {
                Text("•").font(.caption).foregroundColor(.secondary)
                Text("\(tab.wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let doc = tab.documentInfo {
                Text("•").font(.caption).foregroundColor(.secondary)

                // Encoding selector
                Menu {
                    Button("UTF-8") {
                        changeEncoding(to: .utf8)
                    }
                    Button("UTF-16") {
                        changeEncoding(to: .utf16)
                    }
                    Button("UTF-32") {
                        changeEncoding(to: .utf32)
                    }
                    Button("ASCII") {
                        changeEncoding(to: .ascii)
                    }
                    Button("ISO Latin 1") {
                        changeEncoding(to: .isoLatin1)
                    }
                    Button("Mac OS Roman") {
                        changeEncoding(to: .macOSRoman)
                    }
                    Button("Windows Latin 1") {
                        changeEncoding(to: .windowsCP1252)
                    }
                } label: {
                    Text(doc.encoding.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Text("•").font(.caption).foregroundColor(.secondary)
                Text(doc.format.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("•").font(.caption).foregroundColor(.secondary)

            // Line ending selector
            Menu {
                Button("LF (Unix/macOS)") {
                    changeLineEnding(to: .lf)
                }
                Button("CRLF (Windows)") {
                    changeLineEnding(to: .crlf)
                }
                Button("CR (Classic Mac)") {
                    changeLineEnding(to: .cr)
                }
            } label: {
                Text(tab.textEngine.lineEnding.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(1.0))
    }

    private func changeEncoding(to encoding: String.Encoding) {
        guard var docInfo = tab.documentInfo else { return }
        docInfo.encoding = encoding
        tab.documentInfo = docInfo
        tab.isModified = true
    }

    private func changeLineEnding(to lineEnding: TextEngine.LineEnding) {
        tab.textEngine.convertLineEndings(to: lineEnding)
        tab.isModified = true
    }
}

// MARK: - View Extensions

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }
}
