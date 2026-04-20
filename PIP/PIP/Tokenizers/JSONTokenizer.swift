import Foundation

/// Tokenizer for JSON format
///
/// ## Features:
/// - String values in double quotes
/// - Number literals (int, float, scientific notation)
/// - Boolean values: true, false
/// - Null value
/// - Object/Array punctuation: {}, []
/// - Proper handling of escaped characters in strings
public final class JSONTokenizer: BaseTokenizer {

    private let keywords: Set<String> = ["true", "false", "null"]

    public init() {
        super.init(language: "json")
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

            // String literals (JSON strings are always double-quoted)
            if char == "\"" {
                let start = index
                index = line.index(after: index)

                // Find end of string, handling escapes
                var escaped = false
                while index < line.endIndex {
                    let currentChar = line[index]

                    if escaped {
                        escaped = false
                    } else if currentChar == "\\" {
                        escaped = true
                    } else if currentChar == "\"" {
                        index = line.index(after: index)
                        break
                    }

                    index = line.index(after: index)
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )

                // Determine if this is a key or value
                // Keys are typically followed by : (with possible whitespace)
                var isKey = false
                var lookahead = index
                while lookahead < line.endIndex && line[lookahead].isWhitespace {
                    lookahead = line.index(after: lookahead)
                }
                if lookahead < line.endIndex && line[lookahead] == ":" {
                    isKey = true
                }

                let tokenType: TokenType = isKey ? .property : .stringLiteral
                tokens.append(Token(type: tokenType, range: range, text: String(line[start..<index])))
                continue
            }

            // Numbers (including negative)
            if char.isNumber || (char == "-" && index < line.index(before: line.endIndex) &&
                                line[line.index(after: index)].isNumber) {
                let start = index

                // Negative sign
                if char == "-" {
                    index = line.index(after: index)
                }

                // Integer part
                while index < line.endIndex && line[index].isNumber {
                    index = line.index(after: index)
                }

                // Decimal part
                if index < line.endIndex && line[index] == "." {
                    index = line.index(after: index)
                    while index < line.endIndex && line[index].isNumber {
                        index = line.index(after: index)
                    }
                }

                // Scientific notation (e or E)
                if index < line.endIndex && "eE".contains(line[index]) {
                    index = line.index(after: index)

                    // Optional + or -
                    if index < line.endIndex && "+-".contains(line[index]) {
                        index = line.index(after: index)
                    }

                    // Exponent digits
                    while index < line.endIndex && line[index].isNumber {
                        index = line.index(after: index)
                    }
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .numberLiteral, range: range, text: String(line[start..<index])))
                continue
            }

            // Keywords: true, false, null
            if char.isLetter {
                let start = index

                while index < line.endIndex && line[index].isLetter {
                    index = line.index(after: index)
                }

                let text = String(line[start..<index])
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )

                let tokenType: TokenType
                if keywords.contains(text) {
                    tokenType = .keyword
                } else {
                    tokenType = .unknown // Invalid JSON
                }

                tokens.append(Token(type: tokenType, range: range, text: text))
                continue
            }

            // Punctuation: {, }, [, ], :, ,
            if "{}[]:,".contains(char) {
                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: index),
                    length: 1
                )
                tokens.append(Token(type: .punctuation, range: range, text: String(char)))
                index = line.index(after: index)
                continue
            }

            // Unknown character (invalid JSON)
            let range = NSRange(
                location: line.distance(from: line.startIndex, to: index),
                length: 1
            )
            tokens.append(Token(type: .unknown, range: range, text: String(char)))
            index = line.index(after: index)
        }

        return tokens
    }

    // MARK: - Validation

    /// Validate if JSON is well-formed (basic check)
    public func validate(text: String) -> (isValid: Bool, error: String?) {
        // Stack to track opening braces/brackets
        var stack: [Character] = []
        var inString = false
        var escaped = false

        for char in text {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString {
                escaped = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            if inString {
                continue
            }

            switch char {
            case "{":
                stack.append("}")
            case "[":
                stack.append("]")
            case "}", "]":
                if stack.isEmpty || stack.last != char {
                    return (false, "Mismatched bracket or brace: \(char)")
                }
                stack.removeLast()
            default:
                break
            }
        }

        if !stack.isEmpty {
            return (false, "Unclosed bracket or brace")
        }

        if inString {
            return (false, "Unclosed string")
        }

        return (true, nil)
    }

    /// Format JSON with proper indentation
    public func format(text: String, indentSize: Int = 2) -> String {
        var result = ""
        var indentLevel = 0
        var inString = false
        var escaped = false

        for char in text {
            if escaped {
                result.append(char)
                escaped = false
                continue
            }

            if char == "\\" && inString {
                result.append(char)
                escaped = true
                continue
            }

            if char == "\"" {
                result.append(char)
                inString.toggle()
                continue
            }

            if inString {
                result.append(char)
                continue
            }

            switch char {
            case "{", "[":
                result.append(char)
                indentLevel += 1
                result.append("\n")
                result.append(String(repeating: " ", count: indentLevel * indentSize))

            case "}", "]":
                indentLevel -= 1
                result.append("\n")
                result.append(String(repeating: " ", count: indentLevel * indentSize))
                result.append(char)

            case ",":
                result.append(char)
                result.append("\n")
                result.append(String(repeating: " ", count: indentLevel * indentSize))

            case ":":
                result.append(char)
                result.append(" ")

            case " ", "\n", "\t", "\r":
                // Skip existing whitespace (will be replaced by formatting)
                continue

            default:
                result.append(char)
            }
        }

        return result
    }
}
