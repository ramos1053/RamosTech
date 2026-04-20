import Foundation

/// Token type for syntax highlighting
public enum TokenType: String, Codable {
    case keyword
    case identifier
    case stringLiteral
    case numberLiteral
    case comment
    case operator_
    case punctuation
    case type
    case function
    case property
    case constant
    case whitespace
    case unknown
}

/// A token with type and range information
public struct Token: Equatable {
    public let type: TokenType
    public let range: NSRange
    public let text: String

    public init(type: TokenType, range: NSRange, text: String) {
        self.type = type
        self.range = range
        self.text = text
    }
}

/// Protocol for language-specific tokenizers
public protocol Tokenizer {
    /// Tokenize a single line of text
    /// - Parameter line: The line to tokenize
    /// - Parameter lineNumber: Line number (0-indexed)
    /// - Returns: Array of tokens for the line
    func tokenize(line: String, lineNumber: Int) -> [Token]

    /// Tokenize entire text
    /// - Parameter text: Full text to tokenize
    /// - Returns: Array of all tokens
    func tokenize(text: String) -> [Token]

    /// Get the language identifier
    var language: String { get }
}

/// Base tokenizer implementation with common utilities
open class BaseTokenizer: Tokenizer {
    public let language: String

    public init(language: String) {
        self.language = language
    }

    /// Tokenize a single line
    open func tokenize(line: String, lineNumber: Int) -> [Token] {
        fatalError("Subclass must implement tokenize(line:lineNumber:)")
    }

    /// Tokenize entire text by splitting into lines
    open func tokenize(text: String) -> [Token] {
        var allTokens: [Token] = []
        var currentOffset = 0

        let lines = text.components(separatedBy: .newlines)

        for (lineNumber, line) in lines.enumerated() {
            let lineTokens = tokenize(line: line, lineNumber: lineNumber)

            // Adjust token ranges to account for full text offset
            for token in lineTokens {
                let adjustedRange = NSRange(
                    location: currentOffset + token.range.location,
                    length: token.range.length
                )
                allTokens.append(Token(type: token.type, range: adjustedRange, text: token.text))
            }

            // Account for newline character
            currentOffset += line.count + 1
        }

        return allTokens
    }

    /// Check if character is a word boundary
    func isWordBoundary(_ char: Character) -> Bool {
        return char.isWhitespace ||
               char.isPunctuation ||
               ["(", ")", "[", "]", "{", "}", "<", ">", ",", ";", ":", ".", "!"].contains(char)
    }

    /// Extract word at position
    func extractWord(from text: String, at index: String.Index) -> (word: String, range: Range<String.Index>) {
        var start = index
        var end = index

        // Find start of word
        while start > text.startIndex {
            let prevIndex = text.index(before: start)
            let prevChar = text[prevIndex]
            if isWordBoundary(prevChar) {
                break
            }
            start = prevIndex
        }

        // Find end of word
        while end < text.endIndex {
            let char = text[end]
            if isWordBoundary(char) {
                break
            }
            end = text.index(after: end)
        }

        return (String(text[start..<end]), start..<end)
    }
}
