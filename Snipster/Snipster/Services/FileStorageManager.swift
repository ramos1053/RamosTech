//
//  FileStorageManager.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation

actor FileStorageManager {
    private let dataFileName = "snipster-library.json"

    /// Pre-combined-file layout, kept only so an existing install's data can
    /// be migrated forward on first load. Never written to going forward.
    private let legacySnippetsFileName = "snippets.json"
    private let legacyTagsFileName = "tags.json"

    private var storageLocation: StorageLocation
    private var customPath: URL?

    /// Maximum size (bytes) for a storage/import file we are willing to read into memory.
    /// Guards against memory-exhaustion from a maliciously large or corrupt file. 50 MB is far
    /// beyond any realistic snippet library.
    static let maxFileSize: Int = 50 * 1024 * 1024

    private var dataFileURL: URL? {
        if let customPath = customPath {
            return customPath.appendingPathComponent(dataFileName)
        }
        return storageLocation.defaultPath?.appendingPathComponent(dataFileName)
    }

    private var legacySnippetsFileURL: URL? {
        if let customPath = customPath {
            return customPath.appendingPathComponent(legacySnippetsFileName)
        }
        return storageLocation.defaultPath?.appendingPathComponent(legacySnippetsFileName)
    }

    private var legacyTagsFileURL: URL? {
        if let customPath = customPath {
            return customPath.appendingPathComponent(legacyTagsFileName)
        }
        return storageLocation.defaultPath?.appendingPathComponent(legacyTagsFileName)
    }

    init(location: StorageLocation = .local, customPath: URL? = nil) {
        self.storageLocation = location
        self.customPath = customPath
    }

    func loadSnippets() async throws -> [Snippet] {
        try migrateLegacyFilesIfNeeded()
        return try readDocument().snippets
    }

    func saveSnippets(_ snippets: [Snippet]) async throws {
        var document = (try? readDocument()) ?? StorageDocument(snippets: [], tags: [])
        document.snippets = snippets
        try writeDocument(document)
    }

    func loadTags() async throws -> [Tag] {
        try migrateLegacyFilesIfNeeded()
        return try readDocument().tags
    }

    func saveTags(_ tags: [Tag]) async throws {
        var document = (try? readDocument()) ?? StorageDocument(snippets: [], tags: [])
        document.tags = tags
        try writeDocument(document)
    }

    func updateStorageLocation(_ location: StorageLocation, customPath: URL? = nil) async {
        self.storageLocation = location
        self.customPath = customPath
    }

    /// Whether the current location already has a combined data file. Used
    /// when switching locations to decide whether to seed a fresh/empty
    /// destination with the current in-memory data, versus loading whatever
    /// is already there (e.g. a custom folder already synced from another
    /// machine).
    func hasExistingSnippetsFile() -> Bool {
        guard let dataFileURL else { return false }
        return FileManager.default.fileExists(atPath: dataFileURL.path)
    }

    // MARK: - Combined document read/write

    private func readDocument() throws -> StorageDocument {
        guard let dataFileURL else {
            throw FileStorageError.invalidPath
        }

        try createDirectoryIfNeeded(for: dataFileURL)

        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            return StorageDocument(snippets: [], tags: [])
        }

        let data = try readData(at: dataFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StorageDocument.self, from: data)
    }

    private func writeDocument(_ document: StorageDocument) throws {
        guard let dataFileURL else {
            throw FileStorageError.invalidPath
        }

        try createDirectoryIfNeeded(for: dataFileURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(document)
        try data.write(to: dataFileURL, options: .atomic)
        setOwnerOnlyPermissions(at: dataFileURL)
    }

    // MARK: - Legacy migration

    /// If the combined file doesn't exist yet at the current location but the
    /// old separate snippets.json/tags.json do, merge them into the combined
    /// format once. The legacy files are deliberately left in place afterward
    /// — not deleted — as a safety net in case anything about the migration
    /// or the new format turns out to be wrong.
    private func migrateLegacyFilesIfNeeded() throws {
        guard let dataFileURL else { return }
        guard !FileManager.default.fileExists(atPath: dataFileURL.path) else { return }

        let legacySnippets: [Snippet] = (try? readLegacyArray(at: legacySnippetsFileURL)) ?? []
        let legacyTags: [Tag] = (try? readLegacyArray(at: legacyTagsFileURL)) ?? []

        guard !legacySnippets.isEmpty || !legacyTags.isEmpty else { return }

        try writeDocument(StorageDocument(snippets: legacySnippets, tags: legacyTags))
    }

    private func readLegacyArray<T: Decodable>(at url: URL?) throws -> [T] {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try readData(at: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([T].self, from: data)
    }

    private func createDirectoryIfNeeded(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            // Create the directory owner-only (0700). Snippet content is potentially
            // sensitive (passwords, tokens, personal data), so other local users must
            // not be able to traverse into or read the Snipster storage directory.
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    /// Read a file's contents, refusing to load anything larger than `maxFileSize`.
    /// This prevents a maliciously crafted (or corrupt) storage/import file from
    /// exhausting memory before JSON decoding even begins.
    private func readData(at url: URL) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? Int, size > Self.maxFileSize {
            throw FileStorageError.fileTooLarge
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Restrict a freshly written file to owner read/write only (0600). Snippet and tag
    /// data may contain sensitive content and should never be world- or group-readable.
    private func setOwnerOnlyPermissions(at url: URL) {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}

enum FileStorageError: LocalizedError {
    case invalidPath
    case accessDenied
    case encodingFailed
    case decodingFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid storage path"
        case .accessDenied:
            return "Access denied to storage location"
        case .encodingFailed:
            return "Failed to encode snippets"
        case .decodingFailed:
            return "Failed to decode snippets"
        case .fileTooLarge:
            return "Storage file is too large to read safely"
        }
    }
}
