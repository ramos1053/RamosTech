# Changelog

## [1.3.1] - 2026-07-24

### Added
- **Fill-in template variables (`{{INPUT:label}}`)**
  - Pauses expansion and pops a small floating window asking for a value per distinct label in the snippet — Tab moves between fields, Return on the last one submits, Escape cancels (the trigger stays deleted either way, matching how expansion already worked)
  - Date-kind fields show a compact field plus a calendar-icon button that expands a graphical date picker inline, rather than every date field showing a full calendar at once
  - The window sizes itself to the real, measured height of its content (via `NSHostingController.sizingOptions`) instead of a fixed guess, so it never clips a field list regardless of how many fields or how much text a field holds
  - Positions itself near the cursor when there's room, or top-center of the screen as a safety-zone fallback when there isn't — always fully on-screen, and draggable by its background if it ever lands somewhere inconvenient
- **Contact autofill**
  - A small button beside any Name/Contact/Email/Phone/Company-like field lets you pick a contact to fill just that one field, using a label heuristic (not a new token) to decide which contact property it wants
  - The contact picker is its own standalone, resizable window — macOS has no native contact-picker view controller outside Mac Catalyst/UIKit, so this is a plain SwiftUI list given a proper window instead of being crammed into the template popup
  - Prompts for Contacts access the first time it's needed, with a direct link into System Settings if access was denied

### Fixed
- A template field left blank pasted the literal `{{INPUT:label}}` tag into the document instead of just leaving that spot blank
- Submitting the Template Filler popup sometimes pasted nothing (with an alert-sound beep) instead of the filled-in template — bringing the popup to the front required activating Snipster itself, which silently stole keyboard focus from whatever app the trigger was typed into; focus is now explicitly restored to that app before the paste fires
- The contact-picker and calendar icon buttons in the Template Filler only responded to clicks on the icon glyph itself, not the rest of their visible background swatch
- The "Copy Path is Disabled" alert's icon, title, and message were left-aligned instead of centered, and only the OK button's text (not its full visual button) was clickable — replaced with a custom alert panel that centers correctly and makes the entire button clickable, plus Return-key dismissal
- Contacts permission wasn't being requested at all: the hardened runtime (required for Developer ID signing) silently blocks the system consent prompt without the Contacts entitlement, which was missing
- A rare crash triggered by picking certain contacts, caused by an uncaught Objective-C exception from reading a contact property that hadn't been fetched

### Removed
- Leftover iCloud/OneDrive-specific storage code and wording, now that storage is a plain custom-folder picker (see 1.3) — the entitlements file's now-unused iCloud container keys, and iCloud/OneDrive-specific phrasing in the storage picker's UI text
- A dead "All Snippets" option in the quick-access window's navigation that was never actually wired up to appear (present but unreachable since the very first commit), plus several other unused types, methods, and imports found in a full pass over the codebase

### Changed
- The whole codebase now builds warning-free under Swift's strict concurrency checking (`SWIFT_STRICT_CONCURRENCY = complete`, newly enabled for both the app and test targets) — no user-visible behavior change, but every actor-isolation warning that could indicate a real race was found and fixed rather than suppressed

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
