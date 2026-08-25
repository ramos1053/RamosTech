# PIP — Professional Interactive Programming Editor

A high-performance macOS text editor built for bash scripting and multi-language programming work, written in modern Swift and tuned to stay fast on large files.

## Core text engine

Text storage is a piece table with O(log n) insertion and deletion, so editing stays fast even on large documents. Undo/redo is command-based and coalesces edits within a 500ms window rather than recording every keystroke, with full transaction support for grouping complex operations. Parsing and I/O run in the background via Swift concurrency (async/await and actors), and files up to 100MB and beyond are handled through streaming I/O rather than loading everything into memory at once.

## Working with files

PIP opens plain text plus a handful of scripting languages directly — shell scripts (`.sh`, `.bash`, `.zsh`, runnable with ⌘R), Python, Ruby, Perl, JavaScript/Node, and PHP. Encoding support covers UTF-8/16/32 with their variants, ASCII, ISO Latin 1, Mac OS Roman, and Windows CP-1252, with automatic BOM detection and a custom encoding picker on save.

Saving works the way you'd expect — ⌘S to save, ⌘⇧S for Save As with format and encoding selection, an Export As option for format conversion, and atomic writes with backup creation so a crash mid-save doesn't cost you the file. Network volumes are supported too: you can browse, open, and save to them directly, with a remote-file indicator in the UI so you know when you're editing something that isn't local.

## The editing experience

Line numbers and a horizontal ruler are both toggleable, long lines soft-wrap, and invisible characters (spaces, tabs, line endings) can be shown when you need to see exactly what's in a file. Fonts are fully customizable — any system or user-installed font, adjustable size via ⌘+/⌘-, with live preview in preferences — and line endings convert freely between LF, CRLF, and CR.

Syntax highlighting covers Bash, Python, Swift, JavaScript, HTML, CSS, JSON, XML, YAML, Ruby, Perl, PHP, Java, C, C++, Objective-C, Go, Rust, SQL, and TypeScript, and auto-completion is context-aware: it detects the language from the shebang, understands commands, flags, variables, and keywords, and covers Python, Ruby, JavaScript, PHP, Perl, and Bash. It includes control-flow templates (if, for, while, class, function), environment variable completion (`$PATH`, `$HOME`, etc.), and command-flag completion — trigger it manually with Escape.

## Search and replace

The Find panel (⌘F) highlights matches in real time — orange for all matches, red-orange for the current one — with a counter showing your position (like "3/15"), up/down navigation arrows, and toggles for case sensitivity, whole-word matching, and regex. Replace supports both a single find-next replace and Replace All for bulk changes, both fully undoable (⌘Z / ⌘⇧Z), with success notifications showing how many replacements were made and no blocking while it runs.

Related shortcuts: ⌘F to find, ⌘G for find next, ⌘⇧G for find previous, ⌘E to use the current selection as the search term, and ⌘L to jump to a specific line.

## Running scripts

⌘R runs shell, Python, Ruby, Perl, JavaScript, or PHP scripts directly, with the interpreter auto-detected. A verbose mode adds tracing flags where the interpreter supports them (`bash -x`, `python -u`, and so on). Output shows up in a resizable panel at the bottom of the editor (100–400px, with a draggable divider), streaming stdout/stderr in real time with buttons to clear or close it, plus copy support and a monospaced font. ⌘. stops a running script, and a green or red indicator reports the exit code. There are also header templates for quickly inserting shebangs or XML/plist headers at the top of a new file. Bash scripts get a `shellcheck` pass before they run, if `shellcheck` is installed — problems show up alongside the script's own output.

## Workspaces, tabs, and printing

PIP supports multiple independent workspaces, each with its own set of tabs — close with ⌘W, switch freely, and see a modified indicator plus the file name and extension on each tab. The sidebar (⌘⌃S) lists files in the current workspace, and a workspace bar switches between open workspaces.

Printing (⌘P) flows text naturally across pages without truncating it, adapts to whatever page size you pick in the print dialog, defaults to 100% scaling with manual adjustment available, respects your configured margins, and gives you a full preview before anything goes to the printer.

## Preferences

The Editor tab covers ruler and line-number visibility, line wrapping, invisible-character display and coloring, tab width (1–16 spaces), spaces-vs-tabs, auto-save interval, undo history limit, predictive completion, syntax coloring, current-line highlighting, status bar contents, verbose script output, and default window size. Appearance handles theme selection, font family and size (Menlo, Monaco, SF Mono, and others) with live preview, and cursor type and blinking. Document covers font and tab-width defaults specifically for new documents, and Advanced handles snippet management, auto-save settings, default encoding, custom directories for logs and temp scripts, and file cleanup.

## The rest of the interface

The toolbar has a shebang-insertion menu (Bash, Python, Ruby, Perl, PHP, Node, Zsh, XML, Plist), font size controls, a sidebar toggle, Character Inspector (⌘⌥I), the Script Output Window toggle (⌘⌥O), text transformations (case conversion, tabs/spaces), a script-execution button with status indicator, and toggles for the debug console (⌘⌥D) and debugger (off by default). The status bar shows line/column position, encoding, file format, line endings, and character/word counts. A searchable help window (⌘?) documents the editor's features, the full auto-completion reference, keyboard shortcuts, and script execution.

## Project layout

```
PIP/
├── Models/
│   ├── AppPreferences.swift      # UserDefaults-based settings
│   ├── FileFormat.swift          # Format handlers (CSV, RTF, DOCX, etc.)
│   ├── DocumentManager.swift     # File operations manager
│   ├── ScriptExecutor.swift      # Script execution, shellcheck pre-flight & logging
│   ├── AutoSaveManager.swift     # Timed auto-save
│   ├── EditorTheme.swift         # Theme definitions
│   ├── Snippet.swift             # Snippet model
│   ├── TabManager.swift          # Tab/document tracking
│   └── WorkspaceManager.swift    # Multi-workspace state
├── Engine/
│   ├── PieceTable.swift          # Core text storage (grapheme-safe)
│   ├── TextEngine.swift          # Main coordinator
│   └── UndoManager.swift         # Command pattern undo/redo with transactions
├── Search/
│   └── SearchEngine.swift        # Streaming regex search with incremental results
├── Tokenizers/
│   ├── Tokenizer.swift           # Base tokenizer protocol
│   ├── SwiftTokenizer.swift      # Swift language syntax
│   ├── JSONTokenizer.swift       # JSON format syntax
│   ├── BashTokenizer.swift       # Bash/shell syntax
│   └── MarkdownTokenizer.swift   # Markdown syntax
├── UI/
│   ├── EditorView.swift          # NSTextView wrapper with ruler/line numbers
│   ├── LineNumberRulerView.swift # Custom line number gutter
│   ├── PreferencesWindow.swift   # Settings interface
│   ├── FindReplacePanel.swift    # Find/replace UI
│   ├── SnippetsView.swift        # Snippet management UI
│   ├── TabBar.swift              # Tab strip
│   └── WorkspaceBar.swift        # Workspace switcher
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
├── Debug/
│   ├── DebugConsoleWindow.swift  # Debug console (off by default)
│   └── DebugLogger.swift         # Debug logging
├── PIP.sdef                       # Apple Events scripting definition
├── PIP.entitlements               # Sandbox entitlements
├── PIPApp.swift                   # App entry point & menus
└── ContentView.swift               # Main layout
```

## Building

Before the first build, open `PIP.xcodeproj`, select the PIP target's **Signing & Capabilities**, and set **Team** to your own Apple developer account (or "Sign to Run Locally" for an ad-hoc build) — update the bundle identifier too if you need to.

Then select the PIP scheme with **My Mac** as the destination in Xcode 15.4+ and press ⌘R.

Requirements: macOS 14.0+, Xcode 15.4+, Swift 5.9+.

## Testing

There's no `PIPTests` or `PIPBenchmarks` target in the project yet — the Xcode project currently has a single scheme with no automated tests wired up. See "A few more things" below for the performance targets it's built toward.

## Keyboard shortcuts

**File** — ⌘N new, ⌘O open, ⌘S save, ⌘⇧S save as, ⌘P print, ⌘W close tab/window.
**Editing** — ⌘Z undo, ⌘⇧Z redo, ⌘A select all, ⌘C/V/X copy/paste/cut.
**View** — ⌘⌃S toggle sidebar, ⌘⌥O toggle script output, ⌘⌥I character inspector, ⌘⌥D debug console.
**Script execution** — ⌘R run, ⌘. stop.
**Formatting** — ⌘+ / ⌘- font size, ⌘T font panel.
**Application** — ⌘, preferences, ⌘? help, ⌘Q quit.

## Using it

Open files with ⌘O from local or network locations — encoding is auto-detected, and `.sh`, `.bash`, `.zsh`, `.py`, `.rb`, `.pl`, `.js`, `.php`, `.swift`, `.txt`, and `.md` are all recognized. Each opens in a new tab within the current workspace.

⌘S saves in place; ⌘⇧S (Save As) lets you pick both an output format and encoding, local or network. File > Export As handles broader format conversion.

To run a script, open it, edit as needed, and press ⌘R — the output window appears automatically at the bottom with live stdout/stderr, ⌘. stops it if needed, and verbose mode (enabled in preferences) adds command tracing (`bash -x`, `python -u`) if you want to see exactly what's happening. Clear or close the output window from its toolbar.

Header templates live behind the # button in the toolbar — pick a Bash or Python shebang, another language (Ruby, Perl, PHP, Node), or an XML/Plist header, and it's inserted at the top of the document with your cursor positioned right below it, ready to type.

Preferences (⌘,) covers line numbers, ruler, tabs, auto-save, script execution, status bar, and line highlighting under Editor; theme, font, and cursor style under Appearance; font and tab-width defaults under Document; and snippets, auto-save, encoding, and custom directories under Advanced.

Line numbers and the ruler can both be toggled from Preferences or the View menu — line numbers update as you type, and both respect whatever font you've set.

## How the piece table works

The piece table keeps two buffers — an immutable original buffer holding the file's initial content, and an append-only added buffer for everything new — plus a descriptor table sequencing pieces across both, and a grapheme-indices cache for fast lookup of Unicode grapheme cluster boundaries.

All offsets are counted in grapheme clusters, not UTF-16 code units, which matters for anything with emoji, combining marks, or other complex Unicode — a naive UTF-16-based implementation can split a grapheme cluster mid-edit and corrupt the display. For example, `"👨‍👩‍👧‍👦"` (a family emoji built from a zero-width-joiner sequence) is a single grapheme cluster but eleven UTF-16 code units — PIP's piece table reports the length of `"Hello 👨‍👩‍👧‍👦"` as 7, not 16, because it's counting clusters:

```swift
let table = PieceTable(text: "Hello 👨‍👩‍👧‍👦")
print(table.length) // 7 (not 16)
```

Performance-wise: append is O(1), random insert/delete is O(log n), full-text retrieval is O(n), and memory scales with the number of pieces rather than the size of the text.

## Undo, coalesced

Commands merge within a 500ms window — sequential insertions combine, backspace/delete operations combine, and transactions group more complex multi-step edits. A stack size limit keeps it from growing unbounded over a long editing session.

## Crash-safe file I/O

Reads stream in 1MB chunks with progress reporting on large files, BOM detection across UTF-8/16/32, fallback encoding heuristics when there's no BOM, and network file support via `NSOpenPanel`. Writes follow an atomic protocol: write to a temp file with a unique UUID name, `fsync()` it to make sure the data actually hit disk, close the descriptor, atomically rename it over the target (`replaceItemAt` on macOS), then `fsync()` the parent directory so the rename itself is durable. The upshot: even if the power goes out mid-save, you're left with either the complete old file or the complete new one — never something half-written.

```swift
// Atomic save ensures crash safety
try await ioManager.writeFile(content: "Important data", to: url, atomic: true)
// If a crash occurs during write, the original file is preserved
```

## Streaming search

Search works in 64KB chunks with a 1KB overlap between them (so matches spanning a chunk boundary aren't missed), which lets it search multi-gigabyte files without ever loading the whole thing into memory. It's backed by `NSRegularExpression` for regex, supports case-sensitive/insensitive and whole-word matching, tracks line and column numbers, offers a dry-run replace for previewing changes, and streams results incrementally via `AsyncStream`.

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

## Tokenizers

`SwiftTokenizer` recognizes Swift's keywords, capitalization-based type detection (`String`, `Int`, `MyClass`), string literals (plain, multi-line `"""`, and raw `#""#`), comments (`//`, `/* */`, `///`), numeric literals in all their forms (hex, binary, octal, scientific), and the standard set of operators. `JSONTokenizer` handles string values with escape sequences, numeric literals, the `true`/`false`/`null` keywords, key-vs-value detection, plus a built-in validator and an auto-formatter. Adding a new language means subclassing `BaseTokenizer`:

```swift
class MyLanguageTokenizer: BaseTokenizer {
    func tokenize(line: String, lineNumber: Int) -> [Token] {
        // Custom tokenization logic
    }
}
```

## File formats and script execution

Plain text and shell scripts use direct string encoding; CSV is plain text with some special handling; RTF and DOCX go through `NSAttributedString` with the corresponding document type. Format is auto-detected from the file extension, and encoding round-trips cleanly.

Script execution supports Bash, Shell, Zsh, Python, Ruby, Perl, JavaScript/Node, and PHP, picking the interpreter automatically from the extension and shebang. Verbose mode adds the relevant tracing flag per interpreter — `-x` for Bash/Shell/Zsh, `-u` for Python, `-v` for Ruby, `-w` for Perl. Under the hood, PIP makes a temporary copy in a secure location, sets owner-only execute permissions (0700), runs it with the right interpreter, streams stdout/stderr back asynchronously, reports the exit code (green for success, red for failure), and cleans up the process automatically. In normal mode, "success" means a clean exit code with nothing on stderr; in verbose mode, only the exit code is checked, since stderr tends to carry tracing noise.

Syntax highlighting updates incrementally with a 150ms debounce, invalidating only the affected lines and tokenizing in the background based on the detected file language.

Preferences are stored in `UserDefaults` through a singleton accessible app-wide, updating in real time via `@Published` and persisting across launches.

## A few more things

Network file support extends to opening and saving on mounted volumes, with automatic detection of remote paths and an indicator in the toolbar. Encoding options run to eleven: UTF-8 (the default), UTF-16 and its big/little-endian variants, UTF-32 and its variants, ASCII, ISO Latin 1, Mac OS Roman, and Windows CP-1252. Line endings are detected automatically on open, shown in the status bar, and convertible via the Format menu, with your choice preserved on save.

Rough performance targets: under 100ms startup, under 16ms per UI frame, under 1 second to open a 10MB file, under 500MB of memory for a 100MB file, and a 150ms debounce on syntax highlighting.

## Where things stand

The core is done: the piece-table engine, coalescing undo/redo, the editor view itself, streaming file I/O, syntax highlighting, line numbers and ruler, the preferences system, multi-format script support (Bash, Python, Ruby, Perl, PHP, Node), real-time script output, font customization, network file support, multi-workspace/tab handling, header templates, verbose tracing, the resizable output panel, theming, current-line highlighting, cursor customization, the character inspector, and a disabled-by-default debug console.

In progress: find/replace is done with real-time highlighting and navigation, as are text transformations and multi-page printing. Still open: multi-file search, code folding, multiple cursors, a full snippet system (the preferences UI already exists for it), and auto-completion.

PIP already has basic AppleScript support — a scripting definition (`PIP.sdef`) exposes `open`/`close`/`save`/`quit` Apple Events — though Shortcuts support isn't built on top of it yet.

Further out: LSP integration, Git integration (blame, diff, staging), a plugin system via XPC, fuller AppleScript/Shortcuts coverage, a command-line companion tool, and a diff viewer. And further still: a TextKit 2 migration, Tree-sitter parsing, semantic highlighting, memory-mapped large files, incremental layout improvements, and custom themes.

## Why these particular choices

A piece table was the obvious pick — it's what VSCode and Atom use, it beats a gap buffer for random access, it's more efficient than a rope for typical editing patterns, and it's simpler than a CRDT when you don't need multi-user collaboration. NSTextView, likewise, is a mature and battle-tested AppKit component with built-in editing behavior, ruler support, and accessibility handled for you, plus straightforward SwiftUI integration — a move to TextKit 2 is planned, but there was no reason to wait on it for a v1.

On the security side: the app runs sandboxed, file access goes through security-scoped bookmarks, only user-selected files are touched, there are no network connections without explicit user action, and scripts execute in an isolated subprocess.

## Credits

Built with inspiration from VSCode's text buffer implementation, Zed's rope-based editor, Sublime Text's performance focus, BBEdit's file-handling robustness, and Nova's native macOS integration.

## License

MIT — see the LICENSE file for details.
