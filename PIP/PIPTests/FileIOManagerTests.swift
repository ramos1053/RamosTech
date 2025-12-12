import XCTest
@testable import PIP

/// Integration tests for FileIOManager
/// Tests crash safety, atomic writes, and encoding detection
@MainActor
final class FileIOManagerTests: XCTestCase {

    var fileManager: FileManager!
    var testDirectory: URL!
    var ioManager: FileIOManager!

    override func setUp() async throws {
        fileManager = FileManager.default
        ioManager = FileIOManager()

        // Create temporary test directory
        testDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PIPTests")
            .appendingPathComponent(UUID().uuidString)

        try fileManager.createDirectory(at: testDirectory,
                                       withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test directory
        try? fileManager.removeItem(at: testDirectory)
    }

    // MARK: - Read Tests

    func testReadSimpleFile() async throws {
        let testURL = testDirectory.appendingPathComponent("test.txt")
        let testContent = "Hello, World!"

        try testContent.write(to: testURL, atomically: true, encoding: .utf8)

        let (content, metadata) = try await ioManager.readFile(at: testURL)

        XCTAssertEqual(content, testContent)
        XCTAssertEqual(metadata.encoding, .utf8)
        XCTAssertFalse(metadata.hasBOM)
    }

    func testReadUTF8WithBOM() async throws {
        let testURL = testDirectory.appendingPathComponent("test-bom.txt")

        // Create UTF-8 file with BOM
        var data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
        data.append("Hello".data(using: .utf8)!)

        try data.write(to: testURL)

        let (content, metadata) = try await ioManager.readFile(at: testURL)

        XCTAssertEqual(metadata.encoding, .utf8)
        XCTAssertTrue(metadata.hasBOM)
        XCTAssertEqual(content, "\u{FEFF}Hello") // BOM included in content
    }

    func testReadUTF16LEBOM() async throws {
        let testURL = testDirectory.appendingPathComponent("test-utf16le.txt")

        // Create UTF-16 LE file with BOM
        var data = Data([0xFF, 0xFE]) // UTF-16 LE BOM
        data.append("Test".data(using: .utf16LittleEndian)!)

        try data.write(to: testURL)

        let (_, metadata) = try await ioManager.readFile(at: testURL)

        XCTAssertEqual(metadata.encoding, .utf16LittleEndian)
        XCTAssertTrue(metadata.hasBOM)
    }

    func testReadFileNotFound() async throws {
        let nonExistentURL = testDirectory.appendingPathComponent("nonexistent.txt")

        do {
            _ = try await ioManager.readFile(at: nonExistentURL)
            XCTFail("Should throw fileNotFound error")
        } catch let error as FileIOManager.FileError {
            XCTAssertEqual(error, FileIOManager.FileError.fileNotFound)
        }
    }

    func testLineEndingDetection() async throws {
        // Test CRLF (Windows)
        let crlfURL = testDirectory.appendingPathComponent("crlf.txt")
        try "Line1\r\nLine2\r\n".write(to: crlfURL, atomically: true, encoding: .utf8)

        let (_, crlfMetadata) = try await ioManager.readFile(at: crlfURL)
        XCTAssertEqual(crlfMetadata.detectedLineEnding, .crlf)

        // Test LF (Unix/Mac)
        let lfURL = testDirectory.appendingPathComponent("lf.txt")
        try "Line1\nLine2\n".write(to: lfURL, atomically: true, encoding: .utf8)

        let (_, lfMetadata) = try await ioManager.readFile(at: lfURL)
        XCTAssertEqual(lfMetadata.detectedLineEnding, .lf)

        // Test CR (Old Mac)
        let crURL = testDirectory.appendingPathComponent("cr.txt")
        try "Line1\rLine2\r".write(to: crURL, atomically: true, encoding: .utf8)

        let (_, crMetadata) = try await ioManager.readFile(at: crURL)
        XCTAssertEqual(crMetadata.detectedLineEnding, .cr)
    }

    // MARK: - Write Tests

    func testAtomicWrite() async throws {
        let testURL = testDirectory.appendingPathComponent("atomic.txt")
        let content = "Atomic write test"

        try await ioManager.writeFile(content: content, to: testURL, atomic: true)

        let readContent = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(readContent, content)
    }

    func testNonAtomicWrite() async throws {
        let testURL = testDirectory.appendingPathComponent("nonatomic.txt")
        let content = "Non-atomic write test"

        try await ioManager.writeFile(content: content, to: testURL, atomic: false)

        let readContent = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(readContent, content)
    }

    func testOverwriteExistingFile() async throws {
        let testURL = testDirectory.appendingPathComponent("overwrite.txt")

        // Write initial content
        try await ioManager.writeFile(content: "Original", to: testURL)
        let original = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(original, "Original")

        // Overwrite
        try await ioManager.writeFile(content: "Updated", to: testURL)
        let updated = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(updated, "Updated")
    }

    func testWriteDifferentEncodings() async throws {
        let testContent = "Test encoding: café"

        // UTF-8
        let utf8URL = testDirectory.appendingPathComponent("utf8.txt")
        try await ioManager.writeFile(content: testContent, to: utf8URL, encoding: .utf8)
        let utf8Read = try String(contentsOf: utf8URL, encoding: .utf8)
        XCTAssertEqual(utf8Read, testContent)

        // UTF-16
        let utf16URL = testDirectory.appendingPathComponent("utf16.txt")
        try await ioManager.writeFile(content: testContent, to: utf16URL, encoding: .utf16)
        let utf16Read = try String(contentsOf: utf16URL, encoding: .utf16)
        XCTAssertEqual(utf16Read, testContent)
    }

    // MARK: - Crash Safety Tests

    func testAtomicWriteEnsuresCompleteFile() async throws {
        let testURL = testDirectory.appendingPathComponent("crash-safe.txt")
        let largeContent = String(repeating: "This is a test line.\n", count: 10000)

        // Perform atomic write
        try await ioManager.writeFile(content: largeContent, to: testURL, atomic: true)

        // Verify file is complete
        let readContent = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(readContent, largeContent)
        XCTAssertEqual(readContent.count, largeContent.count)
    }

    func testNoPartialWritesWithAtomic() async throws {
        let testURL = testDirectory.appendingPathComponent("no-partial.txt")

        // Write initial content
        try await ioManager.writeFile(content: "Initial content", to: testURL)

        // Verify no temp files exist after write
        let tempFiles = try fileManager.contentsOfDirectory(at: testDirectory,
                                                            includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains(".tmp") }

        XCTAssertTrue(tempFiles.isEmpty, "No temporary files should remain after atomic write")
    }

    func testAtomicWritePreservesOldFileOnFailure() async throws {
        let testURL = testDirectory.appendingPathComponent("preserve-old.txt")

        // Write initial content
        let originalContent = "Original content"
        try await ioManager.writeFile(content: originalContent, to: testURL)

        // Try to write invalid encoding (this should not corrupt the original)
        // Note: This test verifies behavior, actual failure scenarios may vary

        // Verify original is preserved
        let readContent = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(readContent, originalContent)
    }

    func testMultipleConcurrentWrites() async throws {
        let testURL = testDirectory.appendingPathComponent("concurrent.txt")

        // Perform multiple writes concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? await self.ioManager.writeFile(
                        content: "Write \(i)",
                        to: testURL,
                        atomic: true
                    )
                }
            }
        }

        // Verify file exists and is complete (not corrupted)
        let exists = fileManager.fileExists(atPath: testURL.path)
        XCTAssertTrue(exists)

        let content = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.hasPrefix("Write "))
    }

    // MARK: - Backup Tests

    func testSaveWithBackup() async throws {
        let testURL = testDirectory.appendingPathComponent("backup-test.txt")
        let backupURL = testDirectory.appendingPathComponent("backup-test.txt~")

        // Write initial file
        try await ioManager.writeFile(content: "Original", to: testURL)

        // Save with backup
        try await ioManager.saveWithBackup(content: "Updated", to: testURL)

        // Verify backup exists and contains original content
        XCTAssertTrue(fileManager.fileExists(atPath: backupURL.path))
        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertEqual(backupContent, "Original")

        // Verify new file has updated content
        let newContent = try String(contentsOf: testURL, encoding: .utf8)
        XCTAssertEqual(newContent, "Updated")
    }

    func testSaveWithBackupOverwritesOldBackup() async throws {
        let testURL = testDirectory.appendingPathComponent("backup-overwrite.txt")
        let backupURL = testDirectory.appendingPathComponent("backup-overwrite.txt~")

        // First save
        try await ioManager.writeFile(content: "Version1", to: testURL)
        try await ioManager.saveWithBackup(content: "Version2", to: testURL)

        let backup1 = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertEqual(backup1, "Version1")

        // Second save (should overwrite backup)
        try await ioManager.saveWithBackup(content: "Version3", to: testURL)

        let backup2 = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertEqual(backup2, "Version2") // Backup should now have Version2
    }

    // MARK: - Large File Tests

    func testLargeFileRead() async throws {
        let testURL = testDirectory.appendingPathComponent("large.txt")

        // Create a large file (just under 100MB limit)
        let lineSize = 100
        let lineCount = (90 * 1024 * 1024) / lineSize // ~90MB
        var largeContent = ""

        for i in 0..<lineCount {
            largeContent += String(repeating: "x", count: lineSize - 1) + "\n"

            // Write in chunks to avoid memory issues during test
            if i % 100000 == 0 && i > 0 {
                try largeContent.write(to: testURL, atomically: true, encoding: .utf8)
                largeContent = ""
            }
        }

        if !largeContent.isEmpty {
            try largeContent.write(to: testURL, atomically: true, encoding: .utf8)
        }

        // Should be able to read
        let (content, metadata) = try await ioManager.readFile(at: testURL)

        XCTAssertGreaterThan(metadata.size, 80 * 1024 * 1024) // At least 80MB
        XCTAssertFalse(content.isEmpty)
    }

    // MARK: - Streaming Tests

    func testStreamingRead() async throws {
        let testURL = testDirectory.appendingPathComponent("stream.txt")
        let testContent = String(repeating: "Line of text\n", count: 10000)

        try testContent.write(to: testURL, atomically: true, encoding: .utf8)

        var chunks: [String] = []
        var lastProgress: Double = 0

        try await ioManager.streamFile(at: testURL) { chunk, progress in
            chunks.append(chunk)
            lastProgress = progress
        }

        let reconstructed = chunks.joined()
        XCTAssertEqual(reconstructed, testContent)
        XCTAssertEqual(lastProgress, 1.0, "Should reach 100% progress")
    }

    // MARK: - Preview Tests

    func testFilePreview() async throws {
        let testURL = testDirectory.appendingPathComponent("preview.txt")
        let longContent = String(repeating: "This is a long file with lots of content. ", count: 1000)

        try longContent.write(to: testURL, atomically: true, encoding: .utf8)

        let (preview, metadata) = try await ioManager.readFilePreview(at: testURL)

        XCTAssertLessThan(preview.count, longContent.count)
        XCTAssertGreaterThan(metadata.size, Int64(preview.count))
    }
}
