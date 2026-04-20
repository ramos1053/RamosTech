import SwiftUI

/// Comprehensive help documentation for PIP
struct HelpWindow: View {
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory = .gettingStarted

    var body: some View {
        NavigationSplitView {
            // Sidebar with categories
            List(selection: $selectedCategory) {
                Section("Basics") {
                    ForEach(HelpCategory.basicsCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }

                Section("Preferences") {
                    ForEach(HelpCategory.preferencesCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }

                Section("Features") {
                    ForEach(HelpCategory.featuresCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search help...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top)

                    Divider()
                        .padding(.horizontal)

                    // Content
                    if searchText.isEmpty {
                        // Show selected category
                        categoryContent(for: selectedCategory)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    } else {
                        // Show search results
                        searchResults
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryContent(for category: HelpCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.title)
                .font(.largeTitle)
                .bold()

            Text(category.description)
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            ForEach(category.topics) { topic in
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.title)
                        .font(.title2)
                        .bold()

                    Text(topic.content)
                        .font(.body)

                    if !topic.details.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(topic.details, id: \.self) { detail in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(detail)
                                        .font(.body)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)

                if topic.id != category.topics.last?.id {
                    Divider()
                }
            }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Results")
                .font(.largeTitle)
                .bold()

            let results = searchHelpContent(query: searchText)

            if results.isEmpty {
                Text("No results found for '\(searchText)'")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 40)
            } else {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.category)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)

                            Spacer()
                        }

                        Text(result.topic.title)
                            .font(.headline)

                        Text(result.topic.content)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)

                        Button("View") {
                            selectedCategory = result.categoryEnum
                            searchText = ""
                        }
                        .buttonStyle(.link)
                    }
                    .padding(.vertical, 8)

                    if result.id != results.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func searchHelpContent(query: String) -> [HelpSearchResult] {
        guard !query.isEmpty else { return [] }

        let lowercaseQuery = query.lowercased()
        var results: [HelpSearchResult] = []

        for category in HelpCategory.allCategories {
            for topic in category.topics {
                let searchableText = "\(topic.title) \(topic.content) \(topic.details.joined(separator: " "))"
                if searchableText.lowercased().contains(lowercaseQuery) {
                    results.append(HelpSearchResult(
                        category: category.title,
                        categoryEnum: category,
                        topic: topic
                    ))
                }
            }
        }

        return results
    }
}

// MARK: - Data Models

struct HelpCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let topics: [HelpTopic]

    static func == (lhs: HelpCategory, rhs: HelpCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct HelpTopic: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let details: [String]

    init(title: String, content: String, details: [String] = []) {
        self.title = title
        self.content = content
        self.details = details
    }
}

struct HelpSearchResult: Identifiable {
    let id = UUID()
    let category: String
    let categoryEnum: HelpCategory
    let topic: HelpTopic
}

// MARK: - Help Content

extension HelpCategory {
    static let gettingStarted = HelpCategory(
        title: "Getting Started",
        icon: "star.fill",
        description: "Learn the basics of using PIP",
        topics: [
            HelpTopic(
                title: "Welcome to PIP",
                content: "PIP (Plain. Intuitive. Powerful.) is a modern plain text editor for macOS designed for developers, writers, and power users."
            ),
            HelpTopic(
                title: "Creating Documents",
                content: "Create a new document using File > New (⌘N) or open an existing file with File > Open (⌘O).",
                details: [
                    "Support for multiple file types: shell scripts, Python, Ruby, JavaScript, and more",
                    "Automatic file type detection based on shebang or file extension",
                    "Syntax highlighting for supported file types"
                ]
            ),
            HelpTopic(
                title: "Workspaces and Tabs",
                content: "PIP uses workspaces to organize multiple documents. Each workspace can contain multiple tabs.",
                details: [
                    "Create new workspace: File > New Workspace",
                    "Open documents in tabs within a workspace",
                    "Close tab: ⌘⇧W",
                    "Close window: ⌘W"
                ]
            )
        ]
    )

    static let editorPreferences = HelpCategory(
        title: "Editor Settings",
        icon: "doc.text",
        description: "Configure editor behavior and appearance",
        topics: [
            HelpTopic(
                title: "Line Numbers",
                content: "Display line numbers in the editor gutter for easy reference.",
                details: [
                    "Toggle: Preferences > Editor > Show Line Numbers",
                    "Keyboard shortcut: ⌘⇧L",
                    "Optional separator line between numbers and text"
                ]
            ),
            HelpTopic(
                title: "Line Wrapping",
                content: "Control how long lines are displayed in the editor.",
                details: [
                    "Enabled: Lines wrap to fit window width",
                    "Disabled: Lines extend horizontally with scrolling",
                    "Toggle: Preferences > Editor > Wrap Lines"
                ]
            ),
            HelpTopic(
                title: "Auto-Completion",
                content: "Get intelligent code completion suggestions as you type.",
                details: [
                    "Enable/disable: Preferences > Editor > Enable Auto-Completion",
                    "Trigger length: Set how many characters before suggestions appear (1-5)",
                    "Manual trigger: Press Esc or Opt+Esc",
                    "Language-specific: Bash commands, keywords, variables, and control structures",
                    "Template expansion: Insert full code templates for if, for, while, case statements"
                ]
            ),
            HelpTopic(
                title: "Syntax Coloring",
                content: "Enable syntax highlighting for supported file types.",
                details: [
                    "Toggle: Preferences > Editor > Enable Syntax Coloring",
                    "Automatic detection based on file extension or shebang",
                    "Color theme customizable in Appearance preferences"
                ]
            ),
            HelpTopic(
                title: "Undo History",
                content: "Configure how many undo/redo operations to remember.",
                details: [
                    "Range: 1-1000 operations",
                    "Default: 50 operations",
                    "Location: Preferences > Editor > Undo Levels",
                    "Higher values use more memory"
                ]
            ),
            HelpTopic(
                title: "Current Line Highlighting",
                content: "Highlight the line containing the cursor for better visibility.",
                details: [
                    "Enable: Preferences > Editor > Highlight Current Line",
                    "Color options: Light Gray, Light Blue, Light Yellow, Light Green, Light Pink",
                    "Helps track cursor position in large documents"
                ]
            ),
            HelpTopic(
                title: "Invisible Characters",
                content: "Show normally invisible characters like spaces, tabs, and line endings.",
                details: [
                    "Enable: Preferences > Editor > Show Invisible Characters",
                    "Types: Line endings, Tabs, Spaces, Whitespace, Control characters",
                    "Color options: Gray, Blue, Red, Green, Orange",
                    "Useful for debugging whitespace issues"
                ]
            ),
            HelpTopic(
                title: "Status Bar",
                content: "Display document statistics in the status bar.",
                details: [
                    "Character count: Real-time character counting",
                    "Word count: Real-time word counting",
                    "Toggle: Preferences > Editor > Show Character/Word Count"
                ]
            ),
            HelpTopic(
                title: "Script Execution",
                content: "Configure how scripts are executed.",
                details: [
                    "Verbose output: Enable detailed execution logs (bash -x, python -u)",
                    "Shows each command before execution",
                    "Toggle: Preferences > Editor > Verbose Script Output"
                ]
            )
        ]
    )

    static let appearancePreferences = HelpCategory(
        title: "Appearance Settings",
        icon: "paintbrush",
        description: "Customize the visual appearance of the editor",
        topics: [
            HelpTopic(
                title: "Color Themes",
                content: "Choose from various color schemes for the editor.",
                details: [
                    "Location: Preferences > Appearance > Color Scheme",
                    "Preview available before applying",
                    "Affects: Text color, background, line numbers, syntax highlighting"
                ]
            ),
            HelpTopic(
                title: "Cursor Style",
                content: "Select your preferred cursor appearance.",
                details: [
                    "Line: Thin vertical line (traditional)",
                    "Block: Full character block",
                    "Underline: Line under character",
                    "Blinking: Toggle cursor blinking on/off",
                    "Location: Preferences > Appearance"
                ]
            )
        ]
    )

    static let documentPreferences = HelpCategory(
        title: "Document Settings",
        icon: "doc.text",
        description: "Configure document formatting and font settings",
        topics: [
            HelpTopic(
                title: "Font Selection",
                content: "Choose the font family and size for your documents.",
                details: [
                    "Built-in fonts: Menlo, Monaco, SF Mono, Courier, and more",
                    "Custom fonts: Use 'Choose...' button for system font picker",
                    "Size range: 8-72 points",
                    "Preview available",
                    "Location: Preferences > Document"
                ]
            ),
            HelpTopic(
                title: "Indentation",
                content: "Control how tabs and indentation work.",
                details: [
                    "Tab width: 1-16 spaces",
                    "Insert spaces for tabs: Convert tab key to spaces",
                    "Useful for consistent formatting across editors",
                    "Location: Preferences > Document"
                ]
            )
        ]
    )

    static let advancedPreferences = HelpCategory(
        title: "Advanced Settings",
        icon: "gearshape",
        description: "Configure advanced features and automation",
        topics: [
            HelpTopic(
                title: "Text Snippets",
                content: "Create reusable text shortcuts that expand when typed.",
                details: [
                    "Define trigger text and expansion content",
                    "Automatically expand when trigger is typed",
                    "Manage: Preferences > Advanced > Manage Snippets",
                    "Great for boilerplate code, signatures, templates"
                ]
            ),
            HelpTopic(
                title: "Auto Save",
                content: "Automatically save documents at regular intervals.",
                details: [
                    "Enable: Preferences > Advanced > Enable Auto Save",
                    "Intervals: 30 seconds, 1, 2, 5, or 10 minutes",
                    "Only saves documents that have been saved before",
                    "Prevents data loss from crashes or power failures"
                ]
            ),
            HelpTopic(
                title: "Backup on Save",
                content: "Create backup copies before overwriting files.",
                details: [
                    "Enable: Preferences > Advanced > Create Backup on Save",
                    "Backup file created with .backup extension",
                    "Useful for tracking changes or recovering from mistakes"
                ]
            ),
            HelpTopic(
                title: "File Encoding",
                content: "Set the default character encoding for new documents.",
                details: [
                    "Options: UTF-8, UTF-16, ASCII, ISO Latin 1, Mac OS Roman",
                    "UTF-8 recommended for universal compatibility",
                    "Location: Preferences > Advanced > Default Encoding"
                ]
            ),
            HelpTopic(
                title: "Custom Directories",
                content: "Configure where logs and temporary files are stored.",
                details: [
                    "Log save location: Where script execution logs are saved",
                    "Temp script location: Where scripts are stored during execution",
                    "Default locations use system directories",
                    "Cleanup: Remove old temporary files and logs",
                    "Location: Preferences > Advanced > Custom Directories"
                ]
            )
        ]
    )

    static let scriptExecution = HelpCategory(
        title: "Script Execution",
        icon: "terminal",
        description: "Run and debug scripts directly from the editor",
        topics: [
            HelpTopic(
                title: "Running Scripts",
                content: "Execute scripts directly from PIP without leaving the editor.",
                details: [
                    "Supports: Bash, Python, Ruby, Node.js, Perl, PHP",
                    "Auto-detection: Based on shebang or file extension",
                    "Keyboard shortcut: ⌘R",
                    "Output displayed in integrated console"
                ]
            ),
            HelpTopic(
                title: "Shebang Support",
                content: "Use shebangs to specify script interpreters.",
                details: [
                    "Format: #!/path/to/interpreter",
                    "Examples: #!/bin/bash, #!/usr/bin/env python3",
                    "Quick insert: Use Insert > Shebang menu",
                    "Automatic completion based on detected interpreter"
                ]
            ),
            HelpTopic(
                title: "Execution Logs",
                content: "View and save script execution output.",
                details: [
                    "Real-time output in console pane",
                    "Verbose mode: Enable detailed execution traces",
                    "Save logs: Automatically saved to configured directory",
                    "Clear logs: Remove old log files to free space"
                ]
            )
        ]
    )

    static let keyboardShortcuts = HelpCategory(
        title: "Keyboard Shortcuts",
        icon: "keyboard",
        description: "Quick reference for keyboard shortcuts",
        topics: [
            HelpTopic(
                title: "File Operations",
                content: "Common file management shortcuts",
                details: [
                    "⌘N - New document",
                    "⌘O - Open document",
                    "⌘S - Save",
                    "⌘⇧S - Save As",
                    "⌘P - Print",
                    "⌘W - Close document",
                    "⌘⇧W - Close tab"
                ]
            ),
            HelpTopic(
                title: "Editing",
                content: "Text editing shortcuts",
                details: [
                    "⌘Z - Undo",
                    "⌘⇧Z - Redo",
                    "⌘X - Cut",
                    "⌘C - Copy",
                    "⌘V - Paste",
                    "⌘A - Select All"
                ]
            ),
            HelpTopic(
                title: "View",
                content: "View and navigation shortcuts",
                details: [
                    "⌘⇧L - Toggle Line Numbers",
                    "⌃⌘S - Toggle Sidebar",
                    "⌘+ - Increase Font Size",
                    "⌘- - Decrease Font Size",
                    "⌘M - Minimize Window"
                ]
            ),
            HelpTopic(
                title: "Completion",
                content: "Code completion shortcuts",
                details: [
                    "Esc - Trigger completion manually",
                    "Opt+Esc - Alternative completion trigger",
                    "↑↓ - Navigate suggestions",
                    "Enter - Accept suggestion",
                    "Esc - Dismiss suggestions"
                ]
            )
        ]
    )

    static let completionReference = HelpCategory(
        title: "Auto-Completion Reference",
        icon: "text.badge.checkmark",
        description: "Complete guide to all available completion items and templates",
        topics: [
            HelpTopic(
                title: "Control Flow Templates",
                content: "Insert complete control flow structures with proper syntax. Type the keyword and press Enter to expand the template.",
                details: [
                    "if - Conditional statement: if [ condition ]; then ... fi",
                    "for - Loop over items: for var in list; do ... done",
                    "while - Loop while condition true: while [ condition ]; do ... done",
                    "until - Loop until condition true: until [ condition ]; do ... done",
                    "case - Pattern matching: case $var in pattern) ... esac",
                    "function - Define function: function name { ... }",
                    "break - Exit current loop",
                    "continue - Skip to next loop iteration",
                    "return - Exit function with status code"
                ]
            ),
            HelpTopic(
                title: "Bash Built-in Commands",
                content: "Shell built-in commands that execute directly in the shell without spawning a process.",
                details: [
                    "echo - Print text to stdout",
                    "printf - Formatted print output",
                    "read - Read user input",
                    "cd - Change directory",
                    "pwd - Print working directory",
                    "export - Set environment variable",
                    "unset - Remove variable",
                    "declare/local - Declare variables with attributes",
                    "source - Execute script in current shell",
                    "eval - Evaluate and execute arguments",
                    "test/[/[[ - Conditional evaluation",
                    "alias/unalias - Create command shortcuts",
                    "set/shopt - Configure shell options",
                    "history - Command history",
                    "jobs/fg/bg - Job control",
                    "trap - Set signal handlers"
                ]
            ),
            HelpTopic(
                title: "File Operations",
                content: "Commands for file and directory manipulation.",
                details: [
                    "ls - List directory contents",
                    "cp - Copy files/directories",
                    "mv - Move/rename files",
                    "rm - Remove files/directories",
                    "mkdir - Create directories",
                    "touch - Create empty files or update timestamps",
                    "cat - Concatenate and display files",
                    "head/tail - Display start/end of files",
                    "wc - Count lines/words/characters",
                    "file - Determine file type",
                    "stat - Display file statistics",
                    "find - Search for files",
                    "ln - Create links (hard/symbolic)",
                    "chmod - Change file permissions",
                    "chown - Change file ownership"
                ]
            ),
            HelpTopic(
                title: "Text Processing",
                content: "Commands for searching, filtering, and transforming text.",
                details: [
                    "grep/egrep/fgrep - Search text patterns",
                    "sed - Stream editor for text transformation",
                    "awk - Pattern scanning and processing language",
                    "cut - Extract sections from lines",
                    "sort - Sort text lines",
                    "uniq - Report or filter duplicate lines",
                    "tr - Translate or delete characters",
                    "diff/patch - Compare and apply file differences",
                    "xargs - Build command lines from stdin",
                    "tee - Read stdin and write to stdout and files"
                ]
            ),
            HelpTopic(
                title: "Network Commands",
                content: "Tools for network operations and troubleshooting.",
                details: [
                    "curl - Transfer data from/to servers",
                    "wget - Download files from web",
                    "ssh - Secure shell remote login",
                    "scp - Secure file copy",
                    "rsync - Remote file synchronization",
                    "ping - Test network connectivity",
                    "traceroute - Trace packet route",
                    "netstat - Network statistics",
                    "dig/nslookup - DNS lookup",
                    "nc/netcat - Network connections and port scanning",
                    "lsof - List open files and network connections"
                ]
            ),
            HelpTopic(
                title: "Process Management",
                content: "Commands for monitoring and controlling processes.",
                details: [
                    "ps - Display process status",
                    "top/htop - Interactive process viewer",
                    "kill/killall - Terminate processes",
                    "pgrep/pkill - Find/kill processes by name",
                    "nice/renice - Set process priority",
                    "nohup - Run command immune to hangups",
                    "timeout - Run command with time limit",
                    "watch - Execute program periodically"
                ]
            ),
            HelpTopic(
                title: "Git Commands",
                content: "Version control operations with Git.",
                details: [
                    "git clone - Clone repository",
                    "git init - Initialize repository",
                    "git add - Stage files for commit",
                    "git commit - Commit staged changes",
                    "git push - Push commits to remote",
                    "git pull - Fetch and merge from remote",
                    "git status - Show working tree status",
                    "git log - Show commit history",
                    "git diff - Show changes",
                    "git branch - List/create/delete branches",
                    "git checkout - Switch branches or restore files",
                    "git merge - Merge branches",
                    "git stash - Temporarily save changes"
                ]
            ),
            HelpTopic(
                title: "macOS Specific Commands",
                content: "Commands unique to macOS or with macOS-specific behavior.",
                details: [
                    "open - Open files/apps/URLs",
                    "pbcopy/pbpaste - Clipboard operations",
                    "say - Text-to-speech",
                    "osascript - Execute AppleScript",
                    "defaults - Access user defaults system",
                    "plutil - Property list utility",
                    "diskutil - Disk management",
                    "launchctl - Launch daemon/agent control",
                    "mdfind - Spotlight search from command line",
                    "sw_vers - macOS version information",
                    "networksetup - Network configuration",
                    "caffeinate - Prevent system sleep"
                ]
            ),
            HelpTopic(
                title: "Archive & Compression",
                content: "Commands for creating and extracting archives.",
                details: [
                    "tar - Create/extract tar archives",
                    "  tar -czf archive.tar.gz files/ - Create gzipped tar",
                    "  tar -xzf archive.tar.gz - Extract gzipped tar",
                    "gzip/gunzip - Compress/decompress with gzip",
                    "bzip2/bunzip2 - Compress/decompress with bzip2",
                    "zip/unzip - Create/extract ZIP archives",
                    "xz/unxz - Compress/decompress with xz",
                    "7z - 7-Zip compression"
                ]
            ),
            HelpTopic(
                title: "Environment Variables",
                content: "Common shell and system environment variables available for completion.",
                details: [
                    "$HOME - User's home directory",
                    "$PATH - Executable search path",
                    "$USER - Current username",
                    "$SHELL - Current shell path",
                    "$PWD - Current directory",
                    "$OLDPWD - Previous directory",
                    "$EDITOR - Default text editor",
                    "$TMPDIR - Temporary directory",
                    "$0-$9 - Script/function arguments",
                    "$@ - All arguments as separate words",
                    "$# - Number of arguments",
                    "$? - Exit status of last command",
                    "$$ - Current process ID",
                    "$! - Process ID of last background command",
                    "$RANDOM - Random number",
                    "$SECONDS - Seconds since shell started"
                ]
            ),
            HelpTopic(
                title: "Common Command Flags",
                content: "Frequently used command-line flags available through completion.",
                details: [
                    "ls: -a (all), -l (long), -h (human-readable), -R (recursive), -t (sort by time)",
                    "grep: -i (case-insensitive), -r (recursive), -n (line numbers), -v (invert)",
                    "find: -name (by name), -type (f/d), -mtime (modified time), -exec (execute)",
                    "tar: -c (create), -x (extract), -v (verbose), -z (gzip), -f (file)",
                    "git: status, log, diff, add, commit, push, pull, branch, checkout, merge",
                    "-h/--help - Show help message",
                    "-v/--version - Show version",
                    "-q/--quiet - Suppress output",
                    "-f/--force - Force operation",
                    "-r/-R/--recursive - Process directories recursively"
                ]
            ),
            HelpTopic(
                title: "Development Tools",
                content: "Programming languages, build tools, and developer utilities.",
                details: [
                    "Languages: python, python3, ruby, node, perl, php, go, rust, java, swift",
                    "Package Managers: npm, pip, gem, cargo, brew, apt, yum",
                    "Build Tools: make, cmake, gcc, clang, ld",
                    "Containers: docker, kubectl, helm",
                    "DevOps: terraform, ansible, vagrant",
                    "Debuggers: gdb, lldb, valgrind, strace",
                    "Version Control: git, svn, hg",
                    "Code Quality: eslint, pylint, rubocop",
                    "Data Tools: jq, yq, xmllint"
                ]
            )
        ]
    )

    // Category collections
    static let basicsCategories = [gettingStarted, keyboardShortcuts]
    static let preferencesCategories = [editorPreferences, appearancePreferences, documentPreferences, advancedPreferences]
    static let featuresCategories = [scriptExecution, completionReference]
    static let allCategories = basicsCategories + preferencesCategories + featuresCategories
}

#Preview {
    HelpWindow()
        .frame(width: 900, height: 700)
}
