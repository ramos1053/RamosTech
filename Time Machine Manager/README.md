# Time Machine Manager

A modern macOS application for managing Time Machine local snapshots with a native SwiftUI interface.

## Features

- **Snapshot Management**: View all Time Machine local snapshots in a clean, organized list
- **Detailed Information**: Access comprehensive details about each snapshot including:
  - Creation date and age
  - APFS information
  - Backup destination
  - System disk space usage
- **Time Machine Control**: Enable or disable Time Machine directly from the app
- **Snapshot Deletion**: Safely delete individual snapshots with confirmation dialogs
- **Real-time Status**: Monitor Time Machine status (Running, Enabled, or Disabled)
- **Modern UI**: Native macOS SwiftUI interface with split-view layout

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building)
- Administrator privileges (for certain operations like deleting snapshots and toggling Time Machine)

## Building the App

1. Open the Xcode project:
   ```bash
   cd "/Users/aramos/Projects/Time Machine Manager/Time Machine Manager"
   open "Time Machine Manager.xcodeproj"
   ```

2. Select your development team in the project settings

3. Build and run the app (⌘R)

## Usage

### Main Interface

The main window displays:
- **Status Header**: Current Time Machine status with enable/disable toggle
- **Snapshot List**: All local snapshots sorted by date (most recent first)
- **Detail Panel**: Comprehensive information about the selected snapshot

### Operations

#### Viewing Snapshots
- Snapshots are displayed in the left sidebar
- Click any snapshot to view detailed information in the detail panel
- Right-click a snapshot for quick actions

#### Deleting Snapshots
1. Select a snapshot from the list
2. Either:
   - Right-click and choose "Delete..."
   - Click the "Delete" button in the detail panel
3. Confirm the deletion in the dialog
4. **Note**: Administrator privileges are required

#### Enabling/Disabling Time Machine
1. Click the "Enable" or "Disable" button in the status header
2. Confirm the action in the dialog
3. **Note**: Administrator privileges are required

#### Refreshing Data
- Click the refresh button (⟲) in the toolbar
- Data is automatically loaded when the app launches

## Project Structure

```
Time Machine Manager/
├── TimeMachineManager.sh          # Original shell script (legacy)
└── Time Machine Manager/
    └── Time Machine Manager/
        ├── Time_Machine_ManagerApp.swift       # App entry point
        ├── ContentView.swift                   # Main UI
        ├── SnapshotDetailView.swift           # Detail view
        ├── SnapshotViewModel.swift            # State management
        ├── TimeMachineManager.swift           # Core functionality
        └── Assets.xcassets/                   # App assets
```

## Technical Details

### Architecture

- **MVVM Pattern**: Uses ViewModel for state management and separation of concerns
- **SwiftUI**: Modern declarative UI framework
- **Async/Await**: Asynchronous operations for smooth UI performance
- **NavigationSplitView**: Native macOS split-view interface

### Core Components

1. **TimeMachineManager**: Singleton class that interfaces with `tmutil` and system commands
2. **SnapshotViewModel**: ObservableObject that manages app state and user actions
3. **ContentView**: Main interface with snapshot list and controls
4. **SnapshotDetailView**: Detailed view for individual snapshots

### Shell Integration

The app executes the following shell commands:
- `tmutil listlocalsnapshots /` - List all local snapshots
- `tmutil status` - Get Time Machine status
- `tmutil destinationinfo` - Get backup destination information
- `tmutil enable/disable` - Enable or disable Time Machine
- `tmutil deletelocalsnapshots` - Delete a specific snapshot
- `df -h /` - Get disk space information
- `diskutil apfs listSnapshots /` - Get APFS snapshot details

## Permissions

The app requires administrator privileges for:
- Deleting snapshots
- Enabling/disabling Time Machine

When these operations are performed, macOS will prompt for authentication.

## Troubleshooting

### "No Snapshots Found"
- Ensure Time Machine is configured with a backup destination
- Run at least one Time Machine backup to create local snapshots
- Check that snapshots exist: `tmutil listlocalsnapshots /` in Terminal

### Authentication Failures
- Ensure you have administrator privileges
- Check that you're entering the correct password
- Some operations may be restricted by system policies

### Build Errors
- Ensure you're using macOS 14.0 or later
- Update to Xcode 15.0 or later
- Clean the build folder (Shift+⌘+K) and rebuild

## Version History

- **2.1** - Modern SwiftUI native app
- **2.0** - Shell script with AppleScript GUI
- **1.0** - Initial shell script version

## License

Created by Alan Ramos

## Contributing

This is a personal project. Feel free to fork and modify for your own use.
