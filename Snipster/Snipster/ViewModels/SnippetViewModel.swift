//
//  SnippetViewModel.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import SwiftUI
import Combine

@MainActor
class SnippetViewModel: ObservableObject {
    @Published var snippetStore: SnippetStore
    @Published var tagStore: TagStore
    @Published var searchText: String = ""
    @Published var selectedSnippet: Snippet?
    @Published var storageLocation: StorageLocation

    private let storageManager: FileStorageManager
    private var cancellables = Set<AnyCancellable>()

    var filteredSnippets: [Snippet] {
        snippetStore.searchSnippets(query: searchText)
    }

    var hasSnippets: Bool {
        !snippetStore.snippets.isEmpty
    }

    init(storageLocation: StorageLocation = .local) {
        self.storageLocation = storageLocation
        self.storageManager = FileStorageManager(location: storageLocation)
        self.snippetStore = SnippetStore(storageManager: storageManager)
        self.tagStore = TagStore(storageManager: storageManager)

        // Load tags and snippets on init
        Task {
            // Load tags first
            await tagStore.loadTags()

            // Load snippets
            await snippetStore.loadSnippets()

            // Run migration if needed
            let migrationService = TagMigrationService()
            let migratedSnippets = await migrationService.migrateSnippetsToTagIDs(
                snippets: snippetStore.snippets,
                tagStore: tagStore
            )

            // Save if migration occurred
            if migratedSnippets != snippetStore.snippets {
                snippetStore.snippets = migratedSnippets
                await snippetStore.saveSnippets()
                await tagStore.saveTags()
            }

            // Update text expansion monitor with loaded snippets
            TextExpansionMonitor.shared.updateSnippets(snippetStore.snippets)
        }

        // Start text expansion monitoring
        TextExpansionMonitor.shared.startMonitoring()

        // Observe snippet changes to update the monitor
        snippetStore.$snippets
            .sink { snippets in
                TextExpansionMonitor.shared.updateSnippets(snippets)
            }
            .store(in: &cancellables)
    }

    func addSnippet(title: String, content: String, tags: [String] = [], tagIDs: [UUID] = [], triggerPrefix: String, triggerSequence: String, isFavorite: Bool = false) {
        let snippet = Snippet(title: title, content: content, tags: tags, tagIDs: tagIDs, triggerPrefix: triggerPrefix, triggerSequence: triggerSequence, isFavorite: isFavorite)
        Task {
            await snippetStore.addSnippet(snippet)
        }
    }

    func updateSnippet(_ snippet: Snippet) {
        Task {
            await snippetStore.updateSnippet(snippet)
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        Task { @MainActor in
            await snippetStore.deleteSnippet(snippet)
            objectWillChange.send()
        }
    }

    func selectSnippet(_ snippet: Snippet?) {
        selectedSnippet = snippet
    }

    func changeStorageLocation(_ location: StorageLocation) {
        storageLocation = location
        Task {
            await storageManager.updateStorageLocation(location)
            await tagStore.loadTags()
            await snippetStore.loadSnippets()
        }
    }

    // MARK: - Trigger Validation

    /// Checks if a trigger combination is unique (case-insensitive)
    /// - Parameters:
    ///   - prefix: The trigger prefix (e.g., "!")
    ///   - sequence: The trigger sequence (e.g., "email")
    ///   - excludingSnippetID: Optional snippet ID to exclude from check (for editing existing snippets)
    /// - Returns: The conflicting snippet if one exists, nil if trigger is unique
    func findConflictingTrigger(prefix: String, sequence: String, excludingSnippetID: UUID? = nil) -> Snippet? {
        // Empty sequence means no trigger, so it's always valid
        guard !sequence.isEmpty else { return nil }

        let triggerToCheck = (prefix + sequence).lowercased()

        return snippetStore.snippets.first { snippet in
            // Skip the snippet we're editing
            if let excludingID = excludingSnippetID, snippet.id == excludingID {
                return false
            }

            // Check if triggers match (case-insensitive)
            let existingTrigger = snippet.trigger.lowercased()
            return !existingTrigger.isEmpty && existingTrigger == triggerToCheck
        }
    }

    /// Validates if a trigger is unique
    /// - Parameters:
    ///   - prefix: The trigger prefix
    ///   - sequence: The trigger sequence
    ///   - excludingSnippetID: Optional snippet ID to exclude from check
    /// - Returns: True if trigger is unique, false if it conflicts with another snippet
    func isTriggerUnique(prefix: String, sequence: String, excludingSnippetID: UUID? = nil) -> Bool {
        return findConflictingTrigger(prefix: prefix, sequence: sequence, excludingSnippetID: excludingSnippetID) == nil
    }
}
