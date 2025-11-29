//
//  DebugLogger.swift
//  PIP
//
//  Created by A. Ramos on 2025.
//  Copyright © 2025 RamosTech. All rights reserved.
//

import Foundation
import AppKit

/// Comprehensive debug logging system with multiple log levels and persistence
@MainActor
final class DebugLogger: ObservableObject {

    static let shared = DebugLogger()

    // MARK: - Types

    enum LogLevel: Int, CaseIterable, Comparable {
        case trace = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        case critical = 5

        var displayName: String {
            switch self {
            case .trace: return "TRACE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }

        var icon: String {
            switch self {
            case .trace: return "🔍"
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }

        var color: NSColor {
            switch self {
            case .trace: return NSColor.systemGray
            case .debug: return NSColor.systemBlue
            case .info: return NSColor.systemGreen
            case .warning: return NSColor.systemOrange
            case .error: return NSColor.systemRed
            case .critical: return NSColor.systemPurple
            }
        }

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct LogEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let level: LogLevel
        let message: String
        let file: String
        let function: String
        let line: Int
        let category: String

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var formattedMessage: String {
            "[\(formattedTimestamp)] [\(level.displayName)] [\(category)] \(message)"
        }

        enum CodingKeys: String, CodingKey {
            case id, timestamp, level, message, file, function, line, category
        }

        init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, message: String, file: String, function: String, line: Int, category: String) {
            self.id = id
            self.timestamp = timestamp
            self.level = level
            self.message = message
            self.file = file
            self.function = function
            self.line = line
            self.category = category
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            let levelRaw = try container.decode(Int.self, forKey: .level)
            level = LogLevel(rawValue: levelRaw) ?? .info
            message = try container.decode(String.self, forKey: .message)
            file = try container.decode(String.self, forKey: .file)
            function = try container.decode(String.self, forKey: .function)
            line = try container.decode(Int.self, forKey: .line)
            category = try container.decode(String.self, forKey: .category)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(level.rawValue, forKey: .level)
            try container.encode(message, forKey: .message)
            try container.encode(file, forKey: .file)
            try container.encode(function, forKey: .function)
            try container.encode(line, forKey: .line)
            try container.encode(category, forKey: .category)
        }
    }

    struct PerformanceMetrics {
        var memoryUsage: UInt64 = 0
        var operationCount: Int = 0
        var totalOperationTime: TimeInterval = 0
        var fileIOCount: Int = 0
        var lastUpdate: Date = Date()
    }

    // MARK: - Properties

    @Published private(set) var logs: [LogEntry] = []
    @Published var currentLogLevel: LogLevel = .debug
    @Published var isEnabled: Bool = false
    @Published private(set) var performanceMetrics = PerformanceMetrics()

    private let maxLogsInMemory = 10000
    private let logFileURL: URL
    private let performanceUpdateInterval: TimeInterval = 1.0
    private var performanceTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Set up log file directory
        let logsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PIP/Logs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        logFileURL = logsDirectory.appendingPathComponent("pip-\(dateString).log")

        // Start performance monitoring
        startPerformanceMonitoring()

        // Log startup
        log(.info, "PIP Debug Logger initialized", category: "System")
    }

    // MARK: - Logging Methods

    func trace(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.trace, message, file: file, function: function, line: line, category: category)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.debug, message, file: file, function: function, line: line, category: category)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.info, message, file: file, function: function, line: line, category: category)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.warning, message, file: file, function: function, line: line, category: category)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.error, message, file: file, function: function, line: line, category: category)
    }

    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        log(.critical, message, file: file, function: function, line: line, category: category)
    }

    // MARK: - Enhanced Error Logging

    /// Log an error with additional context including error details and optional stack trace
    func logError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        var message = "\(context): \(error.localizedDescription)"

        // Add error code if available
        if let nsError = error as NSError? {
            message += " (Domain: \(nsError.domain), Code: \(nsError.code))"

            // Add additional error info if available
            if let failureReason = nsError.localizedFailureReason {
                message += "\n  Reason: \(failureReason)"
            }
            if let recoverySuggestion = nsError.localizedRecoverySuggestion {
                message += "\n  Suggestion: \(recoverySuggestion)"
            }
        }

        log(.error, message, file: file, function: function, line: line, category: category)
    }

    /// Log with call stack information for debugging complex issues
    func logWithStack(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String = "General") {
        var fullMessage = message

        // Capture and format stack trace (limited to first 5 frames for readability)
        let stackSymbols = Thread.callStackSymbols.prefix(5)
        if !stackSymbols.isEmpty {
            fullMessage += "\n  Stack trace:"
            for (index, symbol) in stackSymbols.enumerated() {
                // Clean up the symbol for readability
                let cleanSymbol = symbol
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                fullMessage += "\n    \(index). \(cleanSymbol)"
            }
        }

        log(level, fullMessage, file: file, function: function, line: line, category: category)
    }

    private func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String) {
        guard isEnabled && level >= currentLogLevel else { return }

        let filename = (file as NSString).lastPathComponent
        let entry = LogEntry(
            level: level,
            message: message,
            file: filename,
            function: function,
            line: line,
            category: category
        )

        // Add to in-memory logs
        logs.append(entry)

        // Trim logs if needed
        if logs.count > maxLogsInMemory {
            logs.removeFirst(logs.count - maxLogsInMemory)
        }

        // Note: File logging disabled - only write when user explicitly exports
        // writeToFile(entry)

        // Print to console for development
        #if DEBUG
        print(entry.formattedMessage)
        #endif
    }

    // MARK: - Performance Monitoring

    func trackOperation<T>(_ name: String, category: String = "Performance", operation: () throws -> T) rethrows -> T {
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime)
            performanceMetrics.operationCount += 1
            performanceMetrics.totalOperationTime += duration

            if duration > 0.1 { // Log slow operations
                warning("Slow operation: \(name) took \(String(format: "%.3f", duration))s", category: category)
            } else {
                trace("Operation: \(name) completed in \(String(format: "%.3f", duration))s", category: category)
            }
        }
        return try operation()
    }

    func trackFileIO(_ operation: String) {
        performanceMetrics.fileIOCount += 1
        trace("File I/O: \(operation)", category: "FileIO")
    }

    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: performanceUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func updatePerformanceMetrics() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            performanceMetrics.memoryUsage = info.resident_size
        }

        performanceMetrics.lastUpdate = Date()
    }

    // MARK: - File Operations

    private func writeToFile(_ entry: LogEntry) {
        let logLine = entry.formattedMessage + "\n"

        guard let data = logLine.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }

    func exportLogs() -> URL? {
        // Write current logs to file when explicitly requested
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())

        let exportURL = logFileURL.deletingLastPathComponent()
            .appendingPathComponent("pip-export-\(dateString).log")

        var logContent = ""
        for entry in logs {
            logContent += entry.formattedMessage + "\n"
        }

        guard let data = logContent.data(using: .utf8) else { return nil }

        do {
            try data.write(to: exportURL)
            return exportURL
        } catch {
            return nil
        }
    }

    func clearLogs() {
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
        info("Logs cleared", category: "System")
    }

    func getLogDirectory() -> URL {
        logFileURL.deletingLastPathComponent()
    }

    // MARK: - Deinitialization

    deinit {
        performanceTimer?.invalidate()
    }
}
