//
//  ClipboardHistoryEntry.swift
//  Snipster
//

import Foundation

/// A single recorded clipboard copy. Not `Codable` — clipboard history is
/// in-memory only and is never written to disk.
struct ClipboardHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: String
    let capturedAt: Date
}
