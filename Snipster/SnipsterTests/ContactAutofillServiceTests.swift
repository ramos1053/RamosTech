//
//  ContactAutofillServiceTests.swift
//  SnipsterTests
//

import XCTest
@testable import Snipster

/// Tests ContactAutofillService.classify(label:) — pure label heuristics,
/// no CNContactStore access involved.
final class ContactAutofillServiceTests: XCTestCase {

    func testClientNameClassifiesAsFullName() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Client Name"), .fullName)
    }

    func testPlainNameClassifiesAsFullName() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Name"), .fullName)
    }

    func testContactClassifiesAsFullName() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Contact"), .fullName)
    }

    func testContactEmailClassifiesAsEmail() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Contact Email"), .email)
    }

    func testPhoneClassifiesAsPhoneNumber() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Phone"), .phoneNumber)
    }

    func testMobileNumberClassifiesAsPhoneNumber() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Mobile Number"), .phoneNumber)
    }

    func testCompanyClassifiesAsOrganization() {
        XCTAssertEqual(ContactAutofillService.classify(label: "Company"), .organization)
    }

    func testCompanyNameClassifiesAsOrganizationNotFullName() {
        // "Company Name" contains both an organization word and a name word —
        // organization must win.
        XCTAssertEqual(ContactAutofillService.classify(label: "Company Name"), .organization)
    }

    func testProjectNameIsNotClassified() {
        XCTAssertNil(ContactAutofillService.classify(label: "Project Name"))
    }

    func testFilePathIsNotClassified() {
        XCTAssertNil(ContactAutofillService.classify(label: "File Path"))
    }

    func testDeadlineIsNotClassified() {
        XCTAssertNil(ContactAutofillService.classify(label: "Deadline"))
    }

    func testBudgetIsNotClassified() {
        XCTAssertNil(ContactAutofillService.classify(label: "Budget"))
    }

    func testClassificationIsCaseInsensitive() {
        XCTAssertEqual(ContactAutofillService.classify(label: "CLIENT EMAIL"), .email)
    }
}
