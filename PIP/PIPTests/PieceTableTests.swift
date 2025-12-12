import XCTest
@testable import PIP

/// Comprehensive unit tests for PieceTable
/// Tests grapheme-safe operations, insert, delete, and edge cases
@MainActor
final class PieceTableTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitEmpty() {
        let table = PieceTable()
        XCTAssertEqual(table.length, 0)
        XCTAssertEqual(table.getText(), "")
    }

    func testInitWithText() {
        let text = "Hello, World!"
        let table = PieceTable(text: text)
        XCTAssertEqual(table.length, text.count)
        XCTAssertEqual(table.getText(), text)
    }

    // MARK: - Grapheme Cluster Tests

    func testGraphemeClusterEmoji() {
        // Single emoji (👨‍👩‍👧‍👦 is ONE grapheme cluster)
        let emoji = "👨‍👩‍👧‍👦"
        let table = PieceTable(text: emoji)

        // Should count as 1 grapheme cluster, not multiple UTF-16 code units
        XCTAssertEqual(table.length, 1, "Family emoji should be counted as 1 grapheme cluster")
        XCTAssertEqual(table.getText(), emoji)
    }

    func testGraphemeClusterCombiningMarks() {
        // "é" can be represented as e + combining acute accent
        let text = "e\u{0301}" // e + combining acute
        let table = PieceTable(text: text)

        // Should count as 1 grapheme cluster
        XCTAssertEqual(table.length, 1, "e with combining accent should be 1 grapheme cluster")
        XCTAssertEqual(table.getText(), text)
    }

    func testGraphemeClusterFlagEmoji() {
        // 🇺🇸 is two regional indicator symbols but ONE grapheme cluster
        let flag = "🇺🇸"
        let table = PieceTable(text: flag)

        XCTAssertEqual(table.length, 1, "Flag emoji should be counted as 1 grapheme cluster")
        XCTAssertEqual(table.getText(), flag)
    }

    func testGraphemeClusterMixedContent() {
        // Mix of ASCII, emoji, and combining marks
        let text = "Hello 👋 café"
        let table = PieceTable(text: text)

        // Count grapheme clusters manually: H-e-l-l-o-SPACE-👋-SPACE-c-a-f-e-́
        // Note: café might be cafe + combining accent
        XCTAssertEqual(table.getText(), text)
        XCTAssertGreaterThan(table.length, 0)
    }

    // MARK: - Insert Tests

    func testInsertAtBeginning() {
        let table = PieceTable(text: "World")
        table.insert(text: "Hello ", at: 0)
        XCTAssertEqual(table.getText(), "Hello World")
    }

    func testInsertAtEnd() {
        let table = PieceTable(text: "Hello")
        table.insert(text: " World", at: 5)
        XCTAssertEqual(table.getText(), "Hello World")
    }

    func testInsertInMiddle() {
        let table = PieceTable(text: "HelloWorld")
        table.insert(text: " ", at: 5)
        XCTAssertEqual(table.getText(), "Hello World")
    }

    func testInsertEmpty() {
        let table = PieceTable(text: "Hello")
        let originalLength = table.length
        table.insert(text: "", at: 2)
        XCTAssertEqual(table.length, originalLength)
        XCTAssertEqual(table.getText(), "Hello")
    }

    func testInsertEmojiAtGraphemeBoundary() {
        let table = PieceTable(text: "Hello")
        table.insert(text: "👋", at: 5)
        XCTAssertEqual(table.getText(), "Hello👋")
        XCTAssertEqual(table.length, 6) // 5 ASCII + 1 emoji
    }

    func testMultipleInserts() {
        let table = PieceTable()
        table.insert(text: "H", at: 0)
        table.insert(text: "e", at: 1)
        table.insert(text: "l", at: 2)
        table.insert(text: "l", at: 3)
        table.insert(text: "o", at: 4)
        XCTAssertEqual(table.getText(), "Hello")
    }

    // MARK: - Delete Tests

    func testDeleteFromBeginning() {
        let table = PieceTable(text: "Hello World")
        table.delete(range: 0..<6)
        XCTAssertEqual(table.getText(), "World")
    }

    func testDeleteFromEnd() {
        let table = PieceTable(text: "Hello World")
        table.delete(range: 5..<11)
        XCTAssertEqual(table.getText(), "Hello")
    }

    func testDeleteFromMiddle() {
        let table = PieceTable(text: "Hello World")
        table.delete(range: 5..<6) // Delete the space
        XCTAssertEqual(table.getText(), "HelloWorld")
    }

    func testDeleteEntireContent() {
        let table = PieceTable(text: "Hello")
        let length = table.length
        table.delete(range: 0..<length)
        XCTAssertEqual(table.getText(), "")
        XCTAssertEqual(table.length, 0)
    }

    func testDeleteEmptyRange() {
        let table = PieceTable(text: "Hello")
        table.delete(range: 2..<2) // Empty range
        XCTAssertEqual(table.getText(), "Hello")
    }

    func testDeleteEmoji() {
        let table = PieceTable(text: "Hello👋World")
        // Delete the emoji (at grapheme index 5)
        table.delete(range: 5..<6)
        XCTAssertEqual(table.getText(), "HelloWorld")
    }

    // MARK: - Substring Tests

    func testGetSubstringFromBeginning() {
        let table = PieceTable(text: "Hello World")
        let substring = table.getSubstring(range: 0..<5)
        XCTAssertEqual(substring, "Hello")
    }

    func testGetSubstringFromEnd() {
        let table = PieceTable(text: "Hello World")
        let substring = table.getSubstring(range: 6..<11)
        XCTAssertEqual(substring, "World")
    }

    func testGetSubstringFromMiddle() {
        let table = PieceTable(text: "Hello World")
        let substring = table.getSubstring(range: 2..<9)
        XCTAssertEqual(substring, "llo Wor")
    }

    func testGetSubstringEntireText() {
        let table = PieceTable(text: "Hello World")
        let substring = table.getSubstring(range: 0..<table.length)
        XCTAssertEqual(substring, table.getText())
    }

    func testGetSubstringWithEmoji() {
        let table = PieceTable(text: "Hello👋World")
        let substring = table.getSubstring(range: 5..<6)
        XCTAssertEqual(substring, "👋")
    }

    // MARK: - Clear and Replace Tests

    func testClear() {
        let table = PieceTable(text: "Hello World")
        table.clear()
        XCTAssertEqual(table.length, 0)
        XCTAssertEqual(table.getText(), "")
    }

    func testReplaceAll() {
        let table = PieceTable(text: "Hello")
        table.replaceAll(with: "Goodbye")
        XCTAssertEqual(table.getText(), "Goodbye")
    }

    func testReplaceAllWithEmptyString() {
        let table = PieceTable(text: "Hello")
        table.replaceAll(with: "")
        XCTAssertEqual(table.length, 0)
        XCTAssertEqual(table.getText(), "")
    }

    // MARK: - Complex Editing Scenarios

    func testComplexEditSequence() {
        let table = PieceTable(text: "The quick brown fox")

        // Insert at middle
        table.insert(text: "very ", at: 4)
        XCTAssertEqual(table.getText(), "The very quick brown fox")

        // Delete a word
        table.delete(range: 15..<21) // Delete "brown "
        XCTAssertEqual(table.getText(), "The very quick fox")

        // Insert at end
        table.insert(text: " jumps", at: table.length)
        XCTAssertEqual(table.getText(), "The very quick fox jumps")
    }

    func testRepeatedInsertsAndDeletes() {
        let table = PieceTable()

        // Simulate typing
        for char in "Hello" {
            table.insert(text: String(char), at: table.length)
        }
        XCTAssertEqual(table.getText(), "Hello")

        // Simulate backspace
        table.delete(range: (table.length - 1)..<table.length)
        XCTAssertEqual(table.getText(), "Hell")

        // Continue typing
        table.insert(text: "o", at: table.length)
        table.insert(text: " ", at: table.length)
        table.insert(text: "World", at: table.length)
        XCTAssertEqual(table.getText(), "Hello World")
    }

    // MARK: - Boundary Tests

    func testInsertAtInvalidOffset() {
        let table = PieceTable(text: "Hello")
        let originalText = table.getText()

        // Try to insert at negative offset
        table.insert(text: "X", at: -1)
        XCTAssertEqual(table.getText(), originalText, "Should not modify on invalid offset")

        // Try to insert beyond end
        table.insert(text: "X", at: table.length + 10)
        XCTAssertEqual(table.getText(), originalText, "Should not modify on invalid offset")
    }

    func testDeleteInvalidRange() {
        let table = PieceTable(text: "Hello")
        let originalText = table.getText()

        // Try to delete with negative start
        table.delete(range: -1..<3)
        XCTAssertEqual(table.getText(), originalText, "Should not modify on invalid range")

        // Try to delete beyond end
        table.delete(range: 2..<100)
        XCTAssertEqual(table.getText(), originalText, "Should not modify on invalid range")
    }

    func testGetSubstringInvalidRange() {
        let table = PieceTable(text: "Hello")

        // Try to get substring with invalid range
        let substring1 = table.getSubstring(range: -1..<3)
        XCTAssertEqual(substring1, "", "Should return empty string for invalid range")

        let substring2 = table.getSubstring(range: 2..<100)
        XCTAssertEqual(substring2, "", "Should return empty string for invalid range")
    }

    // MARK: - Large Text Tests

    func testLargeTextInsertion() {
        let table = PieceTable()
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)

        table.insert(text: largeText, at: 0)
        XCTAssertEqual(table.getText(), largeText)
    }

    func testLargeTextWithMultipleEdits() {
        let initialText = String(repeating: "Line\n", count: 1000)
        let table = PieceTable(text: initialText)

        // Insert at various positions
        table.insert(text: "START\n", at: 0)
        table.insert(text: "MIDDLE\n", at: table.length / 2)
        table.insert(text: "END\n", at: table.length)

        let result = table.getText()
        XCTAssertTrue(result.hasPrefix("START\n"))
        XCTAssertTrue(result.hasSuffix("END\n"))
        XCTAssertTrue(result.contains("MIDDLE\n"))
    }

    // MARK: - Unicode Edge Cases

    func testZeroWidthJoiner() {
        // 👨‍💻 is man + ZWJ + computer
        let text = "👨‍💻"
        let table = PieceTable(text: text)

        XCTAssertEqual(table.length, 1, "ZWJ sequence should be 1 grapheme cluster")
        XCTAssertEqual(table.getText(), text)
    }

    func testVariationSelectors() {
        // Some emoji have variation selectors
        let text = "☺️" // White smiling face + variation selector
        let table = PieceTable(text: text)

        XCTAssertEqual(table.length, 1, "Emoji with variation selector should be 1 grapheme cluster")
        XCTAssertEqual(table.getText(), text)
    }

    func testSkinToneModifiers() {
        // Emoji with skin tone modifier
        let text = "👋🏽" // Waving hand + medium skin tone
        let table = PieceTable(text: text)

        XCTAssertEqual(table.length, 1, "Emoji with skin tone should be 1 grapheme cluster")
        XCTAssertEqual(table.getText(), text)
    }
}
