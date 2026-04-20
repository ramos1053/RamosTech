//
//  SnippetStore.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SnippetStore: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var isLoading: Bool = false
    @Published var error: SnippetError?

    private let storageManager: FileStorageManager

    init(storageManager: FileStorageManager) {
        self.storageManager = storageManager
    }

    func loadSnippets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snippets = try await storageManager.loadSnippets()
        } catch {
            self.error = .loadFailed(error)
        }
    }

    func saveSnippets() async {
        do {
            try await storageManager.saveSnippets(snippets)
        } catch {
            self.error = .saveFailed(error)
        }
    }

    func addSnippet(_ snippet: Snippet) async {
        snippets.append(snippet)
        await saveSnippets()
    }

    func updateSnippet(_ snippet: Snippet) async {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            await saveSnippets()
        }
    }

    func deleteSnippet(_ snippet: Snippet) async {
        snippets.removeAll { $0.id == snippet.id }
        await saveSnippets()
    }

    func searchSnippets(query: String) -> [Snippet] {
        guard !query.isEmpty else { return snippets }

        let lowercasedQuery = query.lowercased()
        return snippets.filter { snippet in
            snippet.title.lowercased().contains(lowercasedQuery) ||
            snippet.content.lowercased().contains(lowercasedQuery)
        }
    }

    func exportSnippets(to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(snippets)
        try data.write(to: url, options: .atomic)
    }

    func importSnippets(from url: URL, mode: ImportMode) async throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedSnippets = try decoder.decode([Snippet].self, from: data)

        var added = 0
        var updated = 0
        var skipped = 0

        for importedSnippet in importedSnippets {
            if let existingIndex = snippets.firstIndex(where: { $0.id == importedSnippet.id }) {
                switch mode {
                case .merge:
                    // Keep newer version based on modifiedAt
                    if importedSnippet.modifiedAt > snippets[existingIndex].modifiedAt {
                        snippets[existingIndex] = importedSnippet
                        updated += 1
                    } else {
                        skipped += 1
                    }
                case .replace:
                    snippets[existingIndex] = importedSnippet
                    updated += 1
                case .skip:
                    skipped += 1
                }
            } else {
                snippets.append(importedSnippet)
                added += 1
            }
        }

        await saveSnippets()

        let result = ImportResult(added: added, updated: updated, skipped: skipped, total: importedSnippets.count)
        return result
    }

    func sortedSnippets(_ snippets: [Snippet], by option: SortOption, tagStore: TagStore) -> [Snippet] {
        switch option {
        case .title:
            return snippets.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .tag:
            return snippets.sorted { snippet1, snippet2 in
                let tags1 = tagStore.tags(byIDs: snippet1.tagIDs).map { $0.name }.joined()
                let tags2 = tagStore.tags(byIDs: snippet2.tagIDs).map { $0.name }.joined()
                return tags1.localizedCaseInsensitiveCompare(tags2) == .orderedAscending
            }
        case .color:
            return snippets.sorted { snippet1, snippet2 in
                guard let tag1 = tagStore.tags(byIDs: snippet1.tagIDs).first,
                      let tag2 = tagStore.tags(byIDs: snippet2.tagIDs).first else {
                    return false
                }
                // Sort by tag name as proxy for color sorting
                return tag1.name.localizedCaseInsensitiveCompare(tag2.name) == .orderedAscending
            }
        case .dateCreated:
            return snippets.sorted { $0.createdAt > $1.createdAt }
        case .dateModified:
            return snippets.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }
}

enum SnippetError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case invalidLocation
    case exportFailed(Error)
    case importFailed(Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load snippets: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save snippets: \(error.localizedDescription)"
        case .invalidLocation:
            return "Invalid storage location"
        case .exportFailed(let error):
            return "Failed to export snippets: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import snippets: \(error.localizedDescription)"
        }
    }
}

enum ImportMode {
    case merge      // Keep newer version based on modifiedAt
    case replace    // Always use imported version
    case skip       // Keep existing version
}

struct ImportResult {
    let added: Int
    let updated: Int
    let skipped: Int
    let total: Int

    var summary: String {
        return "Added: \(added), Updated: \(updated), Skipped: \(skipped), Total: \(total)"
    }
}
