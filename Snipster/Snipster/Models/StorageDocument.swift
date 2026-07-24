//
//  StorageDocument.swift
//  Snipster
//

import Foundation

/// The single combined document Snipster persists to disk — one file
/// instead of separate snippets.json/tags.json — and also the shape used
/// for manual export/backup, so a backup always carries tag data with it
/// rather than leaving imported snippets with orphaned tagIDs.
// nonisolated — pure data, decoded/encoded from FileStorageManager's own
// (non-MainActor) actor-isolated context; no reason for its Codable
// conformance to default to MainActor like the rest of the module.
nonisolated struct StorageDocument: Codable {
    var snippets: [Snippet]
    var tags: [Tag]
}
