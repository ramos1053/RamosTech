//
//  SnippetViewModel.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI
import Combine

@MainActor
class SnippetViewModel: ObservableObject {
    @Published var snippetStore: SnippetStore
    @Published var tagStore: TagStore
    @Published var searchText: String = ""
    @Published var storageLocation: StorageLocation
    @Published var customStoragePath: URL?

    private let storageManager: FileStorageManager
    private var cancellables = Set<AnyCancellable>()

    private static let storageLocationKey = "snipster.storageLocation"
    private static let customStoragePathKey = "snipster.customStoragePath"

    /// The actual path in effect right now, regardless of which mode is active.
    var resolvedStoragePath: URL? {
        switch storageLocation {
        case .local: return storageLocation.defaultPath
        case .custom: return customStoragePath
        }
    }

    var filteredSnippets: [Snippet] {
        snippetStore.searchSnippets(query: searchText)
    }

    var hasSnippets: Bool {
        !snippetStore.snippets.isEmpty
    }

    init() {
        let defaults = UserDefaults.standard
        let savedLocation = defaults.string(forKey: Self.storageLocationKey)
            .flatMap(StorageLocation.init(rawValue:)) ?? .local
        let savedCustomPath = defaults.string(forKey: Self.customStoragePathKey)
            .map { URL(fileURLWithPath: $0) }

        self.storageLocation = savedLocation
        self.customStoragePath = savedLocation == .custom ? savedCustomPath : nil
        self.storageManager = FileStorageManager(
            location: savedLocation,
            customPath: savedLocation == .custom ? savedCustomPath : nil
        )
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

    func deleteSnippets(_ ids: Set<UUID>) {
        Task { @MainActor in
            await snippetStore.deleteSnippets(ids)
            objectWillChange.send()
        }
    }

    func changeStorageLocation(_ location: StorageLocation, customPath: URL? = nil) {
        storageLocation = location
        customStoragePath = customPath

        let defaults = UserDefaults.standard
        defaults.set(location.rawValue, forKey: Self.storageLocationKey)
        if let customPath {
            defaults.set(customPath.path, forKey: Self.customStoragePathKey)
        }

        let hadExistingData = !snippetStore.snippets.isEmpty || !tagStore.tags.isEmpty

        Task {
            await storageManager.updateStorageLocation(location, customPath: customPath)

            // If we're switching to a location that has nothing saved yet but
            // we already have snippets/tags in memory, seed it with the
            // current data instead of just showing an empty list — otherwise
            // switching storage location looks like it wiped everything.
            let destinationHasFile = await storageManager.hasExistingSnippetsFile()
            if hadExistingData && !destinationHasFile {
                await snippetStore.saveSnippets()
                await tagStore.saveTags()
            } else {
                await tagStore.loadTags()
                await snippetStore.loadSnippets()
            }
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
