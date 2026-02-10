import Foundation

/// Tokenizer for Swift language
///
/// ## Features:
/// - Keywords: func, let, var, class, struct, enum, etc.
/// - String literals: "...", """...""", #"..."#
/// - Comments: //, /* */, ///
/// - Numbers: Int, Float, hex, binary, octal
/// - Operators: +, -, *, /, ==, !=, etc.
/// - Types: recognized by capitalization
public final class SwiftTokenizer: BaseTokenizer {

    // MARK: - Swift Keywords

    private let keywords: Set<String> = [
        // Declarations
        "class", "deinit", "enum", "extension", "func", "import", "init",
        "inout", "internal", "let", "operator", "private", "protocol",
        "public", "static", "struct", "subscript", "typealias", "var",

        // Statements
        "break", "case", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return",
        "switch", "where", "while",

        // Expressions
        "as", "catch", "dynamicType", "false", "is", "nil", "rethrows",
        "super", "self", "Self", "throw", "throws", "true", "try",

        // Modifiers
        "associatedtype", "convenience", "dynamic", "didSet", "final",
        "fileprivate", "get", "indirect", "infix", "lazy", "left",
        "mutating", "none", "nonmutating", "optional", "override",
        "postfix", "precedence", "prefix", "Protocol", "required",
        "right", "set", "Type", "unowned", "weak", "willSet",

        // Patterns
        "open", "some", "any",

        // Async/await
        "async", "await", "actor",

        // Attributes
        "available", "escaping", "autoclosure", "discardableResult",
        "testable", "objc", "IBAction", "IBOutlet", "IBInspectable",
        "IBDesignable", "NSManaged", "UIApplicationMain", "main"
    ]

    private let builtinTypes: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Float", "Double", "Bool", "String", "Character",
        "Array", "Dictionary", "Set", "Optional",
        "Any", "AnyObject", "Never", "Void"
    ]

    public init() {
        super.init(language: "swift")
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

            // Single-line comment: //
            if char == "/" && index < line.index(before: line.endIndex) {
                let nextChar = line[line.index(after: index)]
                if nextChar == "/" {
                    let start = index
                    index = line.endIndex // Rest of line is comment

                    let range = NSRange(
                        location: line.distance(from: line.startIndex, to: start),
                        length: line.distance(from: start, to: index)
                    )
                    tokens.append(Token(type: .comment, range: range, text: String(line[start..<index])))
                    continue
                }
            }

            // Multi-line comment: /* */
            if char == "/" && index < line.index(before: line.endIndex) {
                let nextChar = line[line.index(after: index)]
                if nextChar == "*" {
                    let start = index
                    index = line.index(after: line.index(after: index)) // Skip /*

                    // Find end of comment on this line
                    while index < line.index(before: line.endIndex) {
                        if line[index] == "*" && line[line.index(after: index)] == "/" {
                            index = line.index(after: line.index(after: index)) // Skip */
                            break
                        }
                        index = line.index(after: index)
                    }

                    let range = NSRange(
                        location: line.distance(from: line.startIndex, to: start),
                        length: line.distance(from: start, to: index)
                    )
                    tokens.append(Token(type: .comment, range: range, text: String(line[start..<index])))
                    continue
                }
            }

            // String literals
            if char == "\"" {
                let start = index
                index = line.index(after: index)

                // Check for multi-line string """
                let isMultiline = index < line.endIndex &&
                                 line[index] == "\"" &&
                                 index < line.index(before: line.endIndex) &&
                                 line[line.index(after: index)] == "\""

                if isMultiline {
                    // For this line-based tokenizer, treat as regular string
                    index = line.index(after: line.index(after: index))
                }

                // Find end of string
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

            // Numbers
            if char.isNumber {
                let start = index

                // Check for hex (0x), binary (0b), octal (0o)
                if char == "0" && index < line.index(before: line.endIndex) {
                    let nextChar = line[line.index(after: index)]
                    if "xbo".contains(nextChar) {
                        index = line.index(after: line.index(after: index)) // Skip 0x/0b/0o
                    }
                }

                // Consume digits, underscores, and decimal point
                while index < line.endIndex {
                    let currentChar = line[index]
                    if currentChar.isNumber || currentChar == "_" || currentChar == "." {
                        index = line.index(after: index)
                    } else {
                        break
                    }
                }

                // Check for scientific notation (e/E)
                if index < line.endIndex && "eE".contains(line[index]) {
                    index = line.index(after: index)
                    if index < line.endIndex && "+-".contains(line[index]) {
                        index = line.index(after: index)
                    }
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

            // Identifiers and keywords
            if char.isLetter || char == "_" {
                let start = index

                while index < line.endIndex {
                    let currentChar = line[index]
                    if currentChar.isLetter || currentChar.isNumber || currentChar == "_" {
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
                } else if builtinTypes.contains(text) {
                    tokenType = .type
                } else if text.first?.isUppercase == true {
                    tokenType = .type
                } else if text.first == "_" || text.uppercased() == text {
                    tokenType = .constant
                } else {
                    tokenType = .identifier
                }

                tokens.append(Token(type: tokenType, range: range, text: text))
                continue
            }

            // Operators and punctuation
            if "+-*/%<>=!&|^~?:".contains(char) {
                let start = index
                index = line.index(after: index)

                // Multi-character operators
                while index < line.endIndex && "+-*/%<>=!&|^~?".contains(line[index]) {
                    index = line.index(after: index)
                }

                let range = NSRange(
                    location: line.distance(from: line.startIndex, to: start),
                    length: line.distance(from: start, to: index)
                )
                tokens.append(Token(type: .operator_, range: range, text: String(line[start..<index])))
                continue
            }

            // Punctuation
            if "()[]{},.;@#$".contains(char) {
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
