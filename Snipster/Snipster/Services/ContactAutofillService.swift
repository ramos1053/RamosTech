//
//  ContactAutofillService.swift
//  Snipster
//

import Foundation
// @preconcurrency — Contacts predates Swift concurrency and its types
// (CNKeyDescriptor, CNContact, etc.) aren't Sendable-audited; this suppresses
// the resulting warnings for a framework we don't control instead of forcing
// unsafe workarounds onto our own, otherwise-correct nonisolated code.
@preconcurrency import Contacts

/// Which piece of a contact a template field is asking for.
enum ContactFieldRole: Equatable {
    case fullName
    case organization
    case email
    case phoneNumber
}

/// A UI-agnostic snapshot of one matched contact — callers never hold onto or
/// re-decode a CNContact directly.
struct ContactMatch: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displaySubtitle: String
    let fullName: String?
    let organization: String?
    let email: String?
    let phoneNumber: String?

    func value(for role: ContactFieldRole) -> String? {
        switch role {
        case .fullName:
            return fullName ?? organization
        case .organization:
            return organization
        case .email:
            return email
        case .phoneNumber:
            return phoneNumber
        }
    }
}

/// `nonisolated` end to end (aside from `requestAccess()`'s own explicit
/// `@MainActor`) — `search`/`makeMatch` do synchronous `CNContactStore` I/O
/// that's meant to run off the main thread from `ContactPickerWindow`'s
/// `Task.detached`; without this, the module's default MainActor isolation
/// would silently force them onto the main thread instead, contradicting
/// their own doc comments.
nonisolated enum ContactAutofillService {
    // Checked in this order — organization/email/phone win over the generic
    // "name" check, so a label like "Company Name" resolves to .organization,
    // not .fullName.
    private static let organizationWords = ["company", "business", "organization", "employer"]
    private static let emailWords = ["email", "e-mail"]
    private static let phoneWords = ["phone", "mobile", "cell", "tel"]
    private static let nameWords = ["name", "client", "contact", "customer", "recipient", "attendee"]

    // A label containing one of these is never treated as a person's name,
    // even if it also contains a name word — "Project Name" and "File Path"
    // shouldn't grow a contact-picker button.
    private static let nameExclusions = ["file", "project", "product", "folder", "path", "brand", "template", "snippet"]

    /// Classifies a field label by which contact property it's most likely
    /// asking for, or nil if the label doesn't look contact-related at all.
    /// Pure and label-only — a heuristic, not a token, per the "smart
    /// auto-populate with no new syntax" direction.
    static func classify(label: String) -> ContactFieldRole? {
        let lower = label.lowercased()

        if organizationWords.contains(where: lower.contains) { return .organization }
        if emailWords.contains(where: lower.contains) { return .email }
        if phoneWords.contains(where: lower.contains) { return .phoneNumber }
        if nameWords.contains(where: lower.contains), !nameExclusions.contains(where: lower.contains) {
            return .fullName
        }
        return nil
    }

    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Requests Contacts access if not already determined. Returns whether
    /// access is (now) granted. `@MainActor` because Apple's docs require
    /// `CNContactStore.requestAccess(for:)` to be called from the main
    /// thread — this guarantees that regardless of what thread the
    /// caller's own Task happens to be running on. The
    /// `com.apple.security.personal-information.addressbook` entitlement
    /// matters too: Snipster's hardened runtime (required for Developer ID
    /// signing) blocks tccd from even showing the consent prompt without it.
    @MainActor
    static func requestAccess() async -> Bool {
        switch authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                CNContactStore().requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// `CNContactFormatter.string(from:style:)` (used in `makeMatch` below)
    /// reads more than givenName/familyName internally — middleName, name
    /// prefix/suffix, etc. Fetching only the two obvious name keys meant it
    /// tried to read a property that was never fetched, which throws
    /// `CNPropertyNotFetchedException` — an Objective-C exception Swift
    /// can't catch, so it took the whole process down instead of failing
    /// gracefully. `descriptorForRequiredKeys(for:)` is Apple's own
    /// supported way to fetch exactly what the formatter needs.
    private static let keysToFetch: [CNKeyDescriptor] = [
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
    ]

    /// Fetches contacts matching `query` by name (an empty query returns the
    /// first `limit` contacts, unfiltered, so the picker isn't blank before
    /// the user types). Synchronous CNContactStore I/O — call off the main
    /// thread for anything beyond a small address book.
    static func search(_ query: String, limit: Int = 30) -> [ContactMatch] {
        let store = CNContactStore()
        var matches: [ContactMatch] = []

        do {
            if query.isEmpty {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var collected: [CNContact] = []
                try store.enumerateContacts(with: request) { contact, stop in
                    collected.append(contact)
                    if collected.count >= limit { stop.pointee = true }
                }
                matches = collected.map(makeMatch)
            } else {
                let predicate = CNContact.predicateForContacts(matchingName: query)
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                matches = contacts.prefix(limit).map(makeMatch)
            }
        } catch {
            matches = []
        }

        return matches.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func makeMatch(_ contact: CNContact) -> ContactMatch {
        let formattedName = CNContactFormatter.string(from: contact, style: .fullName)
        let fullName = (formattedName?.isEmpty ?? true) ? nil : formattedName
        let organization = contact.organizationName.isEmpty ? nil : contact.organizationName
        let email = contact.emailAddresses.first.map { $0.value as String }
        let phone = contact.phoneNumbers.first?.value.stringValue

        return ContactMatch(
            id: contact.identifier,
            displayName: fullName ?? organization ?? "Unknown",
            displaySubtitle: email ?? phone ?? organization ?? "",
            fullName: fullName,
            organization: organization,
            email: email,
            phoneNumber: phone
        )
    }
}
