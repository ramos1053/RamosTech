import Foundation

/// Tokenizer for Bash/Shell scripts
///
/// ## Features:
/// - Keywords: if, then, else, fi, for, while, case, etc.
/// - Variables: $VAR, ${VAR}, $1, $*, etc.
/// - Comments: #
/// - Strings: "...", '...', backticks
/// - Commands: Common Unix commands
/// - Operators: |, ||, &&, >, >>, <, etc.
public final class BashTokenizer: BaseTokenizer {

    // MARK: - Bash Keywords

    private let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi",
        "for", "while", "until", "do", "done",
        "case", "esac", "in",
        "function", "select",
        "time", "coproc",
        "until", "break", "continue",
        "return", "exit",
        "declare", "local", "readonly", "export",
        "unset", "shift", "source",
        "eval", "exec", "trap"
    ]

    private let builtinCommands: Set<String> = [
        "echo", "printf", "read", "cd", "pwd",
        "ls", "cp", "mv", "rm", "mkdir",
        "cat", "grep", "sed", "awk",
        "chmod", "chown", "find", "sort",
        "test", "true", "false",
        "set", "unalias", "alias",
        "which", "type", "command"
    ]

    private let testOperators: Set<String> = [
        "-eq", "-ne", "-lt", "-le", "-gt", "-ge",
        "-z", "-n",
        "-f", "-d", "-e", "-r", "-w", "-x",
        "-nt", "-ot", "-ef"
    ]

    public init() {
        super.init(language: "bash")
    }

    // MARK: - Tokenization

    public override func tokenize(line: String, lineNumber: Int) -> [Token] {
        var tokens: [Token] = []
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]

            // Skip whitespace
            if char.isWhitespace {
                let start = index
                while index < line.endIndex && line[index].isWhitespace {
                    index = line.index(after: index)
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .whitespace, range: range, text: String(line[start..<index])))
                continue
            }

            // Comments: # to end of line
            if char == "#" {
                let start = index
                index = line.endIndex

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .comment, range: range, text: String(line[start..<index])))
                continue
            }

            // Variables: $VAR, ${VAR}, $1, etc.
            if char == "$" {
                let start = index
                index = line.index(after: index)

                // Handle ${VAR}
                if index < line.endIndex && line[index] == "{" {
                    index = line.index(after: index)
                    while index < line.endIndex && line[index] != "}" {
                        index = line.index(after: index)
                    }
                    if index < line.endIndex {
                        index = line.index(after: index) // Include }
                    }
                } else {
                    // Handle $VAR or $1
                    while index < line.endIndex {
                        let currentChar = line[index]
                        if currentChar.isLetter || currentChar.isNumber || currentChar == "_" {
                            index = line.index(after: index)
                        } else {
                            break
                        }
                    }
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .property, range: range, text: String(line[start..<index])))
                continue
            }

            // Double-quoted strings
            if char == "\"" {
                let start = index
                index = line.index(after: index)

                var escaped = false
                while index < line.endIndex {
                    let currentChar = line[index]
                    if currentChar == "\\" {
                        escaped = !escaped
                    } else if currentChar == "\"" && !escaped {
                        index = line.index(after: index)
                        break
                    } else {
                        escaped = false
                    }
                    index = line.index(after: index)
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .stringLiteral, range: range, text: String(line[start..<index])))
                continue
            }

            // Single-quoted strings
            if char == "'" {
                let start = index
                index = line.index(after: index)

                while index < line.endIndex && line[index] != "'" {
                    index = line.index(after: index)
                }
                if index < line.endIndex {
                    index = line.index(after: index) // Include closing '
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .stringLiteral, range: range, text: String(line[start..<index])))
                continue
            }

            // Backtick command substitution
            if char == "`" {
                let start = index
                index = line.index(after: index)

                while index < line.endIndex && line[index] != "`" {
                    index = line.index(after: index)
                }
                if index < line.endIndex {
                    index = line.index(after: index) // Include closing `
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .function, range: range, text: String(line[start..<index])))
                continue
            }

            // Numbers
            if char.isNumber {
                let start = index

                while index < line.endIndex && (line[index].isNumber || line[index] == ".") {
                    index = line.index(after: index)
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .numberLiteral, range: range, text: String(line[start..<index])))
                continue
            }

            // Words (keywords, commands, identifiers)
            if char.isLetter || char == "_" || char == "-" {
                let start = index

                while index < line.endIndex {
                    let currentChar = line[index]
                    if currentChar.isLetter || currentChar.isNumber || currentChar == "_" || currentChar == "-" {
                        index = line.index(after: index)
                    } else {
                        break
                    }
                }

                let text = String(line[start..<index])
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )

                // Determine token type
                let tokenType: TokenType
                if keywords.contains(text) {
                    tokenType = .keyword
                } else if builtinCommands.contains(text) {
                    tokenType = .function
                } else if testOperators.contains(text) {
                    tokenType = .operator_
                } else if text.uppercased() == text && text.count > 1 {
                    tokenType = .constant
                } else {
                    tokenType = .identifier
                }

                tokens.append(Token(type: tokenType, range: range, text: text))
                continue
            }

            // Operators and punctuation
            if "|&<>;()[]{}!*?".contains(char) {
                let start = index
                index = line.index(after: index)

                // Multi-character operators
                if index < line.endIndex {
                    let nextChar = line[index]
                    if (char == "|" && nextChar == "|") ||
                       (char == "&" && nextChar == "&") ||
                       (char == ">" && nextChar == ">") ||
                       (char == "<" && nextChar == "<") ||
                       (char == "=" && nextChar == "=") ||
                       (char == "!" && nextChar == "=") {
                        index = line.index(after: index)
                    }
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .operator_, range: range, text: String(line[start..<index])))
                continue
            }

            // Other punctuation
            if ".,;=:".contains(char) {
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: index),
                    length: 1
                )
                tokens.append(Token(type: .punctuation, range: range, text: String(char)))
                index = line.index(after: index)
                continue
            }

            // Unknown character
            let range = NSRange(
                location: line.distance(from: line.startIndex, to: index),
                length: 1
            )
            tokens.append(Token(type: .unknown, range: range, text: String(char)))
            index = line.index(after: index)
        }

        return tokens
    }
}
