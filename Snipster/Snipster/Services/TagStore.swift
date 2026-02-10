//
//  TagStore.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import Foundation
import Combine

@MainActor
class TagStore: ObservableObject {
    @Published var tags: [Tag] = []
    @Published var isLoading: Bool = false
    @Published var error: TagError?

    private let storageManager: FileStorageManager

    init(storageManager: FileStorageManager) {
        self.storageManager = storageManager
    }

    func loadTags() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tags = try await storageManager.loadTags()
        } catch {
            self.error = .loadFailed(error)
        }
    }

    func saveTags() async {
        do {
            try await storageManager.saveTags(tags)
        } catch {
            self.error = .saveFailed(error)
        }
    }

    func addTag(_ tag: Tag) async {
        tags.append(tag)
        await saveTags()
    }

    func updateTag(_ tag: Tag) async {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
            await saveTags()
        }
    }

    func deleteTag(_ tag: Tag) async {
        tags.removeAll { $0.id == tag.id }
        await saveTags()
    }

    // MARK: - Lookup methods

    func tag(byID id: UUID) -> Tag? {
        tags.first { $0.id == id }
    }

    func tag(byName name: String) -> Tag? {
        tags.first { $0.name.lowercased() == name.lowercased() }
    }

    func tags(byIDs ids: [UUID]) -> [Tag] {
        tags.filter { ids.contains($0.id) }
    }
}

enum TagError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case invalidTag

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load tags: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save tags: \(error.localizedDescription)"
        case .invalidTag:
            return "Invalid tag"
        }
    }
}
