//
//  SnippetVariableProcessor.swift
//  Snipster
//
//  Created by RamosTech on 12/18/25.
//

import Foundation
import AppKit

nonisolated final class SnippetVariableProcessor: Sendable {
    static let shared = SnippetVariableProcessor()

    private init() {}

    /// Process all variables in snippet content
    func processVariables(in content: String) -> String {
        var processed = content

        // Process all variable patterns
        processed = processDateVariables(processed)
        processed = processTimeVariables(processed)
        processed = processClipboardVariables(processed)
        processed = processSystemVariables(processed)

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

        // {{CLIPBOARD}} - Insert clipboard content
        if let clipboardContent = NSPasteboard.general.string(forType: .string) {
            result = result.replacingOccurrences(of: "{{CLIPBOARD}}", with: clipboardContent)
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
