# PIP

Text editor for macOS built around bash scripting and multi-language development. Handles large files without choking, runs scripts inline, and doesn't get in your way.

**Requires:** macOS 14.0 · Xcode 15.4+ · Swift 5.9+

---

## What makes it different

The text engine uses a piece table — same approach as VSCode — so insertion and deletion stay fast regardless of file size. Files up to 100MB+ open without loading everything into memory at once.

Atomic writes mean a crash during save won't corrupt your file. Ever.

---

## Features

- Run scripts directly with `⌘R` — Bash, Zsh, Python, Ruby, Perl, JavaScript, PHP
- Real-time stdout/stderr output in a resizable panel at the bottom
- Syntax highlighting for Bash, Python, Swift, JavaScript
- Auto-completion with language detection from shebang
- Find/replace with regex, live match highlighting, and match counter
- Multiple workspaces and tabs
- Line numbers, ruler, invisible characters, line wrapping
- 11 encoding options including BOM detection
- LF / CRLF / CR detection and conversion
- Header templates for shebangs, XML, plist

---

## Build

```sh
open PIP.xcodeproj
```

Select the PIP scheme, My Mac as destination, press `⌘R`. Set your signing team first.

---

## Run tests

```sh
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS'
```

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘R` | Run script |
| `⌘.` | Stop script |
| `⌘F` | Find |
| `⌘G` / `⌘⇧G` | Find next / previous |
| `⌘L` | Jump to line |
| `⌘⌃S` | Toggle sidebar |
| `⌘⌥O` | Toggle script output |
| `⌘+` / `⌘-` | Font size |
| `⌘,` | Preferences |
| `⌘?` | Help |

---

MIT License — [LICENSE](../LICENSE)
