//
//  SnippetVariableProcessor.swift
//  Snipster
//
//  Created by Alan Ramos on 12/18/25.
//

import Foundation
import AppKit

nonisolated final class SnippetVariableProcessor: Sendable {
    static let shared = SnippetVariableProcessor()

    /// Maximum length of clipboard content that may be substituted into a single
    /// `{{CLIPBOARD}}` token. Caps the blast radius of a snippet that references the
    /// clipboard many times while the clipboard holds a very large payload.
    private static let maxClipboardLength = 100_000

    /// Hard cap on the fully-expanded output. Together with the clipboard cap this
    /// bounds total memory/typing work regardless of how the snippet is constructed.
    private static let maxOutputLength = 1_000_000

    private init() {}

    /// Process all variables in snippet content
    func processVariables(in content: String) -> String {
        var processed = content

        // Process all variable patterns
        processed = processDateVariables(processed)
        processed = processTimeVariables(processed)
        processed = processClipboardVariables(processed)
        processed = processSystemVariables(processed)

        // Defensively bound the expanded result.
        if processed.count > Self.maxOutputLength {
            processed = String(processed.prefix(Self.maxOutputLength))
        }

        return processed
    }

    /// Extract cursor position marker and return content without marker
    func extractCursorPosition(from content: String) -> (content: String, cursorOffset: Int?) {
        let cursorMarker = "{{CURSOR}}"

        if let range = content.range(of: cursorMarker) {
            let offset = content.distance(from: content.startIndex, to: range.lowerBound)
            let cleanContent = content.replacingOccurrences(of: cursorMarker, with: "")
            return (cleanContent, offset)
        }

        return (content, nil)
    }

    // MARK: - Date Variables

    private func processDateVariables(_ content: String) -> String {
        var result = content

        // {{DATE}} - Short date format (12/18/25)
        result = result.replacingOccurrences(of: "{{DATE}}", with: formatDate(style: .short))

        // {{DATE:LONG}} - Long date format (December 18, 2025)
        result = result.replacingOccurrences(of: "{{DATE:LONG}}", with: formatDate(style: .long))

        // {{DATE:MEDIUM}} - Medium date format (Dec 18, 2025)
        result = result.replacingOccurrences(of: "{{DATE:MEDIUM}}", with: formatDate(style: .medium))

        // {{DATE:FULL}} - Full date format (Wednesday, December 18, 2025)
        result = result.replacingOccurrences(of: "{{DATE:FULL}}", with: formatDate(style: .full))

        // {{DATE:CUSTOM:format}} - Custom format using DateFormatter patterns
        result = processCustomDateFormat(result)

        return result
    }

    private func formatDate(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private func processCustomDateFormat(_ content: String) -> String {
        let pattern = #"\{\{DATE:CUSTOM:(.*?)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return content }

        var result = content
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let matchRange = Range(match.range, in: content),
                  let formatRange = Range(match.range(at: 1), in: content) else { continue }

            let format = String(content[formatRange])
            let formatter = DateFormatter()
            formatter.dateFormat = format
            let formatted = formatter.string(from: Date())

            result.replaceSubrange(matchRange, with: formatted)
        }

        return result
    }

    // MARK: - Time Variables

    private func processTimeVariables(_ content: String) -> String {
        var result = content

        // {{TIME}} - Short time format (2:30 PM)
        result = result.replacingOccurrences(of: "{{TIME}}", with: formatTime(style: .short))

        // {{TIME:LONG}} - Long time format (2:30:45 PM PST)
        result = result.replacingOccurrences(of: "{{TIME:LONG}}", with: formatTime(style: .long))

        // {{TIME:MEDIUM}} - Medium time format (2:30:45 PM)
        result = result.replacingOccurrences(of: "{{TIME:MEDIUM}}", with: formatTime(style: .medium))

        // {{TIME:24}} - 24-hour format (14:30)
        result = result.replacingOccurrences(of: "{{TIME:24}}", with: format24HourTime())

        return result
    }

    private func formatTime(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        return formatter.string(from: Date())
    }

    private func format24HourTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Clipboard Variables

    private func processClipboardVariables(_ content: String) -> String {
        var result = content

        // {{CLIPBOARD}} - Insert clipboard content.
        // Clamp the substituted value: clipboard content is fully untrusted and may be
        // arbitrarily large. Without a cap, a snippet containing several {{CLIPBOARD}}
        // tokens could explode into an enormous string.
        if let clipboardContent = NSPasteboard.general.string(forType: .string) {
            let bounded = String(clipboardContent.prefix(Self.maxClipboardLength))
            result = result.replacingOccurrences(of: "{{CLIPBOARD}}", with: bounded)
        }

        result = processClipboardHistoryVariables(result)

        return result
    }

    /// {{CLIPBOARD:N}} - Insert the Nth most recent clipboard history entry
    /// (1-based, most-recent-first). `lookup` defaults to the real clipboard
    /// history service but is injectable so this can be unit-tested without
    /// touching `NSPasteboard` or `ClipboardHistoryService` at all. Not
    /// `private`, so the test target can reach it via `@testable import`.
    func processClipboardHistoryVariables(
        _ content: String,
        lookup: (Int) -> String? = { ClipboardHistoryService.sharedUnsafe?.historyEntry(back: $0) }
    ) -> String {
        let pattern = #"\{\{CLIPBOARD:(\d+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return content }

        var result = content
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let matchRange = Range(match.range, in: content),
                  let indexRange = Range(match.range(at: 1), in: content),
                  let n = Int(content[indexRange]) else { continue }

            let value = lookup(n) ?? ""
            let bounded = String(value.prefix(Self.maxClipboardLength))
            result.replaceSubrange(matchRange, with: bounded)
        }

        return result
    }

    // MARK: - Input Variables

    /// Matches {{INPUT:DATE:label}} tokens specifically. Checked before the
    /// plain pattern below, since that more general pattern would otherwise
    /// capture "DATE:label" as a single (wrong) label.
    private static let inputDatePattern = #"\{\{INPUT:DATE:([^{}]+)\}\}"#

    /// Matches plain {{INPUT:label}} tokens. A label may not contain `{` or
    /// `}`, so a malformed/empty token like {{INPUT:}} simply fails to match
    /// and is left as literal text, matching how a non-numeric
    /// {{CLIPBOARD:abc}} is handled above.
    private static let inputPattern = #"\{\{INPUT:([^{}]+)\}\}"#

    /// Distinct {{INPUT:...}} fields in content, in order of first
    /// appearance, in order of first appearance across both token forms.
    /// The same label appearing more than once is only listed once, since a
    /// single popup field fills every occurrence of that label.
    static func extractInputFields(from content: String) -> [InputField] {
        struct RawMatch { let location: Int; let label: String; let kind: InputFieldKind }
        var rawMatches: [RawMatch] = []

        if let dateRegex = try? NSRegularExpression(pattern: inputDatePattern) {
            for match in dateRegex.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                guard match.numberOfRanges == 2,
                      let labelRange = Range(match.range(at: 1), in: content) else { continue }
                rawMatches.append(RawMatch(location: match.range.location, label: String(content[labelRange]), kind: .date))
            }
        }

        if let plainRegex = try? NSRegularExpression(pattern: inputPattern) {
            for match in plainRegex.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                guard match.numberOfRanges == 2,
                      let labelRange = Range(match.range(at: 1), in: content) else { continue }
                let label = String(content[labelRange])
                if label.hasPrefix("DATE:") { continue } // already captured above as a date field
                rawMatches.append(RawMatch(location: match.range.location, label: label, kind: .text))
            }
        }

        rawMatches.sort { $0.location < $1.location }

        var seen = Set<String>()
        var fields: [InputField] = []
        for raw in rawMatches where !seen.contains(raw.label) {
            seen.insert(raw.label)
            fields.append(InputField(label: raw.label, kind: raw.kind))
        }
        return fields
    }

    /// Replaces every {{INPUT:label}} and {{INPUT:DATE:label}} occurrence
    /// with `values[label]` — date fields are looked up by their plain
    /// label, same as text fields, since the caller already formats the
    /// picked date into a string before this is called. A label with no
    /// matching value is left as-is (defensive — shouldn't happen in
    /// practice, since the popup is always built from `extractInputFields`'
    /// own output).
    static func substituteInputValues(in content: String, values: [String: String]) -> String {
        var result = content

        if let dateRegex = try? NSRegularExpression(pattern: inputDatePattern) {
            let matches = dateRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard match.numberOfRanges == 2,
                      let matchRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else { continue }
                let label = String(result[labelRange])
                guard let value = values[label] else { continue }
                result.replaceSubrange(matchRange, with: value)
            }
        }

        if let plainRegex = try? NSRegularExpression(pattern: inputPattern) {
            let matches = plainRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard match.numberOfRanges == 2,
                      let matchRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else { continue }
                let label = String(result[labelRange])
                if label.hasPrefix("DATE:") { continue } // already substituted above
                guard let value = values[label] else { continue }
                result.replaceSubrange(matchRange, with: value)
            }
        }

        return result
    }

    // MARK: - System Variables

    private func processSystemVariables(_ content: String) -> String {
        var result = content

        // {{USERNAME}} - Current user's full name
        if let fullName = NSFullUserName() as String? {
            result = result.replacingOccurrences(of: "{{USERNAME}}", with: fullName)
        }

        // {{USER}} - Current user's login name
        result = result.replacingOccurrences(of: "{{USER}}", with: NSUserName())

        // {{HOSTNAME}} - Computer hostname
        if let hostname = Host.current().name {
            result = result.replacingOccurrences(of: "{{HOSTNAME}}", with: hostname)
        }

        return result
    }
}

/// What kind of control a {{INPUT:...}} field should show in the popup.
enum InputFieldKind: Equatable {
    case text
    case date
}

/// One field to prompt for — a label plus which control renders it.
struct InputField: Equatable {
    let label: String
    let kind: InputFieldKind
}
