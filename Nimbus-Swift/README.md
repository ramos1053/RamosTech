# Nimbus-Swift

Management tool for Canto Cumulus servers on macOS. This is a full Swift rewrite of the original Nimbus, which I built in 2003 using AppleScriptKit. That version stopped working when Apple dropped 32-bit support. This one won't have that problem.

**Requires:** macOS 13.0 (Ventura) or later · A Cumulus server installation

---

## What it does

- Detects whether the Cumulus server process is running and shows its PID
- Live graphs for server memory usage, CPU usage, and catalog size — updates every 2 seconds
- Start and stop the server
- Backup catalogs to a configured destination
- Clean up old system logs and crash reports (requires admin password)
- Run custom shell commands with output displayed inline

---

## Build

1. Open `Nimbus-Swift.xcodeproj` in Xcode
2. Set your signing team under Signing & Capabilities
3. Update the Bundle Identifier if needed
4. Press `⌘R`

The app is not sandboxed — required to spawn server processes and run shell commands.

---

## Configure

On first launch, open Preferences and set:

- **Server path** — directory containing `start-cumulus` and `stop-cumulus` (default: `/usr/local/Cumulus5/`)
- **Catalog path** — where Cumulus stores its catalog files (used for size monitoring)
- **Backup path** — destination for catalog backups

---

## What changed from the 2003 version

| Then | Now |
|---|---|
| AppleScriptKit | Pure Swift |
| NIB files | SwiftUI |
| 32-bit | 64-bit |
| Drawer UI | Fixed 650×550 window |
| Registration required | Free |
| Static display | Live graphs |

---

[LICENSE](../LICENSE)
