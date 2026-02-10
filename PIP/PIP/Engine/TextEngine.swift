import Foundation
import SwiftUI

/// Main text engine coordinating the piece table, undo/redo, and text operations
@MainActor
final class TextEngine: ObservableObject {

    // MARK: - Types

    enum LineEnding: CustomStringConvertible {
        case lf      // \n (Unix/macOS)
        case crlf    // \r\n (Windows)
        case cr      // \r (Classic Mac)

        var description: String {
            switch self {
            case .lf: return "LF"
            case .crlf: return "CRLF"
            case .cr: return "CR"
            }
        }

        var separator: String {
            switch self {
            case .lf: return "\n"
            case .crlf: return "\r\n"
            case .cr: return "\r"
            }
        }
    }

    // MARK: - Properties

    @Published private(set) var text: String = ""
    @Published var cursorPosition: Int = 0 {
        didSet {
            updateLineAndColumn()
        }
    }
    @Published var selectionRange: Range<Int>?
    @Published private(set) var lineEnding: LineEnding = .lf
    @Published private(set) var encoding: String = "UTF-8"
    @Published private(set) var isModified: Bool = false
    @Published private(set) var currentLine: Int = 1
    @Published private(set) var currentColumn: Int = 1

    private let pieceTable = PieceTable()
    private let undoManager = TextUndoManager()

    private func updateLineAndColumn() {
        // Clamp cursor position to valid range
        let safeCursor = max(0, min(cursorPosition, text.count))

        let beforeCursor = String(text.prefix(safeCursor))

        // Calculate line number (1-indexed)
        let lines = beforeCursor.components(separatedBy: .newlines)
        let newLine = max(1, lines.count)

        // Calculate column number (1-indexed)
        let newColumn: Int
        if let lastNewline = beforeCursor.lastIndex(of: "\n") {
            let lineStart = beforeCursor.index(after: lastNewline)
            newColumn = beforeCursor.distance(from: lineStart, to: beforeCursor.endIndex) + 1
        } else {
            newColumn = beforeCursor.count + 1
        }

        currentLine = newLine
        currentColumn = newColumn
    }

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    // MARK: - Initialization

    init(initialText: String = "") {
        if !initialText.isEmpty {
            loadText(initialText)
        } else {
            updateLineAndColumn()
        }
    }

    // MARK: - Text Loading

    func loadText(_ newText: String) {
        pieceTable.replaceAll(with: newText)
        text = pieceTable.getText()
        cursorPosition = 0
        selectionRange = nil
        undoManager.clear()
        isModified = false

        // Detect line ending
        lineEnding = detectLineEnding(in: newText)

        // Initialize line and column
        updateLineAndColumn()

        // Explicitly notify observers of the change
        objectWillChange.send()
    }

    private func detectLineEnding(in text: String) -> LineEnding {
        if text.contains("\r\n") {
            return .crlf
        } else if text.contains("\r") {
            return .cr
        } else {
            return .lf
        }
    }

    // MARK: - Text Editing

    func insert(_ string: String, at offset: Int? = nil) {
        let insertOffset = offset ?? cursorPosition
        guard insertOffset >= 0 && insertOffset <= text.count else { return }

        pieceTable.insert(text: string, at: insertOffset)
        undoManager.recordInsert(text: string, offset: insertOffset)

        updateText()
        cursorPosition = insertOffset + string.count
        isModified = true
    }

    func delete(range: Range<Int>) {
        guard range.lowerBound >= 0 && range.upperBound <= text.count else { return }
        guard range.lowerBound < range.upperBound else { return }

        let deletedText = String(text[text.index(text.startIndex, offsetBy: range.lowerBound)..<text.index(text.startIndex, offsetBy: range.upperBound)])
        undoManager.recordDelete(text: deletedText, range: range)
        pieceTable.delete(range: range)

        updateText()
        cursorPosition = range.lowerBound
        isModified = true
    }

    func deleteBackward() {
        if let selection = selectionRange {
            delete(range: selection)
            selectionRange = nil
        } else if cursorPosition > 0 {
            delete(range: (cursorPosition - 1)..<cursorPosition)
        }
    }

    func deleteForward() {
        if let selection = selectionRange {
            delete(range: selection)
            selectionRange = nil
        } else if cursorPosition < text.count {
            delete(range: cursorPosition..<(cursorPosition + 1))
        }
    }

    func replaceRange(_ range: Range<Int>, with string: String) {
        guard range.lowerBound >= 0 && range.upperBound <= text.count else { return }

        undoManager.beginTransaction()
        if range.lowerBound < range.upperBound {
            delete(range: range)
        }
        if !string.isEmpty {
            insert(string, at: range.lowerBound)
        }
        undoManager.endTransaction()
    }

    private func updateText() {
        text = pieceTable.getText()
        objectWillChange.send()
    }

    /// Update text from external source (e.g., NSTextView)
    /// This bypasses the piece table and should only be used for initial sync
    func syncTextFromView(_ newText: String) {
        text = newText
        objectWillChange.send()
        // Notify that text changed (for tab modified tracking)
        NotificationCenter.default.post(name: NSNotification.Name("TextEngineDidChange"), object: self)
    }

    // MARK: - Undo/Redo

    func undo() {
        guard let command = undoManager.undo() else { return }
        applyUndoCommand(command, isUndo: true)
        updateText()
    }

    func redo() {
        guard let command = undoManager.redo() else { return }
        applyUndoCommand(command, isUndo: false)
        updateText()
    }

    private func applyUndoCommand(_ command: TextUndoManager.EditCommand, isUndo: Bool) {
        switch command {
        case let .insert(text, offset):
            if isUndo {
                pieceTable.delete(range: offset..<(offset + text.count))
                cursorPosition = offset
            } else {
                pieceTable.insert(text: text, at: offset)
                cursorPosition = offset + text.count
            }

        case let .delete(text, range):
            if isUndo {
                pieceTable.insert(text: text, at: range.lowerBound)
                cursorPosition = range.upperBound
            } else {
                pieceTable.delete(range: range)
                cursorPosition = range.lowerBound
            }

        case let .compound(commands):
            if isUndo {
                for cmd in commands.reversed() {
                    applyUndoCommand(cmd, isUndo: true)
                }
            } else {
                for cmd in commands {
                    applyUndoCommand(cmd, isUndo: false)
                }
            }
        }
    }

    // MARK: - Line Operations

    func getLine(at lineNumber: Int) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard lineNumber >= 0 && lineNumber < lines.count else { return nil }
        return lines[lineNumber]
    }

    func getLineRange(at lineNumber: Int) -> Range<Int>? {
        let lines = text.components(separatedBy: .newlines)
        guard lineNumber >= 0 && lineNumber < lines.count else { return nil }

        var currentPos = 0
        for (index, line) in lines.enumerated() {
            if index == lineNumber {
                return currentPos..<(currentPos + line.count)
            }
            currentPos += line.count + 1 // +1 for newline
        }

        return nil
    }

    // MARK: - Selection

    func selectAll() {
        selectionRange = 0..<text.count
    }

    func clearSelection() {
        selectionRange = nil
    }

    // MARK: - Conversion

    func convertLineEndings(to newEnding: LineEnding) {
        guard lineEnding != newEnding else { return }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let converted = normalized.replacingOccurrences(of: "\n", with: newEnding.separator)

        loadText(converted)
        lineEnding = newEnding
        isModified = true
    }

    // MARK: - Text Transformations

    func transformToUppercase() {
        if let selection = selectionRange, selection.lowerBound < selection.upperBound {
            // Transform only selected text
            // Validate selection range
            guard selection.lowerBound >= 0 && selection.upperBound <= text.count else { return }

            let startIndex = text.index(text.startIndex, offsetBy: selection.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: selection.upperBound)
            let selectedText = String(text[startIndex..<endIndex])
            let transformed = selectedText.uppercased()
            replaceRange(selection, with: transformed)
        } else {
            // Transform entire document
            let transformed = text.uppercased()
            loadText(transformed)
        }
        isModified = true
    }

    func transformToLowercase() {
        if let selection = selectionRange, selection.lowerBound < selection.upperBound {
            // Transform only selected text
            // Validate selection range
            guard selection.lowerBound >= 0 && selection.upperBound <= text.count else { return }

            let startIndex = text.index(text.startIndex, offsetBy: selection.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: selection.upperBound)
            let selectedText = String(text[startIndex..<endIndex])
            let transformed = selectedText.lowercased()
            replaceRange(selection, with: transformed)
        } else {
            // Transform entire document
            let transformed = text.lowercased()
            loadText(transformed)
        }
        isModified = true
    }

    func convertTabsToSpaces(spacesPerTab: Int = 4) {
        // Validate input
        guard spacesPerTab > 0 && spacesPerTab <= 16 else { return }
        let spaces = String(repeating: " ", count: spacesPerTab)

        if let selection = selectionRange, selection.lowerBound < selection.upperBound {
            // Convert only selected text
            // Validate selection range
            guard selection.lowerBound >= 0 && selection.upperBound <= text.count else { return }

            let startIndex = text.index(text.startIndex, offsetBy: selection.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: selection.upperBound)
            let selectedText = String(text[startIndex..<endIndex])
            let transformed = selectedText.replacingOccurrences(of: "\t", with: spaces)
            replaceRange(selection, with: transformed)
        } else {
            // Convert entire document
            let transformed = text.replacingOccurrences(of: "\t", with: spaces)
            loadText(transformed)
        }
        isModified = true
    }

    func convertSpacesToTabs(spacesPerTab: Int = 4) {
        // Validate input
        guard spacesPerTab > 0 && spacesPerTab <= 16 else { return }
        let spaces = String(repeating: " ", count: spacesPerTab)

        if let selection = selectionRange, selection.lowerBound < selection.upperBound {
            // Convert only selected text
            // Validate selection range
            guard selection.lowerBound >= 0 && selection.upperBound <= text.count else { return }

            let startIndex = text.index(text.startIndex, offsetBy: selection.lowerBound)
            let endIndex = text.index(text.startIndex, offsetBy: selection.upperBound)
            let selectedText = String(text[startIndex..<endIndex])
            let transformed = selectedText.replacingOccurrences(of: spaces, with: "\t")
            replaceRange(selection, with: transformed)
        } else {
            // Convert entire document
            let transformed = text.replacingOccurrences(of: spaces, with: "\t")
            loadText(transformed)
        }
        isModified = true
    }
}
