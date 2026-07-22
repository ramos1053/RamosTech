//
//  ClipboardHistoryBufferTests.swift
//  SnipsterTests
//

import XCTest
@testable import Snipster

final class ClipboardHistoryBufferTests: XCTestCase {

    func testInsertAddsEntryToFront() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        XCTAssertTrue(buffer.insert("first", at: Date()))
        XCTAssertTrue(buffer.insert("second", at: Date()))

        XCTAssertEqual(buffer.entries.count, 2)
        XCTAssertEqual(buffer.entries[0].content, "second")
        XCTAssertEqual(buffer.entries[1].content, "first")
    }

    func testInsertDedupsConsecutiveIdenticalContent() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        XCTAssertTrue(buffer.insert("repeat me", at: Date()))
        XCTAssertFalse(buffer.insert("repeat me", at: Date()))

        XCTAssertEqual(buffer.entries.count, 1)
    }

    func testInsertAllowsNonConsecutiveRepeats() {
        // Re-inserting something that used to be most-recent-but-isn't-anymore
        // should be treated as a fresh entry (this is how "select an old
        // history item" naturally bumps it back to the top).
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        XCTAssertTrue(buffer.insert("a", at: Date()))
        XCTAssertTrue(buffer.insert("b", at: Date()))
        XCTAssertTrue(buffer.insert("a", at: Date()))

        XCTAssertEqual(buffer.entries.map(\.content), ["a", "b", "a"])
    }

    func testInsertRejectsBlankOrWhitespaceOnlyContent() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        XCTAssertFalse(buffer.insert("", at: Date()))
        XCTAssertFalse(buffer.insert("   \n\t  ", at: Date()))
        XCTAssertEqual(buffer.entries.count, 0)
    }

    func testInsertBoundsContentLength() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        let huge = String(repeating: "x", count: ClipboardHistoryBuffer.maxEntryLength + 500)
        XCTAssertTrue(buffer.insert(huge, at: Date()))

        XCTAssertEqual(buffer.entries[0].content.count, ClipboardHistoryBuffer.maxEntryLength)
    }

    func testTrimDropsOldestBeyondCapacity() {
        var buffer = ClipboardHistoryBuffer(capacity: 3)
        for value in ["a", "b", "c", "d", "e"] {
            buffer.insert(value, at: Date())
        }

        XCTAssertEqual(buffer.entries.count, 3)
        XCTAssertEqual(buffer.entries.map(\.content), ["e", "d", "c"])
    }

    func testShrinkingCapacityAndTrimmingDropsExcess() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        for value in ["a", "b", "c", "d"] {
            buffer.insert(value, at: Date())
        }

        buffer.capacity = 2
        buffer.trim()

        XCTAssertEqual(buffer.entries.count, 2)
        XCTAssertEqual(buffer.entries.map(\.content), ["d", "c"])
    }

    func testClearRemovesAllEntries() {
        var buffer = ClipboardHistoryBuffer(capacity: 10)
        buffer.insert("a", at: Date())
        buffer.insert("b", at: Date())

        buffer.clear()

        XCTAssertTrue(buffer.entries.isEmpty)
    }
}
