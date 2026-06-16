//
//  FileStorageManager.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation

actor FileStorageManager {
    private let fileName = "snippets.json"
    private let tagsFileName = "tags.json"
    private var storageLocation: StorageLocation
    private var customPath: URL?

    /// Maximum size (bytes) for a snippets/tags JSON file we are willing to read into memory.
    /// Guards against memory-exhaustion from a maliciously large or corrupt file. 50 MB is far
    /// beyond any realistic snippet library.
    static let maxFileSize: Int = 50 * 1024 * 1024

    private var fileURL: URL? {
        if let customPath = customPath {
            return customPath.appendingPathComponent(fileName)
        }
        return storageLocation.defaultPath?.appendingPathComponent(fileName)
    }

    private var tagsFileURL: URL? {
        if let customPath = customPath {
            return customPath.appendingPathComponent(tagsFileName)
        }
        return storageLocation.defaultPath?.appendingPathComponent(tagsFileName)
    }

    init(location: StorageLocation = .local, customPath: URL? = nil) {
        self.storageLocation = location
        self.customPath = customPath
    }

    func loadSnippets() async throws -> [Snippet] {
        guard let fileURL = fileURL else {
            throw FileStorageError.invalidPath
        }

        // Create directory if needed
        try createDirectoryIfNeeded(for: fileURL)

        // If file doesn't exist, return empty array
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try readData(at: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([Snippet].self, from: data)
    }

    func saveSnippets(_ snippets: [Snippet]) async throws {
        guard let fileURL = fileURL else {
            throw FileStorageError.invalidPath
        }

        try createDirectoryIfNeeded(for: fileURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(snippets)
        try data.write(to: fileURL, options: .atomic)
        setOwnerOnlyPermissions(at: fileURL)
    }

    func loadTags() async throws -> [Tag] {
        guard let tagsFileURL = tagsFileURL else {
            throw FileStorageError.invalidPath
        }

        // Create directory if needed
        try createDirectoryIfNeeded(for: tagsFileURL)

        // If file doesn't exist, return empty array
        guard FileManager.default.fileExists(atPath: tagsFileURL.path) else {
            return []
        }

        let data = try readData(at: tagsFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([Tag].self, from: data)
    }

    func saveTags(_ tags: [Tag]) async throws {
        guard let tagsFileURL = tagsFileURL else {
            throw FileStorageError.invalidPath
        }

        try createDirectoryIfNeeded(for: tagsFileURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(tags)
        try data.write(to: tagsFileURL, options: .atomic)
        setOwnerOnlyPermissions(at: tagsFileURL)
    }

    func updateStorageLocation(_ location: StorageLocation, customPath: URL? = nil) async {
        self.storageLocation = location
        self.customPath = customPath
    }

    func requestAccess(for location: StorageLocation) async -> Bool {
        guard location.needsPermission else { return true }

        switch location {
        case .iCloud:
            // iCloud requires entitlement and container setup
            return FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
        case .oneDrive:
            // OneDrive requires user to grant folder access
            guard let path = location.defaultPath else { return false }
            return FileManager.default.isReadableFile(atPath: path.path)
        case .local:
            return true
        }
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
