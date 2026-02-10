import Foundation

/// Tokenizer for Markdown
///
/// ## Features:
/// - Headings: #, ##, ###, etc.
/// - Bold: **text**, __text__
/// - Italic: *text*, _text_
/// - Code: `code`, ```code```
/// - Links: [text](url)
/// - Images: ![alt](url)
/// - Lists: -, *, +, 1.
/// - Blockquotes: >
/// - Horizontal rules: ---, ***, ___
public final class MarkdownTokenizer: BaseTokenizer {

    public init() {
        super.init(language: "markdown")
    }

    // MARK: - Tokenization

    public override func tokenize(line: String, lineNumber: Int) -> [Token] {
        var tokens: [Token] = []

        // Empty line
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            let range = NSRange(location: 0, length: line.count)
            tokens.append(Token(type: .whitespace, range: range, text: line))
            return tokens
        }

        var index = line.startIndex

        // Check for heading
        if line.hasPrefix("#") {
            let start = index
            while index < line.endIndex && line[index] == "#" {
                index = line.index(after: index)
            }

            let range = NSRange(
                location: line.distance(from: line.startIndex, to: start),
                length: line.distance(from: start, to: line.endIndex)
            )
            tokens.append(Token(type: .keyword, range: range, text: String(line[start..<line.endIndex])))
            return tokens
        }

        // Check for blockquote
        if line.hasPrefix(">") {
            let range = NSRange(location: 0, length: line.count)
            tokens.append(Token(type: .comment, range: range, text: line))
            return tokens
        }

        // Check for code block fence
        if line.hasPrefix("```") || line.hasPrefix("~~~") {
            let range = NSRange(location: 0, length: line.count)
            tokens.append(Token(type: .keyword, range: range, text: line))
            return tokens
        }

        // Check for horizontal rule
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if (trimmed.allSatisfy { $0 == "-" } || trimmed.allSatisfy { $0 == "*" } || trimmed.allSatisfy { $0 == "_" }) &&
           trimmed.count >= 3 {
            let range = NSRange(location: 0, length: line.count)
            tokens.append(Token(type: .operator_, range: range, text: line))
            return tokens
        }

        // Check for list
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            let range = NSRange(location: 0, length: 2)
            tokens.append(Token(type: .punctuation, range: range, text: String(line.prefix(2))))
            index = line.index(line.startIndex, offsetBy: 2)
        } else if let firstChar = line.first, firstChar.isNumber {
            // Numbered list
            var numEnd = index
            while numEnd < line.endIndex && line[numEnd].isNumber {
                numEnd = line.index(after: numEnd)
            }
            if numEnd < line.endIndex && line[numEnd] == "." {
                let dotEnd = line.index(after: numEnd)
                let range = NSRange(location: 0, length: line.distance(from: line.startIndex, to: dotEnd))
                tokens.append(Token(type: .numberLiteral, range: range, text: String(line[..<dotEnd])))
                index = dotEnd
            }
        }

        // Inline parsing
        while index < line.endIndex {
            let char = line[index]

            // Whitespace
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

            // Inline code: `code`
            if char == "`" {
                let start = index
                index = line.index(after: index)

                // Count backticks for multi-backtick code
                var backtickCount = 1
                while index < line.endIndex && line[index] == "`" {
                    backtickCount += 1
                    index = line.index(after: index)
                }

                // Find closing backticks
                while index < line.endIndex {
                    if line[index] == "`" {
                        var closeCount = 0
                        var tempIndex = index
                        while tempIndex < line.endIndex && line[tempIndex] == "`" {
                            closeCount += 1
                            tempIndex = line.index(after: tempIndex)
                        }
                        if closeCount == backtickCount {
                            index = tempIndex
                            break
                        }
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

            // Bold: **text** or __text__
            if (char == "*" || char == "_") && index < line.index(before: line.endIndex) {
                let nextChar = line[line.index(after: index)]
                if nextChar == char {
                    let start = index
                    let marker = char
                    index = line.index(after: line.index(after: index)) // Skip **

                    // Find closing **
                    while index < line.index(before: line.endIndex) {
                        if line[index] == marker && line[line.index(after: index)] == marker {
                            index = line.index(after: line.index(after: index))
                            break
                        }
                        index = line.index(after: index)
                    }

                    let range = NSRange(
                        location: line.distance(from: line.startIndex, to: start),
                        length: line.distance(from: start, to: index)
                    )
                    tokens.append(Token(type: .keyword, range: range, text: String(line[start..<index])))
                    continue
                }
            }

            // Italic: *text* or _text_ (single)
            if char == "*" || char == "_" {
                let start = index
                let marker = char
                index = line.index(after: index)

                // Find closing marker
                while index < line.endIndex && line[index] != marker {
                    index = line.index(after: index)
                }
                if index < line.endIndex {
                    index = line.index(after: index) // Include closing marker
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .comment, range: range, text: String(line[start..<index])))
                continue
            }

            // Links: [text](url) or Images: ![alt](url)
            if char == "[" || (char == "!" && index < line.index(before: line.endIndex) && line[line.index(after: index)] == "[") {
                let start = index

                if char == "!" {
                    index = line.index(after: index) // Skip !
                }

                index = line.index(after: index) // Skip [

                // Find ]
                while index < line.endIndex && line[index] != "]" {
                    index = line.index(after: index)
                }

                if index < line.endIndex {
                    index = line.index(after: index) // Skip ]
                }

                // Check for (
                if index < line.endIndex && line[index] == "(" {
                    index = line.index(after: index)

                    // Find )
                    while index < line.endIndex && line[index] != ")" {
                        index = line.index(after: index)
                    }

                    if index < line.endIndex {
                        index = line.index(after: index) // Skip )
                    }
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .function, range: range, text: String(line[start..<index])))
                continue
            }

            // Regular text
            let start = index

            while index < line.endIndex {
                let currentChar = line[index]
                if currentChar.isWhitespace || "`*_[!".contains(currentChar) {
                    break
                }
                index = line.index(after: index)
            }

            if start < index {
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .identifier, range: range, text: String(line[start..<index])))
            } else {
                // Single character that didn't match any pattern
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: index),
                    length: 1
                )
                tokens.append(Token(type: .punctuation, range: range, text: String(char)))
                index = line.index(after: index)
            }
        }

        return tokens
    }
}
