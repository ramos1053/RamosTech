import Foundation

/// Centralized storage for bash/shell completion data
final class CompletionDatabase {
    static let shared = CompletionDatabase()

    private init() {}

    // MARK: - Bash Commands

    /// Common bash/shell built-in commands and control flow
    let builtinCommands: Set<String> = [
        // Control flow
        "if", "then", "else", "elif", "fi",
        "for", "while", "do", "done", "until",
        "case", "esac", "select",
        "function", "return", "break", "continue",

        // Built-ins
        "echo", "printf", "read", "test", "[", "[[",
        "cd", "pwd", "pushd", "popd", "dirs",
        "export", "unset", "set", "declare", "local", "readonly",
        "source", ".", "eval", "exec", "exit",
        "alias", "unalias", "type", "command",
        "wait", "sleep", "time", "trap",
        "shift", "getopts", "let", "true", "false",
        "history", "fc", "jobs", "fg", "bg", "disown",
        "ulimit", "umask", "enable", "help", "builtin",
        "caller", "compgen", "complete", "shopt"
    ]

    /// Common Unix/Linux command-line utilities
    let systemCommands: Set<String> = [
        // File operations
        "ls", "cp", "mv", "rm", "mkdir", "rmdir",
        "touch", "cat", "more", "less", "head", "tail",
        "wc", "file", "stat", "basename", "dirname",
        "ln", "link", "unlink", "readlink", "realpath",
        "dd", "df", "du", "mount", "umount",

        // Text processing
        "grep", "egrep", "fgrep", "sed", "awk",
        "cut", "paste", "sort", "uniq", "tr",
        "join", "comm", "diff", "patch", "cmp",
        "tee", "xargs", "expand", "unexpand",
        "fmt", "fold", "nl", "od", "xxd", "hexdump",
        "strings", "iconv", "recode",

        // Permissions & ownership
        "chmod", "chown", "chgrp", "chattr", "lsattr",
        "setfacl", "getfacl", "chcon", "getenforce", "setenforce",

        // Archiving & compression
        "tar", "gzip", "gunzip", "bzip2", "bunzip2",
        "zip", "unzip", "compress", "uncompress",
        "xz", "unxz", "7z", "rar", "unrar",
        "zcat", "bzcat", "xzcat",

        // Network
        "curl", "wget", "ssh", "scp", "sftp", "ftp", "rsync",
        "ping", "traceroute", "netstat", "ifconfig", "ip",
        "nc", "netcat", "telnet", "nslookup", "dig", "host",
        "whois", "route", "arp", "hostname", "tcpdump",
        "ss", "lsof", "nmap", "iptables", "ufw",

        // Process management
        "ps", "top", "htop", "kill", "killall", "pkill",
        "pgrep", "pidof", "nice", "renice", "nohup",
        "bg", "fg", "jobs", "disown",
        "watch", "timeout", "pstree", "fuser",

        // Package management (common across distros)
        "apt", "apt-get", "dpkg", "yum", "dnf", "rpm",
        "brew", "port", "pkg", "pacman", "zypper",
        "snap", "flatpak", "pip", "npm", "gem", "cargo",

        // System info
        "uname", "whoami", "id", "groups", "who", "w", "last",
        "uptime", "date", "cal", "locale", "timedatectl",
        "hostnamectl", "free", "vmstat", "iostat", "sar",
        "lscpu", "lspci", "lsusb", "lsblk", "blkid",
        "dmesg", "journalctl", "systemctl", "service",

        // Search & find
        "find", "locate", "updatedb", "which", "whereis",
        "apropos", "man", "info", "whatis",

        // Misc utilities
        "clear", "reset", "stty", "tput", "tty",
        "yes", "seq", "bc", "dc", "expr",
        "factor", "numfmt", "shuf", "split", "csplit",
        "env", "printenv", "sudo", "su", "runuser",
        "screen", "tmux", "script", "at", "cron", "crontab",

        // Build tools & compilers
        "make", "cmake", "autoconf", "automake", "ninja",
        "gcc", "g++", "clang", "clang++", "cc", "c++",
        "ld", "as", "ar", "ranlib", "strip", "nm", "objdump",
        "gdb", "lldb", "valgrind", "strace", "ltrace",

        // Version control
        "git", "svn", "hg", "mercurial", "cvs", "bzr",

        // Editors
        "vim", "vi", "nvim", "nano", "emacs", "ed", "joe", "pico",

        // Scripting languages
        "awk", "sed", "perl", "python", "python2", "python3",
        "ruby", "irb", "node", "npm", "npx", "yarn", "pnpm",
        "php", "bash", "sh", "zsh", "fish", "ksh", "tcsh", "dash",
        "lua", "go", "rust", "cargo", "rustc", "java", "javac",
        "scala", "kotlin", "swift", "swiftc",

        // macOS specific
        "open", "pbcopy", "pbpaste", "say", "osascript",
        "caffeinate", "pmset", "networksetup", "scutil",
        "diskutil", "hdiutil", "airport", "sw_vers",
        "dscl", "dscacheutil", "launchctl", "defaults",
        "plutil", "plistbuddy", "codesign", "spctl",
        "mdls", "mdfind", "mdutil", "spotlight",
        "softwareupdate", "installer", "pkgutil",
        "xcode-select", "xcrun", "xcodebuild", "simctl",

        // Development tools
        "docker", "kubectl", "helm", "terraform", "ansible",
        "vagrant", "packer", "consul", "vault",
        "jq", "yq", "xmllint", "xmlstarlet",
        "base64", "uuencode", "uudecode",
        "openssl", "ssh-keygen", "gpg", "gpg2",
        "htop", "btop", "glances", "iotop", "nload",
        "ack", "ag", "rg", "fd", "bat", "exa", "lsd",
        "tree", "ncdu", "duf", "dust",
        "jless", "fx", "gron",
        "httpie", "http", "wrk", "ab", "siege",
        "nmap", "masscan", "nikto", "sqlmap",
        "ffmpeg", "imagemagick", "convert", "gifsicle",
        "youtube-dl", "yt-dlp", "streamlink",
        "pandoc", "asciidoctor", "rst2html",
        "prettier", "eslint", "pylint", "rubocop", "gofmt"
    ]

    /// All commands combined
    var allCommands: Set<String> {
        builtinCommands.union(systemCommands)
    }

    // MARK: - Flags

    /// Common command flags (command-agnostic)
    let commonFlags: Set<String> = [
        // Help & info
        "-h", "--help", "-?",
        "-v", "--verbose", "-q", "--quiet", "--silent",
        "-V", "--version",
        "-d", "--debug",

        // Common options
        "-f", "--force", "--no-clobber",
        "-i", "--interactive",
        "-n", "--dry-run", "--no-act",
        "-r", "-R", "--recursive",
        "-a", "--all",
        "-l", "--long",
        "-t", "--time", "--sort-by-time",
        "-u", "--update",
        "-y", "--yes", "--assume-yes",
        "-c", "--config",
        "-o", "--output",

        // Format
        "--color", "--colour", "--no-color",
        "--format",
        "--json", "--xml", "--yaml",

        // Performance
        "-j", "--jobs", "--parallel"
    ]

    /// Command-specific flags
    let commandFlags: [String: [CompletionItem]] = [
        "ls": [
            CompletionItem(text: "-a", detailText: "Show hidden files", kind: .flag, score: 90),
            CompletionItem(text: "-l", detailText: "Long format", kind: .flag, score: 95),
            CompletionItem(text: "-h", detailText: "Human-readable sizes", kind: .flag, score: 85),
            CompletionItem(text: "-R", detailText: "Recursive", kind: .flag, score: 70),
            CompletionItem(text: "-t", detailText: "Sort by time", kind: .flag, score: 65),
            CompletionItem(text: "-S", detailText: "Sort by size", kind: .flag, score: 60),
            CompletionItem(text: "-r", detailText: "Reverse order", kind: .flag, score: 55),
            CompletionItem(text: "--color", detailText: "Colorize output", kind: .flag, score: 50)
        ],
        "grep": [
            CompletionItem(text: "-i", detailText: "Case insensitive", kind: .flag, score: 95),
            CompletionItem(text: "-r", detailText: "Recursive", kind: .flag, score: 90),
            CompletionItem(text: "-n", detailText: "Show line numbers", kind: .flag, score: 85),
            CompletionItem(text: "-v", detailText: "Invert match", kind: .flag, score: 75),
            CompletionItem(text: "-E", detailText: "Extended regexp", kind: .flag, score: 70),
            CompletionItem(text: "-F", detailText: "Fixed strings", kind: .flag, score: 65),
            CompletionItem(text: "-w", detailText: "Match whole words", kind: .flag, score: 60),
            CompletionItem(text: "-l", detailText: "Files with matches", kind: .flag, score: 55),
            CompletionItem(text: "-c", detailText: "Count matches", kind: .flag, score: 50),
            CompletionItem(text: "-A", detailText: "Lines after match", kind: .flag, score: 45),
            CompletionItem(text: "-B", detailText: "Lines before match", kind: .flag, score: 45),
            CompletionItem(text: "-C", detailText: "Context lines", kind: .flag, score: 45)
        ],
        "find": [
            CompletionItem(text: "-name", detailText: "Match by name", kind: .flag, score: 95),
            CompletionItem(text: "-type", detailText: "Match by type (f/d)", kind: .flag, score: 90),
            CompletionItem(text: "-mtime", detailText: "Modified time", kind: .flag, score: 75),
            CompletionItem(text: "-size", detailText: "File size", kind: .flag, score: 70),
            CompletionItem(text: "-exec", detailText: "Execute command", kind: .flag, score: 85),
            CompletionItem(text: "-print", detailText: "Print results", kind: .flag, score: 60),
            CompletionItem(text: "-delete", detailText: "Delete matches", kind: .flag, score: 55),
            CompletionItem(text: "-maxdepth", detailText: "Max directory depth", kind: .flag, score: 65),
            CompletionItem(text: "-mindepth", detailText: "Min directory depth", kind: .flag, score: 60)
        ],
        "tar": [
            CompletionItem(text: "-c", detailText: "Create archive", kind: .flag, score: 95),
            CompletionItem(text: "-x", detailText: "Extract archive", kind: .flag, score: 95),
            CompletionItem(text: "-t", detailText: "List contents", kind: .flag, score: 70),
            CompletionItem(text: "-v", detailText: "Verbose", kind: .flag, score: 85),
            CompletionItem(text: "-f", detailText: "File name", kind: .flag, score: 90),
            CompletionItem(text: "-z", detailText: "Gzip compression", kind: .flag, score: 80),
            CompletionItem(text: "-j", detailText: "Bzip2 compression", kind: .flag, score: 70),
            CompletionItem(text: "-J", detailText: "Xz compression", kind: .flag, score: 65)
        ],
        "git": [
            CompletionItem(text: "clone", detailText: "Clone repository", kind: .flag, score: 90),
            CompletionItem(text: "init", detailText: "Initialize repository", kind: .flag, score: 85),
            CompletionItem(text: "add", detailText: "Add files to staging", kind: .flag, score: 95),
            CompletionItem(text: "commit", detailText: "Commit changes", kind: .flag, score: 95),
            CompletionItem(text: "push", detailText: "Push to remote", kind: .flag, score: 90),
            CompletionItem(text: "pull", detailText: "Pull from remote", kind: .flag, score: 90),
            CompletionItem(text: "status", detailText: "Show status", kind: .flag, score: 95),
            CompletionItem(text: "log", detailText: "Show commit history", kind: .flag, score: 80),
            CompletionItem(text: "diff", detailText: "Show differences", kind: .flag, score: 85),
            CompletionItem(text: "branch", detailText: "List/create branches", kind: .flag, score: 85),
            CompletionItem(text: "checkout", detailText: "Switch branches", kind: .flag, score: 85),
            CompletionItem(text: "merge", detailText: "Merge branches", kind: .flag, score: 75),
            CompletionItem(text: "fetch", detailText: "Fetch from remote", kind: .flag, score: 70),
            CompletionItem(text: "rebase", detailText: "Rebase commits", kind: .flag, score: 65),
            CompletionItem(text: "reset", detailText: "Reset changes", kind: .flag, score: 70),
            CompletionItem(text: "stash", detailText: "Stash changes", kind: .flag, score: 75),
            CompletionItem(text: "remote", detailText: "Manage remotes", kind: .flag, score: 70),
            CompletionItem(text: "tag", detailText: "Manage tags", kind: .flag, score: 65)
        ]
    ]

    // MARK: - Environment Variables

    /// Common environment variables
    let variables: Set<String> = [
        // Common shell variables
        "$HOME", "$PATH", "$USER", "$SHELL", "$TERM",
        "$PWD", "$OLDPWD", "$LANG", "$LC_ALL",
        "$EDITOR", "$VISUAL", "$PAGER",
        "$TMPDIR", "$TMP", "$TEMP",
        "$HOSTNAME", "$LOGNAME",
        "$UID", "$EUID", "$GID", "$GROUPS",

        // Special bash variables
        "$0", "$1", "$2", "$3", "$4", "$5", "$6", "$7", "$8", "$9",
        "$@", "$*", "$#", "$?", "$$", "$!", "$-",
        "$BASH", "$BASH_VERSION", "$BASH_SOURCE",
        "$LINENO", "$FUNCNAME", "$SECONDS", "$RANDOM",
        "$REPLY", "$IFS", "$PS1", "$PS2", "$PS3", "$PS4",

        // Development
        "$CC", "$CXX", "$CFLAGS", "$CXXFLAGS",
        "$LDFLAGS", "$LIBRARY_PATH", "$LD_LIBRARY_PATH",
        "$PKG_CONFIG_PATH", "$MANPATH", "$INFOPATH",
        "$JAVA_HOME", "$PYTHON_PATH", "$GOPATH", "$CARGO_HOME",
        "$NODE_PATH", "$GEM_HOME", "$GEM_PATH"
    ]

    // MARK: - Helper Methods

    /// Detect language from shebang or context
    func detectLanguage(from shebang: String?) -> Language {
        guard let shebang = shebang?.lowercased() else { return .bash }

        if shebang.contains("python") { return .python }
        if shebang.contains("ruby") { return .ruby }
        if shebang.contains("node") || shebang.contains("javascript") { return .javascript }
        if shebang.contains("php") { return .php }
        if shebang.contains("perl") { return .perl }
        if shebang.contains("bash") || shebang.contains("/sh") || shebang.contains("zsh") { return .bash }

        return .bash  // Default to bash
    }

    /// Get appropriate keywords based on language
    private func keywordsForLanguage(_ language: Language) -> [String: String] {
        switch language {
        case .bash: return controlFlowKeywords
        case .python: return pythonKeywords
        case .ruby: return rubyKeywords
        case .javascript: return javascriptKeywords
        case .php: return phpKeywords
        case .perl: return perlKeywords
        }
    }

    /// Get completion items for commands and keywords based on language
    func commandCompletions(matching prefix: String, language: Language = .bash) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()
        let keywords = keywordsForLanguage(language)

        // Check keywords first for the detected language
        let keywordMatches = keywords.filter { $0.key.lowercased().hasPrefix(lowercasePrefix) }
        var items: [CompletionItem] = keywordMatches.map { keyword, template in
            CompletionItem(
                text: template,
                displayText: keyword,
                detailText: "\(language.rawValue.capitalized) keyword",
                kind: .keyword,
                score: 100
            )
        }

        // For bash, also include commands
        if language == .bash {
            let matching = allCommands.filter { $0.lowercased().hasPrefix(lowercasePrefix) }

            let commandItems: [CompletionItem] = matching.map { command in
                let score: Int
                let kind: CompletionKind

                if builtinCommands.contains(command) {
                    score = 80
                    kind = .command

                    return CompletionItem(
                        text: command,
                        detailText: "Bash builtin",
                        kind: kind,
                        score: score
                    )
                } else {
                    score = 60
                    kind = .command

                    return CompletionItem(
                        text: command,
                        detailText: "System command",
                        kind: kind,
                        score: score
                    )
                }
            }

            items.append(contentsOf: commandItems)
        }

        let sorted = items.sorted { $0.score > $1.score || ($0.score == $1.score && $0.displayText < $1.displayText) }

        print("DEBUG: commandCompletions for prefix '\(prefix)' in \(language.rawValue) returned \(sorted.count) items:")
        for (index, item) in sorted.prefix(5).enumerated() {
            print("  \(index): \(item.displayText) (score: \(item.score), kind: \(item.kind))")
        }

        return sorted
    }

    /// Supported languages
    enum Language: String {
        case bash = "bash"
        case python = "python"
        case ruby = "ruby"
        case javascript = "javascript"
        case php = "php"
        case perl = "perl"
    }

    /// Control flow keywords with contextual hints (Bash/Shell)
    private let controlFlowKeywords: [String: String] = [
        "if": "if [ condition ]; then\n    \nfi",
        "then": "then\n    ",
        "else": "else\n    ",
        "elif": "elif [ condition ]; then\n    ",
        "fi": "fi",
        "for": "for var in list; do\n    \ndone",
        "while": "while [ condition ]; do\n    \ndone",
        "do": "do\n    ",
        "done": "done",
        "until": "until [ condition ]; do\n    \ndone",
        "case": "case $var in\n    pattern)\n        ;;\nesac",
        "esac": "esac",
        "function": "function name() {\n    \n}",
        "return": "return ",
        "break": "break",
        "continue": "continue"
    ]

    /// Python keywords and templates
    private let pythonKeywords: [String: String] = [
        "if": "if condition:\n    ",
        "elif": "elif condition:\n    ",
        "else": "else:\n    ",
        "for": "for item in iterable:\n    ",
        "while": "while condition:\n    ",
        "def": "def function_name():\n    ",
        "class": "class ClassName:\n    def __init__(self):\n        ",
        "try": "try:\n    \nexcept Exception as e:\n    ",
        "except": "except Exception as e:\n    ",
        "finally": "finally:\n    ",
        "with": "with open('file') as f:\n    ",
        "import": "import ",
        "from": "from module import ",
        "return": "return ",
        "yield": "yield ",
        "lambda": "lambda x: ",
        "pass": "pass",
        "break": "break",
        "continue": "continue",
        "raise": "raise ",
        "assert": "assert "
    ]

    /// Ruby keywords and templates
    private let rubyKeywords: [String: String] = [
        "if": "if condition\n  \nend",
        "elsif": "elsif condition\n  ",
        "else": "else\n  ",
        "unless": "unless condition\n  \nend",
        "case": "case variable\nwhen value\n  \nend",
        "when": "when value\n  ",
        "while": "while condition\n  \nend",
        "until": "until condition\n  \nend",
        "for": "for item in collection\n  \nend",
        "def": "def method_name\n  \nend",
        "class": "class ClassName\n  def initialize\n    \n  end\nend",
        "module": "module ModuleName\n  \nend",
        "begin": "begin\n  \nrescue => e\n  \nend",
        "rescue": "rescue => e\n  ",
        "ensure": "ensure\n  ",
        "do": "do |item|\n  \nend",
        "end": "end",
        "return": "return ",
        "yield": "yield ",
        "break": "break",
        "next": "next",
        "redo": "redo"
    ]

    /// JavaScript/Node.js keywords and templates
    private let javascriptKeywords: [String: String] = [
        "if": "if (condition) {\n  \n}",
        "else": "else {\n  \n}",
        "for": "for (let i = 0; i < length; i++) {\n  \n}",
        "while": "while (condition) {\n  \n}",
        "do": "do {\n  \n} while (condition);",
        "switch": "switch (value) {\n  case option:\n    break;\n  default:\n    \n}",
        "case": "case option:\n  \n  break;",
        "function": "function name() {\n  \n}",
        "const": "const name = ",
        "let": "let name = ",
        "var": "var name = ",
        "try": "try {\n  \n} catch (error) {\n  \n}",
        "catch": "catch (error) {\n  \n}",
        "finally": "finally {\n  \n}",
        "return": "return ",
        "break": "break;",
        "continue": "continue;",
        "throw": "throw new Error('');",
        "async": "async function name() {\n  \n}",
        "await": "await ",
        "class": "class ClassName {\n  constructor() {\n    \n  }\n}",
        "import": "import { } from '';",
        "export": "export ",
        "default": "default "
    ]

    /// PHP keywords and templates
    private let phpKeywords: [String: String] = [
        "if": "if (condition) {\n  \n}",
        "elseif": "elseif (condition) {\n  \n}",
        "else": "else {\n  \n}",
        "for": "for ($i = 0; $i < count; $i++) {\n  \n}",
        "foreach": "foreach ($array as $item) {\n  \n}",
        "while": "while (condition) {\n  \n}",
        "do": "do {\n  \n} while (condition);",
        "switch": "switch ($var) {\n  case value:\n    break;\n  default:\n    \n}",
        "case": "case value:\n  \n  break;",
        "function": "function name() {\n  \n}",
        "class": "class ClassName {\n  public function __construct() {\n    \n  }\n}",
        "try": "try {\n  \n} catch (Exception $e) {\n  \n}",
        "catch": "catch (Exception $e) {\n  \n}",
        "finally": "finally {\n  \n}",
        "return": "return ",
        "break": "break;",
        "continue": "continue;",
        "throw": "throw new Exception('');",
        "namespace": "namespace Name;",
        "use": "use ",
        "require": "require '';",
        "include": "include '';"
    ]

    /// Perl keywords and templates
    private let perlKeywords: [String: String] = [
        "if": "if (condition) {\n  \n}",
        "elsif": "elsif (condition) {\n  \n}",
        "else": "else {\n  \n}",
        "unless": "unless (condition) {\n  \n}",
        "for": "for (my $i = 0; $i < $count; $i++) {\n  \n}",
        "foreach": "foreach my $item (@array) {\n  \n}",
        "while": "while (condition) {\n  \n}",
        "until": "until (condition) {\n  \n}",
        "do": "do {\n  \n} while (condition);",
        "sub": "sub name {\n  my ($arg) = @_;\n  \n}",
        "my": "my $var = ",
        "our": "our $var = ",
        "local": "local $var = ",
        "return": "return ",
        "last": "last;",
        "next": "next;",
        "redo": "redo;",
        "package": "package Name;",
        "use": "use strict;\nuse warnings;",
        "require": "require "
    ]

    /// Get completion items for flags
    func flagCompletions(matching prefix: String, for command: String?) -> [CompletionItem] {
        var results: [CompletionItem] = []

        // Check command-specific flags first
        if let command = command, let specificFlags = commandFlags[command] {
            results.append(contentsOf: specificFlags.filter { $0.text.hasPrefix(prefix) })
        }

        // Add common flags
        let lowercasePrefix = prefix.lowercased()
        let matchingCommon = commonFlags.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
        results.append(contentsOf: matchingCommon.map { flag in
            CompletionItem(text: flag, detailText: "Common flag", kind: .flag, score: 40)
        })

        // Remove duplicates and sort
        var seen = Set<String>()
        return results.filter { item in
            if seen.contains(item.text) {
                return false
            }
            seen.insert(item.text)
            return true
        }.sorted { $0.score > $1.score || ($0.score == $1.score && $0.text < $1.text) }
    }

    /// Get completion items for variables
    func variableCompletions(matching prefix: String) -> [CompletionItem] {
        let lowercasePrefix = prefix.lowercased()
        let matching = variables.filter { $0.lowercased().hasPrefix(lowercasePrefix) }

        return matching.map { variable in
            CompletionItem(
                text: variable,
                detailText: "Environment variable",
                kind: .variable,
                score: 70
            )
        }.sorted { $0.text < $1.text }
    }
}
