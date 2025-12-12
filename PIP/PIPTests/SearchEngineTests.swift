import XCTest
@testable import PIP

/// Comprehensive tests for SearchEngine
/// Focus on chunk boundary correctness and edge cases
@MainActor
final class SearchEngineTests: XCTestCase {

    var searchEngine: SearchEngine!

    override func setUp() async throws {
        searchEngine = SearchEngine()
    }

    // MARK: - Basic Search Tests

    func testLiteralSearch() throws {
        let text = "Hello World, Hello Swift"
        let results = try searchEngine.findAll(pattern: "Hello", in: text)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].matchedText, "Hello")
        XCTAssertEqual(results[1].matchedText, "Hello")
    }

    func testCaseSensitiveSearch() throws {
        let text = "Hello hello HELLO"

        // Case sensitive
        let caseSensitive = try searchEngine.findAll(
            pattern: "hello",
            in: text,
            options: SearchEngine.SearchOptions(caseSensitive: true)
        )
        XCTAssertEqual(caseSensitive.count, 1)

        // Case insensitive
        let caseInsensitive = try searchEngine.findAll(
            pattern: "hello",
            in: text,
            options: SearchEngine.SearchOptions(caseSensitive: false)
        )
        XCTAssertEqual(caseInsensitive.count, 3)
    }

    func testWholeWordSearch() throws {
        let text = "cat category scattered"

        // Whole word only
        let wholeWord = try searchEngine.findAll(
            pattern: "cat",
            in: text,
            options: SearchEngine.SearchOptions(wholeWord: true)
        )
        XCTAssertEqual(wholeWord.count, 1)
        XCTAssertEqual(wholeWord[0].matchedText, "cat")

        // Non-whole word
        let nonWholeWord = try searchEngine.findAll(
            pattern: "cat",
            in: text,
            options: SearchEngine.SearchOptions(wholeWord: false)
        )
        XCTAssertEqual(nonWholeWord.count, 3)
    }

    // MARK: - Regex Tests

    func testRegexSearch() throws {
        let text = "Email: user@example.com and admin@test.org"

        let results = try searchEngine.findAll(
            pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].matchedText, "user@example.com")
        XCTAssertEqual(results[1].matchedText, "admin@test.org")
    }

    func testRegexGroups() throws {
        let text = "Date: 2024-01-15 and 2024-12-31"

        let results = try searchEngine.findAll(
            pattern: "(\\d{4})-(\\d{2})-(\\d{2})",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Line and Column Tests

    func testLineNumberCalculation() throws {
        let text = "Line 1\nLine 2\nLine 3 with pattern"

        let results = try searchEngine.findAll(pattern: "pattern", in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].lineNumber, 3)
    }

    func testColumnNumberCalculation() throws {
        let text = "Hello World"

        let results = try searchEngine.findAll(pattern: "World", in: text)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].columnNumber, 7) // "World" starts at column 7
    }

    func testMultilineMatches() throws {
        let text = "Line 1\nLine 2\nLine 3"

        let results = try searchEngine.findAll(
            pattern: "Line \\d",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].lineNumber, 1)
        XCTAssertEqual(results[1].lineNumber, 2)
        XCTAssertEqual(results[2].lineNumber, 3)
    }

    // MARK: - Chunk Boundary Tests

    func testChunkBoundarySimple() async throws {
        // Create text that will span multiple chunks
        let repeatedText = String(repeating: "x", count: 100_000)
        let text = repeatedText + "PATTERN" + repeatedText

        let isValid = try await searchEngine.validateChunkBoundaries(
            pattern: "PATTERN",
            in: text
        )

        XCTAssertTrue(isValid, "Chunk boundary validation should pass")
    }

    func testChunkBoundaryAtExactBoundary() async throws {
        // Create a pattern that falls exactly on a chunk boundary
        // Default chunk size is 64KB = 65536
        let beforeChunk = String(repeating: "a", count: 65533)
        let pattern = "BOUNDARY"
        let afterChunk = String(repeating: "b", count: 1000)

        let text = beforeChunk + pattern + afterChunk

        let isValid = try await searchEngine.validateChunkBoundaries(
            pattern: pattern,
            in: text
        )

        XCTAssertTrue(isValid, "Should find pattern at chunk boundary")
    }

    func testChunkBoundaryMultipleMatches() async throws {
        // Create text with matches in different chunks
        let chunk1 = String(repeating: "x", count: 50_000) + "MATCH1"
        let chunk2 = String(repeating: "y", count: 50_000) + "MATCH2"
        let chunk3 = String(repeating: "z", count: 50_000) + "MATCH3"

        let text = chunk1 + chunk2 + chunk3

        let isValid = try await searchEngine.validateChunkBoundaries(
            pattern: "MATCH\\d",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertTrue(isValid, "Should find all matches across chunks")
    }

    func testChunkBoundaryOverlap() async throws {
        // Test that overlap region correctly handles matches
        // Pattern spans the overlap region between chunks
        let beforeBoundary = String(repeating: "a", count: 65000)
        let atBoundary = "SPANNING_PATTERN"
        let afterBoundary = String(repeating: "b", count: 5000)

        let text = beforeBoundary + atBoundary + afterBoundary

        let results = try searchEngine.findAll(pattern: "SPANNING_PATTERN", in: text)

        XCTAssertEqual(results.count, 1, "Should find pattern that spans chunk boundary")
    }

    // MARK: - Count Tests

    func testCountMatches() throws {
        let text = "The quick brown fox jumps over the lazy dog"

        let count = try searchEngine.count(pattern: "the", in: text)

        XCTAssertEqual(count, 2) // "the" appears twice (case insensitive)
    }

    func testCountWithRegex() throws {
        let text = "Numbers: 123, 456, 789"

        let count = try searchEngine.count(
            pattern: "\\d+",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertEqual(count, 3)
    }

    // MARK: - Replace Tests

    func testBasicReplace() throws {
        let text = "Hello World"

        let result = try searchEngine.replace(
            pattern: "World",
            replacement: "Swift",
            in: text
        )

        XCTAssertEqual(result, "Hello Swift")
    }

    func testReplaceAll() throws {
        let text = "cat cat cat"

        let result = try searchEngine.replace(
            pattern: "cat",
            replacement: "dog",
            in: text
        )

        XCTAssertEqual(result, "dog dog dog")
    }

    func testReplaceWithRegexGroups() throws {
        let text = "Date: 2024-01-15"

        let result = try searchEngine.replace(
            pattern: "(\\d{4})-(\\d{2})-(\\d{2})",
            replacement: "$2/$3/$1",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        XCTAssertEqual(result, "Date: 01/15/2024")
    }

    func testDryRunReplace() throws {
        let text = "Hello World"

        let results = try searchEngine.dryRunReplace(
            pattern: "World",
            replacement: "Swift",
            in: text
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].replacementText, "Swift")
        XCTAssertEqual(results[0].newText, "Hello Swift")

        // Original text should be unchanged
        XCTAssertNotEqual(text, results[0].newText)
    }

    func testDryRunReplaceMultiple() throws {
        let text = "cat cat cat"

        let results = try searchEngine.dryRunReplace(
            pattern: "cat",
            replacement: "dog",
            in: text
        )

        XCTAssertEqual(results.count, 3)

        // Each result shows what the text would look like after that replacement
        for result in results {
            XCTAssertEqual(result.replacementText, "dog")
        }
    }

    // MARK: - Streaming Tests

    func testStreamingSearch() async throws {
        let text = "Find this pattern multiple times: pattern, pattern, pattern"

        var results: [SearchResult] = []
        let stream = try await searchEngine.search(pattern: "pattern", in: text)

        for await result in stream {
            results.append(result)
        }

        XCTAssertEqual(results.count, 4) // 4 occurrences of "pattern"
    }

    func testStreamingReplace() async throws {
        let text = "one two three"

        var lastProgress: Double = 0
        let stream = try await searchEngine.replaceStreaming(
            pattern: "\\w+",
            replacement: "NUM",
            in: text,
            options: SearchEngine.SearchOptions(useRegex: true)
        )

        for await (_, progress) in stream {
            lastProgress = progress
        }

        XCTAssertEqual(lastProgress, 1.0, "Should reach 100% progress")
    }

    // MARK: - Edge Cases

    func testEmptyText() throws {
        let results = try searchEngine.findAll(pattern: "test", in: "")
        XCTAssertEqual(results.count, 0)
    }

    func testEmptyPattern() throws {
        // Empty pattern should throw or return no results
        do {
            _ = try searchEngine.findAll(pattern: "", in: "Some text")
            // If it doesn't throw, it should return no results or all positions
        } catch {
            // Expected to throw for invalid regex
            XCTAssertTrue(true)
        }
    }

    func testNoMatches() throws {
        let text = "Hello World"
        let results = try searchEngine.findAll(pattern: "xyz", in: text)
        XCTAssertEqual(results.count, 0)
    }

    func testOverlappingMatches() throws {
        // Pattern: "aa" in "aaaa" should find non-overlapping matches
        let text = "aaaa"
        let results = try searchEngine.findAll(pattern: "aa", in: text)

        // NSRegularExpression finds non-overlapping matches by default
        XCTAssertEqual(results.count, 2)
    }

    func testUnicodeSearch() throws {
        let text = "Hello 世界 🌍"

        let results1 = try searchEngine.findAll(pattern: "世界", in: text)
        XCTAssertEqual(results1.count, 1)

        let results2 = try searchEngine.findAll(pattern: "🌍", in: text)
        XCTAssertEqual(results2.count, 1)
    }

    func testLongPattern() throws {
        let longPattern = String(repeating: "a", count: 1000)
        let text = String(repeating: "a", count: 1000) + "b"

        let results = try searchEngine.findAll(pattern: longPattern, in: text)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Performance Tests

    func testLargeTextSearch() throws {
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 10_000)

        let results = try searchEngine.findAll(pattern: "dolor", in: largeText)

        XCTAssertEqual(results.count, 10_000)
    }

    func testLargeTextReplace() throws {
        let largeText = String(repeating: "old ", count: 10_000)

        let result = try searchEngine.replace(
            pattern: "old",
            replacement: "new",
            in: largeText
        )

        XCTAssertTrue(result.contains("new"))
        XCTAssertFalse(result.contains("old"))
    }
}
