import XCTest
@testable import PIP

/// Performance benchmarks for PieceTable
///
/// ## Running Benchmarks:
/// ```bash
/// xcodebuild test -project PIP.xcodeproj -scheme PIP -destination 'platform=macOS' \
///   -only-testing:PIPBenchmarks/PieceTableBenchmarks
/// ```
///
/// ## Interpreting Results:
/// - Insert operations should be O(log n) to O(n) depending on piece splits
/// - Delete operations should be O(n) for finding pieces
/// - getText should be O(n) linear with total text size
/// - Large edits (1MB+) should complete in < 100ms
@MainActor
final class PieceTableBenchmarks: XCTestCase {

    // MARK: - Insert Benchmarks

    /// Benchmark: Sequential inserts at end (append)
    /// Expected: Fast O(1) append operations
    func testBenchmarkSequentialAppend() {
        let iterations = 10_000

        measure {
            let table = PieceTable()
            for i in 0..<iterations {
                table.insert(text: "Line \(i)\n", at: table.length)
            }
        }
    }

    /// Benchmark: Inserts at beginning
    /// Expected: Slower than append due to piece array manipulation
    func testBenchmarkSequentialPrepend() {
        let iterations = 1_000 // Reduced due to O(n) array insertion

        measure {
            let table = PieceTable()
            for i in 0..<iterations {
                table.insert(text: "Line \(i)\n", at: 0)
            }
        }
    }

    /// Benchmark: Random position inserts
    /// Expected: Variable performance based on piece splitting
    func testBenchmarkRandomInserts() {
        let iterations = 1_000
        let table = PieceTable()

        // Pre-populate with some text
        for i in 0..<100 {
            table.insert(text: "Initial line \(i)\n", at: table.length)
        }

        measure {
            for i in 0..<iterations {
                let randomPos = Int.random(in: 0...table.length)
                table.insert(text: "X", at: randomPos)
            }
        }
    }

    /// Benchmark: Large single insert
    /// Expected: Fast due to single piece creation
    func testBenchmarkLargeInsert() {
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100_000)

        measure {
            let table = PieceTable()
            table.insert(text: largeText, at: 0)
        }
    }

    // MARK: - Delete Benchmarks

    /// Benchmark: Sequential deletes from end
    /// Expected: Fast O(1) operations
    func testBenchmarkSequentialDeleteFromEnd() {
        let table = PieceTable()

        // Setup: Create text to delete
        for i in 0..<1_000 {
            table.insert(text: "Line \(i)\n", at: table.length)
        }

        measure {
            // Delete from end repeatedly
            while table.length > 0 {
                let deleteCount = min(10, table.length)
                table.delete(range: (table.length - deleteCount)..<table.length)
            }
        }
    }

    /// Benchmark: Delete from beginning
    /// Expected: Moderate performance
    func testBenchmarkDeleteFromBeginning() {
        measure {
            let table = PieceTable()

            // Setup
            for i in 0..<1_000 {
                table.insert(text: "Line \(i)\n", at: table.length)
            }

            // Delete from beginning
            while table.length > 0 {
                let deleteCount = min(10, table.length)
                table.delete(range: 0..<deleteCount)
            }
        }
    }

    /// Benchmark: Large range delete
    /// Expected: Fast due to minimal piece manipulations
    func testBenchmarkLargeRangeDelete() {
        measure {
            let table = PieceTable()

            // Setup: Large text
            let largeText = String(repeating: "Text ", count: 50_000)
            table.insert(text: largeText, at: 0)

            // Delete large range
            let midPoint = table.length / 2
            let quarterSize = table.length / 4
            table.delete(range: (midPoint - quarterSize)..<(midPoint + quarterSize))
        }
    }

    // MARK: - getText Benchmarks

    /// Benchmark: getText on single piece
    /// Expected: Very fast, minimal overhead
    func testBenchmarkGetTextSinglePiece() {
        let largeText = String(repeating: "Lorem ipsum ", count: 100_000)
        let table = PieceTable(text: largeText)

        measure {
            _ = table.getText()
        }
    }

    /// Benchmark: getText on many pieces
    /// Expected: Slower than single piece, but still linear
    func testBenchmarkGetTextManyPieces() {
        let table = PieceTable()

        // Create many pieces through repeated inserts
        for i in 0..<1_000 {
            table.insert(text: "Line \(i)\n", at: table.length)
        }

        measure {
            _ = table.getText()
        }
    }

    /// Benchmark: getText on fragmented document
    /// Expected: Moderate performance based on piece count
    func testBenchmarkGetTextFragmented() {
        let table = PieceTable()

        // Create initial text
        for i in 0..<500 {
            table.insert(text: "Line \(i)\n", at: table.length)
        }

        // Fragment by inserting in middle repeatedly
        for i in 0..<100 {
            let midPoint = table.length / 2
            table.insert(text: "Insert \(i)\n", at: midPoint)
        }

        measure {
            _ = table.getText()
        }
    }

    // MARK: - getSubstring Benchmarks

    /// Benchmark: Small substring extraction
    /// Expected: Fast, minimal piece traversal
    func testBenchmarkSmallSubstring() {
        let table = PieceTable()

        for i in 0..<10_000 {
            table.insert(text: "Line \(i)\n", at: table.length)
        }

        measure {
            for _ in 0..<1_000 {
                let start = Int.random(in: 0..<(table.length - 100))
                _ = table.getSubstring(range: start..<(start + 100))
            }
        }
    }

    /// Benchmark: Large substring extraction
    /// Expected: Linear with substring size
    func testBenchmarkLargeSubstring() {
        let largeText = String(repeating: "Text ", count: 100_000)
        let table = PieceTable(text: largeText)

        measure {
            let quarterSize = table.length / 4
            _ = table.getSubstring(range: quarterSize..<(quarterSize * 3))
        }
    }

    // MARK: - Realistic Usage Benchmarks

    /// Benchmark: Simulate typing with backspace
    /// Expected: Fast, real-time performance
    func testBenchmarkTypingSimulation() {
        let textToType = "The quick brown fox jumps over the lazy dog. "

        measure {
            let table = PieceTable()

            // Type text 100 times with occasional backspaces
            for round in 0..<100 {
                for (index, char) in textToType.enumerated() {
                    table.insert(text: String(char), at: table.length)

                    // Occasionally backspace
                    if round % 10 == 0 && index % 5 == 0 && table.length > 0 {
                        table.delete(range: (table.length - 1)..<table.length)
                    }
                }
            }
        }
    }

    /// Benchmark: Simulate find-and-replace
    /// Expected: Moderate performance
    func testBenchmarkFindAndReplace() {
        let table = PieceTable()

        // Setup: Create document with pattern
        for i in 0..<1_000 {
            table.insert(text: "Line \(i) contains PATTERN here\n", at: table.length)
        }

        measure {
            let text = table.getText()
            var searchStart = 0

            while let range = text.range(of: "PATTERN", range: text.index(text.startIndex, offsetBy: searchStart)..<text.endIndex) {
                // Convert String.Index to Int offset (simplified for benchmark)
                let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
                let upperBound = text.distance(from: text.startIndex, to: range.upperBound)

                // Delete old text
                table.delete(range: lowerBound..<upperBound)

                // Insert replacement
                table.insert(text: "REPLACED", at: lowerBound)

                searchStart = lowerBound + "REPLACED".count

                // Prevent infinite loop in case of issues
                if searchStart >= table.length {
                    break
                }
            }
        }
    }

    /// Benchmark: Large document edit at multiple locations
    /// Expected: Should handle large documents efficiently
    func testBenchmarkLargeDocumentMultipleEdits() {
        measure {
            let table = PieceTable()

            // Create a 1MB document
            let lineText = "This is a line of text that will be repeated many times to create a large document.\n"
            let linesNeeded = (1_000_000 / lineText.count) // ~1MB

            for _ in 0..<linesNeeded {
                table.insert(text: lineText, at: table.length)
            }

            // Perform edits at 10 random locations
            for _ in 0..<10 {
                let randomPos = Int.random(in: 0..<table.length)
                table.insert(text: "\n--- EDIT MARKER ---\n", at: randomPos)
            }

            // Delete some ranges
            for _ in 0..<5 {
                let randomStart = Int.random(in: 0..<(table.length - 1000))
                table.delete(range: randomStart..<(randomStart + 500))
            }
        }
    }

    // MARK: - Grapheme Cluster Benchmarks

    /// Benchmark: Operations with emoji content
    /// Expected: Slightly slower due to grapheme counting
    func testBenchmarkEmojiContent() {
        let emojiText = "Hello 👋 World 🌍 with emoji 😀 content 🎉"

        measure {
            let table = PieceTable()

            for _ in 0..<1_000 {
                table.insert(text: emojiText, at: table.length)
            }

            _ = table.getText()
        }
    }

    /// Benchmark: Mixed Unicode content
    /// Expected: Moderate performance with complex graphemes
    func testBenchmarkMixedUnicode() {
        let mixedText = "English, Español, 日本語, 한국어, العربية, עברית 🌍"

        measure {
            let table = PieceTable()

            for _ in 0..<500 {
                table.insert(text: mixedText, at: table.length)
                table.insert(text: "\n", at: table.length)
            }

            _ = table.getText()
        }
    }
}
