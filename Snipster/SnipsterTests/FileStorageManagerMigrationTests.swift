//
//  FileStorageManagerMigrationTests.swift
//  SnipsterTests
//

import XCTest
@testable import Snipster

/// Exercises real file I/O against a temp directory (not mocked) — the thing
/// that actually matters here is whether an existing install's separate
/// snippets.json/tags.json genuinely survive the move to the combined
/// snipster-library.json file, since a bug here reads as "my snippets/tags
/// disappeared."
final class FileStorageManagerMigrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnipsterMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeLegacyFiles(snippets: [Snippet], tags: [Tag]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snippets).write(to: tempDir.appendingPathComponent("snippets.json"))
        try encoder.encode(tags).write(to: tempDir.appendingPathComponent("tags.json"))
    }

    func testMigratesLegacySnippetsAndTagsIntoCombinedFile() async throws {
        let tag = Tag(name: "Work", color: .blue)
        let snippet = Snippet(title: "Greeting", content: "Hello", tagIDs: [tag.id], triggerSequence: "hi")
        try writeLegacyFiles(snippets: [snippet], tags: [tag])

        let manager = FileStorageManager(location: .custom, customPath: tempDir)

        let loadedSnippets = try await manager.loadSnippets()
        let loadedTags = try await manager.loadTags()

        XCTAssertEqual(loadedSnippets.map(\.id), [snippet.id])
        XCTAssertEqual(loadedTags.map(\.id), [tag.id])
    }

    func testCombinedFileExistsAfterMigrationAndLegacyFilesArePreserved() async throws {
        let tag = Tag(name: "Personal", color: .green)
        let snippet = Snippet(title: "Sig", content: "Best, Alan", tagIDs: [tag.id])
        try writeLegacyFiles(snippets: [snippet], tags: [tag])

        let manager = FileStorageManager(location: .custom, customPath: tempDir)
        _ = try await manager.loadSnippets()

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("snipster-library.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("snippets.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("tags.json").path))
    }

    func testNoMigrationOccursWhenNoLegacyFilesExist() async throws {
        // Fresh install, nothing on disk at all.
        let manager = FileStorageManager(location: .custom, customPath: tempDir)

        let snippets = try await manager.loadSnippets()
        let tags = try await manager.loadTags()

        XCTAssertTrue(snippets.isEmpty)
        XCTAssertTrue(tags.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("snipster-library.json").path))
    }

    func testSavingAfterMigrationPreservesBothSnippetsAndTags() async throws {
        let tag = Tag(name: "Work", color: .blue)
        let snippet = Snippet(title: "Greeting", content: "Hello", tagIDs: [tag.id])
        try writeLegacyFiles(snippets: [snippet], tags: [tag])

        let manager = FileStorageManager(location: .custom, customPath: tempDir)
        _ = try await manager.loadSnippets()

        // Saving a new snippet must not lose the tag that migration brought over.
        let secondSnippet = Snippet(title: "Second", content: "World")
        try await manager.saveSnippets([snippet, secondSnippet])

        let reloadedSnippets = try await manager.loadSnippets()
        let reloadedTags = try await manager.loadTags()

        XCTAssertEqual(Set(reloadedSnippets.map(\.id)), Set([snippet.id, secondSnippet.id]))
        XCTAssertEqual(reloadedTags.map(\.id), [tag.id])
    }

    func testDoesNotReMigrateOnceCombinedFileExists() async throws {
        let tag = Tag(name: "Work", color: .blue)
        let snippet = Snippet(title: "Greeting", content: "Hello", tagIDs: [tag.id])
        try writeLegacyFiles(snippets: [snippet], tags: [tag])

        let manager = FileStorageManager(location: .custom, customPath: tempDir)
        _ = try await manager.loadSnippets()

        // Now mutate the legacy files directly — since the combined file
        // already exists, a second load must NOT re-migrate and overwrite
        // whatever's already in the combined file.
        try writeLegacyFiles(snippets: [], tags: [])

        let reloadedSnippets = try await manager.loadSnippets()
        XCTAssertEqual(reloadedSnippets.map(\.id), [snippet.id])
    }
}
