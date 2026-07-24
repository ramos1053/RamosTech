//
//  ClipboardHistoryBuffer.swift
//  Snipster
//

import Foundation

/// Pure ring-buffer logic for clipboard history, with no AppKit or system
/// dependencies — kept separate from `ClipboardHistoryService` so the
/// insert/dedup/trim behavior is directly unit-testable without touching
/// `NSPasteboard` or a `Timer`.
// nonisolated — matches the doc comment above: pure logic with no AppKit or
// system dependencies, meant to be directly unit-testable without any actor
// context. It was still implicitly defaulting to MainActor under the
// module's default isolation, contradicting that design.
nonisolated struct ClipboardHistoryBuffer {
    private(set) var entries: [ClipboardHistoryEntry] = []
    var capacity: Int

    /// Mirrors `SnippetVariableProcessor.maxClipboardLength` — clipboard content
    /// is untrusted and may be arbitrarily large.
    static let maxEntryLength = 100_000

    init(capacity: Int) {
        self.capacity = capacity
    }

    /// Records a new clipboard copy. Returns `false` (a no-op) if the content is
    /// blank/whitespace-only or identical to the most recent entry, so repeated
    /// or empty copies don't clutter history.
    @discardableResult
    mutating func insert(_ content: String, at date: Date) -> Bool {
        let bounded = String(content.prefix(Self.maxEntryLength))
        guard !bounded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard entries.first?.content != bounded else { return false }

        entries.insert(ClipboardHistoryEntry(id: UUID(), content: bounded, capturedAt: date), at: 0)
        trim()
        return true
    }

    /// Drops the oldest entries beyond `capacity`.
    mutating func trim() {
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }

    mutating func clear() {
        entries.removeAll()
    }
}
