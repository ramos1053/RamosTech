# Tabby

Tabby is a macOS menu bar app that shows every open tab across Chrome and Edge in one Mission Control-style grid, so you don't have to hunt through two browsers to find the tab you were just looking at.

## How it works

A Chromium extension in each browser enumerates open tabs and streams updates through Native Messaging to a small host binary, which relays them to the Tabby app over a Unix domain socket:

```
Browser Extension → Native Messaging → TabbyHost → Unix Socket → Tabby App
```

## What it does

Press the global hotkey (Cmd+Shift+T by default, and customizable) from anywhere and you get a grid of every tab from Chrome and Edge, each showing its favicon (decoded from whatever the browser hands over, with an HTTP fallback if that fails) and, on hover, a live preview of the page rendered in a sandboxed, auto-zoomed WebView that times out after 5 seconds and refuses to follow cross-origin redirects — so it won't get stuck showing you a login page. You can search by title or URL, click a tile to switch to that tab, right-click to close it (or right-click a browser's section header to close every tab in that browser at once), or drag tiles around to reorder them. Browser groups collapse independently, dark mode follows your system setting or can be forced either way, and the app itself runs as a menu bar agent with no dock icon — it can also launch at login if you want it always available. Bundled browser extensions are re-copied into place on every launch, so updates propagate automatically (you'll still need to reload the extension in-browser, which the in-app Help section walks through).

## Getting started

Build and run Tabby from Xcode, then open Settings from the menu bar cat icon and toggle on whichever of Chrome or Edge you use. The Help section in Settings walks through loading the browser extensions — Developer Mode, "Load unpacked," and the Accessibility permission the global hotkey needs. Once that's done, Cmd+Shift+T opens the grid.

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16+ to build
- Chrome and/or Edge installed

## Project layout

```
Tabby/              Main SwiftUI + AppKit app
Extensions/Chrome/  Chrome MV3 extension (service worker)
Extensions/Edge/    Edge MV3 extension (service worker)
NativeMessagingHost/ Native messaging bridge binary
```

The native messaging protocol uses 4-byte little-endian length-prefixed JSON frames over a per-browser Unix socket (`tabby-<browser>.sock`), with `activateTab`/`requestTabs`/`closeTab`/`closeAllTabs` commands and retry/reconnect logic on both ends.

## License

MIT — see [LICENSE](LICENSE).
