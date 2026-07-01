# Time Machine Manager Pro

A native SwiftUI app for managing Time Machine local snapshots — viewing what's there, inspecting the details, and cleaning them up without dropping into `tmutil` by hand.

## What it does

The main window lists every local snapshot, most recent first, with a status header showing whether Time Machine is running, enabled, or disabled (and a toggle to flip it). Selecting a snapshot shows its creation date and age, APFS info, backup destination, and how much disk space is involved. You can delete snapshots individually with a confirmation dialog first, and a refresh button re-reads everything on demand (it also loads automatically at launch).

Deleting a snapshot or toggling Time Machine both require administrator privileges — macOS will prompt for authentication when you do either.

## Requirements

- macOS 14.0 or later
- Xcode 15.0+ to build
- Administrator privileges for deletion and enable/disable operations

## Building the app

Open the Xcode project:

```bash
open "Time Machine Manager.xcodeproj"
```

Select your development team in the project settings, then build and run with ⌘R.

## Under the hood

It's built MVVM-style: `TimeMachineManager` is a singleton that wraps `tmutil` and friends, `SnapshotViewModel` holds app state and reacts to user actions, and `ContentView` / `SnapshotDetailView` handle the split-view UI. Everything's async/await under `NavigationSplitView`.

The shell commands it actually runs:

```
tmutil listlocalsnapshots /       # list all local snapshots
tmutil status                     # current Time Machine status
tmutil destinationinfo            # backup destination info
tmutil enable / tmutil disable    # toggle Time Machine
tmutil deletelocalsnapshots       # delete a specific snapshot
df -h /                           # disk space
diskutil apfs listSnapshots /     # APFS snapshot details
```

Project layout:

```
Time Machine Manager/
├── TimeMachineManager.sh          # original shell script (legacy)
└── Time Machine Manager/
    └── Time Machine Manager/
        ├── Time_Machine_ManagerApp.swift
        ├── ContentView.swift
        ├── SnapshotDetailView.swift
        ├── SnapshotViewModel.swift
        ├── TimeMachineManager.swift
        └── Assets.xcassets/
```

## Troubleshooting

If snapshots aren't showing up, make sure Time Machine actually has a backup destination configured and has run at least once — `tmutil listlocalsnapshots /` in Terminal will tell you if any exist. Authentication failures usually mean either a wrong password or a system policy blocking the operation; double-check you actually have admin rights. Build errors are almost always a version mismatch — this needs macOS 14+ and Xcode 15+, and a clean build folder (Shift+⌘+K) fixes most of the rest.

## Version history

- 2.1 — the SwiftUI native rewrite
- 2.0 — shell script with an AppleScript GUI
- 1.0 — original shell script

## License

Created by RamosTech.

## Contributing

Personal project, but feel free to fork and adapt it for your own use.
