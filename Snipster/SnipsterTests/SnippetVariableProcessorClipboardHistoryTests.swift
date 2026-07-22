//
//  SnippetVariableProcessorClipboardHistoryTests.swift
//  SnipsterTests
//

import XCTest
@testable import Snipster

/// Tests the {{CLIPBOARD:N}} regex extraction/replacement in isolation, using
/// an injected fake `lookup` closure so no real pasteboard or
/// `ClipboardHistoryService` is touched.
final class SnippetVariableProcessorClipboardHistoryTests: XCTestCase {

    private let processor = SnippetVariableProcessor.shared

    func testSingleTokenIsReplacedWithLookupValue() {
        let result = processor.processClipboardHistoryVariables(
            "Value: {{CLIPBOARD:1}}",
            lookup: { n in n == 1 ? "history-one" : nil }
        )
        XCTAssertEqual(result, "Value: history-one")
    }

    func testMultipleDistinctTokensInOneString() {
        let result = processor.processClipboardHistoryVariables(
            "{{CLIPBOARD:1}} then {{CLIPBOARD:2}}",
            lookup: { n in "entry-\(n)" }
        )
        XCTAssertEqual(result, "entry-1 then entry-2")
    }

    func testRepeatedTokenIsReplacedEverywhere() {
        let result = processor.processClipboardHistoryVariables(
            "{{CLIPBOARD:3}} and again {{CLIPBOARD:3}}",
            lookup: { n in "entry-\(n)" }
        )
        XCTAssertEqual(result, "entry-3 and again entry-3")
    }

    func testOutOfRangeIndexResolvesToEmptyString() {
        let result = processor.processClipboardHistoryVariables(
            "Missing: [{{CLIPBOARD:99}}]",
            lookup: { _ in nil }
        )
        XCTAssertEqual(result, "Missing: []")
    }

    func testNonNumericIndexIsLeftUntouched() {
        // {{CLIPBOARD:abc}} doesn't match \d+, so it should pass through
        // unchanged rather than being (mis)matched.
        let result = processor.processClipboardHistoryVariables(
            "{{CLIPBOARD:abc}}",
            lookup: { _ in "should-not-appear" }
        )
        XCTAssertEqual(result, "{{CLIPBOARD:abc}}")
    }

    func testBareClipboardTokenIsUnaffectedByHistoryProcessing() {
        // {{CLIPBOARD}} (no index) is handled by a separate code path in
        // processClipboardVariables and must be left alone here.
        let result = processor.processClipboardHistoryVariables(
            "{{CLIPBOARD}} and {{CLIPBOARD:1}}",
            lookup: { n in "entry-\(n)" }
        )
        XCTAssertEqual(result, "{{CLIPBOARD}} and entry-1")
    }

    func testContentWithNoTokensIsUnchanged() {
        let result = processor.processClipboardHistoryVariables(
            "Nothing to see here",
            lookup: { _ in "unused" }
        )
        XCTAssertEqual(result, "Nothing to see here")
    }
}
