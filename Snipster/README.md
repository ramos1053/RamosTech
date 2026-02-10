# Snipster

**Version 1.1.0**

A powerful macOS menu bar application for managing and expanding text snippets with keyboard triggers, dynamic variables, and intelligent organization. Features a Spotlight-style quick access window with global hotkey support for instant snippet access from anywhere.

## What's New in v1.1

**Global Hotkey System** - Access your snippets instantly from anywhere with Cmd+Shift+S (customizable)

**Spotlight-Style Search** - Fast, keyboard-driven interface with tag-based navigation and real-time filtering

**Tag Hierarchy** - Browse snippets by drilling down through organized tag folders

**Compact Design** - Streamlined 380px window with tighter spacing for minimal screen footprint

**Position Memory** - Moveable search window remembers where you placed it

**Quick Actions** - Copy with Enter, or copy & paste with Cmd+Return

**Enhanced UX** - Quit from menu bar, improved search behavior, and cleaner visual design

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## Features

### Quick Access Hotkey (New in v1.1)
- **Global hotkey** to instantly access snippets from anywhere (default: `Cmd+Shift+S`)
- **Spotlight-style search window** - compact 380px width with tag-based navigation
- **Tag hierarchy browsing** - drill down through tag folders to find snippets
- **Real-time search** - instantly filter across titles, content, and triggers
- **Keyboard navigation** - arrow keys to browse, Enter to select, Escape to go back/close
- **Smart conflict detection** - prevents conflicts with system shortcuts
- **Customizable hotkey** - record your own key combination in Settings with live preview
- **Auto-paste option** - `Cmd+Return` copies and pastes automatically
- **Window position memory** - moveable window remembers its position
- **Visual preview** - see snippet content, tags, and favorites before selecting
- **Snippet count badges** - see how many snippets are in each tag

### Text Expansion
- **Instant text expansion** using clipboard-based insertion for maximum speed
- **Customizable triggers** with prefix + keyword system (e.g., `!email`, `!addr`)
- **Automatic permission monitoring** - detects accessibility changes in real-time
- **Refresh button** to restart monitoring if needed
- **Trigger uniqueness validation** - prevents duplicate triggers with real-time conflict warnings
- Direct link to System Settings for easy permission setup

### Dynamic Variables
Snippets support powerful variable substitution:
- **Date variables**: `{{DATE}}`, `{{DATE:LONG}}`, `{{DATE:MEDIUM}}`, `{{DATE:FULL}}`, `{{DATE:CUSTOM:yyyy-MM-dd}}`
- **Time variables**: `{{TIME}}`, `{{TIME:LONG}}`, `{{TIME:MEDIUM}}`, `{{TIME:24}}`
- **Clipboard**: `{{CLIPBOARD}}` - inserts current clipboard content
- **System info**: `{{USERNAME}}`, `{{USER}}`, `{{HOSTNAME}}`
- **Cursor positioning**: `{{CURSOR}}` - places cursor at specific position after expansion

### Snippet Management
- **Create, edit, and duplicate** text snippets
- **Favorites/starred snippets** - mark important snippets for quick access
- **Usage statistics** - track how often each snippet is used
- **Multi-level filtering** - search by text, filter by tag, and show favorites
- **Sort options** - by title, tag, color, date created, or date modified
- **Adjustable preview** - 0, 1, or 2 lines of content
- **Context menu actions** - Edit, Favorite, Duplicate, Copy, Delete
- **Quick access** from menu bar

### Backup & Restore
- **Export snippets** to JSON with formatted output
- **Import snippets** with intelligent conflict resolution:
  - **Merge mode** - keeps newer version based on modification date
  - **Replace mode** - always uses imported version
  - **Skip mode** - keeps existing version
- Import summary shows added, updated, and skipped counts
- Backward compatible with older snippet formats

### Tag Organization
- **Color-coded tag system** for visual categorization
- **Full color palette** support via ColorPicker
- **Tag filtering** with visual tag buttons
- **Inline tag management** in settings
- **Snippet count badges** on each tag
- **Tag truncation** for compact display (6 chars + "..")

### Storage Options
- **Local storage** - `~/Library/Application Support/Snipster/`
- **iCloud Drive** - `~/Library/Mobile Documents/iCloud~Snipster/`
- **Dropbox integration** - `~/Dropbox/Apps/Snipster/`
- **Easy location switching** from Settings

## Screenshots

### Spotlight Search Window
The global hotkey brings up a compact, keyboard-driven search interface with tag navigation:
- Tag-based folder browsing
- Real-time search filtering
- Visual snippet previews
- Moveable with position memory

### Menu Bar Interface
Quick access to all snippets with:
- Search and filtering
- Tag-based organization
- Favorites toggle
- Sort options
- One-click actions

### Settings Panel
Centralized configuration:
- Global hotkey customization with conflict detection
- Text expansion toggle and permissions
- Display preferences
- Storage location management
- Inline tag management with color coding
- Export/Import tools

## System Requirements

- macOS 14.0 or later (Sonoma)
- Xcode 15.0 or later (for building from source)
- Accessibility permission for text expansion feature

## Installation

### Building from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/Snipster.git
   cd Snipster
   ```

2. **Open in Xcode:**
   ```bash
   open Snipster.xcodeproj
   ```

3. **Build and Run:**
   - Select the Snipster scheme
   - Press `Cmd+R` to build and run
   - The app will appear in your menu bar

4. **Grant Permissions:**
   - Accessibility permission will be requested on first text expansion attempt
   - Go to System Settings → Privacy & Security → Accessibility
   - Enable Snipster to allow text expansion

### First Launch

1. Click the Snipster icon in your menu bar
2. Create your first snippet with the "+" button
3. Set up your global hotkey in Settings (default: Cmd+Shift+S)
4. Enable text expansion if you want automatic trigger expansion
5. Start using Snipster!

## Usage

### Creating a Snippet
1. Click the Snipster menu bar icon
2. Click the "+" (New Snippet) button
3. Enter:
   - **Title** - name for your snippet
   - **Content** - the text to expand (supports variables)
   - **Trigger** - prefix + keyword (e.g., `!email`)
   - **Tags** - organize with color-coded tags
   - **Favorite** - click star to mark as favorite
4. Click "Save"

### Using Variables in Snippets
Add dynamic content to your snippets:
```
Hello {{USERNAME}},

Today's date is {{DATE:LONG}}.
Current time: {{TIME}}.

Your clipboard content: {{CLIPBOARD}}

Best regards,{{CURSOR}}
```

When expanded, this becomes:
```
Hello John Doe,

Today's date is December 18, 2025.
Current time: 12:30 PM.

Your clipboard content: [whatever was in clipboard]

Best regards,[cursor positioned here]
```

### Using Spotlight Search (Quick Access)
1. Press `Cmd+Shift+S` from anywhere (or your custom hotkey)
2. **Browse by tags:** Click or press Enter on tag folders to drill down
3. **Search mode:** Start typing to search across all snippets
   - Searches titles, content, and triggers simultaneously
   - Results update in real-time as you type
4. **Navigate:** Use arrow keys to move through items
5. **Select:** Press Enter to copy snippet, or Cmd+Return to copy and paste
6. **Go back:** Press Escape to return to previous level
7. **Position:** Drag window anywhere - position is saved for next time

### Text Expansion
1. Open Settings → Text Expansion
2. Click "Enable" if accessibility permission not granted
3. Type your trigger anywhere (e.g., `!email`)
4. Content instantly replaces the trigger
5. If {{CURSOR}} was used, cursor is positioned automatically

### Managing Favorites
- **Star icon** in snippet row - toggle favorite
- **Right-click menu** → "Add to Favorites" / "Remove from Favorites"
- **Edit view** - click star in header to mark as favorite
- **Filter button** - click star in toolbar to show only favorites

### Duplicating Snippets
- **Right-click** any snippet → "Duplicate"
- Creates a copy with " Copy" suffix
- Trigger is cleared (set new trigger to avoid conflicts)
- Edit the duplicate to customize

### Export & Import
**Export:**
1. Settings → Backup & Restore
2. Click "Export" button
3. Choose save location
4. All snippets saved to JSON file

**Import:**
1. Settings → Backup & Restore
2. Click "Import" button
3. Select JSON file
4. Automatic merge (keeps newer versions)
5. See summary of added/updated/skipped

### Managing Tags
1. Settings → Tags section
2. Click "+ Add Tag" to create
3. Click pencil icon to edit
4. Click trash icon to delete
5. Tags show snippet count
6. Tag filter buttons in main view

### Keyboard Shortcuts

**Global:**
- `Cmd+Shift+S` - Open Spotlight-style search (customizable in Settings)
- `Cmd+Q` - Quit Snipster (from menu bar dropdown)

**Spotlight Search Window:**
- `↑` / `↓` - Navigate through items
- `Return` - Open tag folder or copy snippet to clipboard
- `Cmd+Return` - Copy snippet and auto-paste immediately
- `Esc` - Go back to previous level or close window
- `Click and drag` - Move window (position is remembered)

**Snippet Editor:**
- `Cmd+Return` - Save snippet
- `Esc` - Cancel editing

**Main Menu Bar View:**
- `Cmd+N` - Create new snippet
- Double-click snippet - Copy content to clipboard
- Right-click snippet - Context menu (Edit, Favorite, Duplicate, Copy, Delete)

## Architecture

### Core Components
- **SnippetStore**: Manages snippet data persistence and CRUD operations
- **TagStore**: Handles tag library, relationships, and color management
- **TextExpansionMonitor**: Monitors keyboard input for trigger detection with thread-safe event handling
- **HotkeyManager**: Global hotkey registration using Carbon APIs with conflict detection
- **HotkeyRecorderViewModel**: Real-time hotkey recording with validation
- **FileStorageManager**: Handles file-based JSON storage with multiple location support
- **SnippetVariableProcessor**: Processes dynamic variables (date, time, clipboard, etc.)

### Views
- **MenuBarPopoverView**: Main interface with snippet list, search, and filtering
- **SpotlightSearchView**: Spotlight-style search with tag-based navigation hierarchy
- **SpotlightWindow**: Custom NSPanel for floating window with position persistence
- **SpotlightWindowManager**: Singleton manager for Spotlight window lifecycle
- **SnippetDetailView**: Create/edit snippet interface with real-time trigger validation
- **SettingsView**: Unified settings panel with hotkey configuration and inline tag management
- **TagSelectorView**: Visual tag selection with color-coded pills
- **WindowHelper**: Centralized window management utilities

## Storage Format

Snippets are stored in JSON format at the configured location:
- Local: `~/Library/Application Support/Snipster/`
- iCloud: `~/Library/Mobile Documents/iCloud~Snipster/`
- Dropbox: `~/Dropbox/Apps/Snipster/`

## Technical Details

### Global Hotkey System
Snipster uses macOS Carbon Event Manager APIs for global hotkey registration, similar to other popular macOS utilities. The implementation includes:
- Carbon `RegisterEventHotKey` for system-wide keyboard shortcuts
- Event handler callbacks for hotkey press detection
- Conflict detection against common system shortcuts (Spotlight, App Switcher, etc.)
- Persistent storage of user preferences via UserDefaults

### Libraries & Frameworks
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming and state management
- **AppKit** - macOS window management and panel customization
- **Carbon** - Legacy APIs for global event monitoring and hotkey registration
- **CoreGraphics** - CGEvent for keyboard event simulation

## Acknowledgments

### Design Inspiration
The Spotlight-style search interface was inspired by [Clipy](https://github.com/Clipy/Clipy), an excellent open-source clipboard manager for macOS. Clipy's popup menu design provided valuable UX patterns for creating an intuitive, keyboard-driven search experience.

While Snipster implements its own custom search window and hotkey system from scratch, the visual design and interaction model draw from Clipy's proven approach to quick access interfaces.

### Technical References
- Apple's Carbon Event Manager documentation for global hotkey implementation
- Various open-source macOS utilities for conflict detection patterns

### Reporting Bugs
- Check existing issues first
- Include macOS version and Snipster version
- Provide steps to reproduce
- Include relevant screenshots or logs

### Suggesting Features
- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Consider how it fits with existing features

## License

This project is for personal and educational use. Feel free to fork and modify for your own use.
