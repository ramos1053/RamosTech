# Snipster

Version 1.3.1

A macOS menu bar app for managing and expanding text snippets — keyboard triggers, dynamic variables, fill-in template prompts, tag-based organization, a bounded clipboard history, and a Spotlight-style quick-access window you can summon from anywhere with a global hotkey.

## What changed in 1.3.1

Snippets can now pause expansion and ask for values instead of only substituting automatic variables — a new `{{INPUT:label}}` token pops a small window with one field per distinct label, turning a snippet into a real fill-in-the-blank template. Any field that looks like it wants a name, email, phone number, or company can be filled straight from a contact, via a small button beside the field that opens a proper contact-picker window. This release also fixes a handful of real bugs found while building that (blank fields pasting literal `{{INPUT:...}}` tags, a paste that could silently fail after submitting the popup, two icon buttons with a dead-zone in their clickable area, a mis-centered alert) and finishes removing the old iCloud/OneDrive-specific storage code left over from 1.3. Full details are in [CHANGELOG.md](CHANGELOG.md).

## Quick access

Press the hotkey from anywhere and you land in a tag-folder view — click or Enter to drill down, or just start typing to search across titles, content, and triggers simultaneously, with results updating live. Arrow keys navigate, Enter selects, Escape backs out a level or closes the window entirely, and the window itself can be dragged anywhere and will remember its position. A conflict detector warns if your chosen hotkey clashes with something the system already uses.

## Clipboard history

The quick-access window keeps a running, in-memory record of your last several copies — nothing is ever written to disk, and it clears automatically when Snipster quits, plus whatever auto-clear schedule you set (never, hourly, daily, or weekly) as a safety net for sessions that run for days. Browse it from the "Clipboard History" folder at the top of the window; selecting an older entry copies it back to the clipboard and moves it to the top. Right-click any entry and choose Save as Snippet to keep it permanently — it opens the usual new-snippet editor pre-filled with that content.

Copies from apps that mark their pasteboard content as concealed or transient (password managers like 1Password, for instance) are never recorded, following the same `org.nspasteboard.*` convention those apps already use to opt out of other clipboard managers.

History size (10, 30, 50, or 100 entries) and the auto-clear interval are both configurable from Settings > Clipboard History, along with a Clear History Now button.

## Copy Path in Finder

Right-click a file or folder anywhere in Finder and choose Services > Copy Path to copy its full path to the clipboard as plain text — select multiple items and each path is copied on its own line. The feature can be turned off from Settings > Finder Integration; macOS always shows the menu item while Snipster is running (there's no supported way for an app to hide its own Services entry at runtime), so turning it off makes Finder show an alert instead of copying anything.

## Text expansion

Snippets expand via clipboard-based insertion, triggered by a prefix-plus-keyword pattern like `!email` or `!addr`. Snipster monitors accessibility permission in real time and has a refresh button if monitoring needs restarting, along with a direct link into System Settings if permission isn't granted yet. Trigger uniqueness is validated as you type, so you can't accidentally create two snippets with the same trigger.

## Dynamic variables

Snippets can embed live content: date variables (`{{DATE}}`, `{{DATE:LONG}}`, `{{DATE:CUSTOM:yyyy-MM-dd}}` and similar), time variables (`{{TIME}}`, `{{TIME:24}}`), `{{CLIPBOARD}}` for whatever's currently copied (or `{{CLIPBOARD:2}}`, `{{CLIPBOARD:3}}`, and so on to reach further back into clipboard history), `{{USERNAME}}` / `{{USER}}` / `{{HOSTNAME}}` for system info, and `{{CURSOR}}` to place the cursor at a specific spot after expansion.

## Fill-in template variables

`{{INPUT:label}}` turns a snippet into a fill-in-the-blank template: expansion pauses and a small window pops up with one field per distinct label (the same label used twice only asks once and fills both spots), Tab moves between fields, and Return on the last one submits — Escape cancels, leaving the already-deleted trigger un-replaced, same as clicking outside the window. A field can also be typed with a date-shaped label to get a compact date field with an inline calendar picker instead of a plain text box.

Any field whose label looks like it wants a name, email address, phone number, or company — `Client Name`, `Contact Email`, `Company`, and similar — gets a small contact-picker button beside it. Tapping it opens a searchable window over the macOS Contacts database and fills just that one field from whichever contact is picked, leaving every other field in the form untouched and still editable by hand.

For example:

```
Hello {{USERNAME}},

Today's date is {{DATE:LONG}}.
Current time: {{TIME}}.

Your clipboard content: {{CLIPBOARD}}

Best regards,{{CURSOR}}
```

expands to something like:

```
Hello John Doe,

Today's date is December 18, 2025.
Current time: 12:30 PM.

Your clipboard content: [whatever was in clipboard]

Best regards,[cursor positioned here]
```

## Managing snippets

Create, edit, and duplicate snippets from the menu bar, star favorites for quick access, and filter by text, tag, or favorite status — sortable by title, tag, color, or creation/modification date. Preview length is adjustable (0, 1, or 2 lines), and a right-click context menu covers Edit, Favorite, Duplicate, Copy, and Delete.

Check a snippet's checkbox — in either the menu bar list or the quick-access window — to select more than one at a time; the Delete key or right-click removes whatever's checked, with a confirmation if you've selected more than one.

Export writes snippets and tags together to a single formatted JSON file, so a backup never leaves imported snippets with orphaned tags; import handles conflicts with merge (keeps whichever version was modified more recently), replace (always takes the imported version), or skip (keeps what's already there), and shows a summary of what was added, updated, or skipped. Older, snippets-only export files still import fine, just without tag data.

Tags get their own color via a full color picker, with a dropdown for filtering, inline tag management in Settings, per-tag snippet counts, and truncation to keep the tag list compact. Sort by Tag (in the Sort menu) is a separate, complementary feature — it's alphabetical by tag name and reorders the whole list rather than hiding anything.

Snipster stores its data locally by default (`~/Library/Application Support/Snipster/`), or you can point it at any folder you can navigate to — iCloud Drive, OneDrive, Google Drive, Dropbox, an external volume — from Settings > Storage > Change > Custom Folder.

## Building from source

Clone the repository, open `Snipster.xcodeproj`, and on the Snipster target's Signing & Capabilities tab set Team to your own Apple developer account (or "Sign to Run Locally" for an ad-hoc build) — the project ships with no team configured. Select the Snipster scheme and press Cmd+R — the app appears in your menu bar once it launches. The first time you try to expand a trigger, macOS will ask for Accessibility permission; head to System Settings → Privacy & Security → Accessibility and enable Snipster there.

Run the unit tests with Cmd+U, or `xcodebuild -scheme Snipster -destination 'platform=macOS' test` from the command line.

From there: click the menu bar icon, create your first snippet with the + button, set your hotkey in Settings if you don't want the default, and you're up and running.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ to build from source
- Accessibility permission for text expansion

## Keyboard shortcuts

Globally, `Cmd+Shift+S` opens the Spotlight-style search (customizable) and `Cmd+Q` quits from the menu bar dropdown. Inside that search window, `↑`/`↓` navigate, `Return` opens a folder or copies a snippet, `Cmd+Return` copies and auto-pastes, `⌫` deletes whatever's checked, and `Esc` backs out or closes. In the snippet editor, `Cmd+Return` saves and `Esc` cancels. From the main menu bar view, `Cmd+N` creates a new snippet, double-clicking one copies its content, right-clicking opens the context menu, and `⌫` deletes whatever's checked.

## How it's built

`SnippetStore` handles persistence and CRUD, `TagStore` manages the tag library and colors, `TextExpansionMonitor` watches keyboard input for triggers with thread-safe handling, `HotkeyManager` registers the global hotkey through Carbon's `RegisterEventHotKey` with conflict detection built in, and `FileStorageManager` persists everything to a single combined file (`StorageDocument`, `snipster-library.json`) across whichever location you've picked — local or a custom folder — migrating an older two-file install automatically the first time it loads. `CopyPathService` registers Snipster as a Finder Services provider for Copy Path and gates it on the Settings toggle. `ClipboardHistoryService` polls the pasteboard for changes and owns the in-memory ring buffer (`ClipboardHistoryBuffer`), which is covered by unit tests in `SnipsterTests`. On the UI side, `SpotlightWindow` is a custom `NSPanel` that remembers its position, and `MenuBarPopoverView` is the main list/search/filter interface.

`{{INPUT:label}}` parsing/substitution lives in `SnippetVariableProcessor`, and the popup itself is `TemplateInputWindow` — a borderless floating panel sized to its content's real, AppKit-measured height rather than a fixed guess, positioned near the cursor with a top-center screen fallback when there isn't room. `ContactAutofillService` classifies a field label against a contact property using a plain word-list heuristic and wraps the synchronous `CNContactStore` lookups; `ContactPickerWindow` gives that lookup its own standalone, resizable window rather than trying to fit a contact list into the template popup. `InfoAlertWindow` is a custom, centered replacement for `NSAlert` used for the Copy Path disabled notice.

The stack is SwiftUI for the UI, Combine for state management, AppKit for window handling, Carbon for the legacy global-hotkey APIs, Contacts for the autofill lookup, and CoreGraphics for simulating keyboard events during expansion. The whole codebase builds warning-free under Swift's strict concurrency checking (`SWIFT_STRICT_CONCURRENCY = complete`).

## Acknowledgments

The Spotlight-style search interface draws design inspiration from [Clipy](https://github.com/Clipy/Clipy), an open-source clipboard manager for macOS — Snipster's search window and hotkey system are built from scratch, but the interaction model owes a debt to Clipy's approach to quick-access popups.

If you run into a bug, check existing issues first, and include your macOS and Snipster versions along with steps to reproduce. Feature suggestions are welcome too — open an issue with the "enhancement" label and describe the use case.

## License

Personal and educational use. Feel free to fork and modify.
