# Nimbus-Swift

A complete modern rewrite of Nimbus - Cumulus Server Management Tool for macOS.

**100% Free and Open Source**

## Overview

This is a full Swift rewrite of the original Nimbus application (2003), which was built using AppleScriptKit. The new version is:

- **100% Swift** - No AppleScript dependencies
- **SwiftUI-based** - Modern, native macOS UI
- **64-bit ready** - Compatible with macOS 13.0 (Ventura) and later
- **Fully functional** - All original features implemented and enhanced
- **Freeware** - No registration or licensing required
- **Real-time monitoring** - Live server metrics with visual graphs

## Project Structure

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

## Features

### Real-Time Server Monitoring
- **Process Detection** - Automatically detects if Cumulus server is running
- **Process ID Display** - Shows PID of running server process
- **Server Memory Usage** - Real-time memory consumption in MB (specific to server process)
- **Server CPU Usage** - Live CPU percentage used by server process
- **Catalog Size** - Total size of Cumulus catalog/database files in GB
- **System Uptime** - Current system uptime display
- **Auto-refresh** - Metrics update every 2 seconds
- **Visual Graphs** - Color-coded bar graphs (green/orange/red based on thresholds)

### Server Management
- **Start Server** - Launch Cumulus server
- **Stop Server** - Shut down Cumulus server
- Compact, easy-to-use controls

### Backup System
- **Catalog Backup** - Copy Cumulus catalogs to backup location
- Configurable source and destination paths
- Progress and error reporting

### System Maintenance
- **View System Log** - Quick access to /var/log/system.log
- **Cleanup Logs** - Modern log cleanup (removes old logs, archives, crash reports)
- Requires admin privileges for cleanup operations

### Console Command Execution
- **Execute Custom Commands** - Run any shell command
- Real-time output display
- Security blacklist prevents dangerous commands (ssh, telnet, fsck, etc.)

### Compact Interface
- **Fixed Window Size** - 650x550 pixels, non-resizable
- **No Scrolling Required** - All features visible at once
- **Efficient Layout** - Side-by-side controls, compact spacing
- Modern macOS appearance with SwiftUI

## Technical Details

### Requirements
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9+
- **Cumulus Server**: Installation required for server management features

### Build Instructions

#### Code Signing (required before first build)

1. Open `Nimbus-Swift.xcodeproj` in Xcode
2. Click the project in the Navigator → select the **Nimbus-Swift** target
3. Go to **Signing & Capabilities**
4. Set **Team** to your own Apple developer account (or "None / Sign to Run Locally" for ad-hoc)
5. Optionally update **Bundle Identifier** to match your team (e.g. `com.yourname.NimbusSwift`)

#### Build and run

1. Open `Nimbus-Swift.xcodeproj` in Xcode
2. Select the **Nimbus-Swift** scheme and **My Mac** as the destination
3. Press **⌘R** to build and run

### Window Configuration
- Fixed size: 650×550 pixels
- Non-resizable (`.windowResizability(.contentSize)`)
- Hidden title bar for compact appearance
- All content visible without scrolling

### Entitlements

The app requires the following entitlements:
- `com.apple.security.app-sandbox: false` - Required for server management
- `com.apple.security.automation.apple-events: true` - For admin privilege prompts

### Preferences Storage

Preferences are stored in UserDefaults with the key `NimbusPreferences` as JSON:
- Server path (default: `/usr/local/Cumulus5/`)
- Catalog path (default: `/usr/local/Cumulus5/`)
- Backup path

### Monitoring Implementation

**Server Process Detection:**
- Uses `pgrep -fl cumulus` to detect running Cumulus server
- Extracts PID for per-process metrics

**Memory Monitoring:**
- Command: `ps -o rss= -p <pid>`
- Shows RSS (Resident Set Size) in MB
- Green < 1GB, Orange < 1.5GB, Red > 1.5GB

**CPU Monitoring:**
- Command: `ps -o %cpu= -p <pid>`
- Shows actual CPU percentage of server process
- Blue < 50%, Orange < 80%, Red > 80%

**Catalog Size Monitoring:**
- Command: `du -sm <catalog_path>`
- Shows total size of catalog directory in GB
- Green < 50GB, Orange < 75GB, Red > 75GB

## Migration from Original Nimbus

### What Changed

| Original (2003) | Modern (2025) |
|-----------------|---------------|
| AppleScriptKit framework | Pure Swift |
| AppleScript handlers | Swift async/await |
| NIB files | SwiftUI views |
| 32-bit | 64-bit |
| Project Builder (.pbproj) | Xcode (.xcodeproj) |
| macOS 10.2+ | macOS 13.0+ |
| Registration required | Free for all |
| Static interface | Real-time monitoring |
| Drawer UI | Compact fixed window |
| `periodic` command | Modern `find`/`rm` commands |

### Shell Commands

Shell execution now uses Swift's `Process` API:
- Non-privileged: Direct `Process` execution
- Privileged: `osascript` with administrator privileges prompt

## Usage

### First Launch

1. Open Nimbus-Swift
2. Click "Preferences" to configure:
   - **Server Path**: Path to Cumulus server binaries (e.g., `/usr/local/Cumulus5/`)
   - **Catalog Path**: Path to Cumulus catalogs (used for size monitoring)
   - **Backup Path**: Destination for backups
3. Click "Save"

### Server Operations

- **Start Server**: Executes `[server-path]/start-cumulus`
- **Stop Server**: Executes `[server-path]/stop-cumulus`
- **Monitoring**: Automatically detects running server and displays metrics
- All operations show output in alert dialogs

### Real-Time Monitoring

The Server Monitoring panel shows:
- **Status Indicator**: Green dot = running, Red dot = stopped
- **Process ID**: PID of running server (e.g., "PID: 12345")
- **Uptime**: System uptime display
- **Three Graphs**:
  1. Server Memory (MB) - Memory used by Cumulus process
  2. Server CPU (%) - CPU usage by Cumulus process
  3. Catalog Size (GB) - Total size of catalog files

Metrics update automatically every 2 seconds when server is running.

### Backup

1. Ensure catalog and backup paths are configured
2. Click "Backup" button
3. The app will copy catalogs recursively to backup location

### Maintenance

Access via the "Maintenance" dropdown menu:
- **View System Log**: Opens system.log in default text editor
- **Cleanup Logs**: Removes old log files, archives, and crash reports (requires admin password)

### Console Command Execution

The Console Command section allows you to run custom shell commands:
1. Enter your command in the text field
2. Press Enter or click "Run"
3. Output appears in the scrollable area below (60px height)

**Note**: Certain dangerous commands (ssh, telnet, fsck, top, status) are blocked for security.

## Known Differences from Original

- **Compact interface** - Fixed 650×550 window, no scrolling needed
- **Real-time monitoring** - Live graphs showing server metrics
- **Better error handling** - Async errors are properly caught and displayed
- **Modern UI** - SwiftUI provides native macOS appearance with automatic dark mode
- **No Japanese localization** - Only English (can be added later)
- **No registration system** - All features available to everyone
- **Accurate metrics** - Process-specific monitoring instead of system-wide

## Performance Notes

- Monitoring updates every 2 seconds (configurable in ServerViewModel)
- `du` command for catalog size may take longer for very large directories (>100GB)
- Memory and CPU metrics are instant via `ps` command
- No performance impact when server is not running (metrics show as 0)

## Future Enhancements

Potential improvements:
- [ ] Add Dark Mode color scheme for header
- [ ] Historical graph data (track metrics over time)
- [ ] Configurable monitoring refresh rate
- [ ] Localization support (Japanese, others)
- [ ] macOS Notification Center integration for alerts
- [ ] Automatic backup scheduling
- [ ] Export metrics to CSV
- [ ] Server performance alerts/thresholds

## Credits

**Original Nimbus 2.0** (2003)
- AppleScriptKit-based macOS application
- Cumulus Server management tool
- Developed by Spork Software

**Nimbus-Swift 3.0** (2025)
- Complete Swift rewrite
- Modern macOS architecture
- Real-time monitoring and graphs
- Free and open source

## License

This software is provided as freeware. You are free to use, modify, and distribute it.

## Troubleshooting

**Server not detected:**
- Ensure Cumulus server is running
- Check that the process name contains "cumulus"
- Verify server path in Preferences

**Metrics showing 0:**
- Server may not be running
- Check that PID is displayed in monitoring panel
- Ensure catalog path is correct in Preferences

**Log cleanup fails:**
- You must enter your admin password when prompted
- Some log files may be in use by the system
- The script continues even if some files can't be deleted

---

**Note**: This application requires a Cumulus Server installation to be functional. Server management commands are executed at the configured server path.
