# Snipster

Version 1.1.0

A macOS menu bar app for managing and expanding text snippets — keyboard triggers, dynamic variables, tag-based organization, and a Spotlight-style quick-access window you can summon from anywhere with a global hotkey.

## What changed in 1.1

The headline addition is a global hotkey (Cmd+Shift+S by default, customizable) that pulls up a compact, Spotlight-style search window — 380px wide, with tag-folder navigation and real-time filtering as you type. The window remembers where you last moved it, Enter copies a snippet while Cmd+Return copies and pastes it immediately, and there's a general cleanup pass on search behavior and visual polish, plus a proper Quit option from the menu bar. Full details are in [CHANGELOG.md](CHANGELOG.md).

## Quick access

Press the hotkey from anywhere and you land in a tag-folder view — click or Enter to drill down, or just start typing to search across titles, content, and triggers simultaneously, with results updating live. Arrow keys navigate, Enter selects, Escape backs out a level or closes the window entirely, and the window itself can be dragged anywhere and will remember its position. A conflict detector warns if your chosen hotkey clashes with something the system already uses.

## Text expansion

Snippets expand via clipboard-based insertion, triggered by a prefix-plus-keyword pattern like `!email` or `!addr`. Snipster monitors accessibility permission in real time and has a refresh button if monitoring needs restarting, along with a direct link into System Settings if permission isn't granted yet. Trigger uniqueness is validated as you type, so you can't accidentally create two snippets with the same trigger.

## Dynamic variables

Snippets can embed live content: date variables (`{{DATE}}`, `{{DATE:LONG}}`, `{{DATE:CUSTOM:yyyy-MM-dd}}` and similar), time variables (`{{TIME}}`, `{{TIME:24}}`), `{{CLIPBOARD}}` for whatever's currently copied, `{{USERNAME}}` / `{{USER}}` / `{{HOSTNAME}}` for system info, and `{{CURSOR}}` to place the cursor at a specific spot after expansion.

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

Export writes everything to a formatted JSON file; import handles conflicts with merge (keeps whichever version was modified more recently), replace (always takes the imported version), or skip (keeps what's already there), and shows a summary of what was added, updated, or skipped. Older export formats still import fine.

Tags get their own color via a full color picker, with tag buttons for filtering, inline tag management in Settings, per-tag snippet counts, and truncation to keep the tag list compact.

Snipster stores its data locally by default (`~/Library/Application Support/Snipster/`), but you can switch to iCloud Drive or a Dropbox folder from Settings if you want snippets synced across machines.

## Building from source

Clone the repository, open `Snipster.xcodeproj`, select the Snipster scheme, and press Cmd+R — the app appears in your menu bar once it launches. The first time you try to expand a trigger, macOS will ask for Accessibility permission; head to System Settings → Privacy & Security → Accessibility and enable Snipster there.

From there: click the menu bar icon, create your first snippet with the + button, set your hotkey in Settings if you don't want the default, and you're up and running.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ to build from source
- Accessibility permission for text expansion

## Keyboard shortcuts

Globally, `Cmd+Shift+S` opens the Spotlight-style search (customizable) and `Cmd+Q` quits from the menu bar dropdown. Inside that search window, `↑`/`↓` navigate, `Return` opens a folder or copies a snippet, `Cmd+Return` copies and auto-pastes, and `Esc` backs out or closes. In the snippet editor, `Cmd+Return` saves and `Esc` cancels. From the main menu bar view, `Cmd+N` creates a new snippet, double-clicking one copies its content, and right-clicking opens the context menu.

## How it's built

`SnippetStore` handles persistence and CRUD, `TagStore` manages the tag library and colors, `TextExpansionMonitor` watches keyboard input for triggers with thread-safe handling, `HotkeyManager` registers the global hotkey through Carbon's `RegisterEventHotKey` with conflict detection built in, and `FileStorageManager` handles JSON storage across whichever location you've picked (local, iCloud, or Dropbox). On the UI side, `SpotlightWindow` is a custom `NSPanel` that remembers its position, and `MenuBarPopoverView` is the main list/search/filter interface.

The stack is SwiftUI for the UI, Combine for state management, AppKit for window handling, Carbon for the legacy global-hotkey APIs, and CoreGraphics for simulating keyboard events during expansion.

## Acknowledgments

The Spotlight-style search interface draws design inspiration from [Clipy](https://github.com/Clipy/Clipy), an open-source clipboard manager for macOS — Snipster's search window and hotkey system are built from scratch, but the interaction model owes a debt to Clipy's approach to quick-access popups.

If you run into a bug, check existing issues first, and include your macOS and Snipster versions along with steps to reproduce. Feature suggestions are welcome too — open an issue with the "enhancement" label and describe the use case.

## License

Personal and educational use. Feel free to fork and modify.
