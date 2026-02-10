import Foundation
import AppKit

/// Application-wide preferences stored in UserDefaults
@MainActor
final class AppPreferences: ObservableObject {

    static let shared = AppPreferences()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let showRuler = "showRuler"
        static let showLineNumbers = "showLineNumbers"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let defaultEncoding = "defaultEncoding"
        static let tabWidth = "tabWidth"
        static let insertSpacesForTabs = "insertSpacesForTabs"
        static let wrapLines = "wrapLines"
        static let autoSave = "autoSave"
        static let showInvisibles = "showInvisibles"
        static let selectedThemeID = "selectedThemeID"
        static let invisibleCharactersColor = "invisibleCharactersColor"
        static let showToolbarLabels = "showToolbarLabels"
        static let leftMargin = "leftMargin"
        static let rightMargin = "rightMargin"
        static let tabStops = "tabStops"
        static let autoSaveInterval = "autoSaveInterval"
        static let createBackupOnSave = "createBackupOnSave"
        static let enablePredictiveCompletion = "enablePredictiveCompletion"
        static let logSaveDirectory = "logSaveDirectory"
        static let tempScriptDirectory = "tempScriptDirectory"
        static let undoHistoryLimit = "undoHistoryLimit"
        static let cursorType = "cursorType"
        static let cursorBlinks = "cursorBlinks"

        // Invisible character types
        static let showLineEndingsInvisible = "showLineEndingsInvisible"
        static let showTabInvisible = "showTabInvisible"
        static let showSpaceInvisible = "showSpaceInvisible"
        static let showWhitespaceInvisible = "showWhitespaceInvisible"
        static let showControlCharactersInvisible = "showControlCharactersInvisible"

        // Line number options
        static let showLineNumberSeparator = "showLineNumberSeparator"

        // Status bar
        static let showCharacterCount = "showCharacterCount"
        static let showWordCount = "showWordCount"

        // Current line highlight
        static let showCurrentLineHighlight = "showCurrentLineHighlight"
        static let currentLineHighlightColor = "currentLineHighlightColor"

        // Window options
        static let openDocumentsInNewWorkspace = "openDocumentsInNewWorkspace"
        static let defaultWindowWidth = "defaultWindowWidth"
        static let defaultWindowHeight = "defaultWindowHeight"

        // Syntax coloring
        static let enableSyntaxColoring = "enableSyntaxColoring"

        // Script output
        static let verboseScriptOutput = "verboseScriptOutput"

        // Completion
        static let enableAutoCompletion = "enableAutoCompletion"
        static let completionTriggerLength = "completionTriggerLength"
    }

    enum OpenDocumentsMode: String, CaseIterable {
        case always = "Always"
        case never = "Never"

        var displayName: String { rawValue }
    }

    enum CursorType: String, CaseIterable {
        case line = "Line"
        case block = "Block"
        case underline = "Underline"

        var displayName: String { rawValue }
    }

    // MARK: - Editor Preferences

    @Published var showRuler: Bool {
        didSet { defaults.set(showRuler, forKey: Keys.showRuler) }
    }

    @Published var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: Keys.showLineNumbers) }
    }

    @Published var fontName: String {
        didSet { defaults.set(fontName, forKey: Keys.fontName) }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var defaultEncoding: String.Encoding {
        didSet { defaults.set(defaultEncoding.rawValue, forKey: Keys.defaultEncoding) }
    }

    @Published var tabWidth: Int {
        didSet { defaults.set(tabWidth, forKey: Keys.tabWidth) }
    }

    @Published var insertSpacesForTabs: Bool {
        didSet { defaults.set(insertSpacesForTabs, forKey: Keys.insertSpacesForTabs) }
    }

    @Published var wrapLines: Bool {
        didSet { defaults.set(wrapLines, forKey: Keys.wrapLines) }
    }

    @Published var autoSave: Bool {
        didSet { defaults.set(autoSave, forKey: Keys.autoSave) }
    }

    @Published var showInvisibles: Bool {
        didSet { defaults.set(showInvisibles, forKey: Keys.showInvisibles) }
    }

    @Published var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Keys.selectedThemeID) }
    }

    @Published var invisibleCharactersColor: String {
        didSet { defaults.set(invisibleCharactersColor, forKey: Keys.invisibleCharactersColor) }
    }

    @Published var showToolbarLabels: Bool {
        didSet { defaults.set(showToolbarLabels, forKey: Keys.showToolbarLabels) }
    }

    @Published var leftMargin: Double {
        didSet { defaults.set(leftMargin, forKey: Keys.leftMargin) }
    }

    @Published var rightMargin: Double {
        didSet { defaults.set(rightMargin, forKey: Keys.rightMargin) }
    }

    @Published var tabStops: [Double] {
        didSet { defaults.set(tabStops, forKey: Keys.tabStops) }
    }

    @Published var autoSaveInterval: Int {
        didSet { defaults.set(autoSaveInterval, forKey: Keys.autoSaveInterval) }
    }

    @Published var createBackupOnSave: Bool {
        didSet { defaults.set(createBackupOnSave, forKey: Keys.createBackupOnSave) }
    }

    @Published var enablePredictiveCompletion: Bool {
        didSet { defaults.set(enablePredictiveCompletion, forKey: Keys.enablePredictiveCompletion) }
    }

    @Published var logSaveDirectory: String {
        didSet { defaults.set(logSaveDirectory, forKey: Keys.logSaveDirectory) }
    }

    @Published var tempScriptDirectory: String {
        didSet { defaults.set(tempScriptDirectory, forKey: Keys.tempScriptDirectory) }
    }

    @Published var undoHistoryLimit: Int {
        didSet {
            defaults.set(undoHistoryLimit, forKey: Keys.undoHistoryLimit)
        }
    }

    @Published var cursorType: CursorType {
        didSet { defaults.set(cursorType.rawValue, forKey: Keys.cursorType) }
    }

    @Published var cursorBlinks: Bool {
        didSet { defaults.set(cursorBlinks, forKey: Keys.cursorBlinks) }
    }

    // MARK: - Invisible Character Types

    @Published var showLineEndingsInvisible: Bool {
        didSet { defaults.set(showLineEndingsInvisible, forKey: Keys.showLineEndingsInvisible) }
    }

    @Published var showTabInvisible: Bool {
        didSet { defaults.set(showTabInvisible, forKey: Keys.showTabInvisible) }
    }

    @Published var showSpaceInvisible: Bool {
        didSet { defaults.set(showSpaceInvisible, forKey: Keys.showSpaceInvisible) }
    }

    @Published var showWhitespaceInvisible: Bool {
        didSet { defaults.set(showWhitespaceInvisible, forKey: Keys.showWhitespaceInvisible) }
    }

    @Published var showControlCharactersInvisible: Bool {
        didSet { defaults.set(showControlCharactersInvisible, forKey: Keys.showControlCharactersInvisible) }
    }

    // MARK: - Line Number Options

    @Published var showLineNumberSeparator: Bool {
        didSet { defaults.set(showLineNumberSeparator, forKey: Keys.showLineNumberSeparator) }
    }

    // MARK: - Status Bar

    @Published var showCharacterCount: Bool {
        didSet { defaults.set(showCharacterCount, forKey: Keys.showCharacterCount) }
    }

    @Published var showWordCount: Bool {
        didSet { defaults.set(showWordCount, forKey: Keys.showWordCount) }
    }

    // MARK: - Current Line Highlight

    @Published var showCurrentLineHighlight: Bool {
        didSet { defaults.set(showCurrentLineHighlight, forKey: Keys.showCurrentLineHighlight) }
    }

    @Published var currentLineHighlightColor: String {
        didSet { defaults.set(currentLineHighlightColor, forKey: Keys.currentLineHighlightColor) }
    }

    // MARK: - Window Options

    @Published var openDocumentsInNewWorkspace: OpenDocumentsMode {
        didSet { defaults.set(openDocumentsInNewWorkspace.rawValue, forKey: Keys.openDocumentsInNewWorkspace) }
    }

    @Published var defaultWindowWidth: Double {
        didSet { defaults.set(defaultWindowWidth, forKey: Keys.defaultWindowWidth) }
    }

    @Published var defaultWindowHeight: Double {
        didSet { defaults.set(defaultWindowHeight, forKey: Keys.defaultWindowHeight) }
    }

    // MARK: - Syntax Coloring

    @Published var enableSyntaxColoring: Bool {
        didSet { defaults.set(enableSyntaxColoring, forKey: Keys.enableSyntaxColoring) }
    }

    // MARK: - Script Output

    @Published var verboseScriptOutput: Bool {
        didSet { defaults.set(verboseScriptOutput, forKey: Keys.verboseScriptOutput) }
    }

    // MARK: - Completion

    @Published var enableAutoCompletion: Bool {
        didSet { defaults.set(enableAutoCompletion, forKey: Keys.enableAutoCompletion) }
    }

    @Published var completionTriggerLength: Int {
        didSet { defaults.set(completionTriggerLength, forKey: Keys.completionTriggerLength) }
    }

    // MARK: - Computed Properties

    var logSaveDirectoryURL: URL {
        if logSaveDirectory.isEmpty {
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/PIP Logs")
        }
        return URL(fileURLWithPath: logSaveDirectory)
    }

    var tempScriptDirectoryURL: URL {
        if tempScriptDirectory.isEmpty {
            return FileManager.default.temporaryDirectory.appendingPathComponent("PIP Scripts")
        }
        return URL(fileURLWithPath: tempScriptDirectory)
    }

    var currentTheme: EditorTheme {
        EditorTheme.theme(withID: selectedThemeID) ?? .defaultLight
    }

    var editorFont: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    // MARK: - Initialization

    private init() {
        self.showRuler = defaults.bool(forKey: Keys.showRuler)
        self.showLineNumbers = defaults.bool(forKey: Keys.showLineNumbers)
        self.fontName = defaults.string(forKey: Keys.fontName) ?? "Menlo"
        self.fontSize = defaults.double(forKey: Keys.fontSize) == 0 ? 13.0 : defaults.double(forKey: Keys.fontSize)

        let encodingRaw = defaults.integer(forKey: Keys.defaultEncoding)
        self.defaultEncoding = encodingRaw == 0 ? .utf8 : String.Encoding(rawValue: UInt(encodingRaw))

        self.tabWidth = defaults.integer(forKey: Keys.tabWidth) == 0 ? 4 : defaults.integer(forKey: Keys.tabWidth)
        self.insertSpacesForTabs = defaults.bool(forKey: Keys.insertSpacesForTabs)
        self.wrapLines = defaults.object(forKey: Keys.wrapLines) as? Bool ?? true
        self.autoSave = defaults.object(forKey: Keys.autoSave) as? Bool ?? false
        self.showInvisibles = defaults.bool(forKey: Keys.showInvisibles)

        // Theme settings
        self.selectedThemeID = defaults.string(forKey: Keys.selectedThemeID) ?? "default-light"
        self.invisibleCharactersColor = defaults.string(forKey: Keys.invisibleCharactersColor) ?? "red"
        self.showToolbarLabels = defaults.object(forKey: Keys.showToolbarLabels) as? Bool ?? true

        // Margin and tab settings
        self.leftMargin = defaults.double(forKey: Keys.leftMargin) == 0 ? 1.0 : defaults.double(forKey: Keys.leftMargin)
        self.rightMargin = defaults.double(forKey: Keys.rightMargin) == 0 ? 1.0 : defaults.double(forKey: Keys.rightMargin)
        self.tabStops = defaults.array(forKey: Keys.tabStops) as? [Double] ?? [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

        // Auto-save settings
        let savedInterval = defaults.integer(forKey: Keys.autoSaveInterval)
        self.autoSaveInterval = savedInterval == 0 ? 60 : savedInterval // Default 60 seconds
        self.createBackupOnSave = defaults.bool(forKey: Keys.createBackupOnSave)

        // Predictive completion
        self.enablePredictiveCompletion = defaults.object(forKey: Keys.enablePredictiveCompletion) as? Bool ?? false

        // Custom directories
        self.logSaveDirectory = defaults.string(forKey: Keys.logSaveDirectory) ?? ""
        self.tempScriptDirectory = defaults.string(forKey: Keys.tempScriptDirectory) ?? ""

        // Undo history
        self.undoHistoryLimit = defaults.integer(forKey: Keys.undoHistoryLimit) == 0 ? 50 : defaults.integer(forKey: Keys.undoHistoryLimit)

        // Cursor settings
        if let cursorTypeString = defaults.string(forKey: Keys.cursorType),
           let type = CursorType(rawValue: cursorTypeString) {
            self.cursorType = type
        } else {
            self.cursorType = .line
        }
        self.cursorBlinks = defaults.object(forKey: Keys.cursorBlinks) as? Bool ?? true

        // Invisible character types (default to all on)
        self.showLineEndingsInvisible = defaults.object(forKey: Keys.showLineEndingsInvisible) as? Bool ?? true
        self.showTabInvisible = defaults.object(forKey: Keys.showTabInvisible) as? Bool ?? true
        self.showSpaceInvisible = defaults.object(forKey: Keys.showSpaceInvisible) as? Bool ?? true
        self.showWhitespaceInvisible = defaults.object(forKey: Keys.showWhitespaceInvisible) as? Bool ?? true
        self.showControlCharactersInvisible = defaults.object(forKey: Keys.showControlCharactersInvisible) as? Bool ?? true

        // Line number options
        self.showLineNumberSeparator = defaults.bool(forKey: Keys.showLineNumberSeparator)

        // Status bar
        self.showCharacterCount = defaults.object(forKey: Keys.showCharacterCount) as? Bool ?? true
        self.showWordCount = defaults.object(forKey: Keys.showWordCount) as? Bool ?? true

        // Current line highlight
        self.showCurrentLineHighlight = defaults.object(forKey: Keys.showCurrentLineHighlight) as? Bool ?? true
        self.currentLineHighlightColor = defaults.string(forKey: Keys.currentLineHighlightColor) ?? "lightblue"

        // Window options
        if let modeString = defaults.string(forKey: Keys.openDocumentsInNewWorkspace),
           let mode = OpenDocumentsMode(rawValue: modeString) {
            self.openDocumentsInNewWorkspace = mode
        } else {
            self.openDocumentsInNewWorkspace = .never
        }
        self.defaultWindowWidth = defaults.double(forKey: Keys.defaultWindowWidth) == 0 ? 1200 : defaults.double(forKey: Keys.defaultWindowWidth)
        self.defaultWindowHeight = defaults.double(forKey: Keys.defaultWindowHeight) == 0 ? 800 : defaults.double(forKey: Keys.defaultWindowHeight)

        // Syntax coloring
        self.enableSyntaxColoring = defaults.object(forKey: Keys.enableSyntaxColoring) as? Bool ?? false

        // Script output
        self.verboseScriptOutput = defaults.object(forKey: Keys.verboseScriptOutput) as? Bool ?? true

        // Completion
        self.enableAutoCompletion = defaults.object(forKey: Keys.enableAutoCompletion) as? Bool ?? true
        self.completionTriggerLength = defaults.integer(forKey: Keys.completionTriggerLength) == 0 ? 2 : defaults.integer(forKey: Keys.completionTriggerLength)
    }

    // MARK: - Reset

    func resetToDefaults() {
        showRuler = false
        showLineNumbers = true
        fontName = "Menlo"
        fontSize = 13.0
        defaultEncoding = .utf8
        tabWidth = 4
        insertSpacesForTabs = true
        wrapLines = true
        autoSave = false
        showInvisibles = false
        selectedThemeID = "default-light"
        invisibleCharactersColor = "red"
        showToolbarLabels = true
        leftMargin = 1.0
        rightMargin = 1.0
        tabStops = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
        autoSaveInterval = 60
        createBackupOnSave = false
        enablePredictiveCompletion = false
        logSaveDirectory = ""
        tempScriptDirectory = ""
        undoHistoryLimit = 50
        cursorType = .line
        cursorBlinks = true

        // Invisible character types
        showLineEndingsInvisible = true
        showTabInvisible = true
        showSpaceInvisible = true
        showWhitespaceInvisible = true
        showControlCharactersInvisible = true

        // Line number options
        showLineNumberSeparator = false

        // Status bar
        showCharacterCount = true
        showWordCount = true

        // Current line highlight
        showCurrentLineHighlight = true
        currentLineHighlightColor = "lightblue"

        // Window options
        openDocumentsInNewWorkspace = .never
        defaultWindowWidth = 1200
        defaultWindowHeight = 800

        // Syntax coloring
        enableSyntaxColoring = false

        // Script output
        verboseScriptOutput = true
    }

    func resetDirectoriesToDefaults() {
        logSaveDirectory = ""
        tempScriptDirectory = ""
    }

    func resetMarginsAndTabs() {
        leftMargin = 1.0
        rightMargin = 1.0
        tabStops = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    }
}
