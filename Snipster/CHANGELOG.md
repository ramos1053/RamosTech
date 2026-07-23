# Changelog

## [1.3] - 2026-07-23

### Added
- **Multi-select delete**
  - Select multiple snippets at once via checkbox — in both the menu bar popover list and the Spotlight quick-access window
  - Delete key or right-click removes whatever's checked; deleting 2+ at once asks for confirmation, single delete stays instant
  - Checkboxes are a separate tap target from the row itself, so single-click-to-edit and double-click-to-copy are both unchanged
- **Custom folder storage location**
  - Replaces the old iCloud/OneDrive-specific storage options with a plain folder picker (`NSOpenPanel`) — works for iCloud Drive, OneDrive, Google Drive, Dropbox, or any mounted volume
  - The storage location choice is now actually persisted across relaunches (previously always reset to Local)
  - Switching to a new, empty location seeds it with your current snippets/tags instead of appearing to wipe them; switching to a location that already has data loads that instead

### Fixed
- iCloud Drive storage never actually worked: `Snipster.entitlements` declared the iCloud container keys, but the project file never wired up `CODE_SIGN_ENTITLEMENTS`, so the entitlement was never applied to any build. The custom-folder picker above sidesteps the issue entirely by not requiring any entitlement at all.
- Exporting a snippets backup silently dropped tag data, leaving imported snippets with orphaned tagIDs that had to be manually rebuilt. Snippets and tags are now combined into a single file (`snipster-library.json`, replacing separate `snippets.json`/`tags.json`), so export/import always carry both together. Existing installs migrate automatically the first time they load; the old files are left in place, not deleted.

### Changed
- The tag filter in the menu bar popover is now a compact dropdown next to Sort, replacing the horizontal-scrolling row of tag pills. Same filtering behavior, no more sideways scrolling. (Sort by Tag remains alphabetical by tag name, unaffected by this — sort and filter are separate features.)

## [1.2a] - 2026-07-22

### Added
- **Clipboard history**
  - Bounded, in-memory-only history of recent copies (never written to disk), browsable from the Spotlight-style quick-access window under a "Clipboard History" folder
  - Selecting an older entry copies it back to the clipboard and moves it to the top of history
  - Right-click any entry and choose "Save as Snippet" to keep it permanently
  - New `{{CLIPBOARD:N}}` variable to reach back into history from within a snippet, alongside the existing `{{CLIPBOARD}}` for the current clipboard
  - Settings > Clipboard History: enable/disable, history size (10/30/50/100), and an auto-clear schedule (never/hourly/daily/weekly)
  - Copies marked concealed or transient (e.g. from password managers, via the `org.nspasteboard.*` convention) are never recorded
- **Untagged folder**
  - Snippets with no tags — including anything saved from clipboard history without adding one — now appear in their own "Untagged" folder in the quick-access window, instead of only being reachable by search
- **SnipsterTests target**
  - First unit test target in the project, covering the clipboard history ring buffer, the concealed/transient detection, and the `{{CLIPBOARD:N}}` variable parsing

## [1.2.0] - 2026-07-21

### Added
- **Finder integration**
  - Right-click any file or folder in Finder and choose Services > Copy Path to copy its POSIX path to the clipboard as plain text
  - On/off toggle in Settings > Finder Integration
  - Since macOS builds the Services menu from the app's own signed Info.plist, the menu item stays visible while Snipster is running even when the toggle is off; invoking it while off shows an alert instead of copying anything

### Fixed
- Hotkey registration and the new Copy Path service now start immediately when Snipster launches, instead of waiting for the menu bar popover to be opened at least once
- Settings window no longer uses a non-activating panel, which was preventing native switch controls from drawing their full appearance and could make the Preferences window fail to come forward on a fresh launch
- Toggle switches in Settings now tint green when on

## [1.1.0] - 2026-01-09

### Added
- **Global Hotkey System**
  - Default hotkey Cmd+Shift+S (fully customizable)
  - Conflict detection against system shortcuts
  - Live hotkey recording
  - Persistent hotkey preference across sessions
- **Spotlight-style search window**
  - Tag-folder navigation
  - Real-time search across titles, content, and triggers
  - Full keyboard navigation (arrow keys, Enter, Escape)
  - Cmd+Return to copy and auto-paste
  - Remembers window position
  - 380px compact width

### Changed
- Search now filters snippets instead of tags
- Reduced padding and smaller fonts throughout the search window

### Removed
- `TagManagerWindow.swift` and `TagManagementView.swift` (dead code, replaced by inline tag management)

## [Unreleased]

### Planned
- Performance optimizations
