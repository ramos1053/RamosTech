# Snipster

macOS menu bar snippet manager. Type a trigger, get your text. Or pull up the search window from anywhere with a hotkey. Either way it's faster than hunting through notes.

**Requires:** macOS 14.0 (Sonoma) or later

---

## Features

- **Text expansion** — type a trigger (e.g. `!email`) anywhere and it expands instantly
- **Global hotkey** — `Cmd+Shift+S` opens a Spotlight-style search window from any app
- **Dynamic variables** — `{{DATE}}`, `{{TIME}}`, `{{CLIPBOARD}}`, `{{USERNAME}}`, `{{CURSOR}}` and more
- **Tag system** — color-coded tags with snippet count badges and drill-down browsing in the search window
- **Favorites** — star snippets for quick filtering
- **Export / import** — JSON backup with merge, replace, or skip conflict resolution
- **Storage** — local, iCloud Drive, or Dropbox

---

## Build

1. Open `Snipster.xcodeproj` in Xcode
2. Set your signing team under Signing & Capabilities
3. Press `⌘R`

Text expansion requires Accessibility permission — System Settings → Privacy & Security → Accessibility.

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+Shift+S` | Open snippet search (customizable) |
| `↑` / `↓` | Navigate |
| `Return` | Copy to clipboard |
| `Cmd+Return` | Copy and paste immediately |
| `Esc` | Go back / close |
| `Cmd+Q` | Quit |

---

[LICENSE](../LICENSE)
