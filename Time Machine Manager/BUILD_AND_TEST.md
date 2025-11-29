# Build and Test Guide

## Quick Start

### 1. Open the Project in Xcode

```bash
cd "/Users/aramos/Projects/Time Machine Manager/Time Machine Manager"
open "Time Machine Manager.xcodeproj"
```

### 2. Build and Run

1. In Xcode, select your Mac as the destination (Product → Destination → My Mac)
2. Press `⌘R` to build and run the application
3. The app should launch and display your Time Machine snapshots

## Testing Checklist

### Basic Functionality

- [ ] **App Launches**: The app opens without errors
- [ ] **Snapshots Load**: Local snapshots appear in the sidebar
- [ ] **Status Display**: Time Machine status shows correctly (Running/Enabled/Disabled)
- [ ] **Destination Info**: Backup destination is displayed
- [ ] **Disk Space**: System disk space information is shown

### Snapshot List

- [ ] **Snapshot Display**: Each snapshot shows date and age
- [ ] **Sorting**: Snapshots are sorted by date (most recent first)
- [ ] **Selection**: Clicking a snapshot shows details in the right panel
- [ ] **Context Menu**: Right-clicking a snapshot shows options

### Detail View

- [ ] **Snapshot Information**: Name, creation date, and age are displayed
- [ ] **Backup Destination**: Destination name and latest backup are shown
- [ ] **System Information**: Disk space details are visible
- [ ] **APFS Information**: APFS snapshot data appears (if available)

### Actions (Requires Admin Privileges)

⚠️ **Warning**: These actions will modify your system. Test carefully!

- [ ] **Refresh**: Click the refresh button to reload data
- [ ] **Toggle Time Machine**:
  - Click Enable/Disable button
  - Confirm in dialog
  - Enter admin password when prompted
  - Verify status changes

- [ ] **Delete Snapshot** (Optional):
  - Select a snapshot you don't need
  - Click Delete button or use context menu
  - Confirm deletion
  - Enter admin password when prompted
  - Verify snapshot is removed from list

### Error Handling

- [ ] **No Snapshots**: If no snapshots exist, shows appropriate message
- [ ] **Loading State**: Shows loading indicator while fetching data
- [ ] **Error Alerts**: Displays error messages if operations fail
- [ ] **Success Alerts**: Shows success messages after operations complete

## Current System Status

Based on the test run, your system has:
- **Time Machine Status**: Not currently running
- **Backup Destination**: T7 Shield (Local)
- **Local Snapshots**: 2 snapshots found
  - com.apple.TimeMachine.2025-11-04-174502.local
  - com.apple.TimeMachine.2025-11-10-085133.local
- **Disk Space**: 926 GB total, 11 GB used, 663 GB available (2% full)

## Troubleshooting

### Build Errors

If you encounter build errors:

1. **Clean Build Folder**: Press `Shift+⌘+K`
2. **Check Deployment Target**: Ensure it's set to macOS 14.0 or later
3. **Verify Files**: Ensure all Swift files are added to the target
4. **Check Signing**: Select a valid development team in project settings

### Runtime Issues

If the app crashes or doesn't work:

1. **Check Console**: Open Console.app to see error logs
2. **Verify Permissions**: Ensure you have access to `/` for snapshots
3. **Test Commands**: Run the test script:
   ```bash
   cd "/Users/aramos/Projects/Time Machine Manager"
   ./test_tm_commands.sh
   ```

### Authentication Issues

If admin operations fail:

1. **Verify Account**: Ensure your account has admin privileges
2. **Check System Policies**: Some systems may restrict Time Machine access
3. **Test Manually**: Try running `tmutil` commands in Terminal:
   ```bash
   sudo tmutil disable  # Should prompt for password
   sudo tmutil enable   # Re-enable after testing
   ```

## Adding to Xcode Project

If any Swift files are not visible in Xcode:

1. Right-click on "Time Machine Manager" folder in Xcode
2. Select "Add Files to Time Machine Manager..."
3. Select the missing file(s)
4. Ensure "Copy items if needed" is unchecked
5. Click "Add"

## Building for Distribution

To create a release build:

1. Product → Archive
2. Distribute App → Direct Distribution
3. Sign with your Developer ID (if available)
4. Export the app

Note: For distribution outside the Mac App Store, you'll need:
- Apple Developer account
- Developer ID certificate
- Notarization (for macOS 10.15+)

## Performance Notes

The app uses async/await for all Time Machine operations to ensure:
- UI remains responsive during operations
- No blocking of the main thread
- Smooth user experience

## Next Steps

After successful testing, you can:

1. **Customize the UI**: Modify colors, fonts, or layout in SwiftUI views
2. **Add Features**:
   - Start backup manually
   - Browse snapshot contents
   - Compare snapshots
   - Scheduled snapshot deletion
3. **Add App Icon**: Create an app icon in Assets.xcassets
4. **Localization**: Add support for multiple languages

## Support

For issues or questions:
1. Check the README.md for general information
2. Review the code comments in Swift files
3. Test individual components using the test script
