# Tab System Implementation

## Overview
Implemented a comprehensive multi-tab document system for PIP text editor with file tracking, duplicate prevention, and save confirmations.

## Features Implemented

### 1. ✅ Multi-Tab Interface
- **Tab bar** showing all open documents
- Each tab displays **file name with extension**
- Visual distinction between active and inactive tabs
- Tabs show file icons (document vs terminal for executables)
- Smooth tab switching with mouse clicks

### 2. ✅ File Name Display
- Tabs show full file name including extension (e.g., "script.sh", "README.md")
- "Untitled" for new documents without a file
- File path available in toolbar info

### 3. ✅ Duplicate File Prevention
- **Files can only be opened once** - attempting to open an already-open file shows error
- System tracks which files are open by URL path
- Clicking an already-open file's tab switches to that tab instead

### 4. ✅ Close Without Save Confirmation
- Closing tab with unsaved changes shows alert dialog:
  - **Save** button - saves then closes
  - **Don't Save** button - discards changes and closes
  - **Cancel** button - cancels close operation
- Dialog shows which file has unsaved changes

### 5. ✅ Visual Indicator for Edited Files
- **Red close button with black dot** appears when file has unsaved changes
- Matches macOS standard (like Safari/Chrome tabs)
- On hover over unmodified tab: shows gray X button
- Modified tabs always show red button with black dot

### 6. ✅ File Reopening
- Closed files can be reopened
- Saved files can be reopened after closing
- System removes file from tracking when tab closes

## Architecture

### New Files Created

#### 1. `TabDocument.swift` (Models)
```swift
class TabDocument: ObservableObject, Identifiable {
    let id = UUID()
    @Published var textEngine: TextEngine
    @Published var documentInfo: DocumentManager.DocumentInfo?
    @Published var isModified: Bool

    var displayName: String // File name
    var fullDisplayName: String // File name with extension
    var filePath: String?
}
```

Tracks:
- Individual text engine per tab
- File information
- Modified state
- Original content for comparison

#### 2. `TabManager.swift` (Models)
```swift
class TabManager: ObservableObject {
    @Published var tabs: [TabDocument]
    @Published var activeTabID: UUID?
    @Published var showCloseConfirmation: Bool
    @Published var tabToClose: TabDocument?

    func createNewTab()
    func openFile(content:documentInfo:)
    func switchToTab(_:)
    func closeTab(_:)
    func isFileOpen(_:) -> Bool
}
```

Manages:
- All open tabs
- Active tab selection
- Tab creation/closing
- Duplicate file detection
- Close confirmations

#### 3. `TabBar.swift` (UI)
```swift
struct TabBar: View {
    @ObservedObject var tabManager: TabManager
    // Shows all tabs with file names
}

struct TabItem: View {
    @ObservedObject var tab: TabDocument
    // Individual tab with:
    // - File icon
    // - File name with extension
    // - Close button (red with dot if modified)
}
```

Visual Features:
- Horizontal scrolling for many tabs
- Rounded top corners for active tab
- Hover effects
- Close button state changes (clear → gray X → red dot)

### Modified Files

#### 1. `ContentView.swift`
**Major Refactoring**:
- Changed from single `TextEngine` to `TabManager`
- Removed `FileTitleView` from toolbar (handled by tabs)
- Added `TabBar` at top
- Updated all file operations to work with active tab
- Added close confirmation alert dialog
- Each tab has its own `EditorView` with dedicated `TextEngine`

**New Methods**:
- `newDocument()` - Creates new blank tab
- `saveAndCloseTab()` - Saves then closes after confirmation

**Modified Methods**:
- `openFile()` - Checks for duplicates, creates new tab
- `saveFile()` - Saves active tab's content
- `runScript()` - Executes active tab if executable

#### 2. `TextEngine.swift`
**Added**:
- Notification posting when text changes
- `syncTextFromView()` now posts `TextEngineDidChange` notification
- Allows `TabDocument` to track modifications

#### 3. `TabManager.swift` (New Notification)
**Added**:
- `.saveAndCloseTab` notification for save-then-close workflow

## User Experience

### Opening Files
1. File → Open (⌘O)
2. Select file
3. New tab appears with file name
4. If file already open: shows error message

### Creating New Documents
1. File → New (⌘N)
2. New tab appears labeled "Untitled"
3. Type content
4. Save As to give it a name

### Switching Tabs
- Click any tab to switch to it
- Active tab has distinct appearance
- Each tab preserves its cursor position

### Editing & Saving
1. Edit file in any tab
2. Red button with black dot appears immediately
3. File → Save (⌘S) to save
4. Dot disappears when saved

### Closing Tabs
**For unsaved changes**:
1. Click red close button
2. Alert appears: "Save Changes?"
   - File name shown
   - Save / Don't Save / Cancel options
3. Choosing Save: saves then closes
4. Choosing Don't Save: closes without saving
5. Choosing Cancel: keeps tab open

**For saved files**:
1. Click (gray) close button on hover
2. Tab closes immediately

### Reopening Closed Files
1. File closed (saved or unsaved)
2. File → Open (⌘O)
3. Select same file
4. Opens in new tab with saved content

## Visual Indicators

### Tab States
- **Active Tab**: Full opacity, distinct background
- **Inactive Tab**: Slightly transparent
- **Hover**: Shows background highlight

### Close Button States
- **Unmodified, Not Hovering**: Invisible (clear)
- **Unmodified, Hovering**: Gray circle with white X
- **Modified**: Red circle with black dot (always visible)

### File Icons
- 📄 Document icon for text files
- ▶ Terminal icon for executable scripts

## Technical Details

### Modification Tracking
```swift
// In TabDocument
func updateModifiedState() {
    isModified = textEngine.text != originalContent
}

// Called when TextEngine posts change notification
NotificationCenter: "TextEngineDidChange"
```

### Duplicate Detection
```swift
// In TabManager
func isFileOpen(_ url: URL) -> Bool {
    tabs.contains { $0.documentInfo?.url == url }
}

// In ContentView.openFile()
if tabManager.isFileOpen(docInfo.url) {
    errorMessage = "File is already open"
    showingError = true
}
```

### Save Confirmation Flow
```swift
// 1. User clicks close on modified tab
tabManager.closeTab(tab)

// 2. TabManager shows alert
showCloseConfirmation = true
tabToClose = tab

// 3. User chooses action:
// - Save: posts .saveAndCloseTab notification
// - Don't Save: calls performCloseTab()
// - Cancel: sets showCloseConfirmation = false
```

## File Structure
```
PIP/
├── Models/
│   ├── TabDocument.swift (NEW)
│   ├── TabManager.swift (NEW)
│   ├── DocumentManager.swift
│   └── AppPreferences.swift
├── UI/
│   ├── TabBar.swift (NEW)
│   ├── ContentView.swift (MAJOR UPDATE)
│   └── EditorView.swift
└── Engine/
    └── TextEngine.swift (UPDATED - notifications)
```

## Build Configuration
All new files added to `PIP.xcodeproj/project.pbxproj`:
- AA0055/AA0056 - TabDocument.swift
- AA0057/AA0058 - TabManager.swift
- AA0059/AA0060 - TabBar.swift

## Testing Checklist

- [x] Create new tab (⌘N)
- [x] Open file in tab
- [x] Tabs show file names with extensions
- [x] Cannot open same file twice
- [x] Switch between tabs
- [x] Edit file shows red dot indicator
- [x] Save removes red dot
- [x] Close unsaved tab shows confirmation
- [x] Close saved tab works immediately
- [x] Save and close workflow
- [x] Don't save and close workflow
- [x] Cancel close keeps tab open
- [x] Reopen closed file works
- [x] Multiple tabs work simultaneously
- [x] Each tab has independent text engine
- [x] Status bar reflects active tab

## Known Behaviors

### Tab Persistence
- Tabs are not persisted between app launches
- Each launch starts with one blank "Untitled" tab
- Can be extended to save/restore tab state

### Maximum Tabs
- No hard limit on tab count
- Tab bar scrolls horizontally for many tabs
- Performance depends on total text content across tabs

### File Watching
- System doesn't watch for external file changes
- Opening a modified-externally file shows last saved version
- Can be extended with FSEvents monitoring

---

**Implementation Date**: 2025-11-17
**Status**: ✅ Complete and functional
**Breaking Changes**: ContentView significantly refactored - uses TabManager instead of single TextEngine
