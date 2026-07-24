//
//  SnippetVariableProcessorInputTests.swift
//  SnipsterTests
//

import XCTest
@testable import Snipster

/// Tests the {{INPUT:label}} / {{INPUT:DATE:label}} extraction/substitution
/// in isolation — pure string logic, no popup window or
/// TextExpansionMonitor involved.
final class SnippetVariableProcessorInputTests: XCTestCase {

    // MARK: - extractInputFields

    func testExtractsSingleTextField() {
        let fields = SnippetVariableProcessor.extractInputFields(from: "Hello {{INPUT:Name}}")
        XCTAssertEqual(fields, [InputField(label: "Name", kind: .text)])
    }

    func testExtractsSingleDateField() {
        let fields = SnippetVariableProcessor.extractInputFields(from: "Due {{INPUT:DATE:Deadline}}")
        XCTAssertEqual(fields, [InputField(label: "Deadline", kind: .date)])
    }

    func testExtractsDistinctFieldsInOrderOfFirstAppearance() {
        let content = "Dear {{INPUT:Name}}, due {{INPUT:DATE:Deadline}} re: {{INPUT:Subject}}."
        let fields = SnippetVariableProcessor.extractInputFields(from: content)
        XCTAssertEqual(fields, [
            InputField(label: "Name", kind: .text),
            InputField(label: "Deadline", kind: .date),
            InputField(label: "Subject", kind: .text),
        ])
    }

    func testRepeatedLabelOnlyListedOnce() {
        let content = "{{INPUT:Name}} ... thanks, {{INPUT:Name}}"
        let fields = SnippetVariableProcessor.extractInputFields(from: content)
        XCTAssertEqual(fields, [InputField(label: "Name", kind: .text)])
    }

    func testRepeatedDateLabelOnlyListedOnce() {
        let content = "Due {{INPUT:DATE:Deadline}}, reminder on {{INPUT:DATE:Deadline}}"
        let fields = SnippetVariableProcessor.extractInputFields(from: content)
        XCTAssertEqual(fields, [InputField(label: "Deadline", kind: .date)])
    }

    func testMalformedEmptyLabelIsIgnored() {
        let fields = SnippetVariableProcessor.extractInputFields(from: "{{INPUT:}}")
        XCTAssertEqual(fields, [])
    }

    func testContentWithNoInputTokensReturnsEmpty() {
        let fields = SnippetVariableProcessor.extractInputFields(from: "{{DATE}} and {{CLIPBOARD}}")
        XCTAssertEqual(fields, [])
    }

    // MARK: - substituteInputValues

    func testSubstitutesSingleTextField() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "Hello {{INPUT:Name}}",
            values: ["Name": "Alan"]
        )
        XCTAssertEqual(result, "Hello Alan")
    }

    func testSubstitutesDateField() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "Due {{INPUT:DATE:Deadline}}",
            values: ["Deadline": "July 23, 2026"]
        )
        XCTAssertEqual(result, "Due July 23, 2026")
    }

    func testSubstitutesMixOfTextAndDateFields() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "Dear {{INPUT:Name}}, due {{INPUT:DATE:Deadline}}",
            values: ["Name": "Alan", "Deadline": "July 23, 2026"]
        )
        XCTAssertEqual(result, "Dear Alan, due July 23, 2026")
    }

    func testSubstitutesRepeatedLabelEverywhere() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "{{INPUT:Name}} ... thanks, {{INPUT:Name}}",
            values: ["Name": "Alan"]
        )
        XCTAssertEqual(result, "Alan ... thanks, Alan")
    }

    func testMissingValueLeavesTokenUntouched() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "Hello {{INPUT:Name}}",
            values: [:]
        )
        XCTAssertEqual(result, "Hello {{INPUT:Name}}")
    }

    func testMissingDateValueLeavesTokenUntouched() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "Due {{INPUT:DATE:Deadline}}",
            values: [:]
        )
        XCTAssertEqual(result, "Due {{INPUT:DATE:Deadline}}")
    }

    func testValueContainingBracesDoesNotCorruptOtherSubstitutions() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "{{INPUT:Code}} then {{INPUT:Name}}",
            values: ["Code": "{{not a real token}}", "Name": "Alan"]
        )
        XCTAssertEqual(result, "{{not a real token}} then Alan")
    }

    func testCoexistsWithOtherVariableTokensUntouched() {
        let result = SnippetVariableProcessor.substituteInputValues(
            in: "{{INPUT:Name}} copied on {{DATE}}: {{CLIPBOARD}}",
            values: ["Name": "Alan"]
        )
        XCTAssertEqual(result, "Alan copied on {{DATE}}: {{CLIPBOARD}}")
    }
}
