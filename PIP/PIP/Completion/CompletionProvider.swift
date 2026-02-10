import Foundation

/// Represents a single completion suggestion
class CompletionItem: Identifiable, Hashable {
    let id = UUID()
    let text: String              // The text to insert
    let displayText: String       // What to show in menu
    let detailText: String?       // Subtitle/description
    let kind: CompletionKind      // Icon/category
    let score: Int                // Ranking score

    init(text: String, displayText: String? = nil, detailText: String? = nil, kind: CompletionKind, score: Int = 50) {
        self.text = text
        self.displayText = displayText ?? text
        self.detailText = detailText
        self.kind = kind
        self.score = score
    }

    // Hashable conformance for class
    static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Category of completion suggestion
enum CompletionKind {
    case command        // bash: if, for, echo
    case flag           // --help, -v
    case keyword        // swift: func, let, var
    case snippet        // Custom snippets
    case variable       // $VAR, environment vars
    case function       // User-defined functions
}

/// Protocol for language-specific completion providers
protocol CompletionProvider {
    /// File extensions this provider supports (e.g., ["sh", "bash", "zsh"])
    var supportedExtensions: [String] { get }

    /// Returns completions for the given context
    /// - Parameters:
    ///   - prefix: The partial word being typed
    ///   - position: Cursor position in full text
    ///   - fullText: Complete document text
    ///   - cursorLine: The line containing the cursor
    /// - Returns: Array of completion suggestions, sorted by relevance
    func completions(
        for prefix: String,
        at position: Int,
        in fullText: String,
        cursorLine: String
    ) -> [CompletionItem]

    /// Determines if completion should trigger automatically after typing this character
    /// - Parameter character: The character that was just typed
    /// - Returns: True if completions should be shown automatically
    func shouldTriggerAutomatically(after character: Character) -> Bool
}

/// Context for bash completion
enum BashCompletionContext {
    case command        // At start of line or after pipe/&&/||/;
    case flag           // After - or --
    case variable       // After $
    case argument       // After command name
    case subcommand     // After certain commands (git, docker, etc.)
}
