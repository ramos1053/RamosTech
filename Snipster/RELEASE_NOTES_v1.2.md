# Snipster v1.2.0 Release Notes

**Release Date:** July 21, 2026

## Major New Features

### Finder Integration
Snipster can now copy a file's path straight from Finder, without opening the app at all.

- **Copy Path Service:** Right-click any file or folder in Finder and choose Services > Copy Path — the POSIX path (or all selected paths, one per line) is copied to the clipboard as plain text
- **On/Off Toggle:** A Finder Integration section in Settings turns the service on or off
- **Clear Feedback When Off:** Because macOS builds the Services menu from the app's signed Info.plist, the menu item can't disappear at runtime — so instead, invoking it while the toggle is off shows an alert explaining that Copy Path is disabled, rather than silently doing nothing

## Reliability Fixes

### Startup Timing
Hotkey registration and the new Copy Path service previously only started once the menu bar popover had been opened at least once, because they lived inside a SwiftUI `onAppear`. Both now start from `applicationDidFinishLaunching`, so they're active from the moment Snipster launches.

### Settings Window
The Settings window used a non-activating panel that couldn't become the key window. That's harmless for most SwiftUI controls, but it silently prevented native `NSSwitch`-backed toggles (and, previously, `ColorPicker`) from drawing their full appearance, and could make the window fail to come forward reliably on a fresh launch. Settings now opens in a regular, activatable window.

### Toggle Color
Settings toggles now tint green when on, using `SwitchToggleStyle(tint:)` directly rather than a chained `.tint()` modifier, which macOS doesn't consistently honor for switch controls.

## What's Included

### New Files (v1.2)
- `CopyPathService.swift` - Finder Copy Path service provider and its enable/disable state
- `Info.plist` - NSServices declaration for the Copy Path service, merged into the build's generated Info.plist

### Updated Files
- `SnipsterApp.swift` - Adds an `NSApplicationDelegate` so services and the hotkey start at launch
- `WindowHelper.swift` - Settings now opens in a regular window instead of a non-activating panel
- `SettingsView.swift` - Adds the Finder Integration toggle and switches to green-tinted toggles
- `Snipster.xcodeproj/project.pbxproj` - Version bump, `INFOPLIST_FILE` wired in for the merged Info.plist

## Getting Started

### For New Users
1. Clone the repository
2. Open `Snipster.xcodeproj` in Xcode
3. Set your own Team under Signing & Capabilities (the project ships with no team configured)
4. Build and run (Cmd+R)
5. Try Copy Path: right-click a file in Finder and choose Services > Copy Path

### For Existing Users
- Update to v1.2 by pulling the latest changes
- Existing snippets, tags, and settings are untouched
- Copy Path is on by default; turn it off in Settings > Finder Integration if you don't want it

## Migration Notes

### From v1.1 to v1.2
- No manual migration required
- Storage format unchanged
- The Copy Path preference defaults to on for existing installs

## Known Issues

### Limitations
- The Copy Path menu item stays visible in Finder's Services menu even when turned off in Settings, since macOS doesn't support hiding a Service's menu entry at runtime — turning it off changes what happens when you use it, not whether it's listed
- Same background-app limitations noted in v1.1 apply: the global hotkey (and now Copy Path) require Snipster to actually be running

## Future Roadmap

See [CHANGELOG.md](CHANGELOG.md) for planned features:
- Performance optimizations

---

**Version:** 1.2.0
**Build Date:** July 21, 2026
**Minimum macOS:** 14.0 (Sonoma)
**Xcode Version:** 15.0+

Thank you for using Snipster!
