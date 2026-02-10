import Foundation
import AppKit

/// Incremental syntax highlighter with line-based tokenization
@MainActor
final class SyntaxHighlighter: ObservableObject {

    // MARK: - Types

    enum TokenType {
        case keyword
        case string
        case comment
        case number
        case identifier
        case operator_
        case punctuation
        case whitespace

        func color(for theme: EditorTheme) -> NSColor {
            switch self {
            case .keyword: return theme.keywordColor.nsColor
            case .string: return theme.stringColor.nsColor
            case .comment: return theme.commentColor.nsColor
            case .number: return theme.numberColor.nsColor
            case .identifier: return theme.textColor.nsColor
            case .operator_: return theme.operatorColor.nsColor
            case .punctuation: return theme.textColor.nsColor
            case .whitespace: return NSColor.clear
            }
        }
    }

    struct Token {
        let type: TokenType
        let range: Range<Int>
        let text: String
    }

    enum Language: String, CaseIterable {
        case bash
        case python
        case swift
        case javascript
        case typescript
        case html
        case css
        case json
        case xml
        case yaml
        case markdown
        case ruby
        case perl
        case php
        case java
        case c
        case cpp
        case objectiveC
        case go
        case rust
        case sql
        case shell
        case plainText

        var displayName: String {
            switch self {
            case .bash: return "Bash"
            case .python: return "Python"
            case .swift: return "Swift"
            case .javascript: return "JavaScript"
            case .typescript: return "TypeScript"
            case .html: return "HTML"
            case .css: return "CSS"
            case .json: return "JSON"
            case .xml: return "XML"
            case .yaml: return "YAML"
            case .markdown: return "Markdown"
            case .ruby: return "Ruby"
            case .perl: return "Perl"
            case .php: return "PHP"
            case .java: return "Java"
            case .c: return "C"
            case .cpp: return "C++"
            case .objectiveC: return "Objective-C"
            case .go: return "Go"
            case .rust: return "Rust"
            case .sql: return "SQL"
            case .shell: return "Shell"
            case .plainText: return "Plain Text"
            }
        }

        var keywords: Set<String> {
            switch self {
            case .bash, .shell:
                return ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
                        "do", "done", "in", "function", "return", "local", "export", "source",
                        "select", "until", "declare", "typeset", "readonly", "unset", "shift"]

            case .python:
                return ["def", "class", "if", "elif", "else", "for", "while", "return",
                        "import", "from", "as", "try", "except", "finally", "with", "pass",
                        "break", "continue", "lambda", "yield", "async", "await", "raise",
                        "True", "False", "None", "and", "or", "not", "is", "in", "global", "nonlocal"]

            case .swift:
                return ["func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                        "if", "else", "guard", "switch", "case", "for", "while", "return",
                        "import", "public", "private", "internal", "fileprivate", "static",
                        "mutating", "async", "await", "throw", "throws", "try", "catch",
                        "self", "Self", "super", "nil", "true", "false", "where", "associatedtype",
                        "typealias", "init", "deinit", "subscript", "operator", "precedencegroup",
                        "inout", "final", "open", "lazy", "weak", "unowned", "willSet", "didSet"]

            case .javascript, .typescript:
                return ["function", "var", "let", "const", "if", "else", "for", "while",
                        "return", "class", "extends", "import", "export", "from", "async",
                        "await", "try", "catch", "finally", "throw", "new", "this", "super",
                        "true", "false", "null", "undefined", "typeof", "instanceof", "delete",
                        "void", "yield", "static", "get", "set", "of", "in", "break", "continue",
                        "switch", "case", "default", "interface", "type", "enum", "namespace"]

            case .html:
                return ["html", "head", "body", "div", "span", "a", "p", "h1", "h2", "h3", "h4",
                        "h5", "h6", "img", "ul", "ol", "li", "table", "tr", "td", "th", "form",
                        "input", "button", "select", "option", "textarea", "label", "script",
                        "style", "link", "meta", "title", "header", "footer", "nav", "section",
                        "article", "aside", "main", "figure", "figcaption", "video", "audio"]

            case .css:
                return ["color", "background", "font", "margin", "padding", "border", "display",
                        "position", "top", "left", "right", "bottom", "width", "height", "flex",
                        "grid", "transform", "transition", "animation", "opacity", "z-index",
                        "important", "inherit", "initial", "unset", "none", "auto", "solid"]

            case .json:
                return ["true", "false", "null"]

            case .xml:
                return []

            case .yaml:
                return ["true", "false", "null", "yes", "no", "on", "off"]

            case .markdown:
                return []

            case .ruby:
                return ["def", "end", "class", "module", "if", "else", "elsif", "unless",
                        "case", "when", "while", "until", "for", "do", "begin", "rescue",
                        "ensure", "raise", "return", "yield", "break", "next", "redo", "retry",
                        "self", "super", "nil", "true", "false", "and", "or", "not", "in",
                        "then", "attr_reader", "attr_writer", "attr_accessor", "private", "public", "protected"]

            case .perl:
                return ["sub", "my", "local", "our", "if", "else", "elsif", "unless", "while",
                        "until", "for", "foreach", "do", "return", "last", "next", "redo",
                        "use", "require", "package", "BEGIN", "END", "print", "say", "die", "warn"]

            case .php:
                return ["function", "class", "interface", "trait", "extends", "implements",
                        "public", "private", "protected", "static", "final", "abstract",
                        "if", "else", "elseif", "switch", "case", "default", "while", "do",
                        "for", "foreach", "as", "return", "break", "continue", "throw", "try",
                        "catch", "finally", "new", "clone", "instanceof", "use", "namespace",
                        "true", "false", "null", "echo", "print", "include", "require", "global"]

            case .java:
                return ["class", "interface", "enum", "extends", "implements", "public",
                        "private", "protected", "static", "final", "abstract", "synchronized",
                        "volatile", "transient", "native", "if", "else", "switch", "case",
                        "default", "while", "do", "for", "break", "continue", "return",
                        "throw", "throws", "try", "catch", "finally", "new", "instanceof",
                        "this", "super", "void", "null", "true", "false", "import", "package"]

            case .c:
                return ["auto", "break", "case", "char", "const", "continue", "default", "do",
                        "double", "else", "enum", "extern", "float", "for", "goto", "if", "int",
                        "long", "register", "return", "short", "signed", "sizeof", "static",
                        "struct", "switch", "typedef", "union", "unsigned", "void", "volatile",
                        "while", "inline", "restrict", "_Bool", "_Complex", "_Imaginary"]

            case .cpp:
                return ["auto", "break", "case", "char", "const", "continue", "default", "do",
                        "double", "else", "enum", "extern", "float", "for", "goto", "if", "int",
                        "long", "register", "return", "short", "signed", "sizeof", "static",
                        "struct", "switch", "typedef", "union", "unsigned", "void", "volatile",
                        "while", "class", "public", "private", "protected", "virtual", "friend",
                        "inline", "namespace", "new", "delete", "this", "template", "typename",
                        "try", "catch", "throw", "const_cast", "static_cast", "dynamic_cast",
                        "reinterpret_cast", "nullptr", "constexpr", "noexcept", "override", "final"]

            case .objectiveC:
                return ["auto", "break", "case", "char", "const", "continue", "default", "do",
                        "double", "else", "enum", "extern", "float", "for", "goto", "if", "int",
                        "long", "register", "return", "short", "signed", "sizeof", "static",
                        "struct", "switch", "typedef", "union", "unsigned", "void", "volatile",
                        "while", "@interface", "@implementation", "@end", "@property", "@synthesize",
                        "@protocol", "@optional", "@required", "@class", "@selector", "@encode",
                        "self", "super", "nil", "Nil", "YES", "NO", "id", "instancetype"]

            case .go:
                return ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                        "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                        "map", "package", "range", "return", "select", "struct", "switch", "type",
                        "var", "true", "false", "nil", "iota", "append", "cap", "close", "complex",
                        "copy", "delete", "imag", "len", "make", "new", "panic", "print", "println", "real", "recover"]

            case .rust:
                return ["as", "break", "const", "continue", "crate", "else", "enum", "extern",
                        "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
                        "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct",
                        "super", "trait", "true", "type", "unsafe", "use", "where", "while",
                        "async", "await", "dyn", "abstract", "become", "box", "do", "final",
                        "macro", "override", "priv", "typeof", "unsized", "virtual", "yield"]

            case .sql:
                return ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN",
                        "IS", "NULL", "ORDER", "BY", "ASC", "DESC", "LIMIT", "OFFSET", "GROUP",
                        "HAVING", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL", "ON", "AS",
                        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE",
                        "INDEX", "VIEW", "DROP", "ALTER", "ADD", "PRIMARY", "KEY", "FOREIGN",
                        "REFERENCES", "UNIQUE", "DEFAULT", "CHECK", "CONSTRAINT", "CASCADE",
                        "UNION", "ALL", "DISTINCT", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END"]

            case .plainText:
                return []
            }
        }

        static func detect(from fileExtension: String) -> Language {
            switch fileExtension.lowercased() {
            case "sh", "bash": return .bash
            case "zsh": return .shell
            case "py", "pyw": return .python
            case "swift": return .swift
            case "js", "jsx", "mjs": return .javascript
            case "ts", "tsx": return .typescript
            case "html", "htm", "xhtml": return .html
            case "css", "scss", "sass", "less": return .css
            case "json": return .json
            case "xml", "xsl", "xslt", "svg", "plist": return .xml
            case "yml", "yaml": return .yaml
            case "md", "markdown": return .markdown
            case "rb", "rake", "gemspec": return .ruby
            case "pl", "pm": return .perl
            case "php", "phtml": return .php
            case "java": return .java
            case "c", "h": return .c
            case "cpp", "cc", "cxx", "hpp", "hxx", "hh": return .cpp
            case "m", "mm": return .objectiveC
            case "go": return .go
            case "rs": return .rust
            case "sql": return .sql
            default: return .plainText
            }
        }
    }

    // MARK: - Properties

    @Published private(set) var tokens: [Int: [Token]] = [:] // Line number -> tokens
    private var language: Language = .plainText
    private var invalidatedLines: Set<Int> = []
    private var debounceTask: Task<Void, Never>?

    // MARK: - Initialization

    nonisolated init() {
        // Empty init for creating instances in nonisolated contexts
    }

    // MARK: - Configuration

    nonisolated func setLanguage(_ language: Language) {
        Task { @MainActor in
            self.language = language
            invalidateAll()
        }
    }

    // MARK: - Invalidation

    func invalidateLine(_ line: Int) {
        invalidatedLines.insert(line)
        scheduleUpdate()
    }

    func invalidateRange(_ range: Range<Int>) {
        for line in range {
            invalidatedLines.insert(line)
        }
        scheduleUpdate()
    }

    func invalidateAll() {
        tokens.removeAll()
        invalidatedLines.removeAll()
    }

    private func scheduleUpdate() {
        debounceTask?.cancel()

        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce

            guard !Task.isCancelled else { return }
            await processInvalidatedLines()
        }
    }

    // MARK: - Tokenization

    private func processInvalidatedLines() async {
        let linesToProcess = invalidatedLines
        invalidatedLines.removeAll()

        for _ in linesToProcess {
            // Process line tokenization
            // This would typically be done in the background
            // For now, we'll keep it simple
        }
    }

    nonisolated func tokenize(text: String, language: Language) -> [Token] {
        var tokens: [Token] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            // Skip whitespace
            if text[currentIndex].isWhitespace {
                while currentIndex < text.endIndex && text[currentIndex].isWhitespace {
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }

            // Check for comments
            if currentIndex < text.endIndex && text[currentIndex] == "#" {
                let start = currentIndex
                while currentIndex < text.endIndex && text[currentIndex] != "\n" {
                    currentIndex = text.index(after: currentIndex)
                }
                let range = text.distance(from: text.startIndex, to: start)..<text.distance(from: text.startIndex, to: currentIndex)
                tokens.append(Token(type: .comment, range: range, text: String(text[start..<currentIndex])))
                continue
            }

            // Check for strings
            if currentIndex < text.endIndex && (text[currentIndex] == "\"" || text[currentIndex] == "'") {
                let quote = text[currentIndex]
                let start = currentIndex
                currentIndex = text.index(after: currentIndex)

                while currentIndex < text.endIndex {
                    if text[currentIndex] == quote {
                        currentIndex = text.index(after: currentIndex)
                        break
                    }
                    if text[currentIndex] == "\\" {
                        currentIndex = text.index(after: currentIndex)
                        if currentIndex < text.endIndex {
                            currentIndex = text.index(after: currentIndex)
                        }
                    } else {
                        currentIndex = text.index(after: currentIndex)
                    }
                }

                let range = text.distance(from: text.startIndex, to: start)..<text.distance(from: text.startIndex, to: currentIndex)
                tokens.append(Token(type: .string, range: range, text: String(text[start..<currentIndex])))
                continue
            }

            // Check for numbers
            if currentIndex < text.endIndex && text[currentIndex].isNumber {
                let start = currentIndex
                while currentIndex < text.endIndex && (text[currentIndex].isNumber || text[currentIndex] == ".") {
                    currentIndex = text.index(after: currentIndex)
                }
                let range = text.distance(from: text.startIndex, to: start)..<text.distance(from: text.startIndex, to: currentIndex)
                tokens.append(Token(type: .number, range: range, text: String(text[start..<currentIndex])))
                continue
            }

            // Check for identifiers and keywords
            if currentIndex < text.endIndex && (text[currentIndex].isLetter || text[currentIndex] == "_") {
                let start = currentIndex
                while currentIndex < text.endIndex && (text[currentIndex].isLetter || text[currentIndex].isNumber || text[currentIndex] == "_") {
                    currentIndex = text.index(after: currentIndex)
                }

                let word = String(text[start..<currentIndex])
                let range = text.distance(from: text.startIndex, to: start)..<text.distance(from: text.startIndex, to: currentIndex)

                if language.keywords.contains(word) {
                    tokens.append(Token(type: .keyword, range: range, text: word))
                } else {
                    tokens.append(Token(type: .identifier, range: range, text: word))
                }
                continue
            }

            // Operators and punctuation
            let start = currentIndex
            currentIndex = text.index(after: currentIndex)
            let range = text.distance(from: text.startIndex, to: start)..<text.distance(from: text.startIndex, to: currentIndex)
            let char = String(text[start..<currentIndex])

            if "+-*/%=<>!&|^~".contains(char) {
                tokens.append(Token(type: .operator_, range: range, text: char))
            } else {
                tokens.append(Token(type: .punctuation, range: range, text: char))
            }
        }

        return tokens
    }

    // MARK: - Attributed String Generation

    nonisolated func attributedString(for text: String, baseFont: NSFont, theme: EditorTheme, language: Language) -> NSAttributedString {
        let tokens = tokenize(text: text, language: language)
        let attributedString = NSMutableAttributedString(string: text)

        // Use NSString length for proper UTF-16 indexing
        let fullLength = (text as NSString).length

        // Set base attributes
        attributedString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: fullLength))
        attributedString.addAttribute(.foregroundColor, value: theme.textColor.nsColor, range: NSRange(location: 0, length: fullLength))

        // Apply token colors - convert Swift String indices to NSRange
        for token in tokens {
            // Convert Swift String range to NSRange using NSString
            let startIndex = text.index(text.startIndex, offsetBy: token.range.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: token.range.upperBound)
            let nsRange = NSRange(startIndex..<endIndex, in: text)

            if nsRange.location != NSNotFound && nsRange.location + nsRange.length <= fullLength {
                let color = token.type.color(for: theme)
                attributedString.addAttribute(.foregroundColor, value: color, range: nsRange)
            }
        }

        return attributedString
    }
}
