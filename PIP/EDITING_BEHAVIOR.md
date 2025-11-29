# Editing Behavior - BBEdit-like Configuration

## Overview
PIP now uses standard macOS text editing behavior, similar to BBEdit, with proper single-character deletion and all standard keyboard shortcuts.

## Key Changes

### 1. Native NSTextView Command Handling
**Before**: Custom delete handling that could delete multiple characters
**After**: NSTextView handles all commands with standard macOS behavior

```swift
func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    // Return false to let NSTextView handle all commands
    return false
}
```

### 2. Disabled Automatic Substitutions
Like BBEdit, we disable all automatic text transformations:

- ❌ Automatic quote substitution (smart quotes)
- ❌ Automatic dash substitution (em/en dashes)
- ❌ Automatic text replacement
- ❌ Automatic spelling correction
- ❌ Automatic link detection
- ❌ Automatic data detection
- ❌ Automatic text completion
- ❌ Continuous spell checking
- ❌ Grammar checking

### 3. Enabled Smart Features
- ✅ Smart insert/delete - Maintains proper spacing
- ✅ Standard undo/redo
- ✅ Font panel support
- ✅ Find panel support

## Keyboard Shortcuts (BBEdit-compatible)

### Character Deletion
| Key | Action |
|-----|--------|
| **Delete** | Delete one character backward |
| **Fn+Delete** or **Forward Delete** | Delete one character forward |
| **⌥+Delete** | Delete word backward |
| **⌥+Fn+Delete** | Delete word forward |
| **⌘+Delete** | Delete to beginning of line |
| **⌃+K** | Delete to end of line |

### Text Selection
| Key | Action |
|-----|--------|
| **Shift+Arrow** | Extend selection by character |
| **⌥+Shift+Arrow** | Extend selection by word |
| **⌘+Shift+Arrow** | Extend selection to line boundary |
| **⌘+A** | Select all |

### Navigation
| Key | Action |
|-----|--------|
| **Arrow Keys** | Move cursor one character |
| **⌥+Arrow** | Move cursor by word |
| **⌘+Arrow** | Move to line boundary |
| **⌘+↑** | Move to beginning of document |
| **⌘+↓** | Move to end of document |

### Standard Editing
| Key | Action |
|-----|--------|
| **⌘+Z** | Undo |
| **⌘+Shift+Z** | Redo |
| **⌘+C** | Copy |
| **⌘+X** | Cut |
| **⌘+V** | Paste |
| **Tab** | Insert tab (or spaces if configured) |
| **⌘+]** | Indent |
| **⌘+[** | Outdent |

## Behavior Details

### Delete Key Behavior
**Standard Operation**:
1. If text is selected → Delete entire selection
2. If no selection → Delete single character before cursor
3. At beginning of line → Does nothing

**With Modifiers**:
- **Option+Delete**: Deletes entire word (including punctuation boundaries)
- **Command+Delete**: Deletes from cursor to start of line
- **Control+K**: Deletes from cursor to end of line

### Selection Behavior
- Clicking and dragging selects text
- Double-click selects word
- Triple-click selects line/paragraph
- Shift+click extends selection
- Command+A selects all text

### Smart Insert/Delete
When enabled (default), the editor automatically:
- Adds space when pasting between words
- Removes extra spaces when deleting words
- Maintains proper spacing around punctuation

## Comparison with BBEdit

### Same as BBEdit ✅
- Single character deletion with Delete key
- All standard macOS keyboard shortcuts
- No automatic quote/dash substitution
- Clean text editing without interference
- Proper word/line deletion with modifiers

### Different from BBEdit
- No "Zap Gremlins" built-in (can be added)
- No "Educate Quotes" feature
- No scriptability (planned for future)
- Simpler preferences (for now)

## Testing the Behavior

### Test Single Character Deletion:
1. Type: `Hello World`
2. Position cursor after 'd'
3. Press Delete 5 times
4. Should delete: d, l, r, o, W (one at a time)

### Test Word Deletion:
1. Type: `The quick brown fox`
2. Position cursor after 'fox'
3. Press Option+Delete
4. Should delete: 'fox'
5. Press Option+Delete again
6. Should delete: 'brown'

### Test Line Deletion:
1. Type: `Start of line... middle... end`
2. Position cursor at 'middle'
3. Press Command+Delete
4. Should delete from 'middle' to start: `Start of line... `

### Test Selection Deletion:
1. Type: `Select this text`
2. Select 'this' by double-clicking
3. Press Delete
4. Should delete 'this' and become: `Select  text`

## Implementation Notes

### Why Native NSTextView?
NSTextView has 30+ years of optimization for text editing on macOS:
- Handles complex Unicode correctly
- Respects system text preferences
- Supports input methods (Chinese, Japanese, etc.)
- Handles RTL languages properly
- Clipboard integration
- Services menu support
- VoiceOver accessibility

### Performance
- Delete operations are O(1) for single characters
- Selection deletion is O(n) where n = selection length
- No custom logic means no bugs in edge cases
- Native code is optimized by Apple

### Future Enhancements
Planned BBEdit-like features:
- [ ] Hard wrap/soft wrap toggle
- [ ] Text transformations menu
- [ ] Grep pattern matching
- [ ] Rectangular selections
- [ ] Multiple cursors
- [ ] Column editing

## Configuration

### User Preferences
Users can configure via Preferences (⌘,):

**Editor Tab**:
- Tab width (1-16 spaces)
- Insert spaces for tabs
- Smart insert/delete (default: ON)

**Not Configurable** (by design):
- Delete behavior (always standard)
- Keyboard shortcuts (always system)
- These match BBEdit's approach of sensible defaults

## Troubleshooting

### Issue: Delete key not working
**Solution**: Check System Preferences > Keyboard > Key Repeat settings

### Issue: Delete key deletes whole words
**Solution**: Make sure Option key isn't stuck

### Issue: Can't delete at all
**Solution**:
1. Check if file is read-only
2. Verify text view is editable
3. Check permissions

### Issue: Wrong characters being deleted
**Solution**: Check input source (System Preferences > Keyboard > Input Sources)

## Technical Details

### Text Storage
- Uses NSTextView's native text storage
- All edits sync to PIP's piece table
- Undo/redo managed by NSTextView
- Real-time updates to line/column display

### Character Boundaries
NSTextView respects Unicode grapheme clusters:
- Emoji (👨‍👩‍👧‍👦) deletes as single unit
- Accented characters (é) delete as single unit
- Combining marks handled correctly
- Zero-width joiners respected

This matches BBEdit's behavior exactly.
