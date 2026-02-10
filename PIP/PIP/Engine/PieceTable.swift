import Foundation

/// Piece table implementation for efficient text editing with grapheme-safe offsets
///
/// ## Invariants:
/// - All offsets are in grapheme cluster counts, not UTF-16 code units
/// - Piece descriptors reference buffer positions by grapheme cluster index
/// - No piece has zero length
/// - Pieces are non-overlapping and sequential
///
/// ## Performance:
/// - Insert: O(log n) average, O(n) worst case for piece splitting
/// - Delete: O(n) for finding affected pieces, O(1) per piece modification
/// - getText: O(n) where n is total grapheme count
/// - Memory: O(p) where p is number of pieces (typically << n)
@MainActor
final class PieceTable {

    // MARK: - Types

    enum BufferType {
        case original
        case added
    }

    struct Piece {
        let bufferType: BufferType
        let start: Int  // Grapheme cluster index in buffer
        var length: Int // Grapheme cluster count

        var end: Int { start + length }
    }

    // MARK: - Properties

    private var originalBuffer: String = ""
    private var addedBuffer: String = ""
    private var pieces: [Piece] = []

    /// Cache for grapheme cluster indices to avoid repeated computation
    private var originalGraphemeIndices: [String.Index] = []
    private var addedGraphemeIndices: [String.Index] = []

    /// Total length in grapheme clusters
    var length: Int {
        pieces.reduce(0) { $0 + $1.length }
    }

    // MARK: - Initialization

    init(text: String = "") {
        if !text.isEmpty {
            originalBuffer = text
            originalGraphemeIndices = buildGraphemeIndices(for: text)
            let graphemeCount = originalGraphemeIndices.count - 1 // Exclude endIndex
            pieces = [Piece(bufferType: .original, start: 0, length: graphemeCount)]
        }
    }

    // MARK: - Grapheme Cluster Support

    /// Build array of grapheme cluster boundary indices for fast lookup
    /// Returns array including startIndex and endIndex
    private func buildGraphemeIndices(for string: String) -> [String.Index] {
        var indices: [String.Index] = [string.startIndex]
        var currentIndex = string.startIndex

        while currentIndex < string.endIndex {
            currentIndex = string.index(after: currentIndex)
            indices.append(currentIndex)
        }

        return indices
    }

    /// Get grapheme cluster count for a string
    private func graphemeCount(_ string: String) -> Int {
        var count = 0
        var index = string.startIndex
        while index < string.endIndex {
            index = string.index(after: index)
            count += 1
        }
        return count
    }

    /// Extract substring by grapheme cluster range
    private func substring(from buffer: String,
                          indices: [String.Index],
                          start: Int,
                          length: Int) -> String {
        guard start >= 0,
              start + length <= indices.count - 1,
              length > 0 else {
            return ""
        }

        let startIndex = indices[start]
        let endIndex = indices[start + length]
        return String(buffer[startIndex..<endIndex])
    }

    // MARK: - Text Operations

    /// Insert text at the specified offset (in grapheme clusters)
    func insert(text: String, at offset: Int) {
        guard !text.isEmpty else { return }
        guard offset >= 0 && offset <= length else { return }

        // Add to added buffer and update grapheme indices
        let addedStart = addedGraphemeIndices.isEmpty ? 0 : addedGraphemeIndices.count - 1
        addedBuffer.append(text)

        // Build new grapheme indices for the added text
        if addedGraphemeIndices.isEmpty {
            addedGraphemeIndices = buildGraphemeIndices(for: addedBuffer)
        } else {
            // Append new indices to existing cache
            var currentIndex = addedBuffer.index(addedBuffer.startIndex, offsetBy: addedBuffer.count - text.count)
            while currentIndex < addedBuffer.endIndex {
                currentIndex = addedBuffer.index(after: currentIndex)
                addedGraphemeIndices.append(currentIndex)
            }
        }

        let textGraphemeCount = graphemeCount(text)
        let newPiece = Piece(bufferType: .added, start: addedStart, length: textGraphemeCount)

        if offset == 0 {
            pieces.insert(newPiece, at: 0)
            return
        }

        if offset == length {
            pieces.append(newPiece)
            return
        }

        // Find the piece containing the offset
        var currentOffset = 0
        for (index, piece) in pieces.enumerated() {
            let pieceEnd = currentOffset + piece.length

            if offset >= currentOffset && offset < pieceEnd {
                let relativeOffset = offset - currentOffset

                if relativeOffset == 0 {
                    // Insert at the start of this piece
                    pieces.insert(newPiece, at: index)
                } else if relativeOffset == piece.length {
                    // Insert at the end of this piece
                    pieces.insert(newPiece, at: index + 1)
                } else {
                    // Split the piece
                    let leftPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start,
                        length: relativeOffset
                    )
                    let rightPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start + relativeOffset,
                        length: piece.length - relativeOffset
                    )

                    pieces[index] = leftPiece
                    pieces.insert(contentsOf: [newPiece, rightPiece], at: index + 1)
                }

                return
            }

            currentOffset = pieceEnd
        }
    }

    /// Delete text in the specified range
    func delete(range: Range<Int>) {
        guard range.lowerBound >= 0 && range.upperBound <= length else { return }
        guard range.lowerBound < range.upperBound else { return }

        var piecesToRemove: [Int] = []
        var piecesToAdd: [(index: Int, piece: Piece)] = []
        var currentOffset = 0

        for (index, piece) in pieces.enumerated() {
            let pieceStart = currentOffset
            let pieceEnd = currentOffset + piece.length

            // Check if this piece overlaps with the deletion range
            if pieceEnd > range.lowerBound && pieceStart < range.upperBound {
                let deleteStart = max(range.lowerBound - pieceStart, 0)
                let deleteEnd = min(range.upperBound - pieceStart, piece.length)

                if deleteStart == 0 && deleteEnd == piece.length {
                    // Delete entire piece
                    piecesToRemove.append(index)
                } else if deleteStart == 0 {
                    // Delete from start
                    let newPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start + deleteEnd,
                        length: piece.length - deleteEnd
                    )
                    piecesToAdd.append((index, newPiece))
                    piecesToRemove.append(index)
                } else if deleteEnd == piece.length {
                    // Delete to end
                    let newPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start,
                        length: deleteStart
                    )
                    piecesToAdd.append((index, newPiece))
                    piecesToRemove.append(index)
                } else {
                    // Delete middle - split into two pieces
                    let leftPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start,
                        length: deleteStart
                    )
                    let rightPiece = Piece(
                        bufferType: piece.bufferType,
                        start: piece.start + deleteEnd,
                        length: piece.length - deleteEnd
                    )
                    piecesToAdd.append((index, leftPiece))
                    piecesToAdd.append((index + 1, rightPiece))
                    piecesToRemove.append(index)
                }
            }

            currentOffset = pieceEnd
        }

        // Apply deletions in reverse order
        for index in piecesToRemove.reversed() {
            pieces.remove(at: index)
        }

        // Apply additions in forward order
        for (index, piece) in piecesToAdd.sorted(by: { $0.index < $1.index }) {
            let insertIndex = min(index, pieces.count)
            pieces.insert(piece, at: insertIndex)
        }
    }

    /// Get the full text as a String
    func getText() -> String {
        var result = ""

        for piece in pieces {
            let (buffer, indices) = piece.bufferType == .original ?
                (originalBuffer, originalGraphemeIndices) :
                (addedBuffer, addedGraphemeIndices)

            let pieceText = substring(from: buffer,
                                     indices: indices,
                                     start: piece.start,
                                     length: piece.length)
            result.append(pieceText)
        }

        return result
    }

    /// Get a substring in the specified range (in grapheme clusters)
    func getSubstring(range: Range<Int>) -> String {
        guard range.lowerBound >= 0 && range.upperBound <= length else { return "" }

        var result = ""
        var currentOffset = 0

        for piece in pieces {
            let pieceStart = currentOffset
            let pieceEnd = currentOffset + piece.length

            if pieceEnd > range.lowerBound && pieceStart < range.upperBound {
                let (buffer, indices) = piece.bufferType == .original ?
                    (originalBuffer, originalGraphemeIndices) :
                    (addedBuffer, addedGraphemeIndices)

                let relativeStart = max(0, range.lowerBound - pieceStart)
                let relativeEnd = min(piece.length, range.upperBound - pieceStart)

                let pieceText = substring(from: buffer,
                                         indices: indices,
                                         start: piece.start + relativeStart,
                                         length: relativeEnd - relativeStart)
                result.append(pieceText)
            }

            currentOffset = pieceEnd

            if currentOffset >= range.upperBound {
                break
            }
        }

        return result
    }

    /// Reset to initial empty state
    func clear() {
        originalBuffer = ""
        addedBuffer = ""
        pieces = []
        originalGraphemeIndices = []
        addedGraphemeIndices = []
    }

    /// Replace all content with new text
    func replaceAll(with text: String) {
        clear()
        if !text.isEmpty {
            originalBuffer = text
            originalGraphemeIndices = buildGraphemeIndices(for: text)
            let graphemeCount = originalGraphemeIndices.count - 1
            pieces = [Piece(bufferType: .original, start: 0, length: graphemeCount)]
        }
    }
}
