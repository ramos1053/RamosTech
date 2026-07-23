//
//  SpotlightSearchView.swift
//  Snipster
//
//  Created by RamosTech on 1/8/26.
//

import SwiftUI
import AppKit

/// Navigation level in the hierarchy
enum NavigationLevel: Equatable {
    case tags
    case allSnippets
    case tagSnippets(Tag)
    case clipboardHistory
    case untaggedSnippets
}

/// A Spotlight-style search interface for quickly finding and inserting snippets
/// Inspired by Clipy's popup menu design with tag-based grouping
struct SpotlightSearchView: View {
    @EnvironmentObject var viewModel: SnippetViewModel
    @EnvironmentObject var tagStore: TagStore
    @EnvironmentObject var clipboardHistory: ClipboardHistoryService

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var navigationLevel: NavigationLevel = .tags
    @FocusState private var searchFieldFocused: Bool

    /// Cmd/Shift-click multi-select, snippets only (tags/folders/history
    /// entries aren't part of this). Independent of `selectedIndex`, which
    /// is just the arrow-key cursor position.
    @State private var multiSelectedIDs: Set<UUID> = []
    @State private var pendingDeleteIDs: Set<UUID> = []
    @State private var showingBulkDeleteConfirm = false

    // MARK: - Computed Properties

    private var currentItems: [SpotlightItem] {
        switch navigationLevel {
        case .tags:
            // When searching, show matching snippets instead of tags
            if !searchText.isEmpty {
                let items: [SpotlightItem] = filteredAllSnippets.map { SpotlightItem.snippet($0) }
                return items
            } else {
                // No search - show tag folders, with pinned pseudo-folders
                // (Clipboard History, Untagged) at the top when they have
                // anything in them.
                var items: [SpotlightItem] = []
                if clipboardHistory.isEnabled && !clipboardHistory.entries.isEmpty {
                    items.append(.clipboardHistoryFolder)
                }
                if untaggedSnippetCount > 0 {
                    items.append(.untaggedFolder)
                }
                items.append(contentsOf: filteredTags.map { SpotlightItem.tag($0) })
                return items
            }
        case .allSnippets:
            let items: [SpotlightItem] = filteredAllSnippets.map { SpotlightItem.snippet($0) }
            return items
        case .tagSnippets(let tag):
            let snippets = filteredSnippetsForTag(tag)
            let items: [SpotlightItem] = snippets.map { SpotlightItem.snippet($0) }
            return items
        case .clipboardHistory:
            let items: [SpotlightItem] = filteredHistoryEntries.map { SpotlightItem.historyEntry($0) }
            return items
        case .untaggedSnippets:
            let items: [SpotlightItem] = filteredUntaggedSnippets.map { SpotlightItem.snippet($0) }
            return items
        }
    }

    private var filteredTags: [Tag] {
        let allTags = tagStore.tags

        if searchText.isEmpty {
            return allTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return allTags.filter { tag in
            tag.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredAllSnippets: [Snippet] {
        let allSnippets = viewModel.snippetStore.snippets

        if searchText.isEmpty {
            return allSnippets
        }

        return allSnippets.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(searchText) ||
            snippet.content.localizedCaseInsensitiveContains(searchText) ||
            snippet.trigger.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func filteredSnippetsForTag(_ tag: Tag) -> [Snippet] {
        let allSnippets = viewModel.snippetStore.snippets

        let tagSnippets = allSnippets.filter { snippet in
            snippet.tagIDs.contains(tag.id)
        }

        if searchText.isEmpty {
            return tagSnippets
        }

        return tagSnippets.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(searchText) ||
            snippet.content.localizedCaseInsensitiveContains(searchText) ||
            snippet.trigger.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func snippetCount(for tag: Tag) -> Int {
        viewModel.snippetStore.snippets.filter { $0.tagIDs.contains(tag.id) }.count
    }

    private var untaggedSnippetCount: Int {
        viewModel.snippetStore.snippets.filter { $0.tagIDs.isEmpty }.count
    }

    private var filteredUntaggedSnippets: [Snippet] {
        let untagged = viewModel.snippetStore.snippets.filter { $0.tagIDs.isEmpty }

        if searchText.isEmpty {
            return untagged
        }

        return untagged.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(searchText) ||
            snippet.content.localizedCaseInsensitiveContains(searchText) ||
            snippet.trigger.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func itemSnippetCount(for item: SpotlightItem) -> Int? {
        switch item {
        case .tag(let tag):
            return snippetCount(for: tag)
        case .untaggedFolder:
            return untaggedSnippetCount
        default:
            return nil
        }
    }

    private var filteredHistoryEntries: [ClipboardHistoryEntry] {
        let allEntries = clipboardHistory.entries

        if searchText.isEmpty {
            return allEntries
        }

        return allEntries.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    private var breadcrumbText: String {
        switch navigationLevel {
        case .tags:
            return "Browse by Tag"
        case .allSnippets:
            return "All Snippets"
        case .tagSnippets(let tag):
            return tag.name
        case .clipboardHistory:
            return "Clipboard History"
        case .untaggedSnippets:
            return "Untagged"
        }
    }

    private var showBackButton: Bool {
        switch navigationLevel {
        case .tags:
            return false
        case .allSnippets, .tagSnippets, .clipboardHistory, .untaggedSnippets:
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb / Navigation bar
            HStack(spacing: 6) {
                if showBackButton {
                    Button(action: navigateBack) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Go back (ESC)")
                }

                Image(systemName: navigationIcon)
                    .foregroundColor(.secondary)
                    .font(.caption)

                Text(breadcrumbText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(currentItems.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($searchFieldFocused)
                    .onSubmit {
                        selectCurrentItem()
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        selectedIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results list
            if currentItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(emptyStateMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<currentItems.count, id: \.self) { index in
                                let item = currentItems[index]
                                SpotlightItemRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    isMultiSelected: item.snippet.map { multiSelectedIDs.contains($0.id) } ?? false,
                                    snippetCount: itemSnippetCount(for: item),
                                    tagStore: tagStore,
                                    onPromoteToSnippet: promoteToSnippet,
                                    onDeleteSnippet: { requestDelete([$0.id]) },
                                    onDeleteSelected: { requestDelete(multiSelectedIDs) },
                                    onToggleCheck: { toggleChecked($0) }
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectItem(at: index)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo(currentItems[safe: newValue]?.id, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer with shortcuts
            HStack(spacing: 10) {
                if !multiSelectedIDs.isEmpty {
                    Text("\(multiSelectedIDs.count) selected")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    KeyboardShortcutHint(key: "⌫", description: "Delete")
                } else {
                    KeyboardShortcutHint(key: "↑↓", description: "Navigate")
                    KeyboardShortcutHint(key: "↵", description: navigationLevel == .tags ? "Open" : "Copy")
                    if case .tagSnippets = navigationLevel {
                        KeyboardShortcutHint(key: "⌘↵", description: "Paste")
                    } else if case .allSnippets = navigationLevel {
                        KeyboardShortcutHint(key: "⌘↵", description: "Paste")
                    } else if case .clipboardHistory = navigationLevel {
                        KeyboardShortcutHint(key: "⌘↵", description: "Paste")
                    } else if case .untaggedSnippets = navigationLevel {
                        KeyboardShortcutHint(key: "⌘↵", description: "Paste")
                    }
                }
                KeyboardShortcutHint(key: "ESC", description: showBackButton ? "Back" : "Close")

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(width: 380, height: 400)
        .onAppear {
            searchFieldFocused = true
            selectedIndex = 0

            // Start with tags view, but also add "All Snippets" option
            navigationLevel = .tags
        }
        .onChange(of: searchText) { oldValue, newValue in
            selectedIndex = 0
        }
        .onChange(of: navigationLevel) { oldValue, newValue in
            selectedIndex = 0
            searchText = ""
            multiSelectedIDs = []
        }
        .onKeyPress(keys: [.upArrow]) { _ in
            moveSelectionUp()
            return .handled
        }
        .onKeyPress(keys: [.downArrow]) { _ in
            moveSelectionDown()
            return .handled
        }
        .onKeyPress(keys: [.return]) { press in
            if press.modifiers.contains(.command) {
                selectCurrentItemAndPaste()
            } else {
                selectCurrentItem()
            }
            return .handled
        }
        .onKeyPress(keys: [.escape]) { _ in
            if showBackButton {
                navigateBack()
            } else {
                dismissWindow()
            }
            return .handled
        }
        .onKeyPress(keys: [.delete]) { _ in
            guard !multiSelectedIDs.isEmpty else { return .ignored }
            requestDelete(multiSelectedIDs)
            return .handled
        }
        .alert(
            "Delete \(pendingDeleteIDs.count) Snippet\(pendingDeleteIDs.count == 1 ? "" : "s")?",
            isPresented: $showingBulkDeleteConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                performDelete(pendingDeleteIDs)
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Computed UI Properties

    private var navigationIcon: String {
        switch navigationLevel {
        case .tags:
            return "folder.fill"
        case .allSnippets:
            return "doc.on.doc"
        case .tagSnippets:
            return "tag.fill"
        case .clipboardHistory:
            return "doc.on.clipboard"
        case .untaggedSnippets:
            return "tray"
        }
    }

    private var searchPlaceholder: String {
        switch navigationLevel {
        case .tags:
            return "Search snippets..."
        case .allSnippets:
            return "Search snippets..."
        case .tagSnippets(let tag):
            return "Search in \(tag.name)..."
        case .clipboardHistory:
            return "Search clipboard history..."
        case .untaggedSnippets:
            return "Search untagged snippets..."
        }
    }

    private var emptyStateIcon: String {
        switch navigationLevel {
        case .tags:
            return "tag.slash"
        case .allSnippets, .tagSnippets, .untaggedSnippets:
            return "doc.text.magnifyingglass"
        case .clipboardHistory:
            return "doc.on.clipboard"
        }
    }

    private var emptyStateMessage: String {
        switch navigationLevel {
        case .tags:
            return searchText.isEmpty ? "No tags found" : "No tags match '\(searchText)'"
        case .allSnippets:
            return searchText.isEmpty ? "No snippets found" : "No results for '\(searchText)'"
        case .tagSnippets(let tag):
            return searchText.isEmpty ? "No snippets in \(tag.name)" : "No results in \(tag.name)"
        case .clipboardHistory:
            return searchText.isEmpty ? "No clipboard history yet" : "No results for '\(searchText)'"
        case .untaggedSnippets:
            return searchText.isEmpty ? "No untagged snippets" : "No results for '\(searchText)'"
        }
    }

    // MARK: - Helper Functions

    private func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    private func moveSelectionDown() {
        if selectedIndex < currentItems.count - 1 {
            selectedIndex += 1
        }
    }

    private func navigateBack() {
        navigationLevel = .tags
    }

    private func selectItem(at index: Int) {
        selectedIndex = index
        selectCurrentItem()
    }

    /// Toggles a snippet's checkbox — a separate tap target from the row
    /// itself, so it doesn't disturb the row's normal click behavior (copy +
    /// dismiss for snippets, navigate for folders).
    private func toggleChecked(_ snippet: Snippet) {
        if multiSelectedIDs.contains(snippet.id) {
            multiSelectedIDs.remove(snippet.id)
        } else {
            multiSelectedIDs.insert(snippet.id)
        }
    }

    private func requestDelete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        pendingDeleteIDs = ids
        if ids.count > 1 {
            showingBulkDeleteConfirm = true
        } else {
            performDelete(ids)
        }
    }

    private func performDelete(_ ids: Set<UUID>) {
        viewModel.deleteSnippets(ids)
        multiSelectedIDs.subtract(ids)
        // deleteSnippets saves asynchronously, so currentItems hasn't shrunk
        // yet — reset to a always-safe index rather than try to predict the
        // post-delete count. selectCurrentItem() already guards selectedIndex
        // against currentItems.count, so this is never out of bounds.
        selectedIndex = 0
    }

    private func selectCurrentItem() {
        guard selectedIndex < currentItems.count else { return }

        let item = currentItems[selectedIndex]

        switch item {
        case .tag(let tag):
            // Navigate into tag
            navigationLevel = .tagSnippets(tag)
        case .snippet(let snippet):
            // Copy snippet and dismiss
            copySnippet(snippet)
            dismissWindow()
        case .allSnippetsOption:
            // Navigate to all snippets
            navigationLevel = .allSnippets
        case .clipboardHistoryFolder:
            // Navigate into clipboard history
            navigationLevel = .clipboardHistory
        case .untaggedFolder:
            // Navigate into untagged snippets
            navigationLevel = .untaggedSnippets
        case .historyEntry(let entry):
            // Copy the raw history content (no variable processing — it's
            // already-copied text, not a snippet) and dismiss
            copyHistoryEntry(entry)
            dismissWindow()
        }
    }

    private func selectCurrentItemAndPaste() {
        guard selectedIndex < currentItems.count else { return }

        let item = currentItems[selectedIndex]

        switch item {
        case .snippet(let snippet):
            copySnippet(snippet)
            dismissWindow()

            // Small delay before pasting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                simulatePaste()
            }
        case .historyEntry(let entry):
            copyHistoryEntry(entry)
            dismissWindow()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                simulatePaste()
            }
        default:
            // For non-snippet items, just do regular select
            selectCurrentItem()
        }
    }

    private func copySnippet(_ snippet: Snippet) {
        // Process variables in the content
        let processedContent = SnippetVariableProcessor.shared.processVariables(in: snippet.content)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(processedContent, forType: .string)

        // Update usage stats
        var updatedSnippet = snippet
        updatedSnippet.incrementUsage()
        viewModel.updateSnippet(updatedSnippet)
    }

    private func copyHistoryEntry(_ entry: ClipboardHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.content, forType: .string)
        // Deliberately not suppressed: the background poller picking this back
        // up and re-inserting it is what makes "select an old entry" bump it
        // to the top of history, matching expected clipboard-manager behavior.
    }

    private func promoteToSnippet(_ entry: ClipboardHistoryEntry) {
        WindowHelper.openSnippetDetailWindow(mode: .addFromClipboard(entry.content), viewModel: viewModel)
        dismissWindow()
    }

    private func simulatePaste() {
        // Create and post a Cmd+V event
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down for Cmd+V
        if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDownEvent.flags = .maskCommand
            keyDownEvent.post(tap: .cghidEventTap)
        }

        // Key up for Cmd+V
        if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUpEvent.flags = .maskCommand
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }

    private func dismissWindow() {
        SpotlightWindowManager.shared.hide()
    }
}

// MARK: - Array Extension for Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Spotlight Item

enum SpotlightItem: Identifiable {
    case tag(Tag)
    case snippet(Snippet)
    case allSnippetsOption
    case clipboardHistoryFolder
    case historyEntry(ClipboardHistoryEntry)
    case untaggedFolder

    var id: String {
        switch self {
        case .tag(let tag):
            return "tag-\(tag.id.uuidString)"
        case .snippet(let snippet):
            return "snippet-\(snippet.id.uuidString)"
        case .allSnippetsOption:
            return "all-snippets"
        case .clipboardHistoryFolder:
            return "clipboard-history-folder"
        case .historyEntry(let entry):
            return "history-\(entry.id.uuidString)"
        case .untaggedFolder:
            return "untagged-folder"
        }
    }

    var tag: Tag? {
        if case .tag(let tag) = self {
            return tag
        }
        return nil
    }

    var snippet: Snippet? {
        if case .snippet(let snippet) = self {
            return snippet
        }
        return nil
    }
}

// MARK: - Spotlight Item Row View

struct SpotlightItemRow: View {
    let item: SpotlightItem
    let isSelected: Bool
    let isMultiSelected: Bool
    let snippetCount: Int?
    let tagStore: TagStore
    let onPromoteToSnippet: (ClipboardHistoryEntry) -> Void
    let onDeleteSnippet: (Snippet) -> Void
    let onDeleteSelected: () -> Void
    let onToggleCheck: (Snippet) -> Void

    private var isNavigable: Bool {
        switch item {
        case .tag, .allSnippetsOption, .clipboardHistoryFolder, .untaggedFolder:
            return true
        case .snippet, .historyEntry:
            return false
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox — its own tap target, separate from the row's normal
            // click behavior (copy + dismiss for snippets). Only snippets are
            // selectable/deletable this way, not tags/folders/history entries.
            if let snippet = item.snippet {
                Button(action: { onToggleCheck(snippet) }) {
                    Image(systemName: isMultiSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isMultiSelected ? .accentColor : .secondary)
                        .font(.body)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }

            // Icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.body)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(subtitleBackground)
                            .foregroundColor(subtitleForeground)
                            .cornerRadius(3)
                    }

                    Spacer()

                    if let count = snippetCount {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tagColor ?? Color.accentColor)
                            .cornerRadius(8)
                    }

                    if isNavigable {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }

                if let detail = detailText {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Tags for snippets
                if case .snippet(let snippet) = item, !snippet.tagIDs.isEmpty {
                    TagListView(tagIDs: snippet.tagIDs, tagStore: tagStore)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isMultiSelected ? Color.accentColor.opacity(0.2)
                : isSelected ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .contentShape(Rectangle())
        .contextMenu {
            if case .historyEntry(let entry) = item {
                Button("Save as Snippet") {
                    onPromoteToSnippet(entry)
                }
            } else if let snippet = item.snippet {
                if isMultiSelected {
                    Button("Delete Selected", role: .destructive) {
                        onDeleteSelected()
                    }
                } else {
                    Button("Delete", role: .destructive) {
                        onDeleteSnippet(snippet)
                    }
                }
            }
        }
    }

    private var iconName: String {
        switch item {
        case .tag:
            return "folder.fill"
        case .snippet(let snippet):
            return snippet.isFavorite ? "star.fill" : "doc.text"
        case .allSnippetsOption:
            return "doc.on.doc.fill"
        case .clipboardHistoryFolder, .historyEntry:
            return "doc.on.clipboard"
        case .untaggedFolder:
            return "tray.fill"
        }
    }

    private var iconColor: Color {
        switch item {
        case .tag(let tag):
            return tag.color
        case .snippet(let snippet):
            return snippet.isFavorite ? .yellow : .secondary
        case .allSnippetsOption:
            return .accentColor
        case .clipboardHistoryFolder, .historyEntry, .untaggedFolder:
            return .secondary
        }
    }

    private var tagColor: Color? {
        if case .tag(let tag) = item {
            return tag.color
        }
        return nil
    }

    private var title: String {
        switch item {
        case .tag(let tag):
            return tag.name
        case .snippet(let snippet):
            return snippet.title
        case .allSnippetsOption:
            return "All Snippets"
        case .clipboardHistoryFolder:
            return "Clipboard History"
        case .historyEntry(let entry):
            let firstLine = entry.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n", maxSplits: 1)
                .first.map(String.init) ?? entry.content
            return String(firstLine.prefix(60))
        case .untaggedFolder:
            return "Untagged"
        }
    }

    private var subtitle: String? {
        switch item {
        case .snippet(let snippet):
            return snippet.trigger.isEmpty ? nil : snippet.trigger
        case .historyEntry(let entry):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: entry.capturedAt, relativeTo: Date())
        default:
            return nil
        }
    }

    private var subtitleBackground: Color {
        Color.accentColor.opacity(0.2)
    }

    private var subtitleForeground: Color {
        Color.accentColor
    }

    private var detailText: String? {
        switch item {
        case .snippet(let snippet):
            return snippet.content
        case .historyEntry(let entry):
            return entry.content
        default:
            return nil
        }
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutHint: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tag List View

struct TagListView: View {
    let tagIDs: [UUID]
    let tagStore: TagStore

    var tags: [Tag] {
        tagStore.tags(byIDs: tagIDs)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                Text(tag.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tag.color.opacity(0.2))
                    .foregroundColor(tag.color)
                    .cornerRadius(3)
            }
        }
    }
}

#Preview {
    let viewModel = SnippetViewModel()
    return SpotlightSearchView()
        .environmentObject(viewModel)
        .environmentObject(viewModel.tagStore)
        .environmentObject(ClipboardHistoryService.shared)
}
