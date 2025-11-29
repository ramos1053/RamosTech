# Menu Command Fixes

## Problem
Menu commands (Open, New, Save, Save As, Preferences) were not functioning because they weren't properly wired to the ContentView actions.

## Solution
Implemented a **NotificationCenter-based** communication pattern between PIPApp (menu commands) and ContentView (actions).

## Changes Made

### 1. PIPApp.swift
**Before**: Menu commands had empty handlers or referenced non-existent variables
**After**: Menu commands post notifications to NotificationCenter

```swift
Button("Open...") {
    NotificationCenter.default.post(name: .openDocument, object: nil)
}
.keyboardShortcut("o", modifiers: .command)
```

### 2. ContentView.swift
**Before**: No listeners for menu commands
**After**: Added `.onReceive()` modifiers to listen for notifications

```swift
.onReceive(NotificationCenter.default.publisher(for: .openDocument)) { _ in
    openFile()
}
```

### 3. Added exportAs() Function
Created new function in ContentView to handle Export As... menu commands for all file formats (TXT, SH, CSV, RTF, DOCX).

### 4. Preferences Window
**Before**: Used `Window()` which doesn't work properly in macOS 14+
**After**: Changed to `Settings` scene which is the correct API for preferences

```swift
Settings {
    PreferencesWindow()
}
```

## Supported Commands

### File Menu
- ✅ **New** (⌘N) - Creates new document
- ✅ **Open** (⌘O) - Opens file browser
- ✅ **Save** (⌘S) - Saves current document
- ✅ **Save As** (⌘⇧S) - Saves with new name/format/encoding
- ✅ **Export As** - Exports to TXT, SH, CSV, RTF, DOCX

### View Menu
- ✅ **Show Line Numbers** (⌘⇧L) - Toggles line number gutter
- ✅ **Show Ruler** - Toggles horizontal ruler
- ✅ **Wrap Lines** - Toggles line wrapping
- ✅ **Show Invisibles** - Shows spaces/tabs/line endings
- ✅ **Toggle Log** - Shows/hides script output log

### Script Menu
- ✅ **Run Script** (⌘R) - Executes shell scripts
- ✅ **Stop Script** (⌘.) - Terminates running script
- ✅ **Clear Log** - Clears script output
- ✅ **Export Log** - Saves log to file

### Format Menu
- ✅ **Bigger Font** (⌘+) - Increases font size
- ✅ **Smaller Font** (⌘-) - Decreases font size
- ✅ **Show Fonts** (⌘T) - Opens system font panel
- ✅ **Line Endings** - Converts between LF/CRLF/CR

### Settings Menu
- ✅ **Preferences** (⌘,) - Opens preferences window

## Notification Names
All custom notifications defined in `PIPApp.swift`:

```swift
extension Notification.Name {
    static let openDocument = Notification.Name("openDocument")
    static let saveDocument = Notification.Name("saveDocument")
    static let saveDocumentAs = Notification.Name("saveDocumentAs")
    static let exportDocument = Notification.Name("exportDocument")
    static let runScript = Notification.Name("runScript")
    static let stopScript = Notification.Name("stopScript")
    static let clearLog = Notification.Name("clearLog")
    static let exportLog = Notification.Name("exportLog")
    static let toggleLog = Notification.Name("toggleLog")
    static let convertLineEnding = Notification.Name("convertLineEnding")
}
```

## Testing

### To Test Open:
1. Press ⌘O or File > Open
2. Select a file (.sh, .txt, .py, etc.)
3. File should load in editor

### To Test Save:
1. Open or create a document
2. Make changes
3. Press ⌘S or File > Save
4. Changes should be saved

### To Test Preferences:
1. Press ⌘, or PIP > Settings > Preferences
2. Preferences window should open
3. Toggle settings and see them apply immediately

### To Test Script Execution:
1. Open a .sh file
2. Press ⌘R or Script > Run Script
3. Log panel should appear with output
4. Press ⌘. to stop

## Architecture Benefits

### Why NotificationCenter?
1. **Decoupling**: Menu commands don't need direct references to ContentView
2. **Flexibility**: Easy to add new commands
3. **Testing**: Can trigger commands programmatically
4. **Standard Pattern**: Well-established macOS/iOS pattern

### Alternative Approaches Considered
- ❌ **@FocusedBinding**: Too complex for this use case
- ❌ **Environment Objects**: Doesn't work well with WindowGroup
- ✅ **NotificationCenter**: Simple, reliable, maintainable

## Future Improvements
- Add command validation (enable/disable based on state)
- Add undo/redo menu integration
- Add recent documents menu
- Add keyboard shortcut customization
