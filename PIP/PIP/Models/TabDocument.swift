import Foundation
import SwiftUI
import Combine

/// Represents a single document in a tab
@MainActor
class TabDocument: ObservableObject, Identifiable {
    let id = UUID()

    let textEngine: TextEngine  // Changed from @Published var to let
    @Published var documentInfo: DocumentManager.DocumentInfo?
    @Published var isModified: Bool = false
    @Published var originalContent: String = ""
    @Published var customName: String? = nil

    // Status bar info - mirrored from TextEngine for direct observation
    @Published var currentLine: Int = 1
    @Published var currentColumn: Int = 1
    @Published var fileSize: String = "0 bytes"

    private var cancellables = Set<AnyCancellable>()

    // Computed properties for character and word counts
    var characterCount: Int {
        return textEngine.text.count
    }

    var wordCount: Int {
        let words = textEngine.text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    var displayName: String {
        // Use custom name if set
        if let custom = customName, !custom.isEmpty {
            return custom
        }

        if let docInfo = documentInfo {
            return docInfo.displayName
        }
        // Use first word of text as temporary name
        return firstWordOfText
    }

    var fileExtension: String {
        guard let url = documentInfo?.url else { return "" }
        return url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
    }

    var fullDisplayName: String {
        // Use custom name if set
        if let custom = customName, !custom.isEmpty {
            return custom
        }

        if let url = documentInfo?.url {
            return url.lastPathComponent
        }
        // Use first word of text as temporary name
        return firstWordOfText
    }

    /// Extracts the first word from the text to use as a temporary tab name
    private var firstWordOfText: String {
        let text = textEngine.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If text is empty, return "Untitled"
        guard !text.isEmpty else { return "Untitled" }

        // Extract first word (split by whitespace)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let firstWord = words.first(where: { !$0.isEmpty }) ?? "Untitled"

        // Limit to reasonable length and remove special characters
        let cleaned = firstWord.prefix(20)
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)

        return cleaned.isEmpty ? "Untitled" : String(cleaned)
    }

    var filePath: String? {
        documentInfo?.url.path
    }

    var isExecutable: Bool {
        documentInfo?.isExecutable ?? false
    }

    var isRemote: Bool {
        documentInfo?.isRemote ?? false
    }

    init(documentInfo: DocumentManager.DocumentInfo? = nil) {
        // Initialize TextEngine on MainActor
        self.textEngine = MainActor.assumeIsolated {
            TextEngine()
        }
        self.documentInfo = documentInfo
        self.originalContent = ""

        // Subscribe to TextEngine's line and column updates
        textEngine.$currentLine
            .sink { [weak self] newLine in
                self?.currentLine = newLine
            }
            .store(in: &cancellables)

        textEngine.$currentColumn
            .sink { [weak self] newColumn in
                self?.currentColumn = newColumn
            }
            .store(in: &cancellables)

        // Subscribe to text changes to update file size
        textEngine.$text
            .map { text in
                let bytes = text.utf8.count
                if bytes < 1024 {
                    return "\(bytes) bytes"
                } else if bytes < 1024 * 1024 {
                    let kb = Double(bytes) / 1024.0
                    return String(format: "%.1f KB", kb)
                } else if bytes < 1024 * 1024 * 1024 {
                    let mb = Double(bytes) / (1024.0 * 1024.0)
                    return String(format: "%.2f MB", mb)
                } else {
                    let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
                    return String(format: "%.2f GB", gb)
                }
            }
            .sink { [weak self] size in
                self?.fileSize = size
            }
            .store(in: &cancellables)

        // Forward TextEngine changes to TabDocument's objectWillChange
        textEngine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Observe text changes to track modifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TextEngineDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateModifiedState()
            }
        }
    }

    func updateModifiedState() {
        isModified = textEngine.text != originalContent
        // Trigger update for computed properties (like displayName)
        objectWillChange.send()
    }

    func markAsSaved() {
        originalContent = textEngine.text
        isModified = false
    }

    func loadContent(_ content: String, documentInfo: DocumentManager.DocumentInfo) {
        textEngine.loadText(content)
        self.documentInfo = documentInfo
        self.originalContent = content
        self.isModified = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
