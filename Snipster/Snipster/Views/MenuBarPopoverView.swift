//
//  MenuBarPopoverView.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var viewModel: SnippetViewModel
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedTag: Tag? = nil
    @State private var sortOption: SortOption = .title
    @State private var showFavoritesOnly: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar and controls
            VStack(spacing: 8) {
                SearchBar(text: $viewModel.searchText, isFocused: $searchFieldFocused)

                if !viewModel.snippetStore.snippets.isEmpty {
                    HStack(spacing: 12) {
                        // Favorites toggle
                        Button(action: { showFavoritesOnly.toggle() }) {
                            Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                                .foregroundColor(showFavoritesOnly ? .yellow : .secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help(showFavoritesOnly ? "Show all snippets" : "Show favorites only")

                        Divider()
                            .frame(height: 20)

                        // Sort picker
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        Divider()
                            .frame(height: 20)

                        Spacer()

                        // Tag filter
                        TagFilterBar(selectedTag: $selectedTag, allSnippets: viewModel.snippetStore.snippets)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding()

            Divider()

            // Snippet list in scrollable box
            if viewModel.hasSnippets {
                SnippetListView(selectedTag: $selectedTag, sortOption: $sortOption, showFavoritesOnly: $showFavoritesOnly)
            } else {
                EmptyStateView()
            }

            Divider()

            // Bottom toolbar
            BottomToolbar()
        }
        .frame(width: 450, height: 600)
        .onAppear {
            searchFieldFocused = true
        }
    }
}

struct TagFilterBar: View {
    @Binding var selectedTag: Tag?
    let allSnippets: [Snippet]
    @EnvironmentObject var tagStore: TagStore

    var allTags: [Tag] {
        // Get unique tag IDs from all snippets
        var tagIDs = Set<UUID>()
        for snippet in allSnippets {
            for tagID in snippet.tagIDs {
                tagIDs.insert(tagID)
            }
        }
        return tagStore.tags(byIDs: Array(tagIDs)).sorted { $0.name < $1.name }
    }

    var body: some View {
        Menu {
            Button {
                selectedTag = nil
            } label: {
                Text("All Tags")
            }

            if !allTags.isEmpty {
                Divider()

                ForEach(allTags) { tag in
                    Button {
                        selectedTag = tag
                    } label: {
                        Label {
                            Text(tag.name)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(tag.color)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(selectedTag?.color ?? Color.accentColor)
                    .frame(width: 7, height: 7)
                Text(selectedTag?.name ?? "All Tags")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search snippets...", text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Snippets Yet")
                .font(.headline)

            Text("Click the + button below to create your first snippet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct BottomToolbar: View {
    @EnvironmentObject var viewModel: SnippetViewModel

    var body: some View {
        HStack {
            Button(action: {
                WindowHelper.openSnippetDetailWindow(mode: .add, viewModel: viewModel)
            }) {
                Label("New Snippet", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            Spacer()

            Button(action: {
                WindowHelper.openSettingsWindow(viewModel: viewModel)
            }) {
                Image(systemName: "gear")
            }

            Divider()
                .frame(height: 20)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
    }
}

#Preview {
    MenuBarPopoverView()
        .environmentObject(SnippetViewModel())
}
