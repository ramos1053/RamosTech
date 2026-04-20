import Foundation

/// Command-based undo/redo manager with coalescing and transaction support
@MainActor
final class TextUndoManager: ObservableObject {

    // MARK: - Types

    enum EditCommand {
        case insert(text: String, offset: Int)
        case delete(text: String, range: Range<Int>)
        case compound([EditCommand])
    }

    // MARK: - Properties

    private var undoStack: [EditCommand] = []
    private var redoStack: [EditCommand] = []

    private var currentTransaction: [EditCommand] = []
    private var isInTransaction = false

    // Coalescing properties
    private var lastCommand: EditCommand?
    private var lastCommandTime: Date?
    private let coalescingInterval: TimeInterval = 0.5

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Recording Commands

    func recordInsert(text: String, offset: Int) {
        let command = EditCommand.insert(text: text, offset: offset)
        recordCommand(command)
    }

    func recordDelete(text: String, range: Range<Int>) {
        let command = EditCommand.delete(text: text, range: range)
        recordCommand(command)
    }

    private func recordCommand(_ command: EditCommand) {
        if isInTransaction {
            currentTransaction.append(command)
            return
        }

        // Attempt to coalesce with the last command
        if let coalesced = tryCoalesce(command) {
            if !undoStack.isEmpty {
                undoStack[undoStack.count - 1] = coalesced
            }
            lastCommand = coalesced
            lastCommandTime = Date()
        } else {
            undoStack.append(command)
            lastCommand = command
            lastCommandTime = Date()
        }

        // Limit stack size based on preferences
        let limit = AppPreferences.shared.undoHistoryLimit
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }

        // Clear redo stack when a new command is recorded
        redoStack.removeAll()
        objectWillChange.send()
    }

    // MARK: - Coalescing

    private func tryCoalesce(_ newCommand: EditCommand) -> EditCommand? {
        guard let last = lastCommand,
              let lastTime = lastCommandTime,
              Date().timeIntervalSince(lastTime) < coalescingInterval else {
            return nil
        }

        switch (last, newCommand) {
        case let (.insert(lastText, lastOffset), .insert(newText, newOffset)):
            // Coalesce sequential insertions at the same or adjacent positions
            if newOffset == lastOffset + lastText.count {
                return .insert(text: lastText + newText, offset: lastOffset)
            }

        case let (.delete(lastText, lastRange), .delete(newText, newRange)):
            // Coalesce sequential deletions
            if newRange.upperBound == lastRange.lowerBound {
                // Backspace
                return .delete(
                    text: newText + lastText,
                    range: newRange.lowerBound..<lastRange.upperBound
                )
            } else if newRange.lowerBound == lastRange.lowerBound {
                // Forward delete
                return .delete(
                    text: lastText + newText,
                    range: lastRange.lowerBound..<(lastRange.upperBound + newText.count)
                )
            }

        default:
            break
        }

        return nil
    }

    // MARK: - Transactions

    func beginTransaction() {
        isInTransaction = true
        currentTransaction.removeAll()
    }

    func endTransaction() {
        guard isInTransaction else { return }
        isInTransaction = false

        if !currentTransaction.isEmpty {
            let compound = EditCommand.compound(currentTransaction)
            undoStack.append(compound)
            redoStack.removeAll()
            objectWillChange.send()
        }

        currentTransaction.removeAll()
    }

    func cancelTransaction() {
        isInTransaction = false
        currentTransaction.removeAll()
    }

    // MARK: - Undo/Redo

    func undo() -> EditCommand? {
        guard !undoStack.isEmpty else { return nil }

        let command = undoStack.removeLast()
        redoStack.append(command)
        objectWillChange.send()

        return command
    }

    func redo() -> EditCommand? {
        guard !redoStack.isEmpty else { return nil }

        let command = redoStack.removeLast()
        undoStack.append(command)
        objectWillChange.send()

        return command
    }

    // MARK: - Clear

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        currentTransaction.removeAll()
        isInTransaction = false
        lastCommand = nil
        lastCommandTime = nil
        objectWillChange.send()
    }

    // MARK: - Memory Management

    func limitStackSize(to maxSize: Int) {
        if undoStack.count > maxSize {
            undoStack.removeFirst(undoStack.count - maxSize)
        }
        if redoStack.count > maxSize {
            redoStack.removeFirst(redoStack.count - maxSize)
        }
    }
}
