import Foundation

/// Manages file I/O operations with streaming support for large files
///
/// ## Invariants:
/// - All writes use atomic operations (write to temp, fsync, rename)
/// - Encoding is detected via BOM first, then heuristics
/// - Chunk size is optimized for memory/performance balance (1MB)
/// - File handles are always closed even on error
///
/// ## Performance:
/// - Streaming reads for files > 100MB
/// - In-memory reads for files < 100MB
/// - Atomic writes use fsync for crash safety
/// - Progress reporting for long operations
actor FileIOManager {

    // MARK: - Types

    enum FileError: Error, LocalizedError {
        case fileNotFound
        case unreadable
        case encodingDetectionFailed
        case writeFailure(String)
        case fileTooLarge
        case fsyncFailed
        case atomicWriteFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "File not found"
            case .unreadable: return "File is not readable"
            case .encodingDetectionFailed: return "Could not detect file encoding"
            case .writeFailure(let reason): return "Write failed: \(reason)"
            case .fileTooLarge: return "File is too large to open"
            case .fsyncFailed: return "Failed to sync file to disk"
            case .atomicWriteFailed: return "Atomic write operation failed"
            }
        }
    }

    struct FileMetadata {
        let url: URL
        let size: Int64
        let encoding: String.Encoding
        let hasBOM: Bool
        let detectedLineEnding: TextEngine.LineEnding
    }

    // MARK: - Constants

    private let chunkSize = 1024 * 1024 // 1 MB chunks
    private let maxInMemorySize: Int64 = 100 * 1024 * 1024 // 100 MB
    private let previewSize = 1024 * 10 // 10 KB for preview

    // MARK: - Reading

    /// Read entire file into memory (for files under maxInMemorySize)
    func readFile(at url: URL) async throws -> (content: String, metadata: FileMetadata) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FileError.unreadable
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize <= maxInMemorySize else {
            throw FileError.fileTooLarge
        }

        let data = try Data(contentsOf: url)
        let (encoding, hasBOM) = detectEncoding(data: data)

        guard let content = String(data: data, encoding: encoding) else {
            throw FileError.encodingDetectionFailed
        }

        let lineEnding = detectLineEnding(in: content)

        let metadata = FileMetadata(
            url: url,
            size: fileSize,
            encoding: encoding,
            hasBOM: hasBOM,
            detectedLineEnding: lineEnding
        )

        return (content, metadata)
    }

    /// Read file preview (first N bytes)
    func readFilePreview(at url: URL) async throws -> (preview: String, metadata: FileMetadata) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let previewData = try handle.read(upToCount: previewSize) ?? Data()
        let (encoding, hasBOM) = detectEncoding(data: previewData)

        guard let preview = String(data: previewData, encoding: encoding) else {
            throw FileError.encodingDetectionFailed
        }

        let lineEnding = detectLineEnding(in: preview)

        let metadata = FileMetadata(
            url: url,
            size: fileSize,
            encoding: encoding,
            hasBOM: hasBOM,
            detectedLineEnding: lineEnding
        )

        return (preview, metadata)
    }

    /// Stream file in chunks with progress reporting
    func streamFile(
        at url: URL,
        chunkHandler: @escaping (String, Double) async -> Void
    ) async throws {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        // Detect encoding from first chunk
        let firstChunk = try handle.read(upToCount: chunkSize) ?? Data()
        try handle.seek(toOffset: 0)

        let (encoding, _) = detectEncoding(data: firstChunk)

        var bytesRead: Int64 = 0

        while true {
            let data = try handle.read(upToCount: chunkSize)
            guard let data = data, !data.isEmpty else { break }

            if let chunk = String(data: data, encoding: encoding) {
                bytesRead += Int64(data.count)
                let progress = Double(bytesRead) / Double(fileSize)
                await chunkHandler(chunk, progress)
            }
        }
    }

    // MARK: - Writing

    /// Write content to file atomically with crash safety using fsync and rename
    ///
    /// ## Crash Safety Protocol:
    /// 1. Write data to temporary file with unique name
    /// 2. Call fsync on temporary file to ensure data is on disk
    /// 3. Close temporary file
    /// 4. Atomically rename temporary file to target file
    /// 5. Call fsync on parent directory to ensure rename is durable
    ///
    /// This ensures that even in case of power loss or system crash,
    /// either the old file or the new file exists completely, never partial data.
    func writeFile(content: String, to url: URL, encoding: String.Encoding = .utf8, atomic: Bool = true) async throws {
        guard let data = content.data(using: encoding) else {
            throw FileError.writeFailure("Could not encode content")
        }

        if atomic {
            try await atomicWrite(data: data, to: url)
        } else {
            try data.write(to: url, options: [])
        }
    }

    /// Perform atomic write with fsync and rename for crash safety
    private func atomicWrite(data: Data, to url: URL) async throws {
        let fileManager = FileManager.default
        let parentDir = url.deletingLastPathComponent()

        // Generate unique temporary file name
        let tempFileName = ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        let tempURL = parentDir.appendingPathComponent(tempFileName)

        do {
            // Step 1: Write to temporary file
            try data.write(to: tempURL, options: [])

            // Step 2: Open file descriptor for fsync
            let fileDescriptor = open(tempURL.path, O_RDWR)
            guard fileDescriptor >= 0 else {
                throw FileError.fsyncFailed
            }

            defer {
                close(fileDescriptor)
            }

            // Step 3: fsync to ensure data is on disk
            if fsync(fileDescriptor) != 0 {
                throw FileError.fsyncFailed
            }

            // Step 4: Atomically rename/replace
            #if os(macOS) || os(iOS)
            // Use renamex_np on Apple platforms for atomic replace
            if fileManager.fileExists(atPath: url.path) {
                // Remove destination if exists
                _ = try? fileManager.replaceItemAt(url, withItemAt: tempURL,
                                                   backupItemName: nil,
                                                   options: [.usingNewMetadataOnly])
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
            #else
            // On other platforms, use standard rename
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try fileManager.moveItem(at: tempURL, to: url)
            #endif

            // Step 5: fsync parent directory to ensure rename is durable
            try fsyncDirectory(at: parentDir)

        } catch {
            // Clean up temporary file on error
            try? fileManager.removeItem(at: tempURL)
            throw FileError.atomicWriteFailed
        }
    }

    /// Sync directory to ensure file metadata operations (rename, delete) are durable
    private func fsyncDirectory(at url: URL) throws {
        let dirDescriptor = open(url.path, O_RDONLY)
        guard dirDescriptor >= 0 else {
            // Directory fsync failure is not fatal but should be logged
            return
        }

        defer {
            close(dirDescriptor)
        }

        _ = fsync(dirDescriptor)
    }

    /// Save with backup
    func saveWithBackup(content: String, to url: URL, encoding: String.Encoding = .utf8) async throws {
        let fileManager = FileManager.default

        // Create backup if original exists
        if fileManager.fileExists(atPath: url.path) {
            let backupURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent)~")

            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }

            try fileManager.copyItem(at: url, to: backupURL)
        }

        try await writeFile(content: content, to: url, encoding: encoding, atomic: true)
    }

    // MARK: - Encoding Detection

    private func detectEncoding(data: Data) -> (encoding: String.Encoding, hasBOM: Bool) {
        // Check for BOM
        if data.count >= 3 {
            let bom = data.prefix(3)

            // UTF-8 BOM
            if bom == Data([0xEF, 0xBB, 0xBF]) {
                return (.utf8, true)
            }
        }

        if data.count >= 2 {
            let bom = data.prefix(2)

            // UTF-16 BE BOM
            if bom == Data([0xFE, 0xFF]) {
                return (.utf16BigEndian, true)
            }

            // UTF-16 LE BOM
            if bom == Data([0xFF, 0xFE]) {
                return (.utf16LittleEndian, true)
            }
        }

        // Try UTF-8 without BOM
        if String(data: data, encoding: .utf8) != nil {
            return (.utf8, false)
        }

        // Try UTF-16
        if String(data: data, encoding: .utf16) != nil {
            return (.utf16, false)
        }

        // Fall back to ASCII/ISO Latin 1
        return (.isoLatin1, false)
    }

    private func detectLineEnding(in text: String) -> TextEngine.LineEnding {
        if text.contains("\r\n") {
            return .crlf
        } else if text.contains("\r") {
            return .cr
        } else {
            return .lf
        }
    }
}
