//
//  ClipboardHistoryEntry.swift
//  Snipster
//

import Foundation

/// A single recorded clipboard copy. Not `Codable` — clipboard history is
/// in-memory only and is never written to disk.
// nonisolated — pure Sendable data, used by ClipboardHistoryBuffer's own
// nonisolated ring-buffer logic and directly unit-tested without any actor
// context; no reason to default to MainActor like the rest of the module.
nonisolated struct ClipboardHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: String
    let capturedAt: Date
}
