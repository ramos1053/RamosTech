# Tabby

Tabby is a macOS menu bar app that shows every open tab across Chrome and Edge in one Mission Control-style grid, so you don't have to hunt through two browsers to find the tab you were just looking at.

## How it works

A Chromium extension in each browser enumerates open tabs and streams updates through Native Messaging to a small host binary, which relays them to the Tabby app over a Unix domain socket:

```
Browser Extension → Native Messaging → TabbyHost → Unix Socket → Tabby App
```

## What it does

Press the global hotkey (Cmd+Shift+T by default, and customizable) from anywhere and you get a grid of every tab from Chrome and Edge, each showing its favicon and, on hover, a live preview of the page. You can search by title or URL, click a tile to switch to that tab, right-click to close it, or drag tiles around to reorder them. Browser groups collapse independently, dark mode follows your system setting or can be forced either way, and the app itself runs as a menu bar agent with no dock icon — it can also launch at login if you want it always available.

## Getting started

Build and run Tabby from Xcode (see [BUILD.md](BUILD.md) for the full walkthrough), then open Settings from the menu bar cat icon and toggle on whichever of Chrome or Edge you use. The Help section in Settings walks through loading the browser extensions. Once that's done, Cmd+Shift+T opens the grid.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ to build
- Chrome and/or Edge installed

## Project layout

```
Tabby/              Main SwiftUI + AppKit app
Extensions/Chrome/  Chrome MV3 extension (service worker)
Extensions/Edge/    Edge MV3 extension (service worker)
NativeMessagingHost/ Native messaging bridge binary
```

See [BUILD.md](BUILD.md) for the detailed layout and development guide.

## License

Copyright 2025-2026 A. Ramos, RamosTech. All rights reserved.
