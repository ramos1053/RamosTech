# Time Machine Manager

Native SwiftUI app for browsing and managing Time Machine local snapshots. Because the built-in interface doesn't show you much.

**Requires:** macOS 14.0 (Sonoma) or later · Administrator privileges for delete and enable/disable operations

---

## What it does

- Lists all local snapshots sorted by date, with creation date, age, APFS info, backup destination, and disk space
- Enable or disable Time Machine without digging through System Settings
- Delete individual snapshots with a confirmation step
- Real-time status — Running, Enabled, or Disabled at a glance

---

## Build

1. Open `Time Machine Manager/Time Machine Manager.xcodeproj` in Xcode
2. Set your signing team under Signing & Capabilities
3. Press `⌘R`

macOS will prompt for your admin password when deleting snapshots or toggling Time Machine.

---

## If you see "No Snapshots Found"

Make sure Time Machine has a backup destination configured and has completed at least one backup. Verify with:

```sh
tmutil listlocalsnapshots /
```

---

## Version history

- **2.1** — Native SwiftUI app
- **2.0** — Shell script with AppleScript GUI
- **1.0** — Shell script

---

[LICENSE](../LICENSE)
