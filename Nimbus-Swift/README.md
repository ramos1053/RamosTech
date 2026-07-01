# Nimbus-Swift

A full Swift rewrite of Nimbus, a Cumulus server management tool for macOS originally built with AppleScriptKit back in 2003. This version drops AppleScript entirely, runs on SwiftUI, and adds real-time server monitoring the original never had. It's free and open source — no registration, no licensing.

## What's different from the original

Everything's native Swift now instead of AppleScriptKit, it's 64-bit and runs on macOS 13+, and every feature from the 2003 version is implemented (and in most cases improved). The headline addition is live monitoring: memory, CPU, and catalog size update every couple seconds with color-coded graphs, whereas the original only showed a static interface.

## Project layout

```
Nimbus-Swift/
├── Models/
│   ├── AppPreferences.swift           # Data models for preferences
│   └── SystemMetrics.swift            # Server metrics data structures
├── ViewModels/
│   ├── PreferencesManager.swift       # Preferences management with UserDefaults
│   └── ServerViewModel.swift          # Business logic and monitoring
├── Views/
│   ├── ContentView.swift              # Main application window
│   ├── PreferencesView.swift          # Preferences panel
│   └── MetricsGraphView.swift         # Real-time monitoring graphs
├── Utilities/
│   └── ShellExecutor.swift            # Shell command execution wrapper
├── Resources/
│   ├── Assets.xcassets/               # Asset catalog
│   └── final_icon_nimbus.icns         # Original app icon
├── NimbusSwiftApp.swift               # Main app entry point
├── Info.plist                         # App configuration
└── Nimbus_Swift.entitlements          # Entitlements (no sandbox)
```

## What it does

**Monitoring.** Detects whether the Cumulus server is running (via `pgrep -fl cumulus`), shows its PID, and tracks memory (`ps -o rss=`), CPU (`ps -o %cpu=`), and catalog size (`du -sm`) every 2 seconds, with graphs that shift from green to orange to red as usage climbs. System uptime is shown alongside.

**Server control.** Start and stop the Cumulus server with a couple of buttons — nothing fancy, just reliable.

**Backups.** Copy Cumulus catalogs to a configured backup location, with progress and error reporting along the way.

**Maintenance.** Quick access to `/var/log/system.log`, plus a modern log-cleanup routine that clears old logs, archives, and crash reports (this needs admin privileges).

**Console.** Run arbitrary shell commands and see the output in real time. A blacklist blocks the obviously dangerous ones — ssh, telnet, fsck, and similar.

The window itself is fixed at 650×550, non-resizable, with a hidden title bar so everything fits without scrolling.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+
- Swift 5.9+
- A Cumulus Server installation, for the server-management features to have anything to talk to

## Building it

Before the first build, open `Nimbus-Swift.xcodeproj`, select the Nimbus-Swift target's **Signing & Capabilities**, and set **Team** to your own Apple developer account (or "Sign to Run Locally" for an ad-hoc build) — update the bundle identifier too if you need to.

Then select the Nimbus-Swift scheme with **My Mac** as the destination and press ⌘R.

## How it's built

Two entitlements matter here: `com.apple.security.app-sandbox` is set to false (server management wouldn't work sandboxed), and `com.apple.security.automation.apple-events` is true, which is what lets it prompt for admin privileges.

Preferences live in `UserDefaults` under the key `NimbusPreferences` — server path (default `/usr/local/Cumulus5/`), catalog path, and backup path, all stored as JSON.

Shell execution goes through Swift's `Process` API directly for non-privileged commands, and through `osascript` when it needs an admin prompt.

## Comparing to the 2003 original

| Original (2003) | Nimbus-Swift |
|-----------------|---------------|
| AppleScriptKit framework | Pure Swift |
| AppleScript handlers | Swift async/await |
| NIB files | SwiftUI views |
| 32-bit | 64-bit |
| Project Builder (.pbproj) | Xcode (.xcodeproj) |
| macOS 10.2+ | macOS 13.0+ |
| Registration required | Free for everyone |
| Static interface | Real-time monitoring |
| Drawer UI | Compact fixed window |
| `periodic` command | Modern `find`/`rm` |

It's also missing the original's Japanese localization (English only for now), and there's no registration system to speak of — every feature is available to everyone from the start.

## Using it

On first launch, open Preferences and set the server path (where Cumulus's binaries live, typically `/usr/local/Cumulus5/`), the catalog path for size monitoring, and a backup destination. Save, and you're set.

Starting and stopping the server runs `start-cumulus` / `stop-cumulus` from the configured server path, with output shown in an alert dialog. Once running, the monitoring panel picks it up automatically — a green dot for running, red for stopped, the PID, system uptime, and three live graphs for memory, CPU, and catalog size, refreshing every 2 seconds.

Backups just need the catalog and backup paths configured; clicking Backup copies everything over recursively.

The Maintenance menu has the system log viewer and the log cleanup routine (admin password required for the latter). The Console section lets you type a command, hit Enter or click Run, and see the output below — again, a short list of dangerous commands (ssh, telnet, fsck, top, status) is blocked outright.

## Performance notes

Monitoring runs every 2 seconds by default (configurable in `ServerViewModel`). Memory and CPU numbers come back instantly via `ps`; catalog size via `du` can take a while on directories over 100GB. When the server isn't running, metrics just show 0 — no wasted cycles.

## What might come next

Nothing here is promised, but some ideas floating around: a dark-mode-aware header, historical graphs instead of just live numbers, a configurable refresh rate, localization beyond English, Notification Center integration, scheduled backups, CSV export, and configurable performance alerts.

## Credits

The original Nimbus 2.0 (2003) was an AppleScriptKit-based Cumulus management tool built by Spork Software. This rewrite keeps the spirit of that tool but is a from-scratch Swift implementation with real-time monitoring added on top.

## License

Freeware — use it, modify it, share it.

## Troubleshooting

If the server isn't detected, confirm Cumulus is actually running and that its process name contains "cumulus," and double-check the server path in Preferences. If metrics are stuck at 0, the server's probably not running, or the catalog path is wrong — check whether a PID shows up in the monitoring panel. If log cleanup fails, make sure you're entering the right admin password; occasionally a file is locked by the system and gets skipped, but the cleanup continues regardless.

This app needs an actual Cumulus Server installation to do anything useful — the server-management commands run against whatever path you configure.
