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

        let data = try Data(contentsOf: fileURL)
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

        let data = try Data(contentsOf: tagsFileURL)
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
            try FileManager.default.createDirectory(at: directory,
                                                   withIntermediateDirectories: true)
        }
    }
}

enum FileStorageError: LocalizedError {
    case invalidPath
    case accessDenied
    case encodingFailed
    case decodingFailed

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
        }
    }
}
