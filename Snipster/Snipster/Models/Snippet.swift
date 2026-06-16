//
//  Snippet.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation

struct Snippet: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var tags: [String]  // Keep for backward compatibility
    var tagIDs: [UUID]  // New tag reference system
    var triggerPrefix: String
    var triggerSequence: String
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool
    var usageCount: Int
    var lastUsedAt: Date?

    // Computed property for backward compatibility and monitor
    var trigger: String {
        guard !triggerSequence.isEmpty else { return "" }
        return triggerPrefix + triggerSequence
    }

    init(id: UUID = UUID(),
         title: String,
         content: String,
         tags: [String] = [],
         tagIDs: [UUID] = [],
         triggerPrefix: String = "!",
         triggerSequence: String = "",
         createdAt: Date = Date(),
         modifiedAt: Date = Date(),
         isFavorite: Bool = false,
         usageCount: Int = 0,
         lastUsedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.tagIDs = tagIDs
        self.triggerPrefix = triggerPrefix
        self.triggerSequence = triggerSequence
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isFavorite = isFavorite
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
    }

    // Legacy init for backward compatibility with old JSON files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        tags = try container.decode([String].self, forKey: .tags)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)

        // Handle tagIDs (new format) or empty array if not present
        tagIDs = (try? container.decode([UUID].self, forKey: .tagIDs)) ?? []

        // Handle isFavorite (new format) or false if not present
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false

        // Handle usage statistics (new format) or defaults if not present
        usageCount = (try? container.decode(Int.self, forKey: .usageCount)) ?? 0
        lastUsedAt = try? container.decode(Date.self, forKey: .lastUsedAt)

        // Handle legacy trigger field
        if let oldTrigger = try? container.decode(String.self, forKey: .trigger) {
            // Split legacy trigger into prefix and sequence
            if oldTrigger.isEmpty {
                triggerPrefix = "!"
                triggerSequence = ""
            } else {
                let firstChar = String(oldTrigger.prefix(1))
                if firstChar.rangeOfCharacter(from: .alphanumerics) == nil {
                    triggerPrefix = firstChar
                    triggerSequence = String(oldTrigger.dropFirst())
                } else {
                    triggerPrefix = "!"
                    triggerSequence = oldTrigger
                }
            }
        } else {
            // New format
            triggerPrefix = try container.decode(String.self, forKey: .triggerPrefix)
            triggerSequence = try container.decode(String.self, forKey: .triggerSequence)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, tags, tagIDs, triggerPrefix, triggerSequence, trigger, createdAt, modifiedAt, isFavorite, usageCount, lastUsedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(tags, forKey: .tags)
        try container.encode(tagIDs, forKey: .tagIDs)
        try container.encode(triggerPrefix, forKey: .triggerPrefix)
        try container.encode(triggerSequence, forKey: .triggerSequence)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        modifiedAt = Date()
    }

    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
        modifiedAt = Date()
    }

    mutating func updateTagIDs(_ newTagIDs: [UUID]) {
        tagIDs = newTagIDs
        modifiedAt = Date()
    }

    mutating func updateTrigger(prefix: String, sequence: String) {
        triggerPrefix = prefix
        triggerSequence = sequence
        modifiedAt = Date()
    }

    mutating func toggleFavorite() {
        isFavorite.toggle()
        modifiedAt = Date()
    }

    mutating func incrementUsage() {
        usageCount += 1
        lastUsedAt = Date()
    }

    // MARK: - Sanitization

    /// Upper bounds applied to untrusted (imported) snippet fields. These are generous
    /// relative to real usage but prevent a malicious/corrupt file from injecting
    /// multi-megabyte strings or runaway triggers.
    enum Limits {
        static let maxTitle = 1_000
        static let maxContent = 100_000
        static let maxTrigger = 100
        static let maxTags = 100
        static let maxTagName = 200
    }

    /// Returns a copy with all free-text fields clamped to safe lengths. Used when
    /// importing snippets from an untrusted JSON file.
    func sanitized() -> Snippet {
        var copy = self
        copy.title = String(title.prefix(Limits.maxTitle))
        copy.content = String(content.prefix(Limits.maxContent))
        copy.triggerPrefix = String(triggerPrefix.prefix(Limits.maxTrigger))
        copy.triggerSequence = String(triggerSequence.prefix(Limits.maxTrigger))
        copy.tags = tags.prefix(Limits.maxTags).map { String($0.prefix(Limits.maxTagName)) }
        copy.tagIDs = Array(tagIDs.prefix(Limits.maxTags))
        return copy
    }

    func duplicate() -> Snippet {
        return Snippet(
            title: "\(title) Copy",
            content: content,
            tags: tags,
            tagIDs: tagIDs,
            triggerPrefix: triggerPrefix,
            triggerSequence: "", // Clear trigger for duplicate
            isFavorite: false,
            usageCount: 0
        )
    }
}
