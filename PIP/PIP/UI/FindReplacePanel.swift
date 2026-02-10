import SwiftUI
import AppKit

/// Find & Replace panel with regex support (CotEditor-like)
struct FindReplacePanel: View {
    @ObservedObject var preferences = AppPreferences.shared
    @Binding var isVisible: Bool
    @Binding var searchText: String
    @Binding var replaceText: String

    @State private var caseSensitive = false
    @State private var wholeWord = false
    @State private var useRegex = false
    @State private var matchCount = 0
    @State private var currentMatch = 0
    @State private var isReplaceExpanded = false
    @State private var errorMessage: String?

    let searchEngine = SearchEngine()
    var documentText: Binding<String>
    var onFindNext: (() -> Void)?
    var onFindPrevious: (() -> Void)?
    var onReplace: (() -> Void)?
    var onReplaceAll: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Search field row
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Find", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            findNext()
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

                // Match count
                if !searchText.isEmpty {
                    Text("\(currentMatch)/\(matchCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }

                // Navigation buttons
                Button(action: findPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(searchText.isEmpty || matchCount == 0)
                .help("Find Previous (⇧⌘G)")

                Button(action: findNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(searchText.isEmpty || matchCount == 0)
                .help("Find Next (⌘G)")

                // Expand/collapse replace
                Button(action: { withAnimation { isReplaceExpanded.toggle() } }) {
                    Image(systemName: isReplaceExpanded ? "chevron.up.square" : "chevron.down.square")
                }
                .buttonStyle(.borderless)
                .help(isReplaceExpanded ? "Hide Replace" : "Show Replace")

                // Close button
                Button(action: {
                    isVisible = false
                    NotificationCenter.default.post(name: .clearSearchHighlights, object: nil)
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close (Esc)")
            }

            // Replace field row (expandable)
            if isReplaceExpanded {
                HStack(spacing: 8) {
                    // Replace field
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(.secondary)

                        TextField("Replace with", text: $replaceText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )

                    Button("Replace") {
                        replace()
                    }
                    .disabled(searchText.isEmpty || matchCount == 0)

                    Button("All") {
                        replaceAll()
                    }
                    .disabled(searchText.isEmpty || matchCount == 0)
                    .help("Replace All")
                }
            }

            // Options row
            HStack(spacing: 12) {
                Toggle("Aa", isOn: $caseSensitive)
                    .toggleStyle(.button)
                    .help("Case Sensitive")

                Toggle("\\b", isOn: $wholeWord)
                    .toggleStyle(.button)
                    .help("Whole Word")

                Toggle(".*", isOn: $useRegex)
                    .toggleStyle(.button)
                    .help("Regular Expression")

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .onChange(of: searchText) { _, _ in
            updateMatchCount()
        }
        .onChange(of: caseSensitive) { _, _ in
            updateMatchCount()
        }
        .onChange(of: wholeWord) { _, _ in
            updateMatchCount()
        }
        .onChange(of: useRegex) { _, _ in
            updateMatchCount()
        }
        .onAppear {
            // Listen for match info updates from editor
            NotificationCenter.default.addObserver(
                forName: .updateFindMatchInfo,
                object: nil,
                queue: .main
            ) { notification in
                if let info = notification.object as? FindMatchInfo {
                    currentMatch = info.currentMatch
                    matchCount = info.totalMatches
                }
            }
        }
    }

    // MARK: - Actions

    private func updateMatchCount() {
        guard !searchText.isEmpty else {
            matchCount = 0
            currentMatch = 0
            errorMessage = nil
            return
        }

        do {
            let options = SearchEngine.SearchOptions(
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                useRegex: useRegex
            )
            matchCount = try searchEngine.count(pattern: searchText, in: documentText.wrappedValue, options: options)
            currentMatch = matchCount > 0 ? 1 : 0
            errorMessage = nil
        } catch {
            matchCount = 0
            currentMatch = 0
            errorMessage = "Invalid pattern"
        }
    }

    private func findNext() {
        onFindNext?()
        if currentMatch < matchCount {
            currentMatch += 1
        } else {
            currentMatch = 1 // Wrap around
        }

        // Post notification for text view to handle
        NotificationCenter.default.post(
            name: .findNext,
            object: FindRequest(
                searchText: searchText,
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                useRegex: useRegex
            )
        )
    }

    private func findPrevious() {
        onFindPrevious?()
        if currentMatch > 1 {
            currentMatch -= 1
        } else {
            currentMatch = matchCount // Wrap around
        }

        NotificationCenter.default.post(
            name: .findPrevious,
            object: FindRequest(
                searchText: searchText,
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                useRegex: useRegex
            )
        )
    }

    private func replace() {
        onReplace?()

        NotificationCenter.default.post(
            name: .replaceNext,
            object: ReplaceRequest(
                searchText: searchText,
                replaceText: replaceText,
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                useRegex: useRegex
            )
        )

        updateMatchCount()
    }

    private func replaceAll() {
        onReplaceAll?()

        NotificationCenter.default.post(
            name: .replaceAll,
            object: ReplaceRequest(
                searchText: searchText,
                replaceText: replaceText,
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                useRegex: useRegex
            )
        )

        updateMatchCount()
    }
}

// MARK: - Request Types

struct FindRequest {
    let searchText: String
    let caseSensitive: Bool
    let wholeWord: Bool
    let useRegex: Bool
}

struct ReplaceRequest {
    let searchText: String
    let replaceText: String
    let caseSensitive: Bool
    let wholeWord: Bool
    let useRegex: Bool
}

#Preview("Find & Replace Panel") {
    @Previewable @State var isVisible = true
    @Previewable @State var searchText = "function"
    @Previewable @State var replaceText = "method"
    @Previewable @State var documentText = """
    function hello() {
        console.log("Hello");
    }

    function goodbye() {
        console.log("Goodbye");
    }
    """

    return FindReplacePanel(
        isVisible: $isVisible,
        searchText: $searchText,
        replaceText: $replaceText,
        documentText: $documentText
    )
}

