//
//  TagMigrationService.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import Foundation

actor TagMigrationService {
    /// Migrates snippets from string-based tags to UUID-based tag IDs
    /// For each snippet with string tags but no tagIDs:
    ///   - Looks up or creates Tag in tagStore
    ///   - Converts to tagIDs
    /// Returns migrated snippets
    func migrateSnippetsToTagIDs(snippets: [Snippet], tagStore: TagStore) async -> [Snippet] {
        var migratedSnippets: [Snippet] = []
        var needsMigration = false

        for var snippet in snippets {
            // Only migrate if snippet has string tags but no tagIDs
            if snippet.tagIDs.isEmpty && !snippet.tags.isEmpty {
                needsMigration = true
                var tagIDs: [UUID] = []

                for tagName in snippet.tags {
                    // Skip empty tag names
                    guard !tagName.isEmpty else { continue }

                    // Check if tag exists in tag store
                    if let existingTag = await tagStore.tag(byName: tagName) {
                        tagIDs.append(existingTag.id)
                    } else {
                        // Create new tag with default color
                        let currentTags = await tagStore.tags
                        let newTag = Tag(
                            name: tagName,
                            color: TagColorPalette.nextColor(existingTags: currentTags)
                        )
                        await tagStore.addTag(newTag)
                        tagIDs.append(newTag.id)
                    }
                }

                snippet.tagIDs = tagIDs
            }
            migratedSnippets.append(snippet)
        }

        return migratedSnippets
    }
}
