//
//  StorageDocument.swift
//  Snipster
//

import Foundation

/// The single combined document Snipster persists to disk — one file
/// instead of separate snippets.json/tags.json — and also the shape used
/// for manual export/backup, so a backup always carries tag data with it
/// rather than leaving imported snippets with orphaned tagIDs.
struct StorageDocument: Codable {
    var snippets: [Snippet]
    var tags: [Tag]
}
