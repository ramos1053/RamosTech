import Foundation

/// Represents a text snippet that can be expanded
struct Snippet: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var trigger: String
    var expansion: String
    var description: String

    init(id: UUID = UUID(), trigger: String, expansion: String, description: String = "") {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.description = description
    }
}

/// Manages snippets - loading, saving, and providing access
@MainActor
final class SnippetManager: ObservableObject {
    static let shared = SnippetManager()

    @Published var snippets: [Snippet] = []

    private let snippetsURL: URL

    init() {
        // Store snippets in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pipDirectory = appSupport.appendingPathComponent("PIP")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: pipDirectory, withIntermediateDirectories: true)

        self.snippetsURL = pipDirectory.appendingPathComponent("snippets.json")

        loadSnippets()
    }

    // MARK: - Load/Save

    func loadSnippets() {
        guard FileManager.default.fileExists(atPath: snippetsURL.path) else {
            // Create default snippets
            snippets = createDefaultSnippets()
            saveSnippets()
            return
        }

        do {
            let data = try Data(contentsOf: snippetsURL)
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            print("Failed to load snippets: \(error)")
            snippets = createDefaultSnippets()
        }
    }

    func saveSnippets() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snippets)
            try data.write(to: snippetsURL)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }

    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func deleteSnippets(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
        saveSnippets()
    }

    // MARK: - Snippet Lookup

    func findSnippet(for trigger: String) -> Snippet? {
        return snippets.first { $0.trigger == trigger }
    }

    // MARK: - Import/Export

    func exportSnippets(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snippets)
        try data.write(to: url)
    }

    func importSnippets(from url: URL, replace: Bool = false) throws {
        let data = try Data(contentsOf: url)
        let importedSnippets = try JSONDecoder().decode([Snippet].self, from: data)

        if replace {
            snippets = importedSnippets
        } else {
            // Merge, avoiding duplicates by trigger
            for snippet in importedSnippets {
                if !snippets.contains(where: { $0.trigger == snippet.trigger }) {
                    snippets.append(snippet)
                }
            }
        }

        saveSnippets()
    }

    var snippetsFileURL: URL {
        return snippetsURL
    }

    // MARK: - Default Snippets

    private func createDefaultSnippets() -> [Snippet] {
        return [
            Snippet(
                trigger: "!bash",
                expansion: "#!/bin/bash\n\nset -e\n\n",
                description: "Bash script header with error exit"
            ),
            Snippet(
                trigger: "!python",
                expansion: "#!/usr/bin/env python3\n\ndef main():\n    pass\n\nif __name__ == \"__main__\":\n    main()\n",
                description: "Python script template"
            ),
            Snippet(
                trigger: "!date",
                expansion: Date().formatted(date: .abbreviated, time: .omitted),
                description: "Current date"
            ),
            Snippet(
                trigger: "!time",
                expansion: Date().formatted(date: .omitted, time: .shortened),
                description: "Current time"
            )
        ]
    }
}
