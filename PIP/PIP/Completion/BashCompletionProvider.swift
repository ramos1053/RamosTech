import Foundation

/// Bash/shell-specific completion provider with context awareness
final class BashCompletionProvider: CompletionProvider {
    static let shared = BashCompletionProvider()

    private let database = CompletionDatabase.shared

    private init() {}

    // MARK: - CompletionProvider Protocol

    var supportedExtensions: [String] {
        ["sh", "bash", "zsh", ""]  // "" allows shebang-based detection
    }

    func completions(
        for prefix: String,
        at position: Int,
        in fullText: String,
        cursorLine: String
    ) -> [CompletionItem] {
        // Minimum prefix length
        guard prefix.count >= 2 else { return [] }

        // Detect language from shebang (first line)
        let shebang = fullText.components(separatedBy: .newlines).first
        let language = database.detectLanguage(from: shebang)

        // Detect the context at cursor
        let context = detectContext(in: cursorLine, prefix: prefix)

        var results: [CompletionItem] = []

        switch context {
        case .variable:
            // Complete environment variables (bash-specific)
            if language == .bash {
                results = database.variableCompletions(matching: prefix)
            }

        case .flag:
            // Complete flags (try to find the command being flagged)
            let command = extractCommand(from: cursorLine)
            results = database.flagCompletions(matching: prefix, for: command)

        case .command, .subcommand:
            // Complete commands and keywords based on detected language
            results = database.commandCompletions(matching: prefix, language: language)

        case .argument:
            // For now, no argument completions (could add file paths later)
            results = []
        }

        // Limit to top 50 results
        return Array(results.prefix(50))
    }

    func shouldTriggerAutomatically(after character: Character) -> Bool {
        // Trigger on alphanumeric characters, underscore, dash (for flags), and $ (for variables)
        return character.isLetter || character.isNumber || character == "_" || character == "-" || character == "$"
    }

    // MARK: - Context Detection

    /// Detects the completion context based on cursor position in the line
    private func detectContext(in line: String, prefix: String) -> BashCompletionContext {
        // Get text before the prefix
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        // Empty line or start of line → command
        if trimmedLine.isEmpty {
            return .command
        }

        // Check if prefix starts with $ → variable
        if prefix.hasPrefix("$") {
            return .variable
        }

        // Get the word before the cursor (excluding prefix)
        let beforePrefix = String(line.dropLast(prefix.count))

        // Check if we're after a $ character → variable
        if beforePrefix.hasSuffix("$") || beforePrefix.contains("$") && !beforePrefix.hasSuffix(" ") {
            return .variable
        }

        // Check if prefix starts with - or -- → flag
        if prefix.hasPrefix("-") {
            return .flag
        }

        // Check if there's a dash just before the prefix
        let trimmedBefore = beforePrefix.trimmingCharacters(in: .whitespaces)
        if trimmedBefore.hasSuffix("-") {
            return .flag
        }

        // Find where we are in the command structure
        let tokens = tokenizeLine(line)

        guard !tokens.isEmpty else {
            return .command
        }

        // If we're at the first position → command
        if tokens.count == 1 || isCommandPosition(in: line, before: prefix) {
            return .command
        }

        // After git, docker, npm, etc. → subcommand
        let firstToken = tokens[0]
        if ["git", "docker", "npm", "yarn", "cargo", "go", "brew", "apt", "yum"].contains(firstToken) {
            if tokens.count == 2 && !tokens[1].hasPrefix("-") {
                return .subcommand
            }
        }

        // Otherwise, it's an argument position
        return .argument
    }

    /// Checks if cursor is at a command position (start of line or after pipe/;/&&/||)
    private func isCommandPosition(in line: String, before prefix: String) -> Bool {
        let beforeCursor = String(line.dropLast(prefix.count))
        let trimmed = beforeCursor.trimmingCharacters(in: .whitespaces)

        // Empty line
        if trimmed.isEmpty {
            return true
        }

        // Check if last non-whitespace character is a command separator
        let commandSeparators = ["|", ";", "&&", "||", "&", "(", "{"]
        for separator in commandSeparators {
            if trimmed.hasSuffix(separator) {
                return true
            }
        }

        return false
    }

    /// Tokenizes a line into words (simple whitespace split for now)
    private func tokenizeLine(_ line: String) -> [String] {
        line.split(whereSeparator: { char in
            char.isWhitespace || char == "|" || char == ";" || char == "(" || char == ")"
        }).map { String($0) }
    }

    /// Extracts the command name from the line (for context-aware flag completion)
    private func extractCommand(from line: String) -> String? {
        let tokens = tokenizeLine(line)
        guard !tokens.isEmpty else { return nil }

        // Find the first token that looks like a command (not starting with -)
        for token in tokens {
            if !token.hasPrefix("-") && !token.hasPrefix("$") {
                return token
            }
        }

        return nil
    }
}
