# Snipster v1.3.1 Release Notes

**Release Date:** July 24, 2026

## Major New Features

### Fill-in Template Variables
Snippets can now pause expansion and ask for values instead of only substituting automatic variables.

- **`{{INPUT:label}}` tokens:** expansion pauses and a small floating window pops up with one field per distinct label in the snippet — the same label used twice only asks once and fills both spots
- **Keyboard-driven:** Tab moves between fields, Return on the last field submits, Escape cancels (the trigger stays deleted either way, matching how expansion already worked)
- **Date fields:** a label that looks date-shaped gets a compact field plus a calendar-icon button that expands a graphical date picker inline, instead of every date field showing a full calendar at once
- **Real content-based sizing:** the window measures its hosted content's actual height (via `NSHostingController.sizingOptions`) rather than a fixed guess, so it never clips a field list regardless of field count or content length
- **On-screen positioning:** appears near the cursor when there's room to drop down without running off the bottom of the screen, or falls back to top-center of the screen when there isn't — always fully on-screen, and draggable by its background as a safety valve

### Contact Autofill
- **One-click fill from Contacts:** any field whose label looks like it wants a name, email, phone number, or company — `Client Name`, `Contact Email`, `Company`, and similar — gets a small button that opens a contact picker and fills just that one field, leaving every other field untouched and still editable
- **Standalone picker window:** macOS has no native contact-picker view controller outside Mac Catalyst/UIKit, so this is a proper SwiftUI list given its own resizable window rather than being crammed into the template popup
- **Permission handling:** prompts for Contacts access the first time it's needed, with a direct link into System Settings if access was denied

## Reliability Fixes

### Blank Template Fields
A field left blank in the Template Filler pasted the literal `{{INPUT:label}}` tag into the document instead of just leaving that spot blank — the popup's submit handler now always supplies a real (blank, if untouched) value for every field.

### Silent Paste Failure After Submission
Submitting the Template Filler popup could paste nothing at all, with only an alert-sound beep. Bringing the popup to the front over another app required activating Snipster itself, which silently stole keyboard focus away from whatever app the snippet trigger was typed into — so the paste that followed submission landed nowhere. Snipster now records which app was frontmost before activating itself, and explicitly reactivates it before the paste fires.

### Icon Button Dead Zones
The contact-picker and calendar-icon buttons in the Template Filler only responded to clicks on the icon glyph itself, not the rest of their visible background swatch — a `.buttonStyle(.plain)` button's tappable area follows its label's rendered content unless a content shape is set explicitly. Both buttons now treat their whole background swatch as one tappable region.

### Copy Path Alert Layout
The "Copy Path is Disabled" alert's icon, title, and message were left-aligned instead of centered, and only the OK button's text — not its full visual button — was clickable. `NSAlert` couldn't be recentered without pushing its contents off to one side, so it was replaced with a custom alert panel that centers correctly, makes the entire button clickable, and responds to Return as well as a click.

### Contacts Permission Never Prompting
The Contacts access prompt never appeared at all. Snipster's hardened runtime (required for Developer ID signing) silently blocks the system consent prompt without the Contacts entitlement, which had been left out — adding it, plus calling the request on the main thread as Apple's API requires, fixed the prompt for good.

### Contact-Picker Crash
Picking certain contacts could crash the app, traced to an uncaught Objective-C exception from `CNContactFormatter` reading a contact property that had never actually been fetched. Switched to Apple's own `descriptorForRequiredKeys(for:)` so exactly the properties a formatter needs are always fetched.

## Removed

- The last of the iCloud/OneDrive-specific storage code and wording left over from 1.3's custom-folder storage change
- A dead "All Snippets" option in the quick-access window's navigation, present in the code but never actually reachable since the project's first commit
- Several other unused types, methods, and imports found during a full pass over the codebase

## Internal

- The whole codebase now builds warning-free under Swift's strict concurrency checking (`SWIFT_STRICT_CONCURRENCY = complete`, newly enabled for both the app and test targets) — no user-visible behavior change, but every actor-isolation warning that could indicate a real data race was found and fixed rather than suppressed

## What's Included

### New Files (v1.3.1)
- `ContactAutofillService.swift` - label-based heuristic for classifying a field as name/email/phone/company, and the `CNContactStore` search/fetch logic behind contact autofill
- `ContactPickerWindow.swift` - the standalone, resizable contact-picker window and its searchable list
- `TemplateInputWindow.swift` - the `{{INPUT:label}}` popup panel, its content-based sizing/positioning, and per-field date/contact controls
- `InfoAlertWindow.swift` - custom centered alert panel, replacing `NSAlert` for the Copy Path disabled notice
- `HotkeyPickerView.swift` - extracted hotkey-recording UI (unrelated refactor surfaced during this pass)
- `ContactAutofillServiceTests.swift`, `SnippetVariableProcessorInputTests.swift` - unit tests for the label heuristic and `{{INPUT:...}}` extraction/substitution

### Updated Files
- `SnippetVariableProcessor.swift` - `{{INPUT:...}}` label extraction and substitution
- `TextExpansionMonitor.swift` - expansion flow now pauses for a popup when a snippet has `{{INPUT:...}}` tokens
- `Snipster.xcodeproj/project.pbxproj` - version bump, Contacts entitlement build setting, `SWIFT_STRICT_CONCURRENCY = complete`
- `Snipster/Info.plist` - `NSContactsUsageDescription`
- Numerous files touched only for the strict-concurrency pass or the dead-code sweep (see [CHANGELOG.md](CHANGELOG.md) for the complete list)

## Getting Started

### For New Users
1. Clone the repository
2. Open `Snipster.xcodeproj` in Xcode
3. Set your own Team under Signing & Capabilities (the project ships with no team configured)
4. Build and run (Cmd+R)
5. Create a snippet whose content includes `{{INPUT:Name}}` and try triggering it

### For Existing Users
- Update to v1.3.1 by pulling the latest changes
- Existing snippets, tags, and settings are untouched
- The first template snippet you trigger after updating will prompt for Contacts access if any field looks contact-related — this is expected and only needs granting once

## Migration Notes

### From v1.3 to v1.3.1
- No manual migration required
- Storage format unchanged
- No new user-facing settings; `{{INPUT:label}}` and contact autofill work automatically based on snippet content and field labels

## Known Issues

### Limitations
- Contact autofill classification is a label heuristic, not a token — an unusually worded field label may not be recognized as contact-related and won't show the autofill button
- Same background-app limitations noted in earlier releases apply: the global hotkey, Copy Path, and the Template Filler all require Snipster to actually be running

## Future Roadmap

See [CHANGELOG.md](CHANGELOG.md) for planned features:
- Performance optimizations

---

**Version:** 1.3.1
**Build Date:** July 24, 2026
**Minimum macOS:** 14.0 (Sonoma)
**Xcode Version:** 15.0+

Thank you for using Snipster!
