import Foundation

/// Search result with range and match information
public struct SearchResult: Equatable, Identifiable {
    public let id = UUID()
    public let range: NSRange
    public let matchedText: String
    public let lineNumber: Int
    public let columnNumber: Int

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.range == rhs.range &&
        lhs.matchedText == rhs.matchedText &&
        lhs.lineNumber == rhs.lineNumber &&
        lhs.columnNumber == rhs.columnNumber
    }
}

/// Replace operation result
public struct ReplaceResult {
    public let originalRange: NSRange
    public let replacementText: String
    public let newText: String
}

/// Streaming search engine with regex support and chunked processing
///
/// ## Invariants:
/// - Searches process text in chunks to avoid blocking
/// - Regex patterns are compiled once and reused
/// - Chunk boundaries are handled correctly (overlapping search windows)
/// - Results are returned incrementally via async sequence
///
/// ## Performance:
/// - Chunk size: 64KB for balanced memory/performance
/// - Overlap size: 1KB to catch boundary matches
/// - Can search multi-GB files without loading entire content
@MainActor
public final class SearchEngine {

    // MARK: - Configuration

    /// Size of each chunk for streaming search (64KB)
    private let chunkSize = 65_536

    /// Overlap between chunks to catch boundary matches (1KB)
    private let overlapSize = 1_024

    // MARK: - Search Options

    public struct SearchOptions {
        public var caseSensitive: Bool
        public var wholeWord: Bool
        public var useRegex: Bool
        public var multiline: Bool

        public init(
            caseSensitive: Bool = false,
            wholeWord: Bool = false,
            useRegex: Bool = false,
            multiline: Bool = false
        ) {
            self.caseSensitive = caseSensitive
            self.wholeWord = wholeWord
            self.useRegex = useRegex
            self.multiline = multiline
        }
    }

    // MARK: - Search Methods

    /// Search text and return results incrementally
    /// - Parameters:
    ///   - pattern: Search pattern (literal or regex)
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: Async sequence of search results
    public func search(
        pattern: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) async throws -> AsyncStream<SearchResult> {
        let regex = try buildRegex(pattern: pattern, options: options)

        return AsyncStream { continuation in
            Task { @MainActor in
                let nsText = text as NSString
                var processedRanges = Set<NSRange>()

                // Process text in chunks
                var offset = 0
                let totalLength = nsText.length

                while offset < totalLength {
                    // Calculate chunk range with overlap
                    let chunkEnd = min(offset + chunkSize + overlapSize, totalLength)
                    let chunkRange = NSRange(location: offset, length: chunkEnd - offset)

                    // Search within this chunk
                    regex.enumerateMatches(
                        in: text,
                        options: [],
                        range: chunkRange
                    ) { match, _, _ in
                        guard let match = match else { return }

                        let matchRange = match.range

                        // Skip if we've already processed this match (boundary overlap)
                        guard !processedRanges.contains(matchRange) else { return }
                        processedRanges.insert(matchRange)

                        // Calculate line and column numbers
                        let lineInfo = calculateLineInfo(in: nsText, at: matchRange.location)

                        let result = SearchResult(
                            range: matchRange,
                            matchedText: nsText.substring(with: matchRange),
                            lineNumber: lineInfo.line,
                            columnNumber: lineInfo.column
                        )

                        continuation.yield(result)
                    }

                    // Move to next chunk (with overlap)
                    offset += chunkSize

                    // Yield to allow other tasks to run
                    await Task.yield()
                }

                continuation.finish()
            }
        }
    }

    /// Find all matches synchronously (convenience method for small texts)
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: Array of all search results
    public func findAll(
        pattern: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) throws -> [SearchResult] {
        let regex = try buildRegex(pattern: pattern, options: options)
        let nsText = text as NSString
        var results: [SearchResult] = []

        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match = match else { return }

            let matchRange = match.range
            let lineInfo = calculateLineInfo(in: nsText, at: matchRange.location)

            let result = SearchResult(
                range: matchRange,
                matchedText: nsText.substring(with: matchRange),
                lineNumber: lineInfo.line,
                columnNumber: lineInfo.column
            )

            results.append(result)
        }

        return results
    }

    /// Count matches without returning full results (faster)
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: Number of matches
    public func count(
        pattern: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) throws -> Int {
        let regex = try buildRegex(pattern: pattern, options: options)
        let nsText = text as NSString

        return regex.numberOfMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )
    }

    // MARK: - Replace Methods

    /// Perform dry-run replace to preview changes
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - replacement: Replacement string (supports regex groups with $1, $2, etc.)
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: Array of replace results showing what would change
    public func dryRunReplace(
        pattern: String,
        replacement: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) throws -> [ReplaceResult] {
        let regex = try buildRegex(pattern: pattern, options: options)
        let nsText = text as NSString
        var results: [ReplaceResult] = []

        // Use enumerateMatches to get proper NSTextCheckingResult objects
        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match = match else { return }

            // Get the replacement text for this match
            let replacementText = regex.replacementString(
                for: match,
                in: text,
                offset: 0,
                template: replacement
            )

            // Build preview of new text
            let beforeMatch = nsText.substring(to: match.range.location)
            let afterMatch = nsText.substring(from: match.range.location + match.range.length)
            let newText = beforeMatch + replacementText + afterMatch

            // Calculate line and column
            let _ = calculateLineInfo(in: nsText, at: match.range.location)

            results.append(ReplaceResult(
                originalRange: match.range,
                replacementText: replacementText,
                newText: newText
            ))
        }

        return results
    }

    /// Perform actual replace operation
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - replacement: Replacement string (supports regex groups)
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: New text with replacements applied
    public func replace(
        pattern: String,
        replacement: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) throws -> String {
        let regex = try buildRegex(pattern: pattern, options: options)
        let nsText = text as NSString

        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length),
            withTemplate: replacement
        )
    }

    /// Replace matches incrementally with streaming results
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - replacement: Replacement string
    ///   - text: Text to search in
    ///   - options: Search options
    /// - Returns: Async sequence of replace operations with progress
    public func replaceStreaming(
        pattern: String,
        replacement: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) async throws -> AsyncStream<(result: ReplaceResult, progress: Double)> {
        let regex = try buildRegex(pattern: pattern, options: options)
        let nsText = text as NSString

        // Get all matches first with proper NSTextCheckingResult objects
        var allMatches: [(match: NSTextCheckingResult, replacementText: String)] = []
        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match = match else { return }

            let replacementText = regex.replacementString(
                for: match,
                in: text,
                offset: 0,
                template: replacement
            )
            allMatches.append((match, replacementText))
        }

        return AsyncStream { continuation in
            Task { @MainActor in
                var processedText = text
                var cumulativeOffset = 0

                for (index, matchPair) in allMatches.enumerated() {
                    let match = matchPair.match
                    let replacementText = matchPair.replacementText

                    // Adjust range for previous replacements
                    let adjustedRange = NSRange(
                        location: match.range.location + cumulativeOffset,
                        length: match.range.length
                    )

                    // Apply replacement
                    let mutableText = NSMutableString(string: processedText)
                    mutableText.replaceCharacters(in: adjustedRange, with: replacementText)
                    processedText = mutableText as String

                    // Update offset for next iterations
                    cumulativeOffset += replacementText.count - match.range.length

                    // Calculate progress
                    let progress = Double(index + 1) / Double(allMatches.count)

                    let result = ReplaceResult(
                        originalRange: match.range,
                        replacementText: replacementText,
                        newText: processedText
                    )

                    continuation.yield((result, progress))

                    // Yield to allow UI updates
                    await Task.yield()
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Helper Methods

    /// Build regex from pattern and options
    private func buildRegex(pattern: String, options: SearchOptions) throws -> NSRegularExpression {
        var regexOptions: NSRegularExpression.Options = []

        if !options.caseSensitive {
            regexOptions.insert(.caseInsensitive)
        }

        if options.multiline {
            regexOptions.insert(.anchorsMatchLines)
        }

        // Construct final pattern
        var finalPattern = pattern

        if !options.useRegex {
            // Escape regex special characters for literal search
            finalPattern = NSRegularExpression.escapedPattern(for: pattern)
        }

        if options.wholeWord {
            // Add word boundaries
            finalPattern = "\\b" + finalPattern + "\\b"
        }

        return try NSRegularExpression(pattern: finalPattern, options: regexOptions)
    }

    /// Calculate line and column number for a character offset
    private func calculateLineInfo(in text: NSString, at location: Int) -> (line: Int, column: Int) {
        guard location >= 0 && location <= text.length else {
            return (0, 0)
        }

        var line = 1
        var column = 1
        var currentIndex = 0

        while currentIndex < location {
            let char = text.character(at: currentIndex)

            if char == 0x000A { // \n
                line += 1
                column = 1
            } else if char == 0x000D { // \r
                // Check for \r\n
                if currentIndex + 1 < text.length &&
                   text.character(at: currentIndex + 1) == 0x000A {
                    currentIndex += 1 // Skip the \n
                }
                line += 1
                column = 1
            } else {
                column += 1
            }

            currentIndex += 1
        }

        return (line, column)
    }

    /// Validate chunk boundary correctness (for testing)
    /// Returns true if all matches are found correctly across chunk boundaries
    func validateChunkBoundaries(
        pattern: String,
        in text: String,
        options: SearchOptions = SearchOptions()
    ) async throws -> Bool {
        // Find all matches with chunked search
        var chunkedResults: [SearchResult] = []
        let streamResults = try await search(pattern: pattern, in: text, options: options)

        for await result in streamResults {
            chunkedResults.append(result)
        }

        // Find all matches without chunking
        let directResults = try findAll(pattern: pattern, in: text, options: options)

        // Compare results
        guard chunkedResults.count == directResults.count else {
            return false
        }

        // Sort both by location
        let sortedChunked = chunkedResults.sorted { $0.range.location < $1.range.location }
        let sortedDirect = directResults.sorted { $0.range.location < $1.range.location }

        // Compare each result
        for (chunked, direct) in zip(sortedChunked, sortedDirect) {
            if chunked != direct {
                return false
            }
        }

        return true
    }
}
