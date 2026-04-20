import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var preferences = AppPreferences.shared
    @State private var selectedTab = 0

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                EditorPreferencesView(preferences: preferences)
                    .tabItem {
                        Label("Editor", systemImage: "doc.text")
                    }
                    .tag(0)

                AppearancePreferencesView(preferences: preferences)
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .tag(1)

                DocumentPreferencesView(preferences: preferences)
                    .tabItem {
                        Label("Document", systemImage: "doc.text")
                    }
                    .tag(2)

                AdvancedPreferencesView(preferences: preferences)
                    .tabItem {
                        Label("Advanced", systemImage: "gearshape")
                    }
                    .tag(3)
            }
        }
        .frame(width: 700, height: dynamicHeight)
    }

    private var dynamicHeight: CGFloat {
        // Get screen height
        guard let screen = NSScreen.main else { return 650 }
        let screenHeight = screen.visibleFrame.height

        // Preferred height for content (enough to show all editor preferences without scrolling)
        let preferredHeight: CGFloat = 720

        // Cap at 80% of screen height to ensure window chrome is visible
        let maxHeight = screenHeight * 0.8

        return min(preferredHeight, maxHeight)
    }
}

// MARK: - Editor Preferences

struct EditorPreferencesView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 20) {
                    // Left Column
                    VStack(alignment: .leading, spacing: 16) {
                        // General Options
                        VStack(alignment: .leading, spacing: 8) {
                            Text("General")
                                .font(.headline)

                            Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                                .help("Display line numbers in the gutter")

                            Toggle("Draw Separator", isOn: $preferences.showLineNumberSeparator)
                                .help("Draw a vertical line between line numbers and text")
                                .disabled(!preferences.showLineNumbers)
                                .padding(.leading, 20)

                            Toggle("Wrap Lines", isOn: $preferences.wrapLines)
                                .help("Wrap long lines instead of scrolling horizontally")

                            Toggle("Enable Auto-Completion", isOn: $preferences.enableAutoCompletion)
                                .help("Show code completion suggestions as you type (press Esc to trigger manually)")

                            HStack {
                                Text("Trigger After:")
                                Stepper(value: $preferences.completionTriggerLength, in: 1...5) {
                                    Text("\(preferences.completionTriggerLength) character\(preferences.completionTriggerLength == 1 ? "" : "s")")
                                }
                                .frame(width: 130)
                                .disabled(!preferences.enableAutoCompletion)
                            }
                            .padding(.leading, 20)
                            .help("Minimum characters to type before auto-completion triggers")

                            Toggle("Enable Syntax Coloring", isOn: $preferences.enableSyntaxColoring)
                                .help("Highlight code syntax based on file type")

                            HStack {
                                Text("Open Documents:")
                                Picker("", selection: $preferences.openDocumentsInNewWorkspace) {
                                    Text("In New Workspace").tag(AppPreferences.OpenDocumentsMode.always)
                                    Text("In Current Workspace").tag(AppPreferences.OpenDocumentsMode.never)
                                }
                                .frame(width: 180)
                            }
                            .help("Choose whether to open documents in a new workspace or current workspace")

                            HStack {
                                Text("Undo Levels:")
                                TextField("", value: $preferences.undoHistoryLimit, format: .number)
                                    .frame(width: 70)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .help("Number of undo/redo operations to remember (1-1000)")

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default Window Size:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Text("Width:")
                                        .font(.caption)
                                    TextField("", value: $preferences.defaultWindowWidth, format: .number)
                                        .frame(width: 70)
                                        .textFieldStyle(.roundedBorder)

                                    Text("Height:")
                                        .font(.caption)
                                    TextField("", value: $preferences.defaultWindowHeight, format: .number)
                                        .frame(width: 70)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .padding(.leading, 20)
                            }
                        }

                        Divider()

                        // Current Line Highlighting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Line")
                                .font(.headline)

                            Toggle("Highlight Current Line", isOn: $preferences.showCurrentLineHighlight)
                                .help("Highlight the line where the cursor is positioned")

                            HStack {
                                Text("Color:")
                                Picker("", selection: $preferences.currentLineHighlightColor) {
                                    Text("Light Gray").tag("lightgray")
                                    Text("Light Blue").tag("lightblue")
                                    Text("Light Yellow").tag("lightyellow")
                                    Text("Light Green").tag("lightgreen")
                                    Text("Light Pink").tag("lightpink")
                                }
                                .frame(width: 120)
                                .disabled(!preferences.showCurrentLineHighlight)
                            }
                            .padding(.leading, 20)
                        }

                        Divider()

                        // Status Bar Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status Bar")
                                .font(.headline)

                            Toggle("Show Character Count", isOn: $preferences.showCharacterCount)
                                .help("Display real-time character count in the status bar")

                            Toggle("Show Word Count", isOn: $preferences.showWordCount)
                                .help("Display real-time word count in the status bar")
                        }

                        Divider()

                        // Script Execution Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Script Execution")
                                .font(.headline)

                            Toggle("Verbose Script Output", isOn: $preferences.verboseScriptOutput)
                                .help("Enable verbose/trace mode for scripts (bash -x, python -u, etc.). Shows each command before execution and detailed output.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Right Column
                    VStack(alignment: .leading, spacing: 16) {

                        // Invisible Characters Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invisible Characters")
                                .font(.headline)

                            Toggle("Show Invisible Characters", isOn: $preferences.showInvisibles)
                                .help("Display spaces, tabs, and line endings")

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Types:")
                                    .font(.caption)
                                    .foregroundColor(preferences.showInvisibles ? .secondary : .gray)
                                    .padding(.leading, 20)

                                Toggle("Line Endings", isOn: $preferences.showLineEndingsInvisible)
                                    .disabled(!preferences.showInvisibles)
                                    .padding(.leading, 20)
                                Toggle("Tabs", isOn: $preferences.showTabInvisible)
                                    .disabled(!preferences.showInvisibles)
                                    .padding(.leading, 20)
                                Toggle("Spaces", isOn: $preferences.showSpaceInvisible)
                                    .disabled(!preferences.showInvisibles)
                                    .padding(.leading, 20)
                                Toggle("Whitespace", isOn: $preferences.showWhitespaceInvisible)
                                    .disabled(!preferences.showInvisibles)
                                    .padding(.leading, 20)
                                Toggle("Control Characters", isOn: $preferences.showControlCharactersInvisible)
                                    .disabled(!preferences.showInvisibles)
                                    .padding(.leading, 20)
                            }

                            HStack {
                                Text("Color:")
                                Picker("", selection: $preferences.invisibleCharactersColor) {
                                    Text("Gray").tag("gray")
                                    Text("Blue").tag("blue")
                                    Text("Red").tag("red")
                                    Text("Green").tag("green")
                                    Text("Orange").tag("orange")
                                }
                                .frame(width: 100)
                                .disabled(!preferences.showInvisibles)
                            }
                            .padding(.leading, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()

                Divider()
                    .padding(.horizontal)

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        preferences.resetToDefaults()
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Appearance Preferences

struct AppearancePreferencesView: View {
    @ObservedObject var preferences: AppPreferences
    @State private var selectedThemeID: String

    init(preferences: AppPreferences) {
        self.preferences = preferences
        _selectedThemeID = State(initialValue: preferences.selectedThemeID)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Form {
                Section("Theme") {
                HStack {
                    Text("Color Scheme:")
                    Picker("", selection: $selectedThemeID) {
                        ForEach(EditorTheme.allThemes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .frame(width: 200)
                    .onChange(of: selectedThemeID) { _, newValue in
                        preferences.selectedThemeID = newValue
                    }
                }

                // Theme preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                    HStack(spacing: 0) {
                        // Line number area
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("1")
                            Text("2")
                            Text("3")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(preferences.currentTheme.lineNumberColor.nsColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 40)
                        .background(Color(preferences.currentTheme.lineNumberBackgroundColor.nsColor))

                        // Code area
                        VStack(alignment: .leading, spacing: 2) {
                            Text("func example() {")
                            Text("    print(\"Hello\")")
                            Text("}")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(preferences.currentTheme.textColor.nsColor))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(preferences.currentTheme.backgroundColor.nsColor))
                    }
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Section("Cursor") {
                Toggle("Cursor Blinks", isOn: $preferences.cursorBlinks)

                // Cursor preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview:")
                        .font(.caption)

                    HStack(spacing: 30) {
                        CursorPreview(type: .line, label: "Line", isSelected: preferences.cursorType == .line)
                            .onTapGesture {
                                preferences.cursorType = .line
                            }
                        CursorPreview(type: .block, label: "Block", isSelected: preferences.cursorType == .block)
                            .onTapGesture {
                                preferences.cursorType = .block
                            }
                        CursorPreview(type: .underline, label: "Underline", isSelected: preferences.cursorType == .underline)
                            .onTapGesture {
                                preferences.cursorType = .underline
                            }
                    }
                    .padding(12)
                    .background(Color(preferences.currentTheme.backgroundColor.nsColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Document Preferences

struct DocumentPreferencesView: View {
    @ObservedObject var preferences: AppPreferences
    @State private var selectedFont: String
    @State private var fontSize: Double

    init(preferences: AppPreferences) {
        self.preferences = preferences
        _selectedFont = State(initialValue: preferences.fontName)
        _fontSize = State(initialValue: preferences.fontSize)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Form {
                Section("Font") {
                HStack {
                    Text("Font Family:")
                    Picker("", selection: $selectedFont) {
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("SF Mono").tag("SFMono-Regular")
                        Text("Courier").tag("Courier")
                        Text("Courier New").tag("Courier New")
                        Text("Consolas").tag("Consolas")
                        Text("Source Code Pro").tag("SourceCodePro-Regular")
                        Text("Fira Code").tag("FiraCode-Regular")
                        Text("JetBrains Mono").tag("JetBrainsMono-Regular")
                    }
                    .frame(width: 200)
                    .onChange(of: selectedFont) { _, newValue in
                        preferences.fontName = newValue
                    }

                    Button("Choose...") {
                        showFontPanel()
                    }
                }

                HStack {
                    Text("Font Size:")
                    Stepper(value: $fontSize, in: 8...72, step: 1) {
                        Text("\(Int(fontSize)) pt")
                    }
                    .onChange(of: fontSize) { _, newValue in
                        preferences.fontSize = newValue
                    }
                }

                // Font preview
                VStack(alignment: .leading) {
                    Text("Preview:")
                        .font(.caption)
                    Text("The quick brown fox jumps over the lazy dog\n0123456789")
                        .font(.custom(preferences.fontName, size: preferences.fontSize))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
            }

            Section("Indentation") {
                HStack {
                    Text("Tab Width:")
                    Stepper(value: $preferences.tabWidth, in: 1...16) {
                        Text("\(preferences.tabWidth) spaces")
                    }
                }

                Toggle("Insert Spaces for Tabs", isOn: $preferences.insertSpacesForTabs)
                    .help("Use spaces instead of tab characters")
            }

                Spacer()
            }
            .padding()
        }
    }

    private func showFontPanel() {
        let fontPanel = NSFontPanel.shared

        fontPanel.setPanelFont(preferences.editorFont, isMultiple: false)
        fontPanel.orderFront(nil)
    }
}

// MARK: - Advanced Preferences

struct AdvancedPreferencesView: View {
    @ObservedObject var preferences: AppPreferences
    @State private var showingSnippets = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Form {
                Section("Text Snippets") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create text shortcuts that expand when you type them")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Manage Snippets...") {
                        showingSnippets = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Auto Save") {
                Toggle("Enable Auto Save", isOn: $preferences.autoSave)
                    .help("Automatically save documents that have been saved before")

                HStack {
                    Text("Save Interval:")
                    Picker("", selection: $preferences.autoSaveInterval) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                    }
                    .frame(width: 140)
                    .disabled(!preferences.autoSave)
                }

                Toggle("Create Backup on Save", isOn: $preferences.createBackupOnSave)
                    .help("Create a backup copy before overwriting files")
            }

            Section("Default Encoding") {
                Picker("Encoding:", selection: Binding(
                    get: { preferences.defaultEncoding },
                    set: { preferences.defaultEncoding = $0 }
                )) {
                    Text("UTF-8").tag(String.Encoding.utf8)
                    Text("UTF-16").tag(String.Encoding.utf16)
                    Text("ASCII").tag(String.Encoding.ascii)
                    Text("ISO Latin 1").tag(String.Encoding.isoLatin1)
                    Text("Mac OS Roman").tag(String.Encoding.macOSRoman)
                }
                .frame(width: 200)
            }

            Section("Custom Directories") {
                VStack(alignment: .leading, spacing: 12) {
                    // Log save directory
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log Save Location:")
                            .font(.headline)

                        HStack {
                            Text(preferences.logSaveDirectory.isEmpty ? "Default: ~/Documents/PIP Logs" : preferences.logSaveDirectory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Choose...") {
                                chooseLogSaveDirectory()
                            }
                        }

                        Text("Where script execution logs are saved")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Temp script directory
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temporary Script Location:")
                            .font(.headline)

                        HStack {
                            Text(preferences.tempScriptDirectory.isEmpty ? "Default: System Temp/PIP Scripts" : preferences.tempScriptDirectory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Choose...") {
                                chooseTempScriptDirectory()
                            }
                        }

                        Text("Where scripts are temporarily stored during execution")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Button("Reset to Defaults") {
                            preferences.resetDirectoriesToDefaults()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Clean Old Files...") {
                            cleanupOldFiles()
                        }
                    }

                    Text("Cleanup removes temporary scripts older than 7 days and logs older than 30 days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingSnippets) {
            SnippetsView()
        }
    }

    private func chooseLogSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to save script execution logs"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                preferences.logSaveDirectory = url.path
            }
        }
    }

    private func chooseTempScriptDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to temporarily store scripts during execution"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                preferences.tempScriptDirectory = url.path
            }
        }
    }

    private func cleanupOldFiles() {
        let alert = NSAlert()
        alert.messageText = "Clean Up Old Files"
        alert.informativeText = "This will remove:\n• Temporary scripts older than 7 days\n• Log files older than 30 days\n\nDo you want to continue?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Clean Up")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task { @MainActor in
                let executor = ScriptExecutor()
                executor.cleanupTempScripts(olderThanDays: 7)

                let confirmAlert = NSAlert()
                confirmAlert.messageText = "Cleanup Complete"
                confirmAlert.informativeText = "Old temporary files have been removed."
                confirmAlert.alertStyle = .informational
                confirmAlert.runModal()
            }
        }
    }
}

// MARK: - Cursor Preview

struct CursorPreview: View {
    let type: AppPreferences.CursorType
    let label: String
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .secondary)

            ZStack {
                Text("A")
                    .font(.system(size: 24, design: .monospaced))
                    .foregroundColor(.primary)

                // Cursor overlay
                cursorShape
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(width: 40, height: 40)
            .background(Color(NSColor.textBackgroundColor).opacity(isHovering ? 0.8 : 0.5))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : (isHovering ? Color.gray : Color.clear), lineWidth: 2)
            )
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Click to select this cursor style")
    }

    @ViewBuilder
    private var cursorShape: some View {
        switch type {
        case .line:
            // Vertical line cursor
            Rectangle()
                .frame(width: 2, height: 24)
                .offset(x: -8)

        case .block:
            // Block cursor (full character width)
            Rectangle()
                .opacity(0.3)
                .frame(width: 16, height: 24)

        case .underline:
            // Underline cursor
            Rectangle()
                .frame(width: 16, height: 3)
                .offset(y: 10)
        }
    }
}

#Preview {
    PreferencesWindow()
}
