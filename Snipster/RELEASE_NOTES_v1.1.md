# Snipster v1.1.0 Release Notes

**Release Date:** January 9, 2026

## Major New Features

### Global Hotkey System
Snipster now features a powerful global hotkey system that lets you access your snippets instantly from anywhere on your Mac.

- **Default Hotkey:** `Cmd+Shift+S` (fully customizable)
- **Smart Conflict Detection:** Prevents conflicts with system shortcuts
- **Live Hotkey Recording:** See your new hotkey immediately as you press it
- **Persistent Settings:** Your hotkey preference is remembered across sessions

### Spotlight-Style Search Window
A compact search interface inspired by macOS Spotlight and Clipy's popup menu.

**Key Features:**
- **Tag-Based Navigation:** Browse snippets by drilling down through tag folders
- **Real-Time Search:** Filter across titles, content, and triggers as you type
- **Keyboard-Driven:** Full keyboard navigation with arrow keys, Enter, and Escape
- **Auto-Paste:** Use `Cmd+Return` to copy and paste snippets instantly
- **Position Memory:** Window remembers where you placed it
- **Compact Design:** 380px width for minimal screen footprint
- **Visual Feedback:** See snippet content, tags, and favorites before selecting

### Enhanced User Experience
- **Improved Search:** Search now filters snippets instead of tags
- **Tighter UI:** Reduced padding and smaller fonts throughout search window
- **Better Visual Hierarchy:** Cleaner, more focused interface

## Technical Improvements

### Architecture
- Carbon Event Manager integration for global hotkey registration
- Custom NSPanel-based floating window with persistence
- Singleton SpotlightWindowManager for lifecycle management
- Enhanced HotkeyManager with conflict detection

### Code Quality
- Fixed all Swift concurrency actor isolation warnings
- Proper Sendable conformance for thread-safe types
- Removed dead code (TagManagerWindow, TagManagementView)
- Cleaned up debug print statements
- Zero compiler warnings in clean build

### Performance
- Nonisolated processing for text expansion monitoring
- Thread-safe snippet variable processing
- Efficient real-time search filtering

## What's Included

### New Files (v1.1)
- `HotkeyManager.swift` - Global hotkey registration and management
- `SpotlightSearchView.swift` - Spotlight-style search interface
- `SpotlightWindow.swift` - Custom floating panel window

### Updated Files
- `README.md` - Comprehensive documentation for v1.1
- `SnipsterApp.swift` - Hotkey manager initialization
- `SettingsView.swift` - Hotkey configuration UI
- `MenuBarPopoverView.swift` - Quit button addition
- `WindowHelper.swift` - Removed dead code
- All relevant view models and managers

### Removed Files
- `TagManagerWindow.swift` - Dead code (replaced by inline management)
- `TagManagementView.swift` - Dead code (replaced by inline management)

## Getting Started

### For New Users
1. Clone the repository
2. Open `Snipster.xcodeproj` in Xcode
3. Build and run (Cmd+R)
4. Create your first snippet
5. Try the global hotkey (Cmd+Shift+S)

### For Existing Users
- Update to v1.1 by pulling latest changes
- Your existing snippets and tags are fully compatible
- Try the new global hotkey feature in Settings
- Explore tag-based navigation in the Spotlight window

## Migration Notes

### From v1.0 to v1.1
- **No manual migration required** - all data is backward compatible
- Existing snippets, tags, and settings are preserved
- New hotkey feature is optional (text expansion still works independently)
- Storage format unchanged (JSON files remain compatible)

## Known Issues

### Limitations
- Global hotkey requires app to be running (not a background daemon)
- Text expansion requires Accessibility permission
- iCloud sync is file-based (may have minor sync delays)

### Workarounds
- Keep Snipster in Login Items for persistent global hotkey
- Grant Accessibility permission in System Settings
- Use Export/Import for manual backups before major changes

## Future Roadmap

See [CHANGELOG.md](CHANGELOG.md) for planned features:
- Performance optimizations


## Acknowledgments

### Design Inspiration
The Spotlight-style search window was inspired by [Clipy](https://github.com/Clipy/Clipy), an excellent open-source clipboard manager for macOS. While Snipster implements its own custom system from scratch, Clipy's popup menu design provided valuable UX patterns.

### Technical References
- Apple's Carbon Event Manager documentation
- macOS global hotkey implementation patterns from various open-source utilities

---

**Version:** 1.1.0
**Build Date:** January 9, 2026
**Minimum macOS:** 14.0 (Sonoma)
**Xcode Version:** 15.0+

Thank you for using Snipster!
