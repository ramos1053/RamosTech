import SwiftUI

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
    @State private var showCharacterInspector: Bool = false
    @State private var selectedTextForInspector: String = ""

    // Sidebar visibility
    @State private var showSidebar: Bool = true

    // Script output window
    @State private var showScriptOutput: Bool = false
    @State private var outputWindowHeight: CGFloat = 200

    var activeWorkspace: Workspace? {
        workspaceManager.activeWorkspace
    }

    var tabManager: TabManager? {
        activeWorkspace?.tabManager
    }

    var activeTab: TabDocument? {
        tabManager?.activeTab
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

            // Debug controls
            DebugToggleButton(action: toggleDebugLogging)

            ToolbarButton(
                icon: "terminal",
                action: showDebugConsole,
                tooltip: "Show Debug Console (⌘⌥D)",
                label: "Console"
            )
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
    }

    var body: some View {
        mainContentView
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
            }
            // Go to Line sheet
            .sheet(isPresented: $showGoToLine) {
                JumpToLineView(isPresented: $showGoToLine) { lineNumber in
                    jumpToLine(lineNumber)
                }
            }
            // Character Inspector notification
            .onReceive(NotificationCenter.default.publisher(for: .showCharacterInspector)) { _ in
                showCharacterInspectorForSelection()
            }
            // Character Inspector popover
            .popover(isPresented: $showCharacterInspector, arrowEdge: .bottom) {
                CharacterInspectorView(selectedText: selectedTextForInspector)
            }
    }

    private func showCharacterInspectorForSelection() {
        guard let tab = activeTab else { return }

        // Get selected text or character at cursor
        if let range = tab.textEngine.selectionRange {
            let text = tab.textEngine.text
            let start = text.index(text.startIndex, offsetBy: range.lowerBound)
            let end = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
            selectedTextForInspector = String(text[start..<end])
        } else if tab.textEngine.cursorPosition < tab.textEngine.text.count {
            let text = tab.textEngine.text
            let index = text.index(text.startIndex, offsetBy: tab.textEngine.cursorPosition)
            selectedTextForInspector = String(text[index])
        } else {
            selectedTextForInspector = ""
        }

        showCharacterInspector = true
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
        guard let tab = activeTab else { return }

        // Create print view with document content
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        // Create attributed string for printing
        let text = tab.textEngine.text
        let font = preferences.editorFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // Create text view for printing
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: printInfo.paperSize.width - 72, height: printInfo.paperSize.height))
        printView.textStorage?.setAttributedString(attributedString)

        // Get document name for header
        let documentName = tab.documentInfo?.url.lastPathComponent ?? tab.fullDisplayName

        // Configure print operation
        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.jobTitle = documentName
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true

        // Run print operation
        printOperation.run()
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

            // Position cursor after the inserted header (loadText sets cursor to 0, so we need to adjust)
            // For plist headers, position cursor inside the <dict> tags
            if shebang.contains("<dict>\n\t\n</dict>") {
                // Find the position between <dict> and </dict> (after the tab)
                if let dictStart = shebang.range(of: "<dict>\n\t") {
                    let cursorPos = shebang.distance(from: shebang.startIndex, to: dictStart.upperBound)
                    tab.textEngine.cursorPosition = cursorPos
                    // Force update to sync cursor to text view
                    tab.textEngine.objectWillChange.send()
                }
            } else {
                // For other headers, position cursor at the end (on new line after header)
                tab.textEngine.cursorPosition = shebang.count + 1 // +1 for the newline
                // Force update to sync cursor to text view
                tab.textEngine.objectWillChange.send()
            }
        } else if !hasExistingHeader {
            tab.textEngine.insert(shebang + "\n", at: 0)
            // insert() already sets cursor correctly to the end of inserted text
            // Force update to sync cursor to text view
            tab.textEngine.objectWillChange.send()
        } else {
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
                // insert() already sets cursor correctly
                // Force update to sync cursor to text view
                tab.textEngine.objectWillChange.send()
            } else if hasShebang && shebang.hasPrefix("#!") {
                // Replace existing shebang with new one
                if let firstNewline = currentText.firstIndex(of: "\n") {
                    let distance = currentText.distance(from: currentText.startIndex, to: firstNewline)
                    tab.textEngine.delete(range: 0..<(distance + 1))
                }
                tab.textEngine.insert(shebang + "\n", at: 0)
                // insert() already sets cursor correctly
                // Force update to sync cursor to text view
                tab.textEngine.objectWillChange.send()
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
                // insert() already sets cursor correctly
                // Force update to sync cursor to text view
                tab.textEngine.objectWillChange.send()
            }
        }

        // Force scroll to left after inserting header
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: NSNotification.Name("ScrollToLeft"), object: nil)
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
