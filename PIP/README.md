# PIP - Professional Interactive Programming Editor

A feature-rich, high-performance text editor for macOS designed for bash scripting and multi-language programming, built with modern Swift and optimized for large files.

## Features

### Core Text Engine
- **Piece Table Architecture**: Efficient text storage with O(log n) insertion/deletion
- **Command-based Undo/Redo**: Coalescing edits with transaction support (500ms window)
- **Swift Concurrency**: Background parsing and I/O using async/await and actors
- **Large File Support**: Handles files up to 100MB+ with streaming I/O

### File Operations
- **Multi-Format Support**:
  - Plain Text (.txt)
  - Shell Scripts (.sh, .bash, .zsh) - executable with ⌘R
  - Python Scripts (.py)
  - Ruby Scripts (.rb)
  - Perl Scripts (.pl)
  - JavaScript/Node (.js)
  - PHP Scripts (.php)

- **Encoding Support**:
  - UTF-8, UTF-16, UTF-32 (with variant support)
  - ASCII, ISO Latin 1
  - Mac OS Roman, Windows CP-1252
  - Automatic BOM detection
  - Custom encoding selection on save

- **Save Options**:
  - Save (⌘S)
  - Save As (⌘⇧S) with format/encoding selection
  - Export As (multiple formats)
  - Atomic writes with crash safety
  - Backup creation

- **Network Support**:
  - Browse and open files from network volumes
  - Save to network locations
  - Remote file indicator in UI

### Editor Features
- **Line Numbers**: Toggle-able gutter with automatic updates
- **Ruler**: Horizontal ruler display
- **Line Wrapping**: Soft wrap for long lines
- **Invisible Characters**: Show spaces, tabs, and line endings
- **Font Customization**:
  - System and user-installed fonts
  - Adjustable font size (⌘+ / ⌘-)
  - Live preview in preferences
- **Line Ending Conversion**: Convert between LF, CRLF, and CR
- **Syntax Highlighting**: Keyword recognition for Bash, Python, Swift, JavaScript
- **Auto-Completion**: Intelligent code completion for multiple languages
  - Language detection from shebang
  - Context-aware completion (commands, flags, variables, keywords)
  - Python, Ruby, JavaScript, PHP, Perl, Bash support
  - Control flow templates (if, for, while, class, function)
  - Environment variable completion ($PATH, $HOME, etc.)
  - Command flag completion (context-aware)
  - Manual trigger with ESC key

### Search & Replace
- **Find Panel**: Powerful search interface with ⌘F
  - Real-time match highlighting (orange for all matches, red-orange for current)
  - Match counter showing position (e.g., "3/15")
  - Up/down navigation arrows for jumping between matches
  - Case-sensitive search toggle
  - Whole word search toggle
  - Regular expression support
  - Wrap-around navigation
- **Replace Operations**:
  - Single replace with find-next
  - Replace All for bulk operations
  - Full undo/redo support (⌘Z / ⌘⇧Z)
  - Success notifications with count
  - Instant performance (no blocking)
- **Keyboard Shortcuts**:
  - Find: ⌘F
  - Find Next: ⌘G
  - Find Previous: ⌘⇧G
  - Use Selection for Find: ⌘E
  - Jump to Line: ⌘L

### Script Execution
- **Run Scripts**: Execute shell, Python, Ruby, Perl, JavaScript, and PHP scripts with ⌘R
- **Multi-Language Support**: Automatic interpreter detection
- **Verbose Script Output**: Optional tracing mode (bash -x, python -u, etc.)
- **Script Output Window**:
  - Resizable panel at bottom of editor (100-400px)
  - Draggable divider for height adjustment
  - Real-time stdout/stderr streaming
  - Clear output button
  - Close/hide button
  - Monospaced font display
  - Copy output support
- **Process Control**: Stop running scripts with ⌘.
- **Exit Code Reporting**: Green/red indicator for success/failure
- **Header Templates**: Quick insert shebangs and XML/plist headers

### Workspace & Tabs
- **Multi-Workspace Support**: Multiple independent workspaces
- **Tab Management**:
  - Multiple tabs per workspace
  - Close tabs with ⌘W
  - Switch between tabs
  - Modified indicator on tabs
  - File name display with extension
- **Sidebar**: Toggle-able file list (⌘⌃S)
- **New Document**: Create untitled documents
- **Workspace Bar**: Switch between workspaces

### Printing
- **Multi-Page Printing**: Print documents with ⌘P
- **Natural Text Flow**: Text flows naturally across pages without truncation
- **Page Size Support**: Adapts to any page size selected in print dialog
- **100% Magnification**: Default 100% scaling with user-adjustable options
- **Margin Aware**: Respects user-configured page margins
- **Preview Support**: Full print preview before printing

### Application Preferences
- **Editor Tab**:
  - Show/hide ruler
  - Show/hide line numbers with separator
  - Line wrapping
  - Show invisible characters (spaces, tabs, line endings, control chars)
  - Invisible character color selection
  - Tab width (1-16 spaces)
  - Insert spaces for tabs
  - Auto-save with configurable interval
  - Undo history limit
  - Predictive completion
  - Syntax coloring
  - Current line highlighting with color options
  - Status bar options (character count, word count)
  - **Script Execution**: Verbose script output (tracing mode)
  - Window size defaults

- **Appearance Tab**:
  - Theme selection (multiple color schemes)
  - Font family selection (Menlo, Monaco, SF Mono, etc.)
  - Font size adjustment
  - Live font preview
  - System font panel integration
  - Cursor type (Line, Block, Underline)
  - Cursor blinking toggle

- **Document Tab**:
  - Font family and size
  - Tab width configuration
  - Spaces for tabs option

- **Advanced Tab**:
  - Text snippets management
  - Auto-save settings
  - Default file encoding
  - Custom directories (log save, temp scripts)
  - File cleanup utilities

### User Interface
- **Toolbar**:
  - Insert Shebang menu (Bash, Python, Ruby, Perl, PHP, Node, Zsh, XML, Plist)
  - Font size controls (larger/smaller)
  - Sidebar toggle
  - Character Inspector (⌘⌥I)
  - Script Output Window toggle (⌘⌥O)
  - Text transformations (uppercase, lowercase, tabs/spaces conversion)
  - Script execution button with status indicator
  - Debug console toggle (⌘⌥D)
  - Debugger toggle (default disabled)
- **Status Bar**: Line/column, encoding, file format, line endings, character/word count
- **Script Output Window**: Resizable bottom panel with output, clear, and close controls
- **Workspace Bar**: Switch between open workspaces
- **Sidebar**: File list for current workspace tabs
- **Keyboard Shortcuts**: Full keyboard navigation
- **Help System**: Comprehensive help window with searchable documentation (⌘?)
  - Editor features and preferences explained
  - Complete auto-completion reference
  - Keyboard shortcuts guide
  - Script execution documentation

## Architecture

```
PIP/
├── Models/
│   ├── AppPreferences.swift      # UserDefaults-based settings
│   ├── FileFormat.swift          # Format handlers (CSV, RTF, DOCX, etc.)
│   ├── DocumentManager.swift     # File operations manager
│   └── ScriptExecutor.swift      # Script execution & logging
├── Engine/
│   ├── PieceTable.swift          # Core text storage (grapheme-safe)
│   ├── TextEngine.swift          # Main coordinator
│   └── UndoManager.swift         # Command pattern undo/redo with transactions
├── Search/
│   └── SearchEngine.swift        # Streaming regex search with incremental results
├── Tokenizers/
│   ├── Tokenizer.swift           # Base tokenizer protocol
│   ├── SwiftTokenizer.swift      # Swift language syntax
│   └── JSONTokenizer.swift       # JSON format syntax
├── UI/
│   ├── EditorView.swift          # NSTextView wrapper with ruler/line numbers
│   ├── LineNumberRulerView.swift # Custom line number gutter
│   ├── PreferencesWindow.swift   # Settings interface
│   └── LogViewer.swift           # Script output viewer
├── IO/
│   └── FileIOManager.swift       # Streaming file operations with fsync
├── Highlighting/
│   └── SyntaxHighlighter.swift   # Tokenizer & coloring
├── Completion/
│   ├── CompletionProvider.swift        # Provider protocol
│   ├── CompletionDatabase.swift        # Keyword & command database
│   ├── BashCompletionProvider.swift    # Multi-language completion
│   ├── CompletionListView.swift        # Completion UI
│   └── CompletionWindowController.swift # Window management
├── PIPApp.swift                  # App entry point & menus
└── ContentView.swift             # Main layout

PIPTests/
├── PieceTableTests.swift         # Unit tests for text storage
├── SearchEngineTests.swift       # Tests for search/replace
└── FileIOManagerTests.swift      # Integration tests for file I/O

PIPBenchmarks/
└── PieceTableBenchmarks.swift    # Performance benchmarks
```

## Building from Source

### Code Signing (required before first build)

1. Open `PIP.xcodeproj` in Xcode
2. Click the project in the Navigator → select the **PIP** target
3. Go to **Signing & Capabilities**
4. Set **Team** to your own Apple developer account (or "None / Sign to Run Locally" for ad-hoc)
5. Optionally update **Bundle Identifier** (e.g. `com.yourname.PIP`)

### Build and run

1. Open `PIP.xcodeproj` in Xcode 15.4+
2. Select the **PIP** scheme and **My Mac** as the destination
3. Press **⌘R** to build and run

**Requirements:**
- macOS 14.0+
- Xcode 15.4+
- Swift 5.9+

## Testing

### Running All Tests
```bash
# Run all unit tests
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS'
```

### Running Specific Test Suites
```bash
# PieceTable tests (grapheme-safe text storage)
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPTests/PieceTableTests

# SearchEngine tests (regex search, chunk boundaries)
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPTests/SearchEngineTests

# FileIO tests (crash safety, atomic writes)
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPTests/FileIOManagerTests
```

### Running Individual Tests
```bash
# Run specific test method
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPTests/PieceTableTests/testGraphemeClusterEmoji
```

### Test Coverage
- **PieceTableTests**:
  - Grapheme cluster handling (emoji, combining marks, flags)
  - Insert/delete operations at various positions
  - Boundary conditions and edge cases
  - Large text operations

- **SearchEngineTests**:
  - Literal and regex search
  - Case sensitivity and whole word matching
  - Chunk boundary correctness (critical for large files)
  - Replace operations with dry-run
  - Streaming search

- **FileIOManagerTests**:
  - Encoding detection (UTF-8, UTF-16, BOM handling)
  - Line ending detection (LF, CRLF, CR)
  - Atomic writes with crash safety
  - Concurrent write operations
  - Backup creation
  - Large file handling

## Benchmarking

### Running All Benchmarks
```bash
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPBenchmarks
```

### Running Specific Benchmarks
```bash
# PieceTable performance
xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
  -only-testing:PIPBenchmarks/PieceTableBenchmarks
```

### Interpreting Results
- Look for "Time:" in output showing average time per iteration
- Compare baseline vs. changes to detect performance regressions
- Target performance:
  - Sequential append: < 0.001ms per operation (O(1))
  - Random insert: < 0.01ms per operation
  - Large insert (1MB): < 50ms
  - getText (10MB document): < 100ms
  - Find-replace (10MB): < 500ms

### Available Benchmarks
- `testBenchmarkSequentialAppend` - Measures O(1) append performance
- `testBenchmarkRandomInserts` - Random position insert performance
- `testBenchmarkLargeInsert` - Single large text insertion
- `testBenchmarkDeleteFromEnd` - Sequential deletion
- `testBenchmarkGetTextManyPieces` - Full text retrieval with fragmentation
- `testBenchmarkTypingSimulation` - Realistic typing with backspace
- `testBenchmarkFindAndReplace` - Search and replace operations
- `testBenchmarkEmojiContent` - Unicode/emoji handling performance

## Keyboard Shortcuts

### File Operations
- **⌘N**: New file
- **⌘O**: Open file
- **⌘S**: Save
- **⌘⇧S**: Save As
- **⌘P**: Print
- **⌘W**: Close tab/window

### Editing
- **⌘Z**: Undo
- **⌘⇧Z**: Redo
- **⌘A**: Select All
- **⌘C/V/X**: Copy/Paste/Cut

### View
- **⌘⌃S**: Toggle Sidebar
- **⌘⌥O**: Toggle Script Output Window
- **⌘⌥I**: Show Character Inspector
- **⌘⌥D**: Show Debug Console

### Script Execution
- **⌘R**: Run script
- **⌘.**: Stop script

### Formatting
- **⌘+**: Increase font size
- **⌘-**: Decrease font size
- **⌘T**: Show fonts panel

### Application
- **⌘,**: Preferences
- **⌘?**: Help
- **⌘Q**: Quit

## Usage

### Opening Files
1. Use File > Open (⌘O)
2. Select file from local or network location
3. Encoding is auto-detected
4. Supported formats: .sh, .bash, .zsh, .py, .rb, .pl, .js, .php, .swift, .txt, .md
5. Files open in new tabs within the current workspace

### Saving Files
1. **Save**: ⌘S to save to current location
2. **Save As**: ⌘⇧S to choose format and encoding
   - Select output format from dropdown
   - Choose encoding (UTF-8, UTF-16, ASCII, etc.)
   - Save to local or network location
3. **Export**: File > Export As for format conversion

### Running Scripts
1. Open any executable script (.sh, .py, .rb, .pl, .js, .php)
2. Edit as needed
3. Press ⌘R to execute
4. Script output window appears automatically at bottom
5. View real-time stdout/stderr output
6. Press ⌘. to stop if needed
7. Enable verbose mode in preferences for command tracing (bash -x, python -u)
8. Clear output or close window using toolbar buttons

### Header Templates
1. Click the # button in toolbar
2. Select from:
   - Bash shebangs (#!/bin/bash, #!/bin/sh, #!/usr/bin/env zsh)
   - Python shebangs (#!/usr/bin/env python3, #!/usr/bin/env python)
   - Other languages (Ruby, Perl, PHP, Node)
   - XML Header
   - Plist Header (complete template with proper DOCTYPE)
3. Header is inserted at top of document
4. Cursor moves to line below header, ready to type

### Preferences
1. Open with ⌘,
2. **Editor**: Configure line numbers, ruler, tabs, auto-save, script execution (verbose output), status bar, current line highlighting
3. **Appearance**: Select theme, font and size, preview changes, cursor style
4. **Document**: Font settings, tab width
5. **Advanced**: Text snippets, auto-save, default encoding, custom directories

### Line Numbers & Ruler
- Enable in Preferences or View menu
- Line numbers auto-update as you type
- Ruler shows horizontal measurement
- Both respect current font settings

## Implementation Details

### Piece Table (Grapheme-Safe)
The piece table maintains two buffers with grapheme cluster indexing:
- **Original Buffer**: Initial file content (immutable)
- **Added Buffer**: All new text (append-only)
- **Descriptor Table**: Sequence of pieces referencing buffer ranges
- **Grapheme Indices Cache**: Fast lookup for Unicode grapheme cluster boundaries

**Key Features:**
- All offsets use Unicode grapheme clusters (not UTF-16 code units)
- Correctly handles emoji, combining marks, and complex Unicode
- Prevents splitting grapheme clusters during edits

**Performance:**
- O(1) append operations
- O(log n) random inserts/deletes
- O(n) full text retrieval
- Memory: O(number of pieces), not O(text size)

**Example:**
```swift
// "👨‍👩‍👧‍👦" is 1 grapheme cluster, not 11 UTF-16 code units
let table = PieceTable(text: "Hello 👨‍👩‍👧‍👦")
print(table.length) // 7 (not 16)
```

### Undo System
Commands are coalesced within a 500ms window:
- Sequential insertions merge
- Backspace/delete operations combine
- Transactions group complex edits
- Stack size limits prevent unbounded growth

### File I/O (Crash-Safe)
Streaming with bounded buffers and atomic writes:
- **Reading:**
  - 1MB chunk size for reading
  - Progress reporting for large files
  - BOM detection (UTF-8, UTF-16 BE/LE, UTF-32)
  - Fallback encoding heuristics
  - Network file support via NSOpenPanel

- **Writing (Atomic Protocol):**
  1. Write data to temporary file with unique UUID name
  2. Call `fsync()` on temporary file to ensure data is on disk
  3. Close temporary file descriptor
  4. Atomically rename temporary file to target (uses `replaceItemAt` on macOS)
  5. Call `fsync()` on parent directory to ensure rename is durable

**Crash Safety Guarantee:**
Even in case of power loss or system crash, either the old file or the new file exists completely - never partial data.

**Example:**
```swift
// Atomic save ensures crash safety
try await ioManager.writeFile(content: "Important data", to: url, atomic: true)
// If crash occurs during write, original file is preserved
```

### SearchEngine (Streaming Regex)
High-performance search with incremental results:
- **Chunked Processing:**
  - 64KB chunks for memory efficiency
  - 1KB overlap between chunks to catch boundary matches
  - Can search multi-GB files without loading entire content

- **Features:**
  - NSRegularExpression backend for powerful regex
  - Literal search with case-sensitive/insensitive options
  - Whole word matching
  - Line and column number tracking
  - Dry-run replace for preview
  - Streaming results via AsyncStream

**Chunk Boundary Handling:**
Critical for correctness - patterns spanning chunk boundaries are caught via overlap region.

**Example:**
```swift
let engine = SearchEngine()

// Stream search results
let results = try await engine.search(pattern: "\\w+@\\w+\\.com",
                                     in: largeText,
                                     options: .init(useRegex: true))

for await result in results {
    print("Found at line \(result.lineNumber): \(result.matchedText)")
}

// Dry-run replace
let preview = try engine.dryRunReplace(pattern: "old",
                                       replacement: "new",
                                       in: text)
// Review changes before applying
```

### Tokenizers
Language-specific syntax analysis:

**SwiftTokenizer:**
- Keywords: func, var, let, class, struct, enum, etc.
- Types: Detected by capitalization (e.g., String, Int, MyClass)
- String literals: "", """""", #""#
- Comments: //, /* */, ///
- Numbers: Int, Float, hex (0x), binary (0b), octal (0o), scientific notation
- Operators: +, -, ==, !=, &&, ||, etc.

**JSONTokenizer:**
- String values (with escape handling)
- Number literals (int, float, scientific)
- Keywords: true, false, null
- Property vs value detection (keys followed by :)
- Built-in validator
- Auto-formatter with indentation

**Extensibility:**
```swift
class MyLanguageTokenizer: BaseTokenizer {
    func tokenize(line: String, lineNumber: Int) -> [Token] {
        // Custom tokenization logic
    }
}
```

### File Format Handlers
- **Plain Text/Shell**: Direct string encoding
- **CSV**: Plain text with special handling
- **RTF**: NSAttributedString with RTF document type
- **DOCX**: NSAttributedString with DOCX document type
- Auto-detection from file extension
- Encoding preservation on round-trip

### Script Execution
- **Multi-Language Support**: Bash, Shell, Zsh, Python, Ruby, Perl, JavaScript/Node, PHP
- **Automatic Interpreter Selection**: Based on file extension and shebang
- **Verbose Mode**: Optional tracing with interpreter-specific flags
  - Bash/Shell/Zsh: `-x` flag for command tracing
  - Python: `-u` flag for unbuffered output
  - Ruby: `-v` flag for verbose mode
  - Perl: `-w` flag for warnings
- **Execution Process**:
  - Creates temporary copy in secure location
  - Sets execute permissions (0700, owner only)
  - Runs with appropriate interpreter
  - Captures stdout/stderr asynchronously in real-time
  - Reports exit codes (green for success, red for failure)
  - Process termination with automatic cleanup
- **Output Window**: Resizable panel (100-400px) with drag handle
- **Success Detection**:
  - Verbose mode: Only checks exit code
  - Normal mode: Checks exit code and stderr presence

### Syntax Highlighting
Incremental updates:
- 150ms debounce on text changes
- Line-based invalidation
- Background tokenization
- Language detection from file extension
- Keyword, string, comment, number detection

### Preferences
- Stored in UserDefaults
- Singleton pattern for app-wide access
- Real-time updates via @Published
- Persists across app launches

## Advanced Features

### Network File Support
- Open files from mounted network volumes
- Automatic detection of remote paths
- Network indicator in toolbar
- Full read/write support

### Multi-Encoding Support
11 encoding options:
1. UTF-8 (default)
2. UTF-16
3. UTF-16 Big Endian
4. UTF-16 Little Endian
5. UTF-32
6. UTF-32 Big Endian
7. UTF-32 Little Endian
8. ASCII
9. ISO Latin 1
10. Mac OS Roman
11. Windows CP-1252

### Line Ending Normalization
- Automatic detection on open
- Display in status bar
- Convert between formats via Format menu
- Preserves user choice on save

## Performance Targets
- < 100ms startup time
- < 16ms frame time for UI updates
- < 1s to open 10MB files
- < 500MB memory for 100MB files
- 150ms debounce for syntax highlighting

## Roadmap

### Phase 1: Core Features ✅
- [x] Piece table text engine
- [x] Undo/redo with coalescing
- [x] Basic editor view
- [x] File I/O with streaming
- [x] Syntax highlighting foundation
- [x] Line numbers and ruler
- [x] Preferences system
- [x] Multi-format script support (Bash, Python, Ruby, Perl, PHP, Node)
- [x] Script execution with real-time output window
- [x] Font customization
- [x] Network file support
- [x] Multi-workspace and tab system
- [x] Header template insertion (shebangs, XML, plist)
- [x] Verbose script tracing mode
- [x] Resizable script output panel
- [x] Theme support with multiple color schemes
- [x] Current line highlighting
- [x] Cursor customization
- [x] Character inspector
- [x] Debug console (disabled by default)

### Phase 2: Enhanced Editing (In Progress)
- [x] Find/replace UI with real-time highlighting and navigation
- [ ] Multi-file search
- [ ] Code folding
- [ ] Multiple cursors
- [ ] Snippet system (preferences UI exists)
- [ ] Auto-completion
- [x] Text transformations (uppercase, lowercase, tabs/spaces)
- [x] Print capability (⌘P) with multi-page support

### Phase 3: Advanced Features
- [ ] LSP integration for autocomplete
- [ ] Git integration (blame, diff, staging)
- [ ] Plugin system via XPC
- [ ] AppleScript/Shortcuts support
- [ ] Command-line companion tool
- [ ] Diff viewer

### Phase 4: Performance & Polish
- [ ] TextKit 2 migration
- [ ] Tree-sitter parsing
- [ ] Semantic highlighting
- [ ] Memory-mapped large files
- [ ] Incremental layout improvements
- [ ] Custom themes

## Technical Notes

### Why Piece Table?
- VSCode, Atom, and other editors use this approach
- Better than gap buffers for random access
- More efficient than rope for typical editing patterns
- Simpler than CRDT for single-user scenarios

### Why NSTextView?
- Mature, battle-tested AppKit component
- Built-in text editing behaviors
- Ruler and accessibility support
- Easy integration with SwiftUI
- Migration to TextKit 2 planned

### Security Considerations
- App Sandbox enabled
- File access via security-scoped bookmarks
- User-selected file access only
- No network connections without user action
- Script execution in isolated subprocess

## Credits

Built with inspiration from:
- VSCode's text buffer implementation
- Zed's rope-based editor
- Sublime Text's performance focus
- BBEdit's file handling robustness
- Nova's native macOS integration

## License

MIT License - See LICENSE file for details

---

**PIP** - Where Performance Meets Polish
