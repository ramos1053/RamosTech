# Snipster for Windows

Version 1.0.0

A Windows tray app for managing and expanding text snippets — keyboard triggers, dynamic variables, fill-in template prompts, tag-based organization, a bounded clipboard history, and a Spotlight-style quick-access window you can summon from anywhere with a global hotkey. This is an independent Windows port of [Snipster](../Snipster) for macOS, built from scratch against the Win32 and WPF APIs rather than sharing any code with it — see "Differences from the macOS version" below for where the two diverge.

## Quick access

Press the hotkey from anywhere (`Ctrl+Shift+S` by default, customizable in Preferences) and a search window opens over whatever you're doing. Start typing to filter across triggers and content, or click one of the tag chips at the top to narrow the list to a single tag. Enter copies the selected (or top) result and closes the window; Escape closes it without copying anything, and it also closes automatically the moment it loses focus.

## Clipboard history

A running, in-memory record of your last several copies — nothing is ever written to disk, and it's always empty again after Snipster restarts. Reach it from the tray icon's Clipboard History menu; each entry is its own submenu with two actions: Copy to Clipboard, or Create Snippet from This, which opens the snippet editor with that content already filled in and the cursor waiting in the Trigger field.

Copies from apps that mark their clipboard content as excluded from monitoring — password managers, for instance — are never recorded, following the same `ExcludeClipboardContentFromMonitorProcessing` convention Windows itself defines for this purpose.

History size (10, 25, 50, or 100 entries) is configurable from Preferences, along with a Clear Now button.

## Text expansion

Snippets expand via clipboard-based insertion, triggered by a prefix-plus-keyword pattern like `!email` or `!addr`. A global low-level keyboard hook watches for these patterns system-wide, deletes the typed trigger, and pastes the replacement — clipboard-and-paste rather than synthesizing keystrokes directly, because many modern applications don't reliably pick up synthetic keystrokes the way they pick up an actual paste. Trigger uniqueness is validated when you save a snippet, so two snippets can never silently shadow each other. Expansion can be turned off entirely from the tray menu or Preferences without closing Snipster.

Windows' own security model (UIPI) prevents any application — Snipster included — from observing or injecting keystrokes into a window running at a higher privilege level, such as an elevated terminal. This is the direct Windows equivalent of macOS requiring Accessibility permission for the same capability.

## Dynamic variables

Snippets can embed live content: `{{DATE}}` and `{{TIME}}` for the current date and time, `{{CLIPBOARD}}` for whatever's currently on the clipboard, and `{{USERNAME}}` for the signed-in Windows account name.

## Fill-in template variables

`{{INPUT:label}}` turns a snippet into a fill-in-the-blank template: expansion pauses and a small window pops up near the cursor with one field per distinct label (the same label used twice only asks once and fills both spots). Enter submits, Escape cancels and retypes the original trigger text rather than leaving a hole.

Any field whose label looks like it wants a name, email address, phone number, or address gets a small button beside it that opens a contact picker. Windows has no system-wide contacts store the way macOS does, so this draws from a small local address book kept inside Snipster's own library rather than an OS-level Contacts app.

## Managing snippets

Add, edit, and delete snippets from the Manage Snippets window, reachable from the tray icon. A snippet doesn't need a tag at all — tags are purely organizational.

Tags get their own name and color, set through a real color picker (or typed as a hex code directly) from the Manage Tags window, which also shows a live count of how many snippets use each tag. Deleting a tag clears it from any snippets that referenced it rather than leaving a dangling reference behind.

Export writes the whole library to a JSON file. Import shows a preview of exactly what a file contains — every trigger and a preview of its content, with any multi-line content made visible rather than hidden as a single line — before anything is merged in, and any incoming trigger that collides with an existing one is skipped and flagged in that preview.

## Preferences

Reachable from the tray icon's right-click menu. Covers launching Snipster at Windows startup, enabling or disabling text expansion, changing the quick-access hotkey (a candidate combo is tested against every other running application before it's accepted, so you can never end up with a hotkey that silently doesn't work), clipboard history size, and where the snippet library itself is stored — the default location, or a folder you point it at, such as a OneDrive or Dropbox folder you want it to sync through.

## Installing

Download `Snipster-Setup.exe` and run it — it installs entirely into your own user profile and never asks for administrator rights, so it works the same way whether or not your Windows account has local admin permissions. It adds a Start Menu shortcut and, if you check the box during install, a desktop shortcut. Uninstall it the normal way, from Windows' Apps list or the Start Menu shortcut.

## Building from source

Clone the repository, install the [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) if you don't already have it, then from `src/Snipster`:

```
dotnet build
dotnet run
```

No Visual Studio installation is required — the project also opens and runs fine in Visual Studio or Rider if you prefer either of those. To produce a distributable build the same way the installer does:

```
dotnet publish -c Release -r win-x64 --self-contained true
```

## Requirements

- Windows 10 version 1607 or later, or Windows 11
- No administrator rights needed to install or run
- Nothing else to install separately — the installer bundles its own copy of the .NET runtime

## Keyboard shortcuts

`Ctrl+Shift+S` opens the quick-access search window (customizable in Preferences). Inside that window, arrow keys navigate the results, Enter copies the selected snippet and closes, and Escape closes without copying. Inside a fill-in template popup, Tab moves between fields, Enter submits, and Escape cancels.

## How it's built

`TextExpansionMonitor` installs a `WH_KEYBOARD_LL` hook and matches typed text against snippet triggers; `KeyboardLayoutTranslator` turns each keystroke into the character it actually produces under the active window's real keyboard layout and modifier state via `ToUnicodeEx`, rather than assuming a US layout. `HotkeyManager` wraps `RegisterHotKey` with a conflict probe so a hotkey change can never silently fail. `ClipboardHistoryMonitor` uses `AddClipboardFormatListener` — event-driven, not polled. `FileStorageManager` persists the library as a single JSON file with an atomic write-then-rename. `TrayIconManager` uses WinForms' `NotifyIcon`, since WPF has no first-party tray icon API, alongside WPF for every window and dialog in the app. None of this requires administrator rights or any elevated capability — the app's manifest explicitly declares `asInvoker`, and every Win32 API it calls (`RegisterHotKey`, `SetWindowsHookEx`, `AddClipboardFormatListener`, `SendInput`) is a standard, non-elevated, per-user API.

## Differences from the macOS version

This port covers the macOS app's core feature set but isn't a line-for-line match. Contacts are a small local address book instead of the system Contacts database, since Windows has no equivalent store shared across ordinary desktop apps. There's no Explorer integration comparable to the macOS Finder Copy Path service. The dynamic-variable set is narrower — no long-form or custom date formats, no reaching further back into clipboard history than the most recent copy, no cursor-placement token. Import supports one conflict strategy (skip duplicates) rather than a choice between merge, replace, and skip. There's no favorites/starring, duplication, or multi-select delete in the snippet list yet.

If you run into a bug, include your Windows version and Snipster version along with steps to reproduce.

## License

Personal and educational use. Feel free to fork and modify.
